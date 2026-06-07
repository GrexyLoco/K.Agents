# 1. Troubleshooting

<!-- markdownlint-disable MD033 MD036 -->

Häufige Fehlerbilder mit Symptomen, Ursachen und Lösungsschritten.

---

<a id="service-startet-nicht"></a>

## 1.1 Service startet nicht

**Symptom:** `Start-Service K.Switchboard` schlägt fehl oder der Service wechselt sofort in den Zustand `Stopped`.

**Ursache 1: Fehlende Konfigurationsdatei**

Die EXE erwartet `%APPDATA%\K.Switchboard\config.json`. Fehlt die Datei beim ersten Start, wird sie automatisch angelegt. Tritt der Fehler trotzdem auf, prüfe ob das Verzeichnis schreibbar ist:

```pwsh
Test-Path "$env:APPDATA\K.Switchboard"
# Wenn false: Verzeichnis manuell anlegen
New-Item -ItemType Directory -Path "$env:APPDATA\K.Switchboard" -Force
```

**Ursache 2: Port bereits belegt** (siehe [Port belegt](#port-belegt))

**Ursache 3: Fehlende Rechte**

Der Service läuft unter `NT AUTHORITY\NetworkService`. Dieses Konto braucht Lesezugriff auf `%APPDATA%\K.Switchboard\`. Da `%APPDATA%` benutzerspezifisch ist, empfehlen sich für produktive Umgebungen Pfade unter `%ProgramData%\K.Switchboard\`.

**Diagnose via Event Log:**

```pwsh
Get-EventLog -LogName Application -Source "K.Switchboard" -Newest 10
```

---

<a id="port-belegt"></a>

## 1.2 Port belegt

**Symptom:** K.Switchboard startet nicht mit dem Fehler `Failed to bind to address http://*:3456` oder der Health-Check schlägt fehl.

**Ursache:** Ein anderer Prozess belegt Port 3456.

**Lösung 1: Prozess identifizieren und beenden**

```pwsh
# Prozess auf Port 3456 finden:
netstat -ano | Select-String ":3456"
# PID aus der Ausgabe nehmen, z. B. 12345:
Stop-Process -Id 12345 -Force
```

**Lösung 2: Port ändern**

Öffne `%APPDATA%\K.Switchboard\config.json` und ändere `Port`. Starte K.Switchboard neu. Aktualisiere anschließend `ANTHROPIC_BASE_URL` auf den neuen Port.

---

<a id="anthropic-auth-fehler"></a>

## 1.3 Anthropic-Auth-Fehler

**Symptom:** Anfragen schlagen fehl mit HTTP 401 oder der Anthropic-Client meldet `authentication_error`.

**Ursache:** Der `ANTHROPIC_API_KEY` wird nicht an Anthropic weitergeleitet.

K.Switchboard leitet **alle Request-Header einschließlich `x-api-key`** unverändert durch. Der API-Key muss im Client korrekt gesetzt sein.

**Diagnose:**

```pwsh
# Test-Anfrage mit explizitem Key:
$headers = @{
    "x-api-key" = $env:ANTHROPIC_API_KEY
    "anthropic-version" = "2023-06-01"
    "content-type" = "application/json"
}
$body = '{"model":"claude-3-5-haiku-20241022","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}'
Invoke-RestMethod -Uri "http://localhost:3456/v1/messages" -Method Post -Headers $headers -Body $body
```

Erscheint der 401 in den K.Switchboard-Logs? Falls nicht, prüfe ob der Client `ANTHROPIC_BASE_URL=http://localhost:3456` wirklich gesetzt hat.

---

<a id="ollama-nicht-erreichbar"></a>

## 1.4 Ollama nicht erreichbar

**Symptom:** Anfragen an Ollama-Modelle (Modellname mit `:`) schlagen fehl mit Verbindungsfehlern.

**Ursache:** Ollama läuft nicht oder ist auf einer anderen Adresse erreichbar.

**Prüfung:**

```pwsh
# Ollama-Status prüfen:
Invoke-RestMethod http://localhost:11434/api/tags
```

Antwortet Ollama auf einem anderen Port oder Host, ändere `OllamaBaseUrl` in `config.json`:

```json
"OllamaBaseUrl": "http://192.168.1.100:11434"
```

**Modell vorhanden?**

```pwsh
# Verfügbare Modelle auflisten:
(Invoke-RestMethod http://localhost:11434/api/tags).models | Select-Object name
```

Ist das angeforderte Modell nicht geladen, in Ollama pullen:

```pwsh
ollama pull codellama:13b
```

---

<a id="fallback-greift-nicht"></a>

## 1.5 Fallback greift nicht

**Symptom:** Bei Fehlern des primären Modells wird kein Fallback verwendet. Der Header `X-K-Switchboard-Fallback-Used` fehlt.

**Ursache 1: FallbackChains nicht konfiguriert**

Prüfe `config.json`: Der Schlüssel in `FallbackChains` muss exakt dem Modellnamen entsprechen, wie er im Request-Body gesendet wird (nach Alias-Auflösung).

**Ursache 2: Primäres Modell gibt 2xx zurück**

Fallback greift nur bei HTTP 4xx/5xx oder Netzwerkfehlern. Ein leeres oder fehlerhaftes Ergebnis mit HTTP 200 löst keinen Fallback aus.

**Diagnose:**

```pwsh
# Aktuellen Config-Stand prüfen:
Invoke-RestMethod http://localhost:3456/config
```

---

<a id="stats-keine-daten"></a>

## 1.6 /stats gibt keine Daten zurück

**Symptom:** `Invoke-RestMethod http://localhost:3456/stats` liefert `totalCostUsd: 0` obwohl Anfragen gestellt wurden.

**Ursache 1: Pricing nicht konfiguriert**

Kostenberechnung erfordert einen Eintrag in `Pricing` für das verwendete Modell. Prüfe `config.json` — der Schlüssel muss dem genauen Modellnamen in der Anthropic-Antwort entsprechen.

**Ursache 2: Kein Anthropic-Response-Body**

Token-Counts werden aus dem Anthropic-Response-Body ausgelesen (`usage.input_tokens` / `usage.output_tokens`). Ollama-Antworten enthalten diese Felder nicht und werden nicht in Kosten umgerechnet.

---

<a id="unerwartete-substitution"></a>

## 1.7 Request wird unerwartet auf Claude substituiert

**Symptom:** Ein Ollama-Modell wird angefragt, aber die Antwort kommt von Claude. Der Response enthält den Header `X-K-Switchboard-Substitution`.

**Diagnose 1: Header lesen**

```pwsh
$response = Invoke-WebRequest -Uri "http://localhost:3456/v1/messages" `
    -Method Post -Headers $headers -Body $body
$response.Headers["X-K-Switchboard-Substitution"]
```

Mögliche Header-Werte und ihre Bedeutung:

| Header-Wert (Beispiel) | Ursache |
| --- | --- |
| `claude-sonnet-4-6 (local qwen2.5-coder:14b not viable — free 3200MB/9871MB, CPU 12%)` | Zu wenig freier RAM oder CPU-Last zu hoch |
| `claude-sonnet-4-6 (local qwen2.5-coder:14b not viable — no matching hardware class)` | Kein HW-Klassen-Match — Gerät nicht in `HardwareClasses` konfiguriert |
| `claude-sonnet-4-6 (local qwen2.5-coder:14b not viable — no validated footprint)` | `PeakRamMb = 0` oder Modell fehlt in `HardwareClasses[*].Models` |

**Diagnose 2: Serilog-Logs prüfen**

```pwsh
# Letzte ResourceGate-Einträge (Serilog-Konsole oder File-Sink):
Get-Content "$env:APPDATA\K.Switchboard\logs\*.log" -Tail 30 |
    Select-String "ResourceGate"
```

**Mögliche Ursachen und Lösungen:**

- **Zu wenig freier RAM:** `PeakRamMb + RamBuffer` überschreitet den verfügbaren RAM. Andere Anwendungen schließen oder `RamBufferMb` manuell setzen (z.B. 512), um den Puffer zu verkleinern.
- **CPU-Last hoch:** Hintergrundprozesse treiben die Last über `CpuMaxLoadPercent` (Default: 85 %). Schwelle in `config.json` erhöhen oder Hintergrundprozesse reduzieren.
- **PeakRamMb nicht hinterlegt:** Das Modell fehlt in `HardwareClasses[<klasse>].Models` oder hat `PeakRamMb: 0`. Eval durchführen (siehe [eval-measurement.md](eval-measurement.md)) und Wert eintragen.
- **Kein HW-Klassen-Match:** Gerät liegt außerhalb der definierten Klassen (z.B. RAM zwischen 16 und 24 GB ohne VRAM). Neue Klasse in `HardwareClasses` ergänzen.

---

<a id="503-local-not-viable"></a>

## 1.8 HTTP 503 — kein Fallback verfügbar

**Symptom:** K.Switchboard antwortet mit HTTP 503 und einem ProblemDetails-Body:

```json
{
  "title": "Local model not viable",
  "detail": "No fallback or substitute available — <grund>."
}
```

**Ursache:** Das Gate hat das lokale Modell abgelehnt, aber es gibt weder eine passende
`FallbackChains`-Konfiguration noch einen `TierSubstitutions`-Eintrag für das Tier des Modells.

**Lösung 1: TierSubstitutions konfigurieren**

Stelle sicher, dass für alle in `LocalModelTiers` benutzten Tier-Werte ein Substitut vorhanden ist:

```json
"TierSubstitutions": {
  "S": "claude-haiku-4-5",
  "M": "claude-sonnet-4-6",
  "L": "claude-sonnet-4-6"
}
```

**Lösung 2: FallbackChain ergänzen**

```json
"FallbackChains": {
  "qwen2.5-coder:14b": ["claude-sonnet-4-6"]
}
```

**Lösung 3: Modell in LocalModelTiers eintragen**

Fehlt das Modell in `LocalModelTiers`, findet ResourceGate kein Tier und damit kein Substitut.
Den Modellnamen mit dem gewünschten Tier ergänzen.

---

<a id="gpu-nicht-erkannt"></a>

## 1.9 GPU wird nicht erkannt

**Symptom:** `hw-profile.json` enthält `"GpuVendor": "none"` und `"VramMb": 0`, obwohl eine
GPU vorhanden ist. VRAM-basierte HW-Klassen (gpu-7b, gpu-14b, gpu-14b-plus) werden nie gematcht.

**Ursache 1: `nvidia-smi` nicht im PATH (NVIDIA)**

`nvidia-smi` muss im System-PATH auffindbar sein. Prüfung:

```pwsh
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits
```

Gibt dieser Befehl eine Zeile mit GPU-Name und VRAM-MB aus, ist das Tool verfügbar. Andernfalls
`nvidia-smi` zum PATH hinzufügen (typischerweise `C:\Windows\System32\DriverStore\FileRepository\...`
oder `C:\Program Files\NVIDIA Corporation\NVSMI\`).

**Ursache 2: AMD-GPU auf Windows (wmic-Fallback)**

`wmic path win32_VideoController` meldet AMD-GPUs oft mit `AdapterRAM: 0` oder falschen
Bytes-Werten. Das führt zu `VramMb: 0`. Workaround: VRAM in der HW-Klasse manuell setzen,
indem `hw-profile.json` direkt bearbeitet wird (Wert wird beim nächsten Monats-Refresh
überschrieben → Profil-Datei monatlich anpassen oder Refresh mit VRAM-Korrektur skripten).

**Ursache 3: macOS**

Auf macOS ist VRAM via `system_profiler` nicht zuverlässig parsebar — ResourceGate setzt immer
`VramMb: 0`. GPU-basierte Klassen sind auf macOS nicht nutzbar; CPU-Klassen (`cpu-low`, `cpu-32`)
stehen weiterhin zur Verfügung.

---

<a id="profil-veraltet"></a>

## 1.10 Profil veraltet oder falsch

**Symptom:** `hw-profile.json` enthält veraltete Werte (z.B. nach RAM-Ausbau oder GPU-Wechsel).
ResourceGate trifft falsche Entscheidungen.

**Ursache:** Das Profil wird nur 1× pro Kalendermonat erneuert.

**Lösung: Datei löschen → sofortige Neu-Detektion**

```pwsh
Remove-Item "$env:APPDATA\K.Switchboard\hw-profile.json" -Force
```

Der nächste Request an K.Switchboard löst die Neu-Detektion aus. Das neue Profil wird
anschließend in `hw-profile.json` gespeichert.

---

<a id="immer-substitution"></a>

## 1.11 Lokales Modell läuft nie (immer Substitution)

**Symptom:** Trotz aktivem ResourceGate und passendem Hardware-Profil wird immer substituiert.
Der Header `X-K-Switchboard-Substitution` erscheint bei jedem Request.

**Ursache 1: `HardwareClasses[<klasse>].Models` leer oder `PeakRamMb: 0`**

Fehlt das Modell im `Models`-Objekt der zugeordneten HW-Klasse, oder ist `PeakRamMb: 0`,
erzwingt ResourceGate immer die Substitution (fail-safe). Lösung: Eval durchführen und Wert
eintragen (siehe [eval-measurement.md](eval-measurement.md)).

**Ursache 2: cpu-low (≤ 16 GB RAM, kein VRAM) — intentional**

Auf Geräten der Klasse `cpu-low` bleibt `Models` leer — das ist Absicht. Die Evals aus
Spike #251 ergaben 0 % A/B-Score für alle getesteten Modelle auf CPU-only-Hardware.
Kein lokales Modell erfüllt das Qualitätskriterium ≥ 70 % A/B. Die Tier-Substitution auf
Claude ist für cpu-low die vorgesehene Betriebsart.

**Ursache 3: ResourceGate deaktiviert, aber FallbackService greift**

Wenn `Enabled: false` (oder die Sektion fehlt), ist der ResourceGate out-of-play. Ein dennoch
erscheinender `X-K-Switchboard-Substitution`-Header deutet auf eine FallbackChain-Reaktion auf
HTTP-Fehler hin (reaktiv, nicht proaktiv). Ursache: Ollama antwortet mit 4xx/5xx.
