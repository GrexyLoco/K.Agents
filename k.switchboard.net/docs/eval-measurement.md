# Eval-Messmethodik — ResourceGate `peakRamMb` (#268)

> **Querverweise:** [Konfigurationsreferenz](configuration.md) › ResourceGate-Sektion  
> Dieses Dokument beschreibt, wie die empirischen `peakRamMb`-Werte in den
> `HardwareClasses[*].Models`-Einträgen erhoben werden und reproduziert werden können.

---

## 1. Zweck

ResourceGate entscheidet pro Request, ob ein lokales Modell auf der aktuellen
Hardware ausführbar ist (§ 2 der Spec). Die Entscheidungslogik lautet:

```text
benötigter_RAM = PeakRamMb + RamBufferMb
lokale Ausführung zulässig ↔ freier_RAM ≥ benötigter_RAM ∧ CPU-Last ≤ Schwelle
```

`PeakRamMb` ist der beobachtete Peak-RAM eines Modells bei realistischem Kontext.
Dieser Wert kann **nicht** verlässlich aus der Modell-Dateigröße allein abgeleitet werden —
Ollama lädt Modelle je nach Quantisierung, Kontextlänge und verfügbarem VRAM/RAM
unterschiedlich in den Hauptspeicher. **Empirische Messung ist daher zwingend.**

