# 1. RFC-177 K.Switchboard Auslieferungsstrategie

**Status:** Vorschlag · adressiert [#177](https://github.com/GrexyLoco/K.Agents/issues/177)
**Bezug:** [migration-from-python.md](migration-from-python.md), [rfc-178-fulfillment.md](rfc-178-fulfillment.md), Issues #248/#251 (lokale KI)

Dieses Dokument bewertet die Auslieferung von K.Switchboard. Es **aktualisiert die ursprüngliche Issue-Analyse**, die noch von einem Python-K.Switchboard ausging.

---

## 1.1 Prämissen-Korrektur (wichtig)

Das Ursprungs-Issue #177 verglich Auslieferungswege für ein **Python**-Paket (`pip install .`, Wheel `.whl`, GitHub-PyPI-Feed, PyPI public). Seit der Migration auf .NET ([migration-from-python.md](migration-from-python.md)) ist diese Prämisse überholt:

> K.Switchboard ist eine **self-contained .NET-Anwendung** — eine einzelne `K.Switchboard.exe` **ohne Runtime-Abhängigkeit** (kein Python, kein installiertes .NET nötig).

Damit sind die Python-zentrierten Optionen des Issues **gegenstandslos**:

| Issue-Option | .NET-Status |
| --- | --- |
| A — `pip install .` aus Repo-Klon | obsolet (Python) |
| B — GitHub Releases + Python Wheel | obsolet (Python) |
| C — GitHub Packages als privater PyPI-Feed | obsolet (Python) |
| D — PyPI public | obsolet (Python) |

Die folgende Analyse bewertet die Auslieferung für die **.NET-Realität** neu.

---

## 1.2 Status quo: das Kernproblem ist bereits gelöst

Der vom Issue geforderte „reproduzierbare, versions-gepinnte Auslieferungsweg" **existiert bereits** und ist in der CI (`k-switchboard-net-ci.yml`) automatisiert.

**Build (CI):**
```text
dotnet publish src/K.Switchboard/K.Switchboard.csproj -c Release \
  -p:PublishSingleFile=true -p:PublishTrimmed=true -r win-x64 --self-contained true
```
→ eine einzelne `K.Switchboard.exe` (self-contained, single-file, trimmed).

**Release-Bundle:** `K.Switchboard.exe` + `install-windows.ps1` + `K.Switchboard-README.md` werden zu `K.Switchboard-win-x64.zip` gepackt. Beim Stable-Release werden **zwei Assets** angehängt — das ZIP und die `K.Switchboard-README.md` separat (für Vorschau ohne Download): `gh release upload "$tag" "…/K.Switchboard-win-x64.zip" "…/K.Switchboard-README.md" --clobber`. Der Upload erfolgt nur bei echten Stable-Tags (kein `-alpha`/`-beta`/`-freeze`-Suffix).

**Konsum (versions-gepinnt über den Release-Tag):**
```powershell
Invoke-WebRequest "https://github.com/GrexyLoco/K.Agents/releases/download/v1.19.0/K.Switchboard-win-x64.zip" -OutFile $zip
Expand-Archive $zip $dest
.\install-windows.ps1 -AsService
```

Bewertung gegen die **ursprünglichen Issue-Kriterien**:

| Kriterium aus #177 | Status quo (.NET Release-ZIP) |
| --- | --- |
| Kein Repo-Klon erforderlich | ✅ |
| Versions-Pinning | ✅ über Release-Tag |
| Passt zum ReleaseFlow-Prozess | ✅ Asset beim Stable-Tag |
| Reproduzierbar ohne lokales Setup | ✅ keine Runtime-Abhängigkeit |
| Wiederholbar (gleicher Tag = gleiches Artefakt) | ✅ |

**Fazit:** Die Kernfrage des Issues („kein reproduzierbarer Auslieferungsweg") ist mit der .NET-Migration **beantwortet**. Offen bleiben nur **Komfort-/Reichweiten-Optionen** und die **Docker-Frage** für plattformübergreifende sowie CI-/lokale-KI-Szenarien.

---

## 1.3 Neubewertung der Optionen für .NET

| Option | .NET-Status | Bewertung |
| --- | --- | --- |
| **G — Release-ZIP + `install-windows.ps1`** | **implementiert** | **Status quo, empfohlen für Windows** |
| E — One-Liner (`irm \| iex`) | adaptierbar | Komfort, nur mit Tag/SHA-Pinning + interner Nutzung |
| H — winget / Chocolatey | möglich | künftiger Komfort bei breiterem Rollout |
| F — Docker | nicht implementiert | relevant für Linux/macOS + lokale-KI-Eval (siehe 1.4) |
| I — MSI/MSIX-Installer | möglich | Overkill für den aktuellen Bedarf |

### G — GitHub-Release-ZIP + Installer (Status quo)
- ✅ Kein Repo-Zugriff/Git-Wissen nötig · ✅ Tag-Pinning · ✅ keine Runtime · ✅ Windows-Service via `install-windows.ps1 -AsService`
- ❌ Windows-only · ❌ manueller Download/Entpacken (ohne Paketmanager)

### E — One-Liner-Installer (.NET-adaptiert)
`irm <install-windows.ps1-raw-url> | iex`, wobei der Installer das ZIP des passenden Release-Tags selbst zieht.
- ✅ niedrigste Einstiegshürde
- ❌ `irm | iex` ist ein Security-Anti-Pattern (Ausführung ohne Review); ohne Tag/SHA kein Pinning. Nur intern + mit explizitem Tag vertretbar.

### H — winget / Chocolatey
Ein winget-Manifest bzw. Chocolatey-Package wrappt das Release-ZIP → `winget install K.Switchboard` inkl. Update-Pfad.
- ✅ idiomatische Windows-Installation, automatische Updates
- ❌ Manifest-Pflege; winget-Submission ist öffentlich (oder privater Choco-Feed). Erst bei teamweitem/breiterem Rollout sinnvoll.

### F — Docker
Der frühere „Python-Slim ~200 MB"-Einwand des Issues entfällt: Ein **.NET-self-contained-Linux-Image** (`-r linux-x64 --self-contained` auf `runtime-deps`/distroless-Base) ist schlank und braucht keinen Runtime-Layer. Bislang existiert **kein** `Dockerfile`. Docker ist **nicht** für die Windows-Service-Auslieferung nötig (die ist via G gelöst), sondern für (a) plattformübergreifende Nutzung und (b) den lokale-KI-Use-Case — siehe 1.4.

---

## 1.4 Docker + lokale KI in der CI-Pipeline (die Kernfrage des Issues)

Die Analyse des Issues bleibt im Kern gültig — und wird durch .NET sogar **günstiger**:

- **K.Switchboard-Container**: schlankes self-contained .NET-Image, einfacher als das angenommene Python-Slim.
- **Der Engpass ist Ollama, nicht K.Switchboard**: der Modell-Download (`llama3.2:3b` ≈ 2 GB, `qwen2.5-coder:14b` deutlich mehr) ist der limitierende Faktor.

| Szenario | Realistisch? |
| --- | --- |
| GitHub-hosted Runner + `ollama pull` pro Run | ❌ GB-Download je Run, Minuten-Kosten |
| GitHub-hosted Runner, nur Anthropic-Passthrough testen | ✅ kein Ollama nötig |
| Self-hosted Runner + persistenter Ollama-Cache (Volume) | ✅ einmaliger Download |
| Lokale `docker compose up` Dev-Umgebung | ✅ einmaliger Download, danach offline |

**Antwort auf die Issue-Frage:** Docker + lokale KI in CI ist **nur mit self-hosted Runner + persistentem Ollama-Volume** wirtschaftlich. Auf GitHub-hosted Runnern bleibt echter lokaler-KI-Test wegen des Modell-Downloads unrentabel — dort beschränkt sich CI sinnvoll auf (a) die vorhandenen TUnit-Unit-/Integrationstests und (b) optional Anthropic-Passthrough-Tests. **Der Engpass liegt bei Ollama, nicht bei der Auslieferung von K.Switchboard.**

**Bezug zu #248/#251:** Genau die dort nötige lokale-KI-Qualitätsvalidierung (#251 Spike, #248 Migration) braucht laufende Modelle. Ein `docker-compose.dev.yml` (K.Switchboard-Build + Ollama-Sidecar + persistentes `ollama_data`-Volume) ist das natürliche Vehikel für diese **lokale Eval-Umgebung** — unabhängig von CI und ohne den dortigen Download-Zwang.

---

## 1.5 Empfehlung

1. **Status quo (G) als primären Auslieferungsweg bestätigen.** Er erfüllt die Issue-Kriterien bereits; keine Auslieferungs-Aktion nötig außer dieser Dokumentation + Verlinkung in der README.
2. **Docker nur als lokale Dev-/Eval-Umgebung** einführen — getrieben von #248/#251, **nicht** als Auslieferungsersatz: ein `Dockerfile` (linux-x64 self-contained) + `docker-compose.dev.yml` (K.Switchboard + Ollama + persistentes `ollama_data`-Volume). Kein `ghcr.io`-Push nötig, solange nur lokal/Dev.
3. **CI-lokale-KI zurückstellen**, bis ein self-hosted Runner existiert. Bis dahin: CI = TUnit-Unit/Integration (vorhanden) + optional Anthropic-Passthrough.
4. **winget/Chocolatey (H)** als späteren Komfort-Schritt vormerken (erst bei breiterem Rollout).
5. **One-Liner (E)** nur intern + mit Tag-Pinning, falls Onboarding-Komfort gewünscht ist.

---

## 1.6 Beantwortung der offenen Fragen aus #177

1. **Self-hosted Runner vorhanden/geplant?** → derzeit keiner; CI-lokale-KI daher zurückgestellt.
2. **Lokale KI in CI als Ziel?** → nein für GitHub-hosted Runner; ja als lokale `docker-compose`-Dev-Umgebung (für #248/#251).
3. **Öffentliches `ghcr.io`-Image nötig?** → nein; `docker compose build` lokal genügt für den Eval-Use-Case.

---

## 1.7 Nächste Schritte

- [x] Auslieferungs-Realität (.NET Release-ZIP + Installer) dokumentiert (dieses Dokument)
- [ ] Optional (treibt #248/#251): `Dockerfile` + `docker-compose.dev.yml` für lokale KI-Eval
- [ ] Optional (später, bei breiterem Rollout): winget-Manifest / Chocolatey-Package
