"""Tages-Kostenerfassung für Modell-Nutzung."""

from __future__ import annotations

import json
import logging
from datetime import date
from pathlib import Path

from .config import SwitchboardConfig

logger = logging.getLogger(__name__)


def _get_costs_file(config: SwitchboardConfig, target_date: date | None = None) -> Path:
    """Gibt den Pfad zur Tages-Kostendatei zurück."""
    today = target_date or date.today()
    config.config_dir.mkdir(parents=True, exist_ok=True)
    return config.config_dir / f"costs-{today.isoformat()}.json"


def _load_costs(path: Path) -> dict:
    """Lädt bestehende Kostendaten oder gibt ein leeres Dict zurück."""
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as exc:
        logger.warning("Kostendatei konnte nicht gelesen werden (%s): %s", path, exc)
        return {}


def _save_costs(path: Path, data: dict) -> None:
    """Speichert Kostendaten atomar via temporäre Datei."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(".tmp")
    with tmp_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    tmp_path.replace(path)


def record_usage(
    model: str,
    input_tokens: int,
    output_tokens: int,
    config: SwitchboardConfig,
) -> None:
    """Erfasst die Token-Nutzung eines Modells für den heutigen Tag.

    Berechnet die Kosten anhand der konfigurierten Preise und aggregiert
    die Tages-Statistiken in einer JSON-Datei im Konfigurationsverzeichnis.

    Args:
        model: Name des verwendeten Modells.
        input_tokens: Anzahl der Input-Tokens.
        output_tokens: Anzahl der Output-Tokens.
        config: Switchboard-Konfiguration mit Preisangaben.
    """
    costs_file = _get_costs_file(config)
    data = _load_costs(costs_file)

    if model not in data:
        data[model] = {"input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0}

    pricing = config.pricing.get(model)
    cost = 0.0
    if pricing:
        cost = (
            input_tokens * pricing.input / 1_000_000
            + output_tokens * pricing.output / 1_000_000
        )

    data[model]["input_tokens"] += input_tokens
    data[model]["output_tokens"] += output_tokens
    data[model]["cost_usd"] = round(data[model]["cost_usd"] + cost, 9)

    _save_costs(costs_file, data)
    logger.debug(
        "Nutzung erfasst: Modell=%s, Input=%d, Output=%d, Kosten=%.6f USD",
        model,
        input_tokens,
        output_tokens,
        cost,
    )


def get_daily_stats(config: SwitchboardConfig) -> dict:
    """Gibt die aggregierten Tages-Statistiken zurück.

    Returns:
        Dict mit Datum, Modell-Nutzung und Gesamt-Kosten des heutigen Tages.
    """
    costs_file = _get_costs_file(config)
    data = _load_costs(costs_file)

    total_cost = sum(entry.get("cost_usd", 0.0) for entry in data.values())

    return {
        "date": date.today().isoformat(),
        "models": data,
        "total_cost_usd": round(total_cost, 6),
    }
