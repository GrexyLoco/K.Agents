"""Provider-Implementierungen: Anthropic Passthrough und Ollama-Proxy."""

from __future__ import annotations

import json
import logging
from typing import AsyncIterator

import httpx
from fastapi import Request
from fastapi.responses import Response, StreamingResponse

from .config import SwitchboardConfig

logger = logging.getLogger(__name__)

# Headers die niemals an den Provider weitergeleitet werden
_EXCLUDED_REQUEST_HEADERS = frozenset(
    {
        "host",
        "content-length",
        "transfer-encoding",
        "connection",
        "x-k-switchboard-fallback-used",
    }
)
_EXCLUDED_RESPONSE_HEADERS = frozenset(
    {"content-encoding", "transfer-encoding", "content-length", "connection"}
)


async def passthrough_anthropic(
    request: Request,
    resolved_model: str,
    config: SwitchboardConfig,
) -> Response:
    """Leitet einen Request transparent an die Anthropic API weiter.

    Ersetzt das model-Feld im Body und leitet alle relevanten Headers
    (inkl. x-api-key, anthropic-version etc.) bitidentisch weiter.
    Unterstützt Streaming via Server-Sent Events (text/event-stream).

    Args:
        request: Der eingehende FastAPI-Request.
        resolved_model: Der aufgelöste Anthropic-Modellname.
        config: Switchboard-Konfiguration mit anthropic_base_url.

    Returns:
        Response oder StreamingResponse vom Anthropic-Provider.
    """
    body_bytes = await request.body()

    try:
        body_json = json.loads(body_bytes)
    except json.JSONDecodeError:
        body_json = {}

    if body_json.get("model") == resolved_model:
        modified_body = body_bytes
    else:
        body_json["model"] = resolved_model
        modified_body = json.dumps(body_json, separators=(",", ":")).encode("utf-8")

    # Alle Original-Headers außer ausgeschlossene weiterleiten
    forward_headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower() not in _EXCLUDED_REQUEST_HEADERS
    }
    target_url = f"{config.anthropic_base_url}/v1/messages"
    is_streaming = body_json.get("stream", False)

    if is_streaming:
        # Client offen halten während der Stream läuft
        client = httpx.AsyncClient(timeout=httpx.Timeout(300.0))
        req = client.build_request(
            "POST", target_url, content=modified_body, headers=forward_headers
        )
        upstream = await client.send(req, stream=True)

        response_headers = {
            k: v
            for k, v in upstream.headers.items()
            if k.lower() not in _EXCLUDED_RESPONSE_HEADERS
        }

        async def _generate() -> AsyncIterator[bytes]:
            try:
                async for chunk in upstream.aiter_bytes():
                    yield chunk
            finally:
                await upstream.aclose()
                await client.aclose()

        return StreamingResponse(
            _generate(),
            status_code=upstream.status_code,
            headers=response_headers,
            media_type="text/event-stream",
        )
    else:
        async with httpx.AsyncClient(timeout=httpx.Timeout(300.0)) as client:
            upstream = await client.post(
                target_url,
                content=modified_body,
                headers=forward_headers,
            )

        response_headers = {
            k: v
            for k, v in upstream.headers.items()
            if k.lower() not in _EXCLUDED_RESPONSE_HEADERS
        }
        return Response(
            content=upstream.content,
            status_code=upstream.status_code,
            headers=response_headers,
            media_type=upstream.headers.get("content-type", "application/json"),
        )


def _convert_ollama_to_anthropic(ollama_response: dict) -> dict:
    """Konvertiert eine Ollama-Chat-Response in das Anthropic-Messages-API-Format."""
    message = ollama_response.get("message", {})
    content = message.get("content", "")
    model = ollama_response.get("model", "unknown")

    # Token-Nutzung aus Ollama-Metadaten extrahieren
    input_tokens = ollama_response.get("prompt_eval_count", 0)
    output_tokens = ollama_response.get("eval_count", 0)

    return {
        "id": f"msg_ollama_{ollama_response.get('created_at', 'unknown')}",
        "type": "message",
        "role": "assistant",
        "content": [{"type": "text", "text": content}],
        "model": model,
        "stop_reason": "end_turn",
        "stop_sequence": None,
        "usage": {
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
        },
    }


