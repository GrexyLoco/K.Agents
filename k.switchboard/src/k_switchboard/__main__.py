"""Entry-Point für K.Switchboard: CLI und Modul-Start."""

from __future__ import annotations


def main() -> None:
    """Startet den K.Switchboard-Proxy-Server.

    Lädt die Konfiguration aus dem plattformspezifischen Verzeichnis,
    richtet das Logging ein und startet uvicorn auf dem konfigurierten Port.
    """
    import uvicorn

    from .config import load_config
    from .logging_setup import setup_logging
    from .server import create_app

    config = load_config()
    setup_logging(config)

    app = create_app(config)

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=config.port,
        log_config=None,  # Eigenes Logging-Setup übernimmt
    )


if __name__ == "__main__":
    main()
