# Spec: ResourceGate Ausbau +1 (GPU-Pfad, Latenz-Gate, CPU-Sampler Windows)

- **Issue:** #268 (Ausbau-Stufe +1)
- **Train:** v1.21.0 (offen; baut auf MVP-Alpha `v1.21.0-alpha1` auf)
- **Branch:** `feature/268-resource-gate-plus1` (von `dev/v1.21.0`)
- **Datum:** 2026-06-07
- **Basis:** MVP (Spec `2026-06-07-resource-aware-routing-design.md`) ist gemergt; diese Stufe erweitert ihn additiv.

## 1. Ziel & Scope

Drei additive Erweiterungen des MVP-`ResourceGate`:
1. **GPU-Pfad + VRAM-Admission** — GPU-Modelle gegen statisches VRAM (minus Display-Reserve) zulassen statt gegen freien RAM. Inkl. AMD-VRAM-Detektion via `rocm-smi`.
2. **Latenz-Gate** — erwartete Latenz (warm/cold × Kontextlänge) als Hard-Block über konfigurierbarer Schwelle → schützt gegen das #251-Timeout-Szenario.
3. **CPU-Sampler Windows** — System-CPU-Last auf Windows (`GetSystemTimes`) statt nur Linux.

**Out of Scope / Vorgaben:**
- **macOS wird NICHT unterstützt** (User-Direktive). Keine macOS-spezifische Detektion/Sampling; bestehende macOS-Erwähnungen in Code/Docs als „nicht unterstützt" markieren bzw. den defensiven macOS-Pfad im Detektor unangetastet lassen (liefert VRAM=0 → CPU-Pfad, harmlos).
- **Kein Per-Request-VRAM-Polling** (MVP-Spec-Vorgabe bleibt) — VRAM-Admission nutzt das gecachte statische Profil.
- Selbst-Nachpflege des Mappings + Ollama-Prozess-Priorität bleiben in **+2**.

## 2. GPU-Pfad + VRAM-Admission

### Datenmodell
- **`ModelValidation`** (in `SwitchboardOptions.cs`) bekommt `int PeakVramMb` (VRAM-Footprint des Modells beim Laden; `0` = nicht GPU-validiert → kein GPU-Pfad für dieses Modell).

### Detektion (`HardwareProfileDetector`)
- **AMD-VRAM** via `rocm-smi --showmeminfo vram --csv` (analog nvidia-smi-Pfad), Linux + Windows (falls ROCm installiert). Vendor = `"AMD"`, VRAM in MB parsen. Fehlt `rocm-smi`/Exit≠0 → der bestehende wmic-Fallback (Windows) bzw. `none` (CPU-Pfad). NVIDIA bleibt `nvidia-smi`.
- Reihenfolge GPU-Detektion: (1) `nvidia-smi` → NVIDIA; (2) `rocm-smi` → AMD; (3) Windows `wmic` (nur Fallback, 32-bit-Overflow-anfällig); (4) `none`.

