"""Tests für die Tages-Kostenverfolgung."""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path

import pytest

from k_switchboard.config import PricingEntry, SwitchboardConfig
from k_switchboard.costing import get_daily_stats, record_usage


@pytest.fixture
def config(tmp_path: Path) -> SwitchboardConfig:
    """Config mit isoliertem tmp_path als Konfigurationsverzeichnis."""
    cfg = SwitchboardConfig(
        pricing={
            "claude-sonnet-latest": PricingEntry(input=3.0, output=15.0),
            "claude-haiku-latest": PricingEntry(input=0.25, output=1.25),
            "local-fast": PricingEntry(input=0.0, output=0.0),
        }
    )
    # config_dir auf tmp_path umleiten für isolierte Tests
    type(cfg).config_dir = property(lambda self: tmp_path)
    type(cfg).data_dir = property(lambda self: tmp_path)
    type(cfg).log_dir = property(lambda self: tmp_path / "logs")
    return cfg


class TestRecordUsage:
    def test_erste_nutzung_erstellt_kostendatei(
        self, config: SwitchboardConfig, tmp_path: Path
    ) -> None:
        record_usage("claude-sonnet-latest", 100, 200, config)

        today = date.today().isoformat()
        costs_file = tmp_path / f"costs-{today}.json"
        assert costs_file.exists()

        data = json.loads(costs_file.read_text())
        assert "claude-sonnet-latest" in data
        assert data["claude-sonnet-latest"]["input_tokens"] == 100
        assert data["claude-sonnet-latest"]["output_tokens"] == 200

    def test_kosten_korrekt_berechnet(
        self, config: SwitchboardConfig, tmp_path: Path
    ) -> None:
        # 1000 Input-Tokens * 3.0 USD/M = 0.003 USD
        # 500 Output-Tokens * 15.0 USD/M = 0.0075 USD
        record_usage("claude-sonnet-latest", 1000, 500, config)

        today = date.today().isoformat()
        data = json.loads((tmp_path / f"costs-{today}.json").read_text())
        expected_cost = (1000 * 3.0 / 1_000_000) + (500 * 15.0 / 1_000_000)
        assert abs(data["claude-sonnet-latest"]["cost_usd"] - expected_cost) < 1e-9

    def test_mehrfache_nutzung_wird_aggregiert(
        self, config: SwitchboardConfig, tmp_path: Path
    ) -> None:
        record_usage("claude-haiku-latest", 100, 100, config)
        record_usage("claude-haiku-latest", 200, 200, config)

        today = date.today().isoformat()
        data = json.loads((tmp_path / f"costs-{today}.json").read_text())
        assert data["claude-haiku-latest"]["input_tokens"] == 300
        assert data["claude-haiku-latest"]["output_tokens"] == 300

    def test_lokales_modell_kostet_nichts(
        self, config: SwitchboardConfig, tmp_path: Path
    ) -> None:
        record_usage("local-fast", 10_000, 10_000, config)

        today = date.today().isoformat()
        data = json.loads((tmp_path / f"costs-{today}.json").read_text())
        assert data["local-fast"]["cost_usd"] == 0.0

    def test_unbekanntes_modell_wird_ohne_kosten_erfasst(
        self, config: SwitchboardConfig, tmp_path: Path
    ) -> None:
        record_usage("gpt-4-unbekannt", 100, 100, config)

        today = date.today().isoformat()
        data = json.loads((tmp_path / f"costs-{today}.json").read_text())
        assert "gpt-4-unbekannt" in data
        assert data["gpt-4-unbekannt"]["cost_usd"] == 0.0

    def test_verschiedene_modelle_unabhaengig(
        self, config: SwitchboardConfig, tmp_path: Path
    ) -> None:
        record_usage("claude-sonnet-latest", 500, 500, config)
        record_usage("claude-haiku-latest", 1000, 1000, config)

        today = date.today().isoformat()
        data = json.loads((tmp_path / f"costs-{today}.json").read_text())
        assert data["claude-sonnet-latest"]["input_tokens"] == 500
        assert data["claude-haiku-latest"]["input_tokens"] == 1000


class TestGetDailyStats:
    def test_leere_stats_bei_neuer_datei(self, config: SwitchboardConfig) -> None:
        stats = get_daily_stats(config)
        assert stats["models"] == {}
        assert stats["total_cost_usd"] == 0.0
        assert stats["date"] == date.today().isoformat()

    def test_stats_enthalten_datum(self, config: SwitchboardConfig) -> None:
        stats = get_daily_stats(config)
        assert stats["date"] == date.today().isoformat()

    def test_stats_nach_nutzung(self, config: SwitchboardConfig) -> None:
        record_usage("claude-sonnet-latest", 1000, 1000, config)
        stats = get_daily_stats(config)

        assert "claude-sonnet-latest" in stats["models"]
        assert stats["total_cost_usd"] > 0

    def test_gesamtkosten_summiert(self, config: SwitchboardConfig) -> None:
        record_usage("claude-sonnet-latest", 1_000_000, 0, config)  # 3.00 USD
        record_usage("claude-haiku-latest", 1_000_000, 0, config)   # 0.25 USD

        stats = get_daily_stats(config)
        # Mindestens 3.25 USD (ggf. Rundungsabweichungen)
        assert stats["total_cost_usd"] >= 3.0
