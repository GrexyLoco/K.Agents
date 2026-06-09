# Ressourcen-bewusstes Routing

<!-- markdownlint-disable MD033 -->

> **Querverweise:**
> [Konfigurationsreferenz](configuration.md) › [ResourceGate](configuration.md#resource-gate) ·
> [HardwareClasses](configuration.md#hardware-classes) ·
> [LocalModelTiers / TierSubstitutions](configuration.md#local-model-tiers) ·
> [Eval-Messmethodik](eval-measurement.md) ·
> [Troubleshooting](troubleshooting.md#unerwartete-substitution)

---

## 1. Konzept

K.Switchboard betreibt zwei komplementäre Schutzmechanismen:

| Mechanismus | Zeitpunkt | Auslöser | Zweck |
| --- | --- | --- | --- |
| **ResourceGate** (proaktiv) | Pre-flight, vor dem Upstream-Call | RAM/CPU-Prüfung | verhindert Überlastung der Maschine |
| **FallbackService** (reaktiv) | Nach einem fehlgeschlagenen Upstream-Call | HTTP 4xx/5xx oder Netzwerkfehler | Resilienz bei Laufzeitfehlern |

ResourceGate entscheidet anhand von Echtzeit-Ressourcen und committed Messdaten, **bevor** ein
Request die Maschine belastet. Der FallbackService greift als zweite Absicherung, wenn ein
lokaler oder Cloud-Upstream trotzdem mit einem Fehler antwortet.

---

## 2. Datenfluss

```text
Client-Request (model: "qwen2.5-coder:14b")
        │
        ▼
  ┌──────────────────────────────────────────────────────────┐
  │                      ResourceGate                        │
  │                                                          │
  │  1. Gate aktiv? (Enabled=true)                           │
  │     Nein → Proceed (gate-disabled)               ────────┼──► FallbackService / Upstream
  │                                                          │
  │  2. Ziel-Provider = Ollama?                              │
  │     Nein (Anthropic, etc.) → Proceed             ────────┼──► FallbackService / Upstream
  │     (non-local-provider)                                 │
  │                                                          │
  │  3. HW-Profil laden (hw-profile.json / Cache)            │
  │     ↓                                                    │
  │  4. HW-Klassen-Match (erste passende Klasse)             │
  │     Kein Match → BuildSubstitution                       │
  │     ("no matching hardware class")                  ─────┤
  │     ↓                                                    │
  │  5. Modell in Klasse.Models?                             │
  │     PeakVramMb=0 und PeakRamMb=0 → BuildSubstitution    │
  │     ("no validated footprint")                      ─────┤
  │     ↓                                                    │
  │  6. CPU-Last prüfen (alle Pfade)                         │
  │     CpuLoad > CpuMaxLoadPercent → BuildSubstitution ─────┤
  │     ("CPU n%")                                           │
  │     ↓                                                    │
  │  7. Ressourcen-Admission (GPU- oder CPU-Pfad)            │
  │                                                          │
  │     GPU-Pfad (PeakVramMb>0 AND GpuVendor≠"none"         │
  │               AND VramMb>0):                             │
  │       usableVram = max(0, VramMb−VramDisplayReserveMb)   │
  │       PeakVramMb > usableVram → BuildSubstitution   ─────┤
  │       ("VRAM PeakMB/usableMB")                           │
  │                                                          │
  │     CPU-Pfad (sonst):                                    │
  │       freeRam < PeakRamMb+Buffer → BuildSubstitution ────┤
  │       ("free XMB/NMB")                                   │
  │     ↓                                                    │
  │  8. Latenz-Gate (optional, MaxLatencyMs>0                │
  │                  AND LatencyP50Ms>0)                     │
  │     expectedMs = P50 × coldFactor × contextFactor        │
  │     expectedMs > MaxLatencyMs → BuildSubstitution   ─────┤
  │     ("latency ~Xms > Yms (warm=…, ctx×…)")               │
  │     ↓                                                    │
  │     Proceed (local-admitted gpu|cpu)             ────────┼──► OllamaProvider
  │                                                          │
  │  BuildSubstitution:                                       │
  │    a) FallbackChain vorhanden? → Proceed mit              │
  │       chain[0], Header: "<lokal> -> <ziel>                │
  │       (deferred: <grund>)"                       ────────┼──► FallbackService / Upstream
  │    b) LocalModelTiers + TierSubstitutions?                │
  │       → Proceed mit Claude-Modell, Header:                │
  │       "<claude> (local <lokal> not viable                 │
  │       — <grund>)"                                ────────┼──► AnthropicProvider
  │    c) Kein Fallback, kein Substitut → 503        ────────┼──► Client (HTTP 503)
  │                                                          │
  │  Monitor-Fehler (ex) → fail-open: Proceed          ──────┼──► FallbackService / Upstream
  │  (resource-monitor-error)                               │
  └──────────────────────────────────────────────────────────┘
```

**Hinweis macOS:** Der CPU-Sampler gibt auf macOS immer 0 % zurück (Schritt 6 blockiert nie),
und der GPU-Detektor liefert immer `VramMb=0` (kein GPU-Pfad). macOS ist daher nicht
unterstützt — nur Linux und Windows sind vollständig funktionsfähig.

---

## 3. Die zwei Datenspeicher

ResourceGate kombiniert zwei getrennte Datenquellen:

### 3.1 Datenspeicher A — HW-Profil (`hw-profile.json`)

- **Was:** Maschinenspezifisches Hardware-Profil (RAM, Cores, GPU, VRAM, Zeitpunkt)
- **Ort:** `%APPDATA%\K.Switchboard\hw-profile.json` (Windows) / `~/.config/K.Switchboard/hw-profile.json` (Linux); macOS nicht unterstützt
- **Herkunft:** Automatisch erkannt beim ersten Request; 1× pro Kalendermonat erneuert
- **Committed:** Nein — maschinenspezifisch, per `.gitignore` ausgeschlossen
- **Felder:** `TotalRamMb`, `Cores`, `GpuVendor`, `GpuModel`, `VramMb`, `DetectedOn`

### 3.2 Datenspeicher B — HardwareClasses (`config.json`)

- **Was:** Committedes Mapping: HW-Klassen → validierte lokale Modelle + empirische Messdaten
- **Ort:** `%APPDATA%\K.Switchboard\config.json` › `HardwareClasses`
- **Herkunft:** Team-kuratiert; basiert auf Evals (siehe [eval-measurement.md](eval-measurement.md))
- **Committed:** Ja — ist Teil der Anwendungskonfiguration
- **Felder pro Modell:** `PeakRamMb`, `PeakVramMb`, `ValidatedOn`, `LatencyP50Ms`, `Score`

Die Trennung ist bewusst: Datenspeicher A beschreibt *diese* Maschine (dynamisch, lokal),
Datenspeicher B beschreibt, was auf welcher Klasse *funktioniert* (statisch, shared).

---

## 4. Substitutions-Logik (Tier-basiert)

Kann ein lokales Modell nicht ausgeführt werden, sucht ResourceGate ein Claude-Substitut
in zwei Schritten:

1. **FallbackChain** (höhere Priorität): Ist für das angefragte Modell eine explizite
   `FallbackChains`-Kette konfiguriert, wird `chain[0]` verwendet.
2. **Tier-Substitution**: Das Modell wird via `LocalModelTiers` einem Tier (`S`/`M`/`L`)
   zugeordnet, und `TierSubstitutions[tier]` liefert das Claude-Modell.

Das Tier beschreibt die **Aufgabengröße**, keine Qualitätsäquivalenz. Die Entscheidung,
`claude-sonnet-4-6` als Default für Tier M und L zu nutzen, ist empirisch begründet:
Spike #251 zeigte 0 % A/B-Score für alle lokalen Modelle auf cpu-only-Hardware.

Gibt es weder FallbackChain noch Tier-Substitut, antwortet K.Switchboard mit HTTP 503.

---

## 5. Maschinen-Schutz (Blast-Radius)

Drei Mechanismen begrenzen die Auswirkung lokaler Inferenz auf das System:

**`num_thread`-Drosselung:**  
Ollama-Requests erhalten `options.num_thread = max(2, Kerne - 2)`. Auf einer 12-Kern-Maschine
laufen maximal 10 Threads für Ollama; 2 Kerne bleiben für OS und andere Prozesse reserviert.
Der Floor von 2 stellt sicher, dass auch auf Maschinen mit sehr wenigen Kernen ein Minimum an
Parallelität erhalten bleibt.

**Single-Inference-Serialisierung:**  
Ein interner `LocalInferenceGate`-Lock serialisiert alle Ollama-Requests — es läuft stets
nur eine Inferenz gleichzeitig. Parallele Requests blockieren und warten auf Freigabe.

**Ollama-Prozess-Priorität (opt-in):**  
Ist `LowerOllamaPriority` aktiv, senkt K.Switchboard beim Start die Prozess-Priorität des lokalen
Ollama-Prozesses auf below-normal. Damit verdrängt lokale Inferenz interaktive Prozesse (IDE,
Browser) nicht, wenn die CPU unter Last steht. Greift nur bei lokalem Ollama (localhost) und ist
best-effort (ein Fehler bricht den Start nicht ab); die Priorität wird einmalig beim Start gesetzt.
macOS wird nicht unterstützt. Details und Default siehe
[ResourceGate § 1.10.1](configuration.md#resource-gate).

---

## 6. Live-Telemetrie (read-only)

Ist `RecordLocalInferenceStats` aktiv, beobachtet K.Switchboard pro erfolgreicher lokaler Inferenz
die tatsächlich gemessene End-to-End-Latenz und ein RAM-Delta (2-Punkt-GC-Approximation) und
schreibt sie aggregiert pro Modell nach `learned-stats.json` (per-install, nicht committed).

Diese Telemetrie ist ein reiner **Beobachtungs-Seitenkanal**: sie **beeinflusst den Datenfluss aus
Abschnitt 2 und die Admission-Entscheidung des ResourceGate NICHT**. Die committed
`ModelValidation`-Werte (`PeakRamMb`, `LatencyP50Ms`) werden zur Laufzeit nicht überschrieben — es
gibt keinen Drift und keine automatische Selbst-Nachpflege. Die erfassten Werte dienen
ausschließlich als Datenquelle für die **manuelle** Verfeinerung des Mappings (siehe
[eval-measurement.md](eval-measurement.md) und [configuration.md § 1.10.4](configuration.md#learned-stats)).

---

## 7. Transparenz

### 7.1 Serilog-Logging

ResourceGate schreibt für jede Entscheidung einen Serilog-Eintrag:

| Situation | Log-Level | Nachricht (Muster) |
| --- | --- | --- |
| Zugelassen | Information | `ResourceGate: lokal zugelassen {Model} ({Path}, CPU {Cpu}%, warm={Warm})` — `{Path}` = `GPU` oder `CPU` |
| FallbackChain | Information | `ResourceGate: defer-to-fallback {Header}` |
| Tier-Substitution | Information | `ResourceGate: substitution {Header}` |
| Tier ohne Substitut | Warning | `ResourceGate: Tier '{Tier}' für {Model} ist nicht in TierSubstitutions konfiguriert.` |
| 503 | Warning | `ResourceGate: kein Fallback/Substitut für {Model} ({Reason}) → 503` |
| Monitor-Fehler (fail-open) | Warning | `ResourceGate: Ressourcen-Check fehlgeschlagen für {Model} → fail-open (Proceed).` |

**Hinweis:** `warm` im Log-Eintrag (ob das Modell bereits geladen ist) ist ein reiner
Informationswert — er beeinflusst die Zulassungs-Entscheidung nicht.

### 7.2 Response-Header

Bei jeder Substitution setzt K.Switchboard den Header `X-K-Switchboard-Substitution` in der
HTTP-Antwort. Clients können ihn auslesen, um zu erkennen, ob und warum umgeleitet wurde.

**FallbackChain-Format:**

```text
<lokalesModell> -> <zielModell> (deferred: <grund>)
```

**Tier-Substitutions-Format:**

```text
<claudeModell> (local <lokalesModell> not viable — <grund>)
```

Mögliche `<grund>`-Werte: `free <X>MB/<N>MB` · `CPU <n>%` · `VRAM <P>MB/<U>MB` ·
`latency ~<e>ms > <m>ms (warm=<b>, ctx×<f>)` · `no matching hardware class` ·
`no validated footprint`

---

## 8. Fail-Open bei Monitor-Fehlern

Tritt beim Ressourcen-Check ein interner Fehler auf (z.B. `hw-profile.json` unlesbar,
Prozess-Abbruch beim GPU-Tool-Start), gibt ResourceGate mit Grund `resource-monitor-error`
grünes Licht (Proceed). Der Request wird unverändert an den FallbackService übergeben.

Begründung: Ein defekter Ressourcen-Monitor darf nicht jeden lokalen Request mit HTTP 500
killen. Der FallbackService übernimmt die reaktive Fehlerbehandlung. `OperationCanceledException`
(Client-Abbruch) wird hingegen bewusst durchgereicht und nicht als fail-open behandelt.
