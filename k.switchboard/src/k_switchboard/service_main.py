"""Windows-Dienst-Host fuer K.Switchboard via pywin32.

Registrierung:  python -m k_switchboard.service_main install
Start:          python -m k_switchboard.service_main start
Stop:           python -m k_switchboard.service_main stop
Deinstallation: python -m k_switchboard.service_main remove

Alternativ via PowerShell-Installer:
    install-windows.ps1 -AsService      # installiert + startet
    install-windows.ps1 -Unregister     # stoppt + entfernt
"""

from __future__ import annotations

import subprocess
import sys
import threading

import servicemanager
import win32event
import win32service
import win32serviceutil


class KSwitchboardService(win32serviceutil.ServiceFramework):
    """Windows-Dienst-Wrapper fuer den K.Switchboard HTTP-Proxy."""

    _svc_name_ = "KSwitchboard"
    _svc_display_name_ = "K.Switchboard Proxy"
    _svc_description_ = (
        "K.Switchboard HTTP-Proxy: leitet KI-Tool-Anfragen an Anthropic oder Ollama weiter."
    )

    def __init__(self, args: list[str]) -> None:
        win32serviceutil.ServiceFramework.__init__(self, args)
        self._stop_event = win32event.CreateEvent(None, 0, 0, None)
        self._process: subprocess.Popen[bytes] | None = None

    def SvcStop(self) -> None:
        """Dienst-Stop-Handler: sendet Stop-Signal und wartet auf Prozess-Ende."""
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self._stop_event)
        if self._process is not None:
            self._process.terminate()
            try:
                self._process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self._process.kill()

    def SvcDoRun(self) -> None:
        """Haupt-Loop: startet k_switchboard als Kindprozess und wartet auf Stop-Signal."""
        servicemanager.LogMsg(
            servicemanager.EVENTLOG_INFORMATION_TYPE,
            servicemanager.PYS_SERVICE_STARTED,
            (self._svc_name_, ""),
        )

        self._process = subprocess.Popen(
            [sys.executable, "-m", "k_switchboard"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        # Auf Stop-Event oder Prozess-Ende warten
        monitor_thread = threading.Thread(target=self._monitor_process, daemon=True)
        monitor_thread.start()

        win32event.WaitForSingleObject(self._stop_event, win32event.INFINITE)

    def _monitor_process(self) -> None:
        """Ueberwacht den Kindprozess; setzt Stop-Event bei unerwartetem Ende."""
        if self._process is not None:
            self._process.wait()
            win32event.SetEvent(self._stop_event)


if __name__ == "__main__":
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(KSwitchboardService)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        win32serviceutil.HandleCommandLine(KSwitchboardService)
