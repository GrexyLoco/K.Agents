"""Konfigurationsmodell und Lade-Logik für K.Switchboard."""

from __future__ import annotations

import os
import platform
from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, Field, ConfigDict


class FallbackChain(BaseModel):
    """Definiert eine Fallback-Kette von einem Modell zum nächsten."""

    from_: str = Field(alias="from")
    to: str

    model_config = ConfigDict(populate_by_name=True)


class PricingEntry(BaseModel):
    """Preise eines Modells in USD per 1M Tokens."""

    input: float
    output: float


def _get_config_dir() -> Path:
    """Ermittelt das plattformspezifische Konfigurationsverzeichnis."""
    if platform.system() == "Windows":
        appdata = os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming"))
        return Path(appdata) / "K.Switchboard"
    return Path.home() / ".config" / "k-switchboard"


def _get_data_dir() -> Path:
    """Ermittelt das plattformspezifische Datenverzeichnis."""
    if platform.system() == "Windows":
        appdata = os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming"))
        return Path(appdata) / "K.Switchboard"
    return Path.home() / ".local" / "share" / "k-switchboard"


class SwitchboardConfig(BaseModel):
    """Hauptkonfiguration für K.Switchboard."""

    port: int = 3456
    anthropic_base_url: str = "https://api.anthropic.com"
    ollama_base_url: str = "http://localhost:11434"
    model_aliases: dict[str, str] = Field(default_factory=dict)
    fallback_chains: list[FallbackChain] = Field(default_factory=list)
    pricing: dict[str, PricingEntry] = Field(default_factory=dict)

    @property
    def config_dir(self) -> Path:
        """Gibt das Konfigurationsverzeichnis zurück."""
        return _get_config_dir()

    @property
    def data_dir(self) -> Path:
        """Gibt das Datenverzeichnis zurück."""
        return _get_data_dir()

    @property
    def log_dir(self) -> Path:
        """Gibt das Log-Verzeichnis zurück."""
        if platform.system() == "Windows":
            return _get_config_dir() / "logs"
        return _get_data_dir() / "logs"


def load_config() -> SwitchboardConfig:
    """Lädt die Konfiguration aus der plattformspezifischen YAML-Datei.

    Gibt eine Standardkonfiguration zurück wenn keine Datei vorhanden ist.
    """
    config_path = _get_config_dir() / "config.yaml"

    if not config_path.exists():
        return SwitchboardConfig()

    with config_path.open("r", encoding="utf-8") as f:
        raw: dict[str, Any] = yaml.safe_load(f) or {}

    return SwitchboardConfig.model_validate(raw)