async def proxy_ollama(
    request: Request,
    resolved_model: str,
    config: SwitchboardConfig,
) -> Response:
    """Leitet einen Anthropic-kompatiblen Request an Ollama weiter.

    Konvertiert das Anthropic-Request-Format in das Ollama-Chat-Format
    und die Response zurück in das Anthropic-Messages-Format.
    Unterstützt Streaming.

    Args:
        request: Der eingehende FastAPI-Request im Anthropic-Format.
        resolved_model: Der aufgelöste Ollama-Modellname (z.B. 'llama3.2:3b').
        config: Switchboard-Konfiguration mit ollama_base_url.

    Returns:
        Response im Anthropic-kompatiblen Format.
    """
    body_bytes = await request.body()

    try:
        body_json = json.loads(body_bytes)
    except json.JSONDecodeError:
        body_json = {}

    is_streaming = body_json.get("stream", False)

    # Anthropic-Format zu Ollama-Chat-Format konvertieren
    ollama_messages = []
    for msg in body_json.get("messages", []):
        content = msg.get("content", "")
        if isinstance(content, list):
            # Content-Blöcke (z.B. Text-Blöcke) zu String zusammenführen
            text_parts = [
                block.get("text", "")
                for block in content
                if block.get("type") == "text"
            ]
            content = "".join(text_parts)
        ollama_messages.append({"role": msg.get("role", "user"), "content": content})

    ollama_body: dict = {
        "model": resolved_model,
        "messages": ollama_messages,
        "stream": is_streaming,
    }

    # Optionale Parameter übernehmen
    if "max_tokens" in body_json:
        ollama_body["options"] = {"num_predict": body_json["max_tokens"]}

    target_url = f"{config.ollama_base_url}/api/chat"
    headers = {
        "content-type": "application/json",
        "authorization": "Bearer ollama",
    }

    if is_streaming:
        client = httpx.AsyncClient(timeout=httpx.Timeout(300.0))
        req = client.build_request("POST", target_url, json=ollama_body, headers=headers)
        upstream = await client.send(req, stream=True)

        async def _stream_ollama_as_sse() -> AsyncIterator[bytes]:
            message_id = f"msg_ollama_{resolved_model.replace(':', '_')}"
            message_start = {
                "type": "message_start",
                "message": {
                    "id": message_id,
                    "type": "message",
                    "role": "assistant",
                    "content": [],
                    "model": resolved_model,
                    "stop_reason": None,
                    "stop_sequence": None,
                    "usage": {"input_tokens": 0, "output_tokens": 0},
                },
            }
            content_start = {
                "type": "content_block_start",
                "index": 0,
                "content_block": {"type": "text", "text": ""},
            }
            yield f"data: {json.dumps(message_start)}\n\n".encode("utf-8")
            yield f"data: {json.dumps(content_start)}\n\n".encode("utf-8")

            try:
                async for line in upstream.aiter_lines():
                    if not line:
                        continue
                    try:
                        chunk = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    content_delta = chunk.get("message", {}).get("content", "")
                    if content_delta:
                        sse_event = {
                            "type": "content_block_delta",
                            "index": 0,
                            "delta": {"type": "text_delta", "text": content_delta},
                        }
                        yield f"data: {json.dumps(sse_event)}\n\n".encode("utf-8")
                    if chunk.get("done", False):
                        usage = {
                            "input_tokens": chunk.get("prompt_eval_count", 0),
                            "output_tokens": chunk.get("eval_count", 0),
                        }
                        content_stop = {"type": "content_block_stop", "index": 0}
                        message_delta = {
                            "type": "message_delta",
                            "delta": {"stop_reason": "end_turn", "stop_sequence": None},
                            "usage": usage,
                        }
                        message_stop = {"type": "message_stop"}
                        yield f"data: {json.dumps(content_stop)}\n\n".encode("utf-8")
                        yield f"data: {json.dumps(message_delta)}\n\n".encode("utf-8")
                        yield f"data: {json.dumps(message_stop)}\n\n".encode("utf-8")
                        yield b"data: [DONE]\n\n"
            finally:
                await upstream.aclose()
                await client.aclose()

        return StreamingResponse(
            _stream_ollama_as_sse(),
            status_code=upstream.status_code,
            media_type="text/event-stream",
        )
    else:
        async with httpx.AsyncClient(timeout=httpx.Timeout(300.0)) as client:
            upstream = await client.post(target_url, json=ollama_body, headers=headers)

        if upstream.status_code != 200:
            return Response(
                content=upstream.content,
                status_code=upstream.status_code,
                media_type="application/json",
            )

        ollama_data = upstream.json()
        anthropic_response = _convert_ollama_to_anthropic(ollama_data)
        return Response(
            content=json.dumps(anthropic_response).encode("utf-8"),
            status_code=200,
            media_type="application/json",
        )
