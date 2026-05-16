"""Tests für die Fallback-Logik."""

from __future__ import annotations

import pytest
from fastapi.responses import Response

from k_switchboard.config import FallbackChain, SwitchboardConfig
from k_switchboard.fallback import execute_with_fallback


@pytest.fixture
def config_with_fallback() -> SwitchboardConfig:
    return SwitchboardConfig(
        fallback_chains=[
            FallbackChain(**{"from": "local-coder", "to": "claude-sonnet-latest"}),
            FallbackChain(**{"from": "claude-sonnet-latest", "to": "claude-haiku-latest"}),
        ]
    )


@pytest.fixture
def config_no_fallback() -> SwitchboardConfig:
    return SwitchboardConfig(fallback_chains=[])


class TestExecuteWithFallback:
    async def test_erfolgreicher_request_kein_fallback(
        self, config_with_fallback: SwitchboardConfig
    ) -> None:
        """Bei Erfolg (2xx) wird der Fallback nicht aufgerufen."""
        call_count = {"n": 0}

        async def request_func(model: str) -> Response:
            call_count["n"] += 1
            return Response(content=b'{"ok": true}', status_code=200)

        response = await execute_with_fallback(
            "local-coder", request_func, config_with_fallback
        )
        assert response.status_code == 200
        assert call_count["n"] == 1

    async def test_5xx_fehler_loest_fallback_aus(
        self, config_with_fallback: SwitchboardConfig
    ) -> None:
        """Bei HTTP 5xx wird der konfigurierte Fallback aufgerufen."""
        called_with: list[str] = []

        async def request_func(model: str) -> Response:
            called_with.append(model)
            if model == "local-coder":
                return Response(content=b"Service Unavailable", status_code=503)
            return Response(content=b'{"ok": true}', status_code=200)

        response = await execute_with_fallback(
            "local-coder", request_func, config_with_fallback
        )
        assert response.status_code == 200
        assert called_with == ["local-coder", "claude-sonnet-latest"]

    async def test_4xx_fehler_loest_fallback_aus(
        self, config_with_fallback: SwitchboardConfig
    ) -> None:
        """Bei HTTP 4xx wird ebenfalls der Fallback versucht."""
        called_with: list[str] = []

        async def request_func(model: str) -> Response:
            called_with.append(model)
            if model == "local-coder":
                return Response(content=b"Too Many Requests", status_code=429)
            return Response(content=b'{"ok": true}', status_code=200)

        response = await execute_with_fallback(
            "local-coder", request_func, config_with_fallback
        )
        assert response.status_code == 200
        assert len(called_with) == 2

    async def test_fallback_header_wird_gesetzt(
        self, config_with_fallback: SwitchboardConfig
    ) -> None:
        """Der X-K-Switchboard-Fallback-Used Header wird bei Fallback gesetzt."""

        async def request_func(model: str) -> Response:
            if model == "local-coder":
                return Response(content=b"Fehler", status_code=503)
            return Response(content=b'{"ok": true}', status_code=200)

        response = await execute_with_fallback(
            "local-coder", request_func, config_with_fallback
        )
        assert "x-k-switchboard-fallback-used" in response.headers
        assert (
            "local-coder -> claude-sonnet-latest"
            in response.headers["x-k-switchboard-fallback-used"]
        )

    async def test_kein_fallback_konfiguriert_gibt_fehler_response(
        self, config_no_fallback: SwitchboardConfig
    ) -> None:
        """Ohne Fallback-Konfiguration wird die originale Fehler-Response zurückgegeben."""

        async def request_func(model: str) -> Response:
            return Response(content=b"Fehler", status_code=503)

        response = await execute_with_fallback(
            "unbekanntes-modell", request_func, config_no_fallback
        )
        assert response.status_code == 503
        assert "x-k-switchboard-fallback-used" not in response.headers

    async def test_netzwerkfehler_loest_fallback_aus(
        self, config_with_fallback: SwitchboardConfig
    ) -> None:
        """Auch bei Netzwerkfehlern (Exception) wird der Fallback versucht."""
        called_with: list[str] = []

        async def request_func(model: str) -> Response:
            called_with.append(model)
            if model == "local-coder":
                raise ConnectionError("Ollama nicht erreichbar")
            return Response(content=b'{"ok": true}', status_code=200)

        response = await execute_with_fallback(
            "local-coder", request_func, config_with_fallback
        )
        assert response.status_code == 200
        assert len(called_with) == 2

    async def test_primaerer_request_hat_keinen_fallback_header(
        self, config_with_fallback: SwitchboardConfig
    ) -> None:
        """Bei erfolgreichem primärem Request wird kein Fallback-Header gesetzt."""

        async def request_func(model: str) -> Response:
            return Response(content=b'{"ok": true}', status_code=200)

        response = await execute_with_fallback(
            "local-coder", request_func, config_with_fallback
        )
        assert "x-k-switchboard-fallback-used" not in response.headers
