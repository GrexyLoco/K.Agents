# Spec: Ressourcen-bewusstes lokal/Provider-Routing (ResourceGate)

- **Issue:** #268 (`feat(switchboard)`)
- **Train:** v1.21.0
- **Branch:** `feature/268-resource-aware-routing` (von `dev/v1.21.0`)
- **Datum:** 2026-06-07
- **Scope:** Vollständig — MVP + Ausbau +1 + Ausbau +2 (per User-Entscheidung)

## 1. Problem

K.Switchboard trifft die Lokal-vs-Provider-Entscheidung heute **statisch** (Alias → Provider) und
bemerkt Ressourcenknappheit erst, wenn das lokale Modell bereits hängt. Spike #251 hat gezeigt:
Tauglichkeit lokaler Modelle ist **stark hardware-abhängig** (`qwen2.5-coder:14b` auf 15-GB-CPU-Workstation
nicht lauffähig → Swapping → Ollama-Hänger; `7b` mit 2/5 Timeouts). Es fehlt ein proaktiver Gate, der
**pro Request** entscheidet, ob das lokale Modell **jetzt** ausführbar ist, und sonst transparent
auf einen Provider ausweicht oder klar fehlschlägt — ohne die Maschine zu zerschießen, jede Entscheidung
begründet im Log **und** in der Antwort.

## 2. Architektur-Überblick

Neuer Pre-flight-Schritt **`ResourceGate`**, der im Endpoint **vor** `FallbackService.ForwardWithFallbackAsync`
läuft. Der Gate prüft **proaktiv** das primär angefragte Modell; der bestehende `FallbackService` bleibt
unverändert für **reaktive** HTTP-Fehler zuständig.

```
POST /v1/messages → requestedModel
  └─ ResourceGate.Evaluate(requestedModel) → RoutingDecision
       resolve alias → (provider, model)
       provider ≠ ollama  → no-op (durchreichen)
       provider = ollama:
         profile = HardwareProfileCache.Get()        (statisch, gecacht)
         class   = HardwareClassifier.Match(profile)
         need    = class.Models[model].peakRamMb + ramBuffer
         live    = LiveResourceProbe.Sample()        (freier RAM, CPU-Last, /api/ps-Warmth)
         ┌ ausführbar  → RunLocal
         └ nicht ausf. → Priorität:
              1) FallbackChains[requestedModel] gesetzt → Start auf erstes Glied
              2) Substitutions[model] vorhanden → still substituieren + Header + Log
              3) nichts davon → HTTP 5xx + ProblemDetails + Log
  └─ effektives Modell → FallbackService.ForwardWithFallbackAsync (unverändert)
```

**Gate-Reichweite (Design-Entscheidung):** Der Gate prüft **nur das primär angefragte Modell**, nicht
jedes Fallback-Glied. Er sitzt als eigener Service **vor** dem `FallbackService` (näher am Issue-Diagramm,
saubere Trennung proaktiv/reaktiv).

### Einhängepunkte (verifizierte Code-Anker, Stand v1.20.0)

