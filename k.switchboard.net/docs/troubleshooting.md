# Troubleshooting

Häufige Fehlerbilder mit Symptomen, Ursachen und Lösungsschritten.

---

## Service startet nicht

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

## Port belegt

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

## Anthropic-Auth-Fehler

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

## Ollama nicht erreichbar

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

## Fallback greift nicht

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

## /stats gibt keine Daten zurück

**Symptom:** `Invoke-RestMethod http://localhost:3456/stats` liefert `totalCostUsd: 0` obwohl Anfragen gestellt wurden.

**Ursache 1: Pricing nicht konfiguriert**

Kostenberechnung erfordert einen Eintrag in `Pricing` für das verwendete Modell. Prüfe `config.json` — der Schlüssel muss dem genauen Modellnamen in der Anthropic-Antwort entsprechen.

**Ursache 2: Kein Anthropic-Response-Body**

Token-Counts werden aus dem Anthropic-Response-Body ausgelesen (`usage.input_tokens` / `usage.output_tokens`). Ollama-Antworten enthalten diese Felder nicht und werden nicht in Kosten umgerechnet.
