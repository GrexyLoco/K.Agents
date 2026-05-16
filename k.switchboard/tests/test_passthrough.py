"""Tests für den Anthropic-Passthrough-Backend."""

from __future__ import annotations

import json

import httpx
import pytest
import respx
from fastapi.responses import StreamingResponse
from starlette.requests import Request as StarletteRequest

from k_switchboard.backends import passthrough_anthropic
from k_switchboard.config import SwitchboardConfig


def _make_mock_request(
    body: dict,
    extra_headers: dict[str, str] | None = None,
) -> StarletteRequest:
    """Erstellt einen minimalen Starlette-Request für Tests.

    Args:
        body: Der JSON-Body des Requests.
        extra_headers: Optionale zusätzliche Headers.

    Returns:
        Starlette-Request-Objekt mit dem angegebenen Body.
    """
    body_bytes = json.dumps(body).encode("utf-8")

    default_headers: dict[str, str] = {
        "content-type": "application/json",
        "x-api-key": "sk-test-key",
        "anthropic-version": "2023-06-01",
        "content-length": str(len(body_bytes)),
    }
    if extra_headers:
        default_headers.update(extra_headers)

    scope = {
        "type": "http",
        "method": "POST",
        "path": "/v1/messages",
        "headers": [
            (k.lower().encode(), v.encode()) for k, v in default_headers.items()
        ],
        "query_string": b"",
    }

    async def receive():
        return {"type": "http.request", "body": body_bytes, "more_body": False}

    return StarletteRequest(scope, receive)


@pytest.fixture
def config() -> SwitchboardConfig:
    return SwitchboardConfig(anthropic_base_url="https://api.anthropic.com")


