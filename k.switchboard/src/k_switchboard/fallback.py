"""Fallback-Logik: Bei Backend-Fehler auf ein alternatives Modell ausweichen."""

from __future__ import annotations

import logging
from typing import Callable, Awaitable

from fastapi.responses import Response

from .config import SwitchboardConfig

logger = logging.getLogger(__name__)


def _find_fallback(model: str, config: SwitchboardConfig) -> str | None:
    """Sucht die erste konfigurierte Fallback-Option für das angegebene Modell."""
    for chain in config.fallback_chains:
        if chain.from_ == model:
            return chain.to
    return None


async def execute_with_fallback(
    model: str,
    request_func: Callable[[str], Awaitable[Response]],
    config: SwitchboardConfig,
) -> Response:
    """Führt request_func aus und fällt bei Fehler auf ein Ersatz-Modell zurück.

    Versucht zuerst das primäre Modell. Bei HTTP-Fehler (4xx/5xx) oder
    Netzwerkfehler wird maximal ein Fallback aus der konfigurierten
    Fallback-Kette versucht.

    Der Header X-K-Switchboard-Fallback-Used wird nur an den Client
    gesendet, niemals ans Backend weitergeleitet.

    Args:
        model: Der ursprünglich angeforderte (bereits aufgelöste) Modellname.
        request_func: Async-Funktion die einen Modellnamen entgegennimmt
                      und eine Response zurückgibt.
        config: Switchboard-Konfiguration mit Fallback-Ketten.

    Returns:
        Response vom primären oder Fallback-Modell.

    Raises:
        RuntimeError: Wenn weder primäres noch Fallback-Modell erreichbar sind
                      und kein Fallback konfiguriert ist.
    """
    primary_error: str | None = None
    primary_response: Response | None = None

    # Primären Request versuchen
    try:
        response = await request_func(model)
        if response.status_code < 400:
            return response
        primary_error = f"HTTP {response.status_code}"
        primary_response = response
    except Exception as exc:
        primary_error = str(exc)
        primary_response = None

    logger.warning(
        "Primäres Modell '%s' fehlgeschlagen (%s), suche Fallback.",
        model,
        primary_error,
    )

    # Fallback suchen
    fallback_model = _find_fallback(model, config)
    if fallback_model is None:
        logger.warning("Kein Fallback für Modell '%s' konfiguriert.", model)
        if primary_response is not None:
            return primary_response
        raise RuntimeError(
            f"Modell '{model}' nicht erreichbar und kein Fallback konfiguriert"
        )

    logger.info("Fallback: '%s' → '%s'", model, fallback_model)

    try:
        fallback_response = await request_func(fallback_model)
    except Exception as exc:
        logger.error(
            "Fallback-Modell '%s' ebenfalls fehlgeschlagen: %s", fallback_model, exc
        )
        if primary_response is not None:
            return primary_response
        raise

    if fallback_response.status_code >= 400:
        logger.error(
            "Fallback-Modell '%s' fehlgeschlagen: HTTP %d",
            fallback_model,
            fallback_response.status_code,
        )
        if primary_response is not None:
            return primary_response
        return fallback_response

    # Fallback-Header nur für den Client setzen
    fallback_response.headers["X-K-Switchboard-Fallback-Used"] = (
        f"{model} -> {fallback_model}"
    )
    return fallback_response