Per `SwitchboardOptions.ModelValidation.PeakRamMb = 0` (nicht validiert) erzwingt
ResourceGate immer eine Tier-Substitution — kein Modell wird lokal gestartet.
Für `cpu-low` (≤ 16 GB RAM, kein VRAM) bleibt `HardwareClasses[cpu-low].Models`
leer (alle Evals aus Spike #251: 0 % A/B, zu hohe Latenz), da kein lokales Modell
das Qualitätskriterium ≥ 70 % A/B erfüllt. Die Messwerte dienen als Referenz.

---

## 2. Messarchitektur

### 2.1 Skript

```text
plugins/kagents/agents/commit-messenger/evals/run-evals.ps1
plugins/kagents/agents/code-reviewer/evals/run-evals.ps1
```

Beide Skripte sind unabhängig (kein gemeinsamer Include); die Hilfsfunktionen
`Get-FreeRamMb` und `Get-OllamaModelSizeMb` sind in jedem Skript dupliziert.

**Wichtige Parameter:**

| Parameter | Default | Zweck |
| --- | --- | --- |
| `-Models` | modellspezifisch | Ollama-Modellnamen, die getestet werden |
| `-MaxInputs` | 0 (alle) | Anzahl Inputs begrenzen (defensiver Schnelllauf) |
| `-TimeoutSec` | 300 / 1800 | HTTP-Timeout pro Inference-Call |
| `-OllamaUrl` | `http://localhost:11434` | Ollama-Endpunkt |

### 2.2 Fixtures

Jedes Eval-Verzeichnis enthält fünf reale Inputs (`01-input.md` bis `05-input.md`):

- **commit-messenger:** git-Diffs aus der Repo-Historie (diverse type/scope-Szenarien).
- **code-reviewer:** Code-Ausschnitte mit bekannten Soll-Findings (aus Spike #251).

Die Inputs sind bewusst typdivers (kleine und große Kontexte), damit Latenz- und
RAM-Messungen die Bandbreite realer Nutzung abdecken.

### 2.3 Hardware-Setup

Jedes Run-Ergebnis enthält eine Baseline-Zeile am Ende der Datei, die den
freien RAM unmittelbar vor dem ersten Inference-Call für dieses Modell ausweist.
Das Hardware-Setup (HW-Klasse) muss manuell in `results.md` erfasst werden:

```text
HW-Setup: <Gerät>, <Gesamt-RAM> MB, <CPU/GPU>, Klasse: <cpu-low|gpu-7b|…>
```

---

## 3. Peak-RAM-Messung

### 3.1 Free-RAM-Sampling (Cross-Platform)

```powershell
function Get-FreeRamMb {
    if ($IsWindows) {
        return [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
    }
    elseif ($IsLinux) {
        $line = Get-Content -Path '/proc/meminfo' |
            Where-Object { $_ -match 'MemAvailable' } | Select-Object -First 1
        if ($line -and $line -match '\d+') { return [int]([long]$Matches[0] / 1024) }
        return 0
    }
    else { return 0 }   # macOS: vm_stat-Parsing optional
}
```

### 3.2 Ablauf pro Inference-Call

```text
1. preFree = Get-FreeRamMb          ← free RAM unmittelbar vor dem Call
2. Inference-Call in Start-ThreadJob (PS7 in-process, leichter als Start-Job)
3. Foreground-Loop alle 300 ms: f = Get-FreeRamMb; if f < localMin → localMin = f
4. Receive-Job (wait for completion)
5. peakRamDeltaMb = preFree - localMin
```

`peakRamDeltaMb` = wie viel RAM im Messfenster zusätzlich belegt wurde.
Positiver Wert = Modell hat RAM alloziert; Nullwert = Modell war bereits warm.

### 3.3 Ollama `/api/ps` (authoritative Footprint)

Nach jedem Call wird `GET http://localhost:11434/api/ps` abgefragt:

```json
{
  "models": [
    { "name": "llama3.2:3b", "size": 4077203520, "size_vram": 0 }
  ]
}
```

- **`size`** (Bytes) = Gesamt-Speicherbelegung des Modells laut Ollama
  (RAM + ggf. VRAM).
- **`size_vram`** = davon auf GPU-VRAM; `0` bei reiner CPU-Inferenz.
- Umrechnung: `SizeMb = size / 1_048_576`.

### 3.4 Peak-VRAM-Erhebung via `/api/ps` (`PeakVramMb`)

Für GPU-Pfad-Evals wird `size_vram` aus `/api/ps` direkt als `PeakVramMb` verwendet:

```powershell
$ps = Invoke-RestMethod http://localhost:11434/api/ps
$model = $ps.models | Where-Object { $_.name -eq $targetModel } | Select-Object -First 1
$peakVramMb = [int][math]::Ceiling($model.size_vram / 1MB)
```

Der Wert sollte bei einem **GPU Cold-Load** erhoben werden (Modell vorher entladen:
`ollama stop <modell>`), da Ollama bei warmem Modell keinen neuen VRAM-Allokations-Peak
erzeugt. `size_vram = 0` bedeutet reiner CPU-Pfad — für GPU-Klassen muss ein positiver
Wert vorhanden sein, damit ResourceGate den GPU-Pfad aktiviert.

Als `PeakVramMb` in `HardwareClasses[*].Models[*]` wird der `/api/ps`-`size_vram`-Wert
(aufgerundet auf volle 100 MB) eingetragen, gemessen auf der Ziel-GPU-Klasse.

**Warum `/api/ps` zuverlässiger ist als das Delta:**  
Das Free-RAM-Delta misst systemweiten Speicher — andere Prozesse (IDE, Browser)
können das Ergebnis verfälschen, insbesondere auf einer 15-GB-Workstation.
Ab dem zweiten Input desselben Modells ist der Delta zudem ~0, weil
`keep_alive=10m` das Modell warm hält. `/api/ps` liefert den tatsächlichen
Footprint unabhängig vom Messzeitpunkt.

### 3.5 Welcher Wert in die Konfiguration?

Als `PeakRamMb` in `HardwareClasses[*].Models[*]` wird der **`/api/ps`-SizeMb**
(aufgerundet auf volle 100 MB) eingetragen, gemessen bei einem Cold-Load (Modell
vor dem Eval nicht im Speicher). Der Free-RAM-Delta dient als Plausibilitätscheck.

Als `PeakVramMb` wird der `/api/ps`-`size_vram`-Wert (aufgerundet auf volle 100 MB)
eingetragen, gemessen bei einem GPU Cold-Load. Ist `size_vram = 0`, bleibt `PeakVramMb = 0`
und ResourceGate nutzt den CPU-Pfad für dieses Modell.

---

## 4. Latenz-Messung

Latenz wird aus der Ollama-Antwort selbst gelesen (kein separates Stopwatch):

```powershell
$totalS = [math]::Round($resp.total_duration / 1e9, 1)
```

`total_duration` (Nanosekunden) umfasst Tokenisierung + Inferenz + Dekodierung.
**P50-Latenz** wird über die fünf Inputs pro Modell manuell berechnet und in
`results.md` eingetragen.

### 4.1 Cold-Load-Kalibrierung (`ColdLatencyFactor`)

`ColdLatencyFactor` (Default: `2.0`) skaliert die erwartete Latenz, wenn das Modell nicht
geladen ist. Um den Faktor zu kalibrieren:

1. **Warm-Lauf:** Modell bereits geladen (via `keep_alive`). Eval mit 5 Inputs, P50 notieren.
2. **Cold-Lauf:** `ollama stop <modell>` → Eval mit 5 Inputs, P50 notieren.
3. **Faktor:** `ColdLatencyFactor = ColdP50 / WarmP50`

```powershell
# Warm-P50 und Cold-P50 aus den Ergebnissen:
$warmP50  = 15700   # ms, Beispielwert
$coldP50  = 32000   # ms, Beispielwert (Cold-Load dauert ~2× länger)
$factor   = [math]::Round($coldP50 / $warmP50, 1)
Write-Host "ColdLatencyFactor: $factor"
```

Für CPU-only-Hardware lag der Faktor in Vorversuchen bei ca. 2,0 (Default). Auf GPU-Hardware
ist der Wert tendenziell niedriger (GPU-Laden ist schneller), muss aber empirisch bestimmt
werden.

**Status:** GPU-Cold-Load-Kalibrierung ausstehend — diese Entwicklungsmaschine ist
CPU-only; GPU-Pfad ist mock-verifiziert, nicht auf echter GPU-Hardware gemessen.

---

## 5. Reproduzierbarkeit

**Voraussetzungen:**

1. Ollama läuft (`http://localhost:11434/api/tags` erreichbar, Timeout 3 s).
2. Modell bereits gepullt — **kein automatischer Pull** im Skript (defensiv).
3. Vor dem Messlauf: Modell aus dem Speicher entladen (`ollama stop <modell>`),
   damit Cold-Load gemessen wird.
4. Keine anderen großen Prozesse, die RAM stark verändern (IDE schließen
   oder RAM-Verbrauch vorher notieren).

**Ausführung:**

```powershell
# commit-messenger — alle Inputs, nur llama3.2:3b
./plugins/kagents/agents/commit-messenger/evals/run-evals.ps1 -Models 'llama3.2:3b'

# Defensiver Schnelllauf (2 Inputs)
./plugins/kagents/agents/commit-messenger/evals/run-evals.ps1 -Models 'llama3.2:3b' -MaxInputs 2

# code-reviewer — 7b (Timeout explizit, da CPU-only lange dauert)
./plugins/kagents/agents/code-reviewer/evals/run-evals.ps1 -Models 'qwen2.5-coder:7b' -TimeoutSec 1800
```

Ergebnisse landen in `runs/<yyyy-MM-dd>/`. Scores und P50-Latenz manuell in
`results.md` eintragen.

---

## 6. Messwerte-Tabelle

> **Interpretation:**
>
> - **PeakRamMb** = `/api/ps` `size` (MB) beim Cold-Load; freier-RAM-Delta als Quervergleich.
> - **PeakVramMb** = `/api/ps` `size_vram` (MB) beim GPU Cold-Load. `0` = CPU-Pfad / nicht gemessen.
> - **LatenzP50Ms** = Median der `total_duration`-Werte über alle Inputs (ms).
> - **Score** = Anteil A/B aus Spike #251 (Quality-Eval gegen Claude-Baseline).
> - **Status** = `gemessen` (auf dieser HW real erhoben) | `ausstehend`.

| Modell | HW-Klasse | PeakRamMb | PeakVramMb | LatenzP50Ms | Score (A/B) | Status |
| --- | --- | ---: | ---: | ---: | :---: | --- |
| `llama3.2:3b` | cpu-low | 3887 | 0 | 15 700 ¹ | 0 % | gemessen (2026-06-07, warm; /api/ps-Footprint; Latenz aus #251) |
| `qwen2.5-coder:1.5b` | cpu-low | — | 0 | 7 400 | 0 % | ausstehend — konservativer Default |
| `qwen2.5-coder:7b` | cpu-low | — | 0 | 34 800 | 0 % | ausstehend — konservativer Default |
| `qwen2.5-coder:14b` | cpu-low | — | 0 | n/a | n/a | nicht testbar (RAM-Limit, #251) |
| *(alle Modelle)* | gpu-7b | — | ausstehend | — | — | ausstehend — vom PO auf Ziel-HW zu erheben |
| *(alle Modelle)* | gpu-14b | — | ausstehend | — | — | ausstehend — vom PO auf Ziel-HW zu erheben |
| *(alle Modelle)* | gpu-14b-plus | — | ausstehend | — | — | ausstehend — vom PO auf Ziel-HW zu erheben |
| *(alle Modelle)* | cpu-32 | — | 0 | — | — | ausstehend — vom PO auf Ziel-HW zu erheben |

**Hinweis zur cpu-low-Messung (2026-06-07):**  
Das Modell `llama3.2:3b` war beim Messlauf bereits warm geladen (PeakRamDelta = 0 MB).
Der `/api/ps`-Wert von **3887 MB** entspricht dem tatsächlichen Footprint im
Speicher und ist unabhängig vom Warm/Cold-Zustand zuverlässig. Für einen
reproduzierbaren Cold-Load-Wert: `ollama stop llama3.2:3b` vor dem Lauf ausführen.

**Latenz** (aus #251-Daten, cpu-low, alle 5 Inputs):

| Modell | Input01 | Input02 | Input03 | Input04 | Input05 | P50 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `qwen2.5-coder:1.5b` | 11,9 s | 3,1 s | 7,4 s | 11,6 s | 7,6 s | ~7,6 s |
| `llama3.2:3b` | 18,3 s | 5,4 s | 15,7 s | 25,3 s | 15,8 s | ~15,7 s |
| `qwen2.5-coder:7b` | 41,7 s | 12,7 s | 34,8 s | 62,4 s | 33,3 s | ~34,8 s |

---

## 7. `ramBufferMb`-Herleitung

`ResourceGate.cs` verwendet folgenden Default-Buffer, wenn `RamBufferMb = 0` konfiguriert ist:

```csharp
var buffer = opts.ResourceGate.RamBufferMb > 0
    ? opts.ResourceGate.RamBufferMb
    : Math.Max(1024, validation.PeakRamMb / 4);
```

**Begründung:**

| Anteil | Herleitung |
| --- | --- |
| `PeakRamMb / 4` | 25 % Puffer für Kontext-Overhead: ein `llama3.2:3b`-Peak von ~3887 MB erzeugt bei großem Kontext (Input #04, ~1500 Tokens) ca. 300–600 MB mehr als bei kleinem Kontext. 25 % ≈ 970 MB decken diesen Spielraum. |
| `max(…, 1024)` | OS-Reserve: Windows und Linux halten typischerweise 0,5–2 GB RAM für Kernel, I/O-Cache und andere Systemdienste vor. Das Minimum von 1 GB stellt sicher, dass auch bei sehr kleinen Modellen (z. B. 1.5b-Modelle mit ~1,3 GB Peak) kein Rechner in Swap-Gefahr gerät. |

**Beispielrechnung `llama3.2:3b` auf `cpu-low`:**

```text
PeakRamMb    = 3887
Buffer       = max(1024, 3887 / 4) = max(1024, 971) = 1024
Bedarf       = 3887 + 1024 = 4911 MB
Schwelle     = free_RAM muss ≥ 4911 MB sein
```

Auf dem 15-GB-Laptop mit ~5765 MB frei (laufende IDE) würde ResourceGate
`llama3.2:3b` mit ~854 MB Spielraum zulassen — sofern `PeakRamMb` in der
Konfiguration eingetragen wäre. Da `cpu-low.Models` leer bleibt (0 % A/B),
wird immer substituiert, unabhängig vom RAM-Check.

---

## 8. Bekannte Einschränkungen

- **Warmer Modellzustand:** Das Free-RAM-Delta ist ~0 für alle Inputs außer dem
  ersten Cold-Load. `/api/ps` bleibt in allen Fällen korrekt.
- **Systemweites Rauschen:** IDE, Browser und Hintergrundprozesse können den
  Delta während der Messung verfälschen. Mehrere Läufe auf derselben HW empfohlen.
- **macOS:** `Get-FreeRamMb` gibt auf macOS immer 0 zurück (vm_stat-Parsing nicht
  implementiert). `/api/ps`-Werte bleiben korrekt. Delta-Spalte ignorieren.
  macOS ist nicht unterstützt (CPU-Sampler = 0, GPU-Pfad nie aktiv).
- **PeakRamMb = 0 und PeakVramMb = 0 in der Konfiguration** → ResourceGate sperrt
  lokale Ausführung für dieses Modell (fail-safe). Fehlende Messwerte führen zur
  sicheren Substitution, nicht zu Fehlern.
- **GPU-VRAM-Messung:** Alle GPU-Klassen-Werte (`PeakVramMb`) sind auf dieser
  Entwicklungsmaschine (CPU-only) ausstehend. Der GPU-Pfad ist im Code mock-verifiziert;
  reale Werte müssen auf der Ziel-GPU-Hardware erhoben werden.

---

## 9. Live-Betriebsdaten (`learned-stats.json`)

Ergänzend zu den dedizierten Eval-Läufen (§ 2–5) liefert K.Switchboard im laufenden Betrieb eine
**Live-Datenquelle**, wenn `RecordLocalInferenceStats: true` gesetzt ist (opt-in, siehe
[configuration.md § 1.10.4](configuration.md#learned-stats)). Pro erfolgreicher lokaler Inferenz
werden Latenz und ein RAM-Delta erfasst und aggregiert pro Modell nach `learned-stats.json`
geschrieben (per-install, nicht committed).

### 9.1 Verwendung für die manuelle Mapping-Pflege

Die Live-Daten sind eine **ergänzende** Hilfe, um die committed `ModelValidation`-Werte in
`HardwareClasses[*].Models[*]` zwischen den Eval-Läufen plausibel zu halten:

| Feld in `learned-stats.json` | Verfeinert | Verwendung |
| --- | --- | --- |
| `avgLatencyMs` (laufender Mittelwert über reale Läufe) | `LatencyP50Ms` | Driftet die reale Latenz deutlich vom committed `LatencyP50Ms` ab, ist ein neuer dedizierter Eval-Lauf angezeigt. Der Live-Wert ist ein Mittelwert über reale Kontexte, kein sauberer Median über die fünf festen Fixtures. |
| `lastRamDeltaMb` (2-Punkt-GC-Approximation) | `PeakRamMb` | Dient als **Plausibilitätscheck** gegen den committed `PeakRamMb`. Liegt das Live-Delta dauerhaft weit über dem hinterlegten Wert, lohnt sich eine erneute `/api/ps`-Messung (§ 3.3). |

### 9.2 Klarstellung: Approximation vs. präzise Quelle

Die Live-Telemetrie ist bewusst eine **Approximation**:

- `avgLatencyMs` ist ein laufender Mittelwert über reale, variabel große Kontexte — kein über
  fixe Fixtures berechneter Median wie `LatencyP50Ms` (§ 4).
- `lastRamDeltaMb` ist ein systemweites GC-Delta (durch Fremdprozesse verrauschbar) — kein
  authoritativer Footprint wie der `/api/ps`-`size`-Wert (§ 3.3).

**Die dedizierten Eval-Läufe (§ 2–5) bleiben die präzise Quelle** für die committed Werte. Die
Live-Daten zeigen lediglich an, *wann* ein erneuter Eval-Lauf sinnvoll ist. Es findet **keine**
automatische Laufzeit-Nachpflege statt — `learned-stats.json` wird ausschließlich gelesen und
manuell ausgewertet (read-only, siehe [resource-aware-routing.md § 6](resource-aware-routing.md)).