### Admission-Pfadentscheidung (`ResourceGate.EvaluateAsync`)
Nach Klassen-Match + `ModelValidation`-Lookup (wie MVP), VOR der RAM-Admission:
- **GPU-Pfad**, wenn `profile.GpuVendor != "none"` **und** `profile.VramMb > 0` **und** `validation.PeakVramMb > 0`:
  - `usableVram = profile.VramMb − ResourceGate.VramDisplayReserveMb`
  - Admission: `validation.PeakVramMb ≤ usableVram` (zzgl. keiner separaten RAM-Prüfung — GPU-Modell liegt im VRAM; ein kleiner RAM-Anteil wird vom OS getragen). CPU-Last-Check bleibt (GPU-Inferenz nutzt auch CPU für Sampling/Tokenization).
  - Erfüllt → `Proceed` (lokal, GPU). Nicht erfüllt → Substitution (Grund „VRAM").
- **CPU-Pfad** (sonst, inkl. GPU vorhanden aber Modell hat kein `PeakVramMb`): bestehende **RAM-Admission** unverändert.

> VRAM ist statisch (gecachtes Profil) — kein Live-Polling. Die Display-Reserve deckt ab, dass die GPU auch den Desktop bedient; auf headless-Servern auf 0 setzbar.

### Config
- **`ResourceGateOptions.VramDisplayReserveMb`** — Default **2048**. Begründung: DWM/Compositor (~0,5 GB) + Browser-GPU (~0,5–1 GB) + IDE (~0,3–0,5 GB) ≈ 1,5–2 GB; GPU-OOM ist hart (Crash/CPU-Fallback), daher konservativ. Headless → 0.

## 3. Latenz-Gate

### Config (`ResourceGateOptions`)
- **`MaxLatencyMs`** — Default **0 = Gate aus** (Opt-in, backward-safe). Doku-Empfehlung als Startwert: **100000** (100 s, das #251-Schmerzlimit).
- **`ColdLatencyFactor`** — Default **2.0**. Cold-Load = Lade-Zeit + Inferenz ≈ 1,5–2× warm; grobe Heuristik, im Cold-Eval kalibrierbar.
- **`LatencyContextReferenceTokens`** — Default **4000** (≈ reales Headless-Payload #248 ~4130 Tokens).

### Berechnung (`ResourceGate.EvaluateAsync`)
Nur aktiv wenn `MaxLatencyMs > 0` **und** `validation.LatencyP50Ms > 0`:
```
contextFactor = max(0.5, inputTokens / LatencyContextReferenceTokens)
coldFactor    = live.ModelWarm ? 1.0 : ColdLatencyFactor
expectedMs    = validation.LatencyP50Ms * coldFactor * contextFactor
```
`expectedMs > MaxLatencyMs` → lokal ablehnen → Substitution (Grund „latency `<expectedMs>`ms > `<max>`ms"). Greift im GPU- wie CPU-Pfad (nach bestandener RAM/VRAM-Admission).

### Input-Größe an den Gate
- Der Endpoint (`Program.cs`) extrahiert eine grobe **Input-Token-Zahl** aus dem bereits geparsten Request-Body (Summe der `messages[].content`-Längen / 4 als grobe Token-Schätzung; 0 wenn nicht ermittelbar) und übergibt sie an `EvaluateAsync` (neuer Parameter `int inputTokens`).
- `EvaluateAsync`-Signatur wird zu `EvaluateAsync(string requestedModel, int inputTokens, CancellationToken ct)`. Bestehende Aufrufer/Tests anpassen (MVP-Tests übergeben `inputTokens: 0` → contextFactor = max(0.5, 0) = 0.5, Latenz-Gate bei MaxLatencyMs=0 ohnehin inaktiv → kein Verhalten geändert).

## 4. CPU-Sampler Windows

- **`CpuLoadSampler`** bekommt einen Windows-Zweig via Win32 `GetSystemTimes(out idle, out kernel, out user)` über **`[LibraryImport]`** (source-generated P/Invoke → trim/AOT-safe, anders als `[DllImport]`). Zwei Snapshots über das Fenster; `busy% = (Δkernel+Δuser − Δidle) / (Δkernel+Δuser) × 100`.
- Linux bleibt `/proc/stat`. macOS/Andere → `0.0` (nicht unterstützt, dokumentiert).
- Die Klasse braucht `partial` für den source-generierten P/Invoke-Code.

## 5. Tests (TUnit)

- **VRAM-Admission:** genug VRAM (nach Reserve-Abzug) → Proceed; zu wenig → Substitution; Display-Reserve wird korrekt abgezogen; GPU vorhanden aber `PeakVramMb=0` → CPU-Pfad (RAM-Admission).
- **GPU-vs-CPU-Pfadwahl:** NVIDIA-Profil + GPU-validiertes Modell → VRAM-Pfad; CPU-Profil → RAM-Pfad.
- **Latenz-Gate:** warm unter Schwelle → Proceed; cold über Schwelle → Substitution; Kontext-Skalierung (großer inputTokens hebt expectedMs); `MaxLatencyMs=0` → Gate inaktiv (kein Block).
- **Detektor:** gemockter `rocm-smi`-Output → AMD-Profil mit VRAM; rocm-smi fehlt → Fallback-Pfad.
- **CpuLoadSampler Windows:** der Windows-Zweig liefert einen plausiblen Wert (0–100) auf der CI-Windows-Maschine (der Test läuft real auf win-x64; Linux-CI würde 0 liefern — Test plattform-tolerant gestalten).
- Bestehende 91 MVP-Tests bleiben grün (Signatur-Anpassung `EvaluateAsync` + `inputTokens` einarbeiten).

## 6. Config-Defaults (`CreateDefault()`)

```jsonc
"ResourceGate": {
  "enabled": true, "ramBufferMb": 0, "cpuLoadWindowSeconds": 4, "cpuMaxLoadPercent": 85,
  "vramDisplayReserveMb": 2048,
  "maxLatencyMs": 0,
  "coldLatencyFactor": 2.0,
  "latencyContextReferenceTokens": 4000
}
```
GPU-Klassen-`Models` bleiben leer (PeakVramMb/PeakRamMb erst nach Messung auf Ziel-HW; wie MVP).

## 7. Dokumentation

- `configuration.md`: neue ResourceGate-Felder (VramDisplayReserveMb, MaxLatencyMs, ColdLatencyFactor, LatencyContextReferenceTokens), `ModelValidation.PeakVramMb`, rocm-smi-AMD-Detektion, GPU-vs-CPU-Admission-Pfad. **macOS als nicht unterstützt markieren** (bestehenden macOS-Pfad-Eintrag entsprechend kennzeichnen).
- `resource-aware-routing.md`: GPU-Pfad + Latenz-Gate in Datenfluss-Diagramm ergänzen.
- `troubleshooting.md`: „lokales GPU-Modell wird trotz GPU substituiert" (VRAM < PeakVramMb+Reserve), „Request wegen Latenz substituiert" (MaxLatencyMs greift), „AMD-GPU nicht erkannt" (rocm-smi fehlt).
- `eval-measurement.md`: Cold-Load-Messlauf + PeakVramMb-Erhebung ergänzen (ColdLatencyFactor-Kalibrierung).

## 8. Akzeptanzkriterien (+1)

- [ ] `ModelValidation.PeakVramMb` + VRAM-Admission gegen statisches VRAM − Display-Reserve
- [ ] GPU-vs-CPU-Pfadentscheidung im ResourceGate
- [ ] AMD-VRAM via `rocm-smi` (Detektor), NVIDIA bleibt nvidia-smi
- [ ] Latenz-Gate: `MaxLatencyMs`/`ColdLatencyFactor`/Kontext-Faktor, Hard-Block über Schwelle, Opt-in (Default aus)
- [ ] Endpoint übergibt grobe Input-Token-Zahl an `EvaluateAsync`
- [ ] CPU-Sampler Windows via `GetSystemTimes` (LibraryImport, trim-safe)
- [ ] Config-Defaults in `CreateDefault()`; backward-safe (Latenz-Gate Opt-in)
- [ ] Docs aktualisiert (macOS als nicht unterstützt); TUnit-Tests; 91 MVP-Tests bleiben grün

## 9. ReleaseFlow

- Branch `feature/268-resource-gate-plus1` → PR gegen `dev/v1.21.0` (Train offen). Train-Check + `dotnet format` + lowercase Commit-Descriptions vor Push. Kein `Closes` (nur `Ref #268`) — #268 schließt erst beim Stable-Promo nach +2.
