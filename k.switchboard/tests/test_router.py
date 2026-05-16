"""Tests für die Router-Logik."""

from __future__ import annotations

import pytest

from k_switchboard.config import SwitchboardConfig
from k_switchboard.router import is_ollama_model, resolve_model


@pytest.fixture
def config() -> SwitchboardConfig:
    return SwitchboardConfig(
        model_aliases={
            "local-coder": "codellama:13b",
            "local-fast": "llama3.2:3b",
            "claude-alias": "claude-sonnet-latest",
        },
    )


class TestIsOllamaModel:
    def test_alias_auf_ollama_modell(self, config: SwitchboardConfig) -> None:
        assert is_ollama_model("local-coder", config) is True

    def test_alias_auf_claude_modell(self, config: SwitchboardConfig) -> None:
        assert is_ollama_model("claude-alias", config) is False

    def test_direkter_ollama_tag_mit_doppelpunkt(self, config: SwitchboardConfig) -> None:
        assert is_ollama_model("mistral:7b", config) is True

    def test_claude_modell_ohne_alias(self, config: SwitchboardConfig) -> None:
        assert is_ollama_model("claude-sonnet-latest", config) is False

    def test_unbekanntes_modell_ohne_doppelpunkt(self, config: SwitchboardConfig) -> None:
        assert is_ollama_model("unbekanntes-modell", config) is False

    def test_direkter_ollama_tag_ohne_alias(self, config: SwitchboardConfig) -> None:
        assert is_ollama_model("llama3:latest", config) is True

    def test_alias_local_fast(self, config: SwitchboardConfig) -> None:
        assert is_ollama_model("local-fast", config) is True


class TestResolveModel:
    def test_alias_auf_ollama_gibt_ollama_backend(
        self, config: SwitchboardConfig
    ) -> None:
        resolved, backend = resolve_model("local-coder", config)
        assert resolved == "codellama:13b"
        assert backend == "ollama"

    def test_alias_auf_claude_gibt_anthropic_backend(
        self, config: SwitchboardConfig
    ) -> None:
        resolved, backend = resolve_model("claude-alias", config)
        assert resolved == "claude-sonnet-latest"
        assert backend == "anthropic"

    def test_direkter_ollama_tag(self, config: SwitchboardConfig) -> None:
        resolved, backend = resolve_model("mistral:7b", config)
        assert resolved == "mistral:7b"
        assert backend == "ollama"

    def test_claude_modell_direkt(self, config: SwitchboardConfig) -> None:
        resolved, backend = resolve_model("claude-haiku-latest", config)
        assert resolved == "claude-haiku-latest"
        assert backend == "anthropic"

    def test_unbekanntes_modell_wird_anthropic(self, config: SwitchboardConfig) -> None:
        resolved, backend = resolve_model("gpt-4-turbo", config)
        assert resolved == "gpt-4-turbo"
        assert backend == "anthropic"

    def test_local_fast_alias_aufloesen(self, config: SwitchboardConfig) -> None:
        resolved, backend = resolve_model("local-fast", config)
        assert resolved == "llama3.2:3b"
        assert backend == "ollama"