class TestPassthroughAnthropic:
    @respx.mock
    async def test_leitet_request_an_anthropic_weiter(
        self, config: SwitchboardConfig
    ) -> None:
        """Der Request wird korrekt an den Anthropic-Endpoint weitergeleitet."""
        mock_route = respx.post("https://api.anthropic.com/v1/messages").mock(
            return_value=httpx.Response(200, json={"id": "msg_123", "type": "message"})
        )

        request = _make_mock_request(
            {"model": "claude-sonnet-latest", "messages": [{"role": "user", "content": "Hallo"}]}
        )
        response = await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert response.status_code == 200
        assert mock_route.called

    @respx.mock
    async def test_model_wird_im_body_ersetzt(
        self, config: SwitchboardConfig
    ) -> None:
        """Das model-Feld im Body wird durch den aufgelösten Modellnamen ersetzt."""
        captured_body: dict = {}

        def capture(request: httpx.Request) -> httpx.Response:
            captured_body.update(json.loads(request.content))
            return httpx.Response(200, json={"id": "msg_123", "type": "message"})

        respx.post("https://api.anthropic.com/v1/messages").mock(side_effect=capture)

        request = _make_mock_request({"model": "original-alias", "messages": []})
        await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert captured_body.get("model") == "claude-sonnet-latest"

    @respx.mock
    async def test_api_key_header_wird_weitergeleitet(
        self, config: SwitchboardConfig
    ) -> None:
        """Der x-api-key Header wird unverändert ans Backend weitergeleitet."""
        captured_headers: dict[str, str] = {}

        def capture(request: httpx.Request) -> httpx.Response:
            captured_headers.update(dict(request.headers))
            return httpx.Response(200, json={"id": "msg_123", "type": "message"})

        respx.post("https://api.anthropic.com/v1/messages").mock(side_effect=capture)

        request = _make_mock_request(
            {"model": "claude-sonnet-latest", "messages": []},
            extra_headers={"x-api-key": "sk-prod-key-12345"},
        )
        await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert "x-api-key" in captured_headers
        assert captured_headers["x-api-key"] == "sk-prod-key-12345"

    @respx.mock
    async def test_client_host_header_wird_nicht_weitergeleitet(
        self, config: SwitchboardConfig
    ) -> None:
        """Der Client-host-Header darf nicht ans Backend weitergeleitet werden."""
        captured_headers: dict[str, str] = {}

        def capture(request: httpx.Request) -> httpx.Response:
            captured_headers.update(dict(request.headers))
            return httpx.Response(200, json={"id": "msg_123", "type": "message"})

        respx.post("https://api.anthropic.com/v1/messages").mock(side_effect=capture)

        request = _make_mock_request(
            {"model": "claude-sonnet-latest", "messages": []},
            extra_headers={"host": "localhost:3456"},
        )
        await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert captured_headers["host"] == "api.anthropic.com"

    @respx.mock
    async def test_fallback_header_wird_nicht_weitergeleitet(
        self, config: SwitchboardConfig
    ) -> None:
        """Switchboard-interne Fallback-Header dürfen nicht ans Backend gehen."""
        captured_headers: dict[str, str] = {}

        def capture(request: httpx.Request) -> httpx.Response:
            captured_headers.update(dict(request.headers))
            return httpx.Response(200, json={"id": "msg_123", "type": "message"})

        respx.post("https://api.anthropic.com/v1/messages").mock(side_effect=capture)

        request = _make_mock_request(
            {"model": "claude-sonnet-latest", "messages": []},
            extra_headers={"x-k-switchboard-fallback-used": "local -> fallback"},
        )
        await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert "x-k-switchboard-fallback-used" not in captured_headers

    @respx.mock
    async def test_anthropic_version_header_wird_weitergeleitet(
        self, config: SwitchboardConfig
    ) -> None:
        """Der anthropic-version Header wird korrekt weitergeleitet."""
        captured_headers: dict[str, str] = {}

        def capture(request: httpx.Request) -> httpx.Response:
            captured_headers.update(dict(request.headers))
            return httpx.Response(200, json={"id": "msg_123", "type": "message"})

        respx.post("https://api.anthropic.com/v1/messages").mock(side_effect=capture)

        request = _make_mock_request(
            {"model": "claude-sonnet-latest", "messages": []},
            extra_headers={"anthropic-version": "2023-06-01"},
        )
        await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert "anthropic-version" in captured_headers
        assert captured_headers["anthropic-version"] == "2023-06-01"

    @respx.mock
    async def test_streaming_gibt_streaming_response_zurueck(
        self, config: SwitchboardConfig
    ) -> None:
        """Streaming-Requests werden als StreamingResponse zurückgegeben."""
        sse_data = b"data: {\"type\": \"message_start\"}\n\ndata: [DONE]\n\n"

        respx.post("https://api.anthropic.com/v1/messages").mock(
            return_value=httpx.Response(
                200,
                content=sse_data,
                headers={"content-type": "text/event-stream"},
            )
        )

        request = _make_mock_request(
            {"model": "claude-sonnet-latest", "messages": [], "stream": True}
        )
        response = await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert isinstance(response, StreamingResponse)

    @respx.mock
    async def test_fehler_response_wird_durchgeleitet(
        self, config: SwitchboardConfig
    ) -> None:
        """HTTP-Fehler (z.B. 401) vom Backend werden an den Client weitergeleitet."""
        respx.post("https://api.anthropic.com/v1/messages").mock(
            return_value=httpx.Response(
                401, json={"error": {"type": "authentication_error", "message": "Unauthorized"}}
            )
        )

        request = _make_mock_request(
            {"model": "claude-sonnet-latest", "messages": []}
        )
        response = await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert response.status_code == 401

    @respx.mock
    async def test_body_wird_unveraendert_weitergeleitet(
        self, config: SwitchboardConfig
    ) -> None:
        """Alle Body-Felder außer model werden unverändert weitergeleitet."""
        captured_body: dict = {}

        def capture(request: httpx.Request) -> httpx.Response:
            captured_body.update(json.loads(request.content))
            return httpx.Response(200, json={"id": "msg_123", "type": "message"})

        respx.post("https://api.anthropic.com/v1/messages").mock(side_effect=capture)

        request = _make_mock_request({
            "model": "claude-sonnet-latest",
            "messages": [{"role": "user", "content": "Testinhalt"}],
            "max_tokens": 1024,
            "temperature": 0.7,
        })
        await passthrough_anthropic(request, "claude-sonnet-latest", config)

        assert captured_body["max_tokens"] == 1024
        assert captured_body["temperature"] == 0.7
        assert captured_body["messages"][0]["content"] == "Testinhalt"
