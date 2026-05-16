"""FastAPI-Server: Haupt-Proxy-Logik für K.Switchboard."""

from __future__ import annotations

import json
import logging
import time

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, Response

from .backends import passthrough_anthropic, proxy_ollama
from .config import SwitchboardConfig
from .costing import get_daily_stats, record_usage
from .fallback import execute_with_fallback
from .router import resolve_model

logger = logging.getLogger(__name__)


def _select_usage_model(
    requested_model: str,
    resolved_model: str,
    response: Response,
    config: SwitchboardConfig,
) -> str:
    """Bestimmt das Modell, unter dem Token-Nutzung verbucht wird."""
    fallback_header = response.headers.get("x-k-switchboard-fallback-used")
    if fallback_header and " -> " in fallback_header:
        fallback_model = fallback_header.rsplit(" -> ", maxsplit=1)[1]
        fallback_resolved_model, _ = resolve_model(fallback_model, config)
        return fallback_model if fallback_model in config.pricing else fallback_resolved_model

    return requested_model if requested_model in config.pricing else resolved_model


def create_app(config: SwitchboardConfig) -> FastAPI:
    """Erstellt und konfiguriert die FastAPI-Anwendung.

    Args:
        config: Geladene Switchboard-Konfiguration.

    Returns:
        Konfigurierte FastAPI-Instanz, bereit für uvicorn.
    """
    app = FastAPI(
        title="K.Switchboard",
        description="Transparenter HTTP-Proxy zwischen Claude Max und Ollama",
        version="0.1.0",
        docs_url="/docs",
        redoc_url=None,
    )

    @app.middleware("http")
    async def _log_requests(request: Request, call_next):
        """Logt alle Requests mit Methode, Pfad, Status-Code und Latenz."""
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start) * 1000
        logger.info(
            "%s %s → %d (%.1f ms)",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )
        return response

    @app.get("/health")
    async def health() -> dict:
        """Health-Check-Endpoint. Gibt {'status': 'ok'} zurück."""
        return {"status": "ok"}

    @app.get("/stats")
    async def stats() -> JSONResponse:
        """Gibt die aggregierten Tages-Kostenstatistiken zurück."""
        return JSONResponse(content=get_daily_stats(config))

    @app.post("/v1/messages")
    async def proxy_messages(request: Request) -> Response:
        """Haupt-Proxy-Endpoint für die Anthropic Messages API.

        Liest das model-Feld aus dem JSON-Body, routet den Request
        an Anthropic oder Ollama weiter und nutzt Fallback-Logik bei Fehlern.
        Token-Nutzung wird für nicht-streaming Requests erfasst.
        """
        body_bytes = await request.body()

        try:
            body_json = json.loads(body_bytes)
        except json.JSONDecodeError as exc:
            raise HTTPException(
                status_code=400, detail=f"Ungültiger JSON-Body: {exc}"
            ) from exc

        model_name: str | None = body_json.get("model")
        if not model_name:
            raise HTTPException(
                status_code=400, detail="Pflichtfeld 'model' fehlt im Request-Body"
            )

        resolved_model, backend = resolve_model(model_name, config)
        logger.debug(
            "Route: '%s' → '%s' (Backend: %s)", model_name, resolved_model, backend
        )

        async def _request_func(target_model: str) -> Response:
            """Sendet den Request mit dem angegebenen Modellnamen ans Backend."""
            target_resolved_model, target_backend = resolve_model(target_model, config)
            if target_backend == "ollama":
                return await proxy_ollama(request, target_resolved_model, config)
            return await passthrough_anthropic(request, target_resolved_model, config)

        response = await execute_with_fallback(model_name, _request_func, config)

        # Token-Nutzung nur bei erfolgreichen, nicht-streaming Responses erfassen
        if response.status_code == 200 and not body_json.get("stream", False):
            try:
                resp_body = json.loads(response.body)
                usage = resp_body.get("usage", {})
                record_usage(
                    model=_select_usage_model(model_name, resolved_model, response, config),
                    input_tokens=usage.get("input_tokens", 0),
                    output_tokens=usage.get("output_tokens", 0),
                    config=config,
                )
            except (json.JSONDecodeError, AttributeError, KeyError):
                # StreamingResponse hat kein .body — ignorieren
                pass

        return response

    return app