| Datei | Stelle | Änderung |
|---|---|---|
| `Program.cs` | Endpoint `POST /v1/messages` (~Z. 121–165) | `ResourceGate.Evaluate` vor `ForwardWithFallbackAsync`; DI-Registrierung der neuen Services |
| `Routing/ModelRouter.cs` | `Resolve()` | unverändert; vom Gate genutzt zur Alias-Auflösung |
| `Services/FallbackService.cs` | `ForwardWithFallbackAsync` | unverändert; empfängt effektives Modell |
| `Providers/OllamaProvider.cs` | `BuildOllamaBodyAsync` `options` (Z. 95–98) | `num_thread = Kerne−2` ergänzen; `SemaphoreSlim(1)`-Serialisierung; Watchdog (#252) |
| `Configuration/SwitchboardOptions.cs` | Record | neue Properties `HardwareClasses`, `LocalProviderSubstitutions`, `ResourceGate` |

## 3. Komponenten

### 3.1 `IHardwareProfileDetector`
Erkennt **(a)** RAM (gesamt), CPU-Kerne, GPU-Modell, VRAM, Vendor.
- **RAM/CPU:** .NET-APIs (`GC.GetGCMemoryInfo().TotalAvailableMemoryBytes`, `Environment.ProcessorCount`) — keine externen Abhängigkeiten.
- **GPU/VRAM:** **Subprocess** pro OS (Design-Entscheidung), trim-safe, keine P/Invoke:
  - NVIDIA: `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits`
  - Windows (Fallback): CIM/`wmic path win32_VideoController get name,AdapterRAM`
  - macOS: `system_profiler SPDisplaysDataType` / `sysctl hw.memsize`
  - Tool fehlt im PATH → `gpuVendor = "none"` → CPU-Pfad (kein harter Fehler).

### 3.2 `HardwareProfileCache`
Persistiert Profil **(a)** als `hw-profile.json` unter `Environment.SpecialFolder.ApplicationData`
(`%APPDATA%\K.Switchboard\` auf Windows, `~/.config/K.Switchboard/` auf Linux, `~/Library/Application Support/`
auf macOS). **Nicht committed** (`.gitignore`-Eintrag analog `config.json`).
- **Refresh:** bei leer/fehlend **oder** wenn der aktuelle Monat ≠ Monat von `detectedOn` (1×/Monat,
  am ersten Lauf-Tag des Monats). Profil trägt `detectedOn`-Timestamp.

> **Begründung Per-Install-Cache:** (a) ist maschinenspezifisch und darf **nicht** mit der committed Config
> zwischen Laptop (15 GB) und Desktop (32 GB) mitwandern.

### 3.3 `ILiveResourceProbe`
Pro Request nur **günstige** OS-Reads:
- freier System-RAM (jetzt)
- CPU-Last als kurzer rollender Mittelwert (3–5 s) — Momentan-Spike blockt nicht fälschlich
- Ollama `/api/ps` — ist das Modell bereits **warm**? (stärkster Latenz-Prädiktor; Cold-Load = #251-Timeout-Ursache)

> **Kein** Per-Request-VRAM-Polling (`nvidia-smi` ~50–150 ms Prozess-Spawn). GPU-vs-CPU-Pfad kommt aus
> dem gecachten statischen Profil (a).

### 3.4 `HardwareClassifier`
Ordnet erkanntes Profil **(a)** einer committed **HW-Klasse (b)** zu. Match über Bereiche
(CPU-Kerne, RAM, GPU-Vendor, VRAM). Erste passende Klasse gewinnt; keine Klasse → konservative
Default-Klasse (CPU-only, kleinstes Modell).

### 3.5 `ResourceGate`
Pre-flight-Service. Liefert ein `RoutingDecision`-Objekt (siehe 3.7). Admission-Regel:
`freier RAM ≥ peakRamMb(model) + ramBuffer` **und** `CPU-Last ≤ cpuMaxLoadPercent`. Warmth aus `/api/ps`
fließt in die Latenz-/Entscheidungsbegründung ein.

### 3.6 Blast-Radius-Cap (`OllamaProvider`-Erweiterung)
1. `num_thread = Kerne − 2` in `options` (an `OllamaProvider.cs:95-98` neben `num_predict`) → ≥ 2 Kerne frei.
2. `SemaphoreSlim(1)` — nie zwei lokale Inferenzen gleichzeitig.
3. Watchdog: bestehender Timeout (#252) bricht hängende lokale Inferenz ab → Provider-Fallback.
4. **+2 (Ausbau):** Ollama-Prozess-Priorität below-normal, plattformspezifisch.

### 3.7 `RoutingDecision` (Record)
Strukturierte Entscheidung speist **beides**:
- **Serilog:** z. B. „claude-opus-4-8, weil qwen2.5-coder:14b bei RAM 0.6/15 GB nicht ausführbar".
- **Response-Header:** `X-K-Switchboard-Substitution: claude-opus-4-8 (local qwen2.5-coder:14b not viable — RAM)`
  (analog zum bestehenden `X-K-Switchboard-Fallback-Used: <from> -> <to>`).

## 4. Config-Schema (committed, `SwitchboardOptions`)

### 4.1 HW-Klassen-Taxonomie (b) — VRAM-getrieben

Klassen matchen über **RAM + GPU-Vendor + VRAM-Schwelle** (nicht über spezifische Kartennamen — die
konkreten Karten sind Beispiele je VRAM-Bucket). VRAM-Schwellen aus Recherche: 7B ≈ 5–6 GB, 14B (Q4_K_M)
≈ 8,7 GB → Buckets `6144` / `10240` / `16384` MB.

| Klasse | Match | Beispiel-HW | Lokaler Pfad |
|---|---|---|---|
| `cpu-low` | `maxRamMb 16384`, `gpuVendor none` | **Dieser Laptop** (15,4 GB, CPU) | Keine lokalen Modelle (real 0 % A/B, #251) → immer substituieren |
| `cpu-32` | `minRamMb 24576`, GPU `none` **oder** `maxVramMb 6143` | 32 GB ohne GPU · 32 GB + **GTX 970** (3,5 GB eff.) / GTX 1050 Ti / RX 580 | CPU-Inferenz 7B/14B (langsam) |
| `gpu-7b` | `minVramMb 6144`, `maxVramMb 10239` | 8-GB-GPUs | 7B auf GPU |
| `gpu-14b` | `minVramMb 10240`, `maxVramMb 16383` | **GTX 1080 Ti** (11 GB) · AMD **RX 6700 XT** (12 GB) | 7B komfortabel, 14B eng |
| `gpu-14b-plus` | `minVramMb 16384` | **RTX 5070 Ti** (16 GB) · AMD **RX 9070 XT** (16 GB) | 14B + großer Kontext, 32B knapp |

> **GTX 970 = real 3.584 MB nutzbar** (Hardware-Partitionierung, Class-Action-bekannt) → unter 6-GB-Schwelle,
> fällt in `cpu-32`. Schwache GPUs (970, 1050 Ti) ändern den Pfad nicht ggü. reiner CPU. `gpuVendor`
> unterscheidet CUDA (`NVIDIA`) / ROCm (`AMD`) / CPU (`none`).

### 4.2 Tier-basiertes Substitutions-Mapping — datenbasiert

**Kein** Qualitäts-Match (jedes lokale Modell liegt unter dem schwächsten Claude: `qwen:32b` = 8 % vs.
Haiku 28 % vs. Sonnet 79 % Aider Polyglot). Stattdessen **Aufgaben-Tier** des konfigurierten Modells.
Tier-Zuordnung aus **LiveCodeBench** (S <10 %, M ~18 %, L >23 %; HumanEval/MBPP gesättigt → **nie** fürs Routing).

```jsonc
"LocalModelTiers": {                 // lokales Modell → Tier (wartungsarm erweiterbar)
  "qwen2.5-coder:1.5b": "S", "llama3.2:3b": "S",
  "qwen2.5-coder:7b":  "M", "llama3.1:8b": "M",
  "qwen2.5-coder:14b": "L", "qwen2.5-coder:32b": "L"
},
"TierSubstitutions": {               // Tier → Claude-Substitut
  "S": "claude-haiku-4-5",           //  einfachste Aufgaben (Format/Commits)
  "M": "claude-sonnet-4-6",          //  Standard-Coding
  "L": "claude-sonnet-4-6"           //  Code-Review — Opus per Opt-in (auf claude-opus-4-8 setzen)
}
```

### 4.3 HardwareClasses (b) + ResourceGate

```jsonc
"HardwareClasses": [
  { "name": "gpu-14b",
    "match": { "minRamMb": 24576, "gpuVendor": "NVIDIA", "minVramMb": 10240, "maxVramMb": 16383 },
    "models": { "qwen2.5-coder:14b": { "peakRamMb": 0, "validatedOn": "<eval>", "latencyP50Ms": 0, "score": "" } } },
  { "name": "cpu-low",
    "match": { "maxRamMb": 16384, "gpuVendor": "none" },
    "models": {} }                   // leer = keine lokalen Modelle tauglich → immer substituieren
],
"ResourceGate": {
  "enabled": true,
  "ramBufferMb": 0,                  // 0 = im eval-measurement.md hergeleiteter Default (siehe §5)
  "cpuLoadWindowSeconds": 4,
  "cpuMaxLoadPercent": 85
}
```

Neue Records: `HardwareClassConfig` (name, match, models), `HardwareClassMatch`
(minRamMb?, maxRamMb?, minCores?, gpuVendor?, minVramMb?, maxVramMb?), `ModelValidation`
(peakRamMb, validatedOn, latencyP50Ms, score), `ResourceGateOptions`. Hot-Reload über bestehenden
`IOptionsMonitor`-Pfad; Defaults so, dass fehlende Sektion = Gate deaktiviert (backward-compatible).

## 5. Admission-Sizing & ramBuffer-Kalibrierung

`freier RAM ≥ peakRamMb + ramBuffer` — **nicht** die `ollama list`-Dateigröße allein (geladenes Modell =
Datei + KV-Cache/Kontext-Overhead, wächst mit Kontextlänge). Die Live-Probe misst bereits den **freien**
RAM (nach OS/IDE); der `ramBuffer` deckt nur noch (a) KV-Cache-Wachstum über die Eval-Kontextlänge hinaus,
(b) Allokations-Jitter, (c) Reserve gegen die Swapping-Schwelle (#251: Swapping = Ollama-Hänger).

**Kalibrierung (statt geratener 2 GB):**
- `peakRamMb` im Hybrid-Eval beim **realistischen Max-Kontext** messen (Referenz: #248-Payload ~4.130 Tokens
  bzw. konfiguriertes Maximum), nicht beim Minimal-Prompt.
- `ramBuffer`-Default im `eval-measurement.md` **datenbasiert hergeleitet** (Differenz Peak bei kleinem vs.
  großem Kontext + OS-Reserve), konfigurierbar. `ramBufferMb: 0` in der Config = „nutze hergeleiteten Default".

## 6. Eval-Measurement (Hybrid)

- `plugins/kagents/agents/*/evals/run-evals.ps1` um **RAM-Sampling + Latenz** erweitern:
  Ollama `/api/ps` + RAM-Snapshot um den Inferenz-Call (Peak über kurzes Sampling-Fenster).
- **1 realer Lauf** auf dieser Maschine → echte `peakRamMb`/`validatedOn`/`latencyP50Ms` für die hiesige
  HW-Klasse. Übrige Klassen mit dokumentierten konservativen Defaults (Dateigröße × Faktor), klar als
  „nicht gemessen" markiert.
- Neues `k.switchboard.net/docs/eval-measurement.md`: reproduzierbare Methodik (Skript, Fixtures, Setup)
  + konkrete Messwerte je HW-Setup. Aus `configuration.md` referenziert, damit Mapping-Werte nachvollziehbar/erneuerbar sind.

## 7. Kein-Fallback-Verhalten

Greift weder Fallback noch Substitutions-Mapping → **HTTP 5xx + klare Meldung + Log**. Bewusst **kein**
stiller lokaler Versuch „auf eigene Gefahr" (widerspräche dem Maschinenschutz), **kein** stiller
Qualitäts-/Kostensprung ohne Mapping.

## 8. Dokumentation (verbindlich)

- `k.switchboard.net/docs/configuration.md`: neue Sektionen — HW-Profil-Cache, HW-Klasse→Modell-Mapping,
  Substitutions-Mapping, ResourceGate, Blast-Radius-Caps, Transparenz-Header.
- `k.switchboard.net/docs/troubleshooting.md`: neue Routing-Gründe.
- Neu: `k.switchboard.net/docs/resource-aware-routing.md` (Konzeptübersicht).
- Neu: `k.switchboard.net/docs/eval-measurement.md` (siehe 6).

## 9. Tests (TUnit)

Bestehendes `Build()`-Pattern + `StubProvider`/`FakeOptionsMonitor` aus `FallbackServiceTests.cs` nutzen.
- **Gate-Entscheidungen:** genug RAM → RunLocal; zu wenig RAM → Substitution; CPU hoch → Substitution;
  kalt vs. warm (`/api/ps`); Substitution-Header gesetzt + geloggt; kein Fallback/Substitut → 5xx.
- **Classifier:** Profil → korrekte Klasse; kein Match → Default-Klasse.
- **Cache:** Refresh bei leer; Refresh bei Monatswechsel; kein Refresh innerhalb des Monats.
- **Detector:** gemockte Subprocess-Outputs (nvidia-smi vorhanden/fehlend) → korrektes Profil; Tool fehlt → `gpuVendor=none`.
- **Blast-Radius:** `num_thread = Kerne−2` im Ollama-Body; `SemaphoreSlim(1)` serialisiert.
- Ziel: bestehende Coverage (53 %) nicht senken; neue Logik abgedeckt.

## 10. Akzeptanzkriterien (gestaffelt, ein Issue)

### MVP
- [ ] HW-Profil-Auto-Detektion (RAM, Kerne, GPU-Modell/VRAM, Vendor) → Per-Install-Cache; Refresh bei leer + 1×/Monat
- [ ] `ResourceGate` als Pre-flight vor `FallbackService`
- [ ] Live-Gate: freier RAM + CPU-Last (3–5 s) + Ollama `/api/ps`-Warmth
- [ ] Admission: freier RAM ≥ Peak-Footprint + Puffer (empirisch aus `validatedOn`)
- [ ] Blast-Radius: `num_thread = Kerne−2` + `SemaphoreSlim(1)` + Watchdog/Timeout-Abbruch
- [ ] Mapping (b) HW-Klasse→Modell (committed) + Mapping lokal↔Provider-Substitut
- [ ] Transparenz: Serilog + `X-K-Switchboard-Substitution`-Header
- [ ] Kein-Fallback → HTTP 5xx + Log
- [ ] Doku in `k.switchboard.net/docs/` + separates referenziertes Eval-Measurement-md
- [ ] TUnit-Tests: Gate-Entscheidungen (genug/zu wenig RAM, CPU hoch, kalt/warm, Substitution, 5xx)

### Ausbau +1
- [ ] GPU-Pfad-Entscheidung aus statischem Profil (NVIDIA + AMD), VRAM-Schwellen je Klasse
- [ ] Feinere Latenz-Vorhersage (warm vs. cold, Kontextlänge)

### Ausbau +2
- [ ] Ollama-Prozess-Priorität (below-normal), plattformspezifisch
- [ ] Selbst-Nachpflege des Mappings aus Live-Messungen

## 11. Out of Scope

- Erneute Qualitäts-Evals auf besserer Hardware (separat; hier ist die **Mechanik**, nicht die Modellauswahl).
- Änderung der Agent-Definitionen — bleiben hardware-agnostisch (abstrakte Aliase); Mapping lebt in K.Switchboard.

## 12. ReleaseFlow-Constraints (Umsetzung)

- Alle Arbeit auf `feature/268-resource-aware-routing` → PR(s) gegen `dev/v1.21.0`.
- **Train-Check vor jedem Push.** Niemals auf `master`/`release/*` pushen.
- #268 wird beim Stable-Promo via Closing-Keyword geschlossen (kompletter Scope in v1.21.0).
