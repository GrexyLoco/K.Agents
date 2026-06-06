# Claude-Baseline 05 — install-windows.ps1 (ACL-Rule + Idempotenz, PS)

**Findings (Referenz):**
- 💬 **Hinweis — barer `catch { continue }`** beim SID-`Translate()` im Dedup-Loop: fängt jede Exception; präziser wäre `catch [System.Security.Principal.IdentityNotMappedException]`.
- 💬 **Hinweis — `[OutputType([...FileSystemAccessRule])]`** an `New-NetworkServiceAccessRule` würde IDE-Unterstützung/Lesbarkeit verbessern.

**Lob:** SID `S-1-5-20` statt lokalisiertem Account (sprachunabhängig, #246), SID-basierter Dedup (kein String-Vergleich), `CmdletBinding(SupportsShouldProcess)`, `Set-StrictMode`, keine Host-Stream-Ausgaben. **Kein Blocker/Wichtig** — solide PS-Qualität.
