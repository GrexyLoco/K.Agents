"""Routing-Logik: bestimmt, welcher Provider (Ollama oder Anthropic) ein Modell bedient."""

from __future__ import annotations

from .config import SwitchboardConfig


def is_ollama_model(model_name: str, config: SwitchboardConfig) -> bool:
    """Prüft ob ein Modell zu Ollama geroutet werden soll.

    Gibt True zurück wenn:
    - model_name ist ein bekannter Alias, der auf ein Ollama-Modell zeigt
    - model_name enthält ':' (direkter Ollama-Tag wie 'llama3.2:3b')
    """
    if model_name in config.model_aliases:
        resolved = config.model_aliases[model_name]
        # Aufgelöster Alias ist Ollama wenn er ':' enthält oder selbst ein Alias auf Ollama ist
        return ":" in resolved

    return ":" in model_name


def resolve_model(model_name: str, config: SwitchboardConfig) -> tuple[str, str]:
    """Löst einen Modellnamen auf und bestimmt den Ziel-Provider.

    Args:
        model_name: Der vom Client angeforderte Modellname (ggf. ein Alias).
        config: Switchboard-Konfiguration mit Alias-Mapping.

    Returns:
        Tuple aus (aufgelöster Modellname, Provider: 'ollama' oder 'anthropic').
    """
    if model_name in config.model_aliases:
        resolved = config.model_aliases[model_name]
        provider = "ollama" if is_ollama_model(resolved, config) else "anthropic"
        return resolved, provider

    if ":" in model_name:
        return model_name, "ollama"

    return model_name, "anthropic"
