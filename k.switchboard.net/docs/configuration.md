# 1. Konfigurationsreferenz

<!-- markdownlint-disable MD033 -->

K.Switchboard liest seine Konfiguration aus `%APPDATA%\K.Switchboard\config.json`. Die Datei wird beim ersten Start mit Standardwerten angelegt. Änderungen werden zur Laufzeit erkannt — kein Neustart erforderlich ([IOptionsMonitor](https://learn.microsoft.com/en-us/dotnet/core/extensions/options#use-ioptionsmonitor-to-read-updated-data)).

---

<a id="port"></a>

## 1.1 Port

```json
"Port": 3456
```

Der TCP-Port, auf dem K.Switchboard HTTP-Anfragen entgegennimmt.

**Standardwert:** `3456`  
**Typ:** Ganzzahl  
**Hinweis:** Nach einer Port-Änderung muss K.Switchboard neu gestartet werden, da Kestrel den Port beim Start bindet. Stelle sicher, dass `ANTHROPIC_BASE_URL` auf den neuen Port zeigt.

---

<a id="anthropic-base-url"></a>

## 1.2 AnthropicBaseUrl

```json
"AnthropicBaseUrl": "https://api.anthropic.com"
```

Basis-URL des Anthropic-API-Endpunkts. Alle Anthropic-Anfragen werden an `{AnthropicBaseUrl}/v1/messages` weitergeleitet.

**Standardwert:** `https://api.anthropic.com`  
**Typ:** URL-Zeichenkette  
**API-Referenz:** [Anthropic Messages API](https://docs.anthropic.com/en/api/messages)

---

<a id="ollama-base-url"></a>

## 1.3 OllamaBaseUrl

```json
"OllamaBaseUrl": "http://localhost:11434"
```

Basis-URL des lokalen Ollama-Endpunkts. Anfragen für Modelle mit `:` im Namen (z. B. `codellama:13b`) oder explizite Ollama-Aliase werden an `{OllamaBaseUrl}/api/chat` weitergeleitet.

**Standardwert:** `http://localhost:11434`  
**Typ:** URL-Zeichenkette  
**API-Referenz:** [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)

<a id="ollama-timeout-seconds"></a>

### 1.3.1 OllamaTimeoutSeconds

```json
"OllamaTimeoutSeconds": 600
```

Timeout in Sekunden für den HTTP-Client, der Anfragen an Ollama weiterleitet. Lokale CPU-Inferenz größerer Modelle überschreitet häufig den .NET-Standard-Timeout von 100 s und führte zuvor zu `TaskCanceledException`/Timeout-Abbrüchen. Der Wert gilt ausschließlich für den Ollama-Pfad — der Anthropic-Client behält bewusst den kurzen Standard-Timeout.

**Standardwert:** `600` (10 Minuten)  
**Typ:** Ganzzahl (Sekunden)  
**Hinweis:** Änderungen an `OllamaTimeoutSeconds` erfordern einen Neustart (wird beim Start in den HTTP-Client eingebacken, analog zu `Port`); `OllamaKeepAlive` wird hingegen per-Request gelesen und wirkt sofort.

<a id="ollama-keep-alive"></a>

### 1.3.2 OllamaKeepAlive

```json
"OllamaKeepAlive": "30m"
```

Wert für das `keep_alive`-Feld im weitergeleiteten Ollama-Request. Steuert, wie lange Ollama das Modell nach einem Request im Speicher geladen hält. Ohne diesen Wert entlädt Ollama das Modell nach 5 Minuten Idle, was beim nächsten Request einen Cold-Load auslöst. Akzeptiert Ollama-Dauer-Zeichenketten (z. B. `"30m"`, `"1h"`) — siehe [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md#parameters).

**Standardwert:** `"30m"`  
**Typ:** Zeichenkette (Ollama-Dauer)

---

<a id="model-aliases"></a>

## 1.4 ModelAliases

```json
"ModelAliases": {
  "local-coder": "codellama:13b",
  "local-fast": "llama3.2:3b",
  "prod": "claude-3-5-sonnet-20241022"
}
```

Alias-Mapping von beliebigen Kurznamen auf vollständige Modellnamen. Ein Client kann `"model": "local-coder"` senden — K.Switchboard löst den Alias auf `codellama:13b` auf, bevor der passende Provider ermittelt wird.

**Standardwert:** `{}` (kein Alias)  
**Typ:** Objekt mit String-zu-String-Paaren  
**Routing-Regel:** Modellnamen mit `:` werden automatisch zu Ollama geroutet. Alle anderen zu Anthropic.

---

<a id="fallback-chains"></a>

## 1.5 FallbackChains

```json
"FallbackChains": {
  "claude-opus-latest": ["claude-sonnet-latest", "claude-haiku-latest"],
  "local-coder": ["codellama:7b"]
}
```

Definiert Fallback-Ketten pro Modell. Bei einem HTTP-Fehler (4xx/5xx) oder Netzwerkfehler des primären Modells versucht K.Switchboard die Modelle in der angegebenen Reihenfolge.

**Standardwert:** `{}` (kein Fallback)  
**Typ:** Objekt; Schlüssel ist der primäre Modellname, Wert ist eine geordnete Liste von Fallback-Modellen  
**Response-Header:** Bei erfolgreichem Fallback wird `X-K-Switchboard-Fallback-Used: <primär> -> <verwendet>` gesetzt.

---

<a id="pricing"></a>

## 1.6 Pricing

```json
"Pricing": {
  "claude-3-5-sonnet-20241022": {
    "InputPerMillion": 3.0,
    "OutputPerMillion": 15.0
  },
  "claude-3-5-haiku-20241022": {
    "InputPerMillion": 0.8,
    "OutputPerMillion": 4.0
  }
}
```

Kosten pro Modell in USD pro Million Tokens. Wird für den `/stats`-Endpoint verwendet.

**Standardwert:** `{}` (keine Kostenberechnung)  
**Typ:** Objekt; Schlüssel ist der genaue Modellname aus der Anthropic-Antwort  
**Hinweis:** Nur Anthropic-Modelle liefern Token-Counts im Response-Body. Ollama-Aufrufe werden nicht in Kosten umgerechnet.  
**Preisreferenz:** [Anthropic Pricing](https://www.anthropic.com/pricing#anthropic-api)

### 1.6.1 /stats-Antwortformat

```json
{
  "date": "2026-05-17",
  "models": {
    "claude-3-5-sonnet-20241022": {
      "inputTokens": 12500,
      "outputTokens": 3200,
      "costUsd": 0.085500
    }
  },
  "totalCostUsd": 0.085500
}
```

Statistiken werden täglich in `%APPDATA%\K.Switchboard\costs-yyyy-MM-dd.json` gespeichert.

---

<a id="hw-profil-cache"></a>

## 1.7 HW-Profil-Cache (`hw-profile.json`)

K.Switchboard erkennt beim ersten Start das lokale Hardware-Profil und speichert es als
`hw-profile.json` im Per-Install-Verzeichnis:

| Betriebssystem | Pfad |
| --- | --- |
| Windows | `%APPDATA%\K.Switchboard\hw-profile.json` |
| Linux | `~/.config/K.Switchboard/hw-profile.json` |
| macOS | nicht unterstützt (CPU-Sampler liefert 0, GPU-Pfad nie aktiv) |

Die Datei ist maschinenspezifisch und wird **nicht committed**. Sie enthält folgende Felder:

```json
{
  "TotalRamMb": 16384,
  "Cores": 12,
  "GpuVendor": "NVIDIA",
  "GpuModel": "NVIDIA GeForce RTX 3070",
  "VramMb": 8192,
  "DetectedOn": "2026-06-07T09:00:00+00:00"
}
```

| Feld | Beschreibung |
| --- | --- |
| `TotalRamMb` | Gesamter System-RAM in MB (via .NET GC-API) |
| `Cores` | Logische CPU-Kerne (`Environment.ProcessorCount`) |
| `GpuVendor` | `"NVIDIA"`, `"AMD"` oder `"none"` |
| `GpuModel` | GPU-Modellname oder leer |
| `VramMb` | VRAM in MB (0 = keine oder unbekannte GPU) |
| `DetectedOn` | UTC-Zeitpunkt der letzten Erkennung |

**Refresh-Logik:** Die Erkennung läuft beim ersten Request des Monats (UTC) neu, wenn die
Datei fehlt, unlesbar ist oder `DetectedOn` nicht im aktuellen Kalendermonat liegt (1×/Monat).

**Datei löschen → sofortige Neu-Detektion:** Um das Profil manuell zu erzwingen (z.B. nach
GPU-Wechsel), die Datei löschen und K.Switchboard neu starten oder den nächsten Request abwarten.

```pwsh
Remove-Item "$env:APPDATA\K.Switchboard\hw-profile.json" -Force
```

**GPU-Erkennung:** Reihenfolge — `nvidia-smi` (cross-platform), dann `rocm-smi` (AMD, Linux +
Windows, falls ROCm installiert), dann `wmic` (Windows-Fallback), dann `system_profiler`
(macOS — liefert immer `VramMb=0`, kein GPU-Pfad möglich). Steht kein Tool zur Verfügung oder
gibt es Exit-Code ≠ 0, wird `GpuVendor="none"` gesetzt und der CPU-Pfad genutzt. Siehe auch
[GPU wird nicht erkannt](troubleshooting.md#gpu-nicht-erkannt).

---

<a id="hardware-classes"></a>

## 1.8 HardwareClasses (Mapping b)

`HardwareClasses` ist das committede Mapping, das festlegt, welche lokalen Modelle auf welcher
HW-Klasse validiert sind. Es wird einmalig vom Team gepflegt und liegt in `config.json`.

```json
"HardwareClasses": [
  {
    "Name": "cpu-low",
    "Match": { "MaxRamMb": 16384 },
    "Models": {}
  },
  {
    "Name": "gpu-7b",
    "Match": { "MinVramMb": 6144, "MaxVramMb": 10239 },
    "Models": {
      "qwen2.5-coder:7b": {
        "PeakRamMb": 5200,
        "ValidatedOn": "gpu-7b, RTX 3060 12GB, 2026-06-01",
        "LatencyP50Ms": 1800,
        "Score": "B"
      }
    }
  }
]
```

### 1.8.1 Schema

**`HardwareClassConfig`:**

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `Name` | string | Eindeutiger Klassenname (z.B. `"gpu-14b"`, `"cpu-low"`) |
| `Match` | Objekt | Match-Kriterien gegen das erkannte HW-Profil (AND-Verknüpfung) |
| `Models` | Objekt | Validierte Modelle dieser Klasse; Key = Ollama-Modellname (darf `:` enthalten) |

**`HardwareClassMatch`** — alle Felder optional (`null` = kein Constraint):

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `MinRamMb` | int? | Mindest-RAM in MB (inklusive) |
| `MaxRamMb` | int? | Maximal-RAM in MB (inklusive) |
| `MinCores` | int? | Mindest-Kernzahl (inklusive) |
| `GpuVendor` | string? | GPU-Vendor: `"NVIDIA"`, `"AMD"` oder `"none"` |
| `MinVramMb` | int? | Mindest-VRAM in MB (inklusive) |
| `MaxVramMb` | int? | Maximal-VRAM in MB (inklusive) |

**`ModelValidation`** — empirische Messdaten (siehe [eval-measurement.md](eval-measurement.md)):

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `PeakRamMb` | int | Beobachteter Peak-RAM (MB) bei realistischem Max-Kontext. **0 = nicht validiert → lokale Ausführung gesperrt** |
| `PeakVramMb` | int | Beobachteter Peak-VRAM (MB) beim Laden auf der GPU. **0 = nicht GPU-validiert → CPU-Pfad gilt** (Admission via RAM-Check) |
| `ValidatedOn` | string | Setup-Beschreibung für Reproduzierbarkeit |
| `LatencyP50Ms` | int | Median-Latenz (ms) aus dem Eval. 0 = nicht gemessen |
| `Score` | string | Qualitäts-Score aus dem Eval (`A`/`B`/`C`/`F`). Leer = nicht bewertet |

**Hinweis:** Model-Keys dürfen `:` enthalten (z.B. `"qwen2.5-coder:14b"`) — das ist gültiges JSON.

### 1.8.2 Reihenfolge = Match-Priorität

Die Klassen werden der Reihe nach geprüft; die **erste** passende Klasse gewinnt. Die fünf
ausgelieferten Klassen sind:

| Klasse | Match-Kriterien | Modelle (Auslieferung) |
| --- | --- | --- |
| `cpu-low` | `MaxRamMb ≤ 16384` | keine (leer — cpu-low ist intentional ohne lokale Modelle, siehe [Troubleshooting](troubleshooting.md#immer-substitution)) |
| `gpu-7b` | `MinVramMb ≥ 6144, MaxVramMb ≤ 10239` | auszufüllen nach Eval |
| `gpu-14b` | `MinVramMb ≥ 10240, MaxVramMb ≤ 16383` | auszufüllen nach Eval |
| `gpu-14b-plus` | `MinVramMb ≥ 16384` | auszufüllen nach Eval |
| `cpu-32` | `MinRamMb ≥ 24576` | auszufüllen nach Eval |

**Kein Match:** Passt keine Klasse (z.B. kein VRAM und 17–24 GB RAM), ergibt sich kein
`hwClass`-Treffer. ResourceGate substituiert in diesem Fall mit Grund
`"no matching hardware class"` — fail-safe.

---

<a id="local-model-tiers"></a>

## 1.9 LocalModelTiers und TierSubstitutions

### 1.9.1 Konzept

`LocalModelTiers` ordnet jedem lokalen Ollama-Modell ein Aufgaben-**Tier** zu (`S`, `M` oder
`L`). `TierSubstitutions` legt fest, welches Claude-Modell eingesetzt wird, wenn ein lokales
Modell des jeweiligen Tiers nicht ausführbar ist.

Das Tier beschreibt die **Aufgabengröße** (nicht Qualitätsäquivalenz): S = leicht/schnell,
M = mittel, L = komplex/lang. Die Substitutions-Entscheidung ist datenbasiert —
nach Spike #251 (0 % A/B auf cpu-low) wurde bewusst auf Tier-Substitution umgestellt,
statt eine Qualitätsstufe anzunehmen.

### 1.9.2 Ausgelieferte Defaults

`CreateDefault()` liefert folgendes Mapping:

**`LocalModelTiers`:**

| Modell | Tier |
| --- | --- |
| `qwen2.5-coder:1.5b` | S |
| `llama3.2:3b` | S |
| `qwen2.5-coder:7b` | M |
| `llama3.1:8b` | M |
| `qwen2.5-coder:14b` | L |
| `qwen2.5-coder:32b` | L |

**`TierSubstitutions`:**

| Tier | Claude-Modell |
| --- | --- |
| S | `claude-haiku-4-5` |
| M | `claude-sonnet-4-6` |
| L | `claude-sonnet-4-6` |

### 1.9.3 Opus für Tier-L aktivieren

Das ausgelieferte Tier-L-Substitut ist `claude-sonnet-4-6`. Um Opus für L-Tier-Anfragen zu
aktivieren, `TierSubstitutions["L"]` in `config.json` überschreiben:

```json
"TierSubstitutions": {
  "S": "claude-haiku-4-5",
  "M": "claude-sonnet-4-6",
  "L": "claude-opus-4-8"
}
```

**Achtung:** Opus-Anfragen erzeugen deutlich höhere API-Kosten. Eval-Daten zum Vergleich:
[eval-measurement.md](eval-measurement.md).

---

<a id="resource-gate"></a>

## 1.10 ResourceGate

`ResourceGate` ist ein Pre-flight-Check: Bevor K.Switchboard einen lokalen Ollama-Request
weiterleitet, prüft er ob die Ressourcen (RAM/VRAM und CPU) die Ausführung erlauben. Schlägt
der Check fehl, wird auf die FallbackChain oder Tier-Substitution ausgewichen.

```json
"ResourceGate": {
  "Enabled": true,
  "RamBufferMb": 0,
  "CpuLoadWindowSeconds": 4,
  "CpuMaxLoadPercent": 85,
  "VramDisplayReserveMb": 2048,
  "MaxLatencyMs": 0,
  "ColdLatencyFactor": 2.0,
  "LatencyContextReferenceTokens": 4000
}
```

### 1.10.1 Felder

| Feld | Typ | Default | Beschreibung |
| --- | --- | --- | --- |
| `Enabled` | bool | `false` (Property-Default) | Gate aktiv? Bestehende `config.json` ohne `ResourceGate`-Sektion → Gate bleibt **aus** (rückwärtskompatibel). Neue Installationen via `CreateDefault()` erhalten `true`. |
| `RamBufferMb` | int | `0` | Zusätzlicher Sicherheitspuffer über `PeakRamMb`. `0` = Code-hergeleiteter Default: `max(1024, PeakRamMb / 4)`. Siehe [eval-measurement.md § 7](eval-measurement.md#7-rambuffermb-herleitung). |
| `CpuLoadWindowSeconds` | int | `4` | Fenster (s) für den rollenden CPU-Last-Mittelwert. |
| `CpuMaxLoadPercent` | int | `85` | CPU-Last-Schwelle (%). Lokale Inferenz wird blockiert, wenn die CPU-Last diesen Wert überschreitet. |
| `VramDisplayReserveMb` | int | `2048` | VRAM (MB), der für Display/Compositor reserviert bleibt und nicht für lokale Inferenz zählt. GPU-Admission: `PeakVramMb ≤ Gesamt-VRAM − VramDisplayReserveMb`. Auf Headless-Servern ohne angeschlossenen Monitor → `0` setzen. |
| `MaxLatencyMs` | int | `0` | Latenz-Schwelle (ms): Ist die erwartete lokale Latenz höher, wird substituiert. **0 = Latenz-Gate aus** (Opt-in, backward-safe). Empfohlener Einstiegswert: `100000` (= 100 s). Das Gate greift nur, wenn zusätzlich `LatencyP50Ms > 0` im Modell-Eintrag vorhanden ist. |
| `ColdLatencyFactor` | double | `2.0` | Multiplikator für Cold-Load-Latenz (Modell noch nicht geladen). Erwartete Latenz = `P50 × ColdLatencyFactor`. Ist das Modell warm, wird Faktor 1,0 verwendet. |
| `LatencyContextReferenceTokens` | int | `4000` | Referenz-Kontextlänge (Tokens) für die Latenz-Skalierung. Entspricht einem typischen realen Payload. Die Latenz skaliert linear mit dem Verhältnis `inputTokens / LatencyContextReferenceTokens`, Untergrenze 0,5. |

### 1.10.2 GPU-Pfad vs. CPU-Pfad

ResourceGate wählt den Admission-Pfad anhand dreier Bedingungen:

```text
GPU-Pfad aktiv, wenn:
  PeakVramMb > 0                 (Modell GPU-validiert)
  UND GpuVendor ≠ "none"         (GPU erkannt)
  UND VramMb > 0                 (VRAM bekannt)

GPU-Admission:
  nutzbarer VRAM = max(0, VramMb − VramDisplayReserveMb)
  zulässig ↔ PeakVramMb ≤ nutzbarer VRAM

CPU-Pfad (fallback):
  freier RAM ≥ PeakRamMb + RamBuffer
```

In beiden Fällen gilt zusätzlich:

```text
CPU-Last ≤ CpuMaxLoadPercent
```

Der CPU-Sampler liefert auf Linux (`/proc/stat`) und Windows (`GetSystemTimes`) echte Werte.
Auf macOS gibt er immer 0 zurück — die CPU-Last-Prüfung blockiert dort nie; macOS wird daher
als nicht unterstützte Plattform eingestuft.

Fehlt das validierte Footprint (`PeakRamMb = 0` und `PeakVramMb = 0`, oder kein
`hwClass`-Match), erzwingt das Gate immer die Substitution — fail-safe, kein Fehler.

### 1.10.3 Latenz-Gate

Nach dem Ressourcen-Check (RAM/VRAM) prüft das Gate zusätzlich die erwartete Latenz:

```text
contextFactor = max(0.5, inputTokens / LatencyContextReferenceTokens)
coldFactor    = ColdLatencyFactor  (wenn Modell nicht warm)
               1.0                 (wenn Modell warm)
expectedMs    = LatencyP50Ms × coldFactor × contextFactor

Substitution, wenn: MaxLatencyMs > 0
                UND LatencyP50Ms > 0
                UND expectedMs > MaxLatencyMs
```

Das Gate ist standardmäßig **deaktiviert** (`MaxLatencyMs = 0`). Ist `LatencyP50Ms` nicht
gemessen (= 0), greift das Latenz-Gate ebenfalls nie — kein gemessener Wert bedeutet kein
Blocking.

**Reason-String im `X-K-Switchboard-Substitution`-Header:**

```text
latency ~{expectedMs}ms > {MaxLatencyMs}ms (warm={ModelWarm}, ctx×{contextFactor})
```

---

<a id="blast-radius"></a>

## 1.11 Blast-Radius (Maschinen-Schutz)

K.Switchboard trifft zwei Maßnahmen, um die Entwicklermaschine zu schützen:

**1. `num_thread`-Drosselung:**  
Ollama-Requests erhalten `options.num_thread = max(2, Kerne - 2)`. Auf einer 12-Kern-Maschine
werden 10 Threads für Ollama reserviert, 2 verbleiben für das OS und andere Prozesse. Der Floor
von 2 verhindert, dass auf Maschinen mit sehr wenigen Kernen `num_thread` auf 0 oder 1 fällt.

**2. Single-Inference-Serialisierung:**  
Ein interner `LocalInferenceGate`-Lock stellt sicher, dass stets nur eine Ollama-Inferenz
gleichzeitig läuft. Parallele Requests warten, bis die laufende Inferenz abgeschlossen ist.

---

<a id="transparenz-header"></a>

## 1.12 Transparenz-Header (`X-K-Switchboard-Substitution`)

Bei jeder ResourceGate-Substitution setzt K.Switchboard den Response-Header
`X-K-Switchboard-Substitution`. Der Wert zeigt Clients, warum und wohin umgeleitet wurde.

**Format bei FallbackChain-Umleitung:**

```text
<lokalesModell> -> <zielModell> (deferred: <grund>)
```

Beispiel:

```text
qwen2.5-coder:14b -> claude-sonnet-4-6 (deferred: free 3200MB/9871MB, CPU 12%)
```

**Format bei Tier-Substitution:**

```text
<claudeModell> (local <lokalesModell> not viable — <grund>)
```

Beispiel:

```text
claude-sonnet-4-6 (local qwen2.5-coder:14b not viable — no matching hardware class)
```

**Mögliche Gründe (`<grund>`):**

| Grund | Bedeutung |
| --- | --- |
| `free <X>MB/<N>MB` | Zu wenig freier RAM |
| `CPU <n>%` | CPU-Last überschreitet `CpuMaxLoadPercent` |
| `VRAM <P>MB/<U>MB` | GPU-Pfad: `PeakVramMb` überschreitet nutzbaren VRAM |
| `latency ~<e>ms > <m>ms (warm=<b>, ctx×<f>)` | Erwartete Latenz überschreitet `MaxLatencyMs` |
| `no matching hardware class` | Kein HW-Klassen-Match für dieses Gerät |
| `no validated footprint` | `PeakRamMb = 0` und `PeakVramMb = 0`, oder Modell fehlt in der Klasse |

---

<a id="full-example"></a>

## 1.13 Vollständiges Beispiel

```json
{
  "Port": 3456,
  "AnthropicBaseUrl": "https://api.anthropic.com",
  "OllamaBaseUrl": "http://localhost:11434",
  "OllamaTimeoutSeconds": 600,
  "OllamaKeepAlive": "30m",
  "ModelAliases": {
    "local-coder": "qwen2.5-coder:14b",
    "local-fast": "llama3.2:3b",
    "prod": "claude-sonnet-4-6"
  },
  "FallbackChains": {
    "claude-opus-latest": ["claude-sonnet-4-6"]
  },
  "Pricing": {
    "claude-sonnet-4-6": {
      "InputPerMillion": 3.0,
      "OutputPerMillion": 15.0
    },
    "claude-haiku-4-5": {
      "InputPerMillion": 0.8,
      "OutputPerMillion": 4.0
    }
  },
  "LocalModelTiers": {
    "qwen2.5-coder:1.5b": "S",
    "llama3.2:3b": "S",
    "qwen2.5-coder:7b": "M",
    "llama3.1:8b": "M",
    "qwen2.5-coder:14b": "L",
    "qwen2.5-coder:32b": "L"
  },
  "TierSubstitutions": {
    "S": "claude-haiku-4-5",
    "M": "claude-sonnet-4-6",
    "L": "claude-sonnet-4-6"
  },
  "ResourceGate": {
    "Enabled": true,
    "RamBufferMb": 0,
    "CpuLoadWindowSeconds": 4,
    "CpuMaxLoadPercent": 85,
    "VramDisplayReserveMb": 2048,
    "MaxLatencyMs": 0,
    "ColdLatencyFactor": 2.0,
    "LatencyContextReferenceTokens": 4000
  },
  "HardwareClasses": [
    {
      "Name": "cpu-low",
      "Match": { "MaxRamMb": 16384 },
      "Models": {}
    },
    {
      "Name": "gpu-7b",
      "Match": { "MinVramMb": 6144, "MaxVramMb": 10239 },
      "Models": {
        "qwen2.5-coder:7b": {
          "PeakRamMb": 5200,
          "PeakVramMb": 0,
          "ValidatedOn": "gpu-7b, RTX 3060 12GB, 2026-06-01",
          "LatencyP50Ms": 1800,
          "Score": "B"
        }
      }
    },
    {
      "Name": "gpu-14b",
      "Match": { "MinVramMb": 10240, "MaxVramMb": 16383 },
      "Models": {}
    },
    {
      "Name": "gpu-14b-plus",
      "Match": { "MinVramMb": 16384 },
      "Models": {}
    },
    {
      "Name": "cpu-32",
      "Match": { "MinRamMb": 24576 },
      "Models": {}
    }
  ]
}
```
