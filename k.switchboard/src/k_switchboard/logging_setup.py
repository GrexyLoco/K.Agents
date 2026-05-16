"""Logging-Konfiguration für K.Switchboard."""

from __future__ import annotations

import json
import logging
import logging.handlers
import sys
from datetime import datetime, timezone
from pathlib import Path

from .config import SwitchboardConfig


class _JsonFormatter(logging.Formatter):
    """Formatiert Log-Einträge als JSON-Zeilen für strukturiertes Datei-Logging."""

    def format(self, record: logging.LogRecord) -> str:
        log_data: dict = {
            "timestamp": datetime.fromtimestamp(
                record.created, tz=timezone.utc
            ).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_data, ensure_ascii=False)


def setup_logging(config: SwitchboardConfig, log_level: str = "INFO") -> None:
    """Konfiguriert das Logging-System mit Konsolen- und Datei-Handler.

    Konsolen-Handler: Human-readable Format via rich (falls installiert).
    Datei-Handler: JSON-Format mit automatischer Rotation (10 MB, 5 Backup-Dateien).

    Args:
        config: Switchboard-Konfiguration (wird für Log-Verzeichnis genutzt).
        log_level: Log-Level als String (z.B. 'INFO', 'DEBUG', 'WARNING').
    """
    numeric_level = getattr(logging, log_level.upper(), logging.INFO)
    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)

    # Vorhandene Handler entfernen um Duplikate zu vermeiden
    root_logger.handlers.clear()

    # Konsolen-Handler via rich (menschenlesbar)
    try:
        from rich.logging import RichHandler

        console_handler: logging.Handler = RichHandler(
            level=numeric_level,
            show_path=False,
            rich_tracebacks=True,
        )
    except ImportError:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(numeric_level)
        console_handler.setFormatter(
            logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")
        )

    root_logger.addHandler(console_handler)

    # Datei-Handler (JSON-Format, rotierend)
    log_dir: Path = config.log_dir
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "k-switchboard.log"

    file_handler = logging.handlers.RotatingFileHandler(
        log_file,
        maxBytes=10 * 1024 * 1024,  # 10 MB pro Datei
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setLevel(numeric_level)
    file_handler.setFormatter(_JsonFormatter())
    root_logger.addHandler(file_handler)

    # Uvicorn-Access-Log nicht doppelt ausgeben
    logging.getLogger("uvicorn.access").propagate = False
    # httpx-Requests nur bei Warnungen loggen
    logging.getLogger("httpx").setLevel(logging.WARNING)
