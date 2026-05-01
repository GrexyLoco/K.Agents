---
name: security-audit
description: Sicherheitsanalyse — Dependency Scanning, OWASP Top 10, NuGet Vulnerabilities, Code Security Review, Severity-Klassifizierung
---

# Security-Audit Skill

## Übersicht

Dieses Skill behandelt systematische Sicherheitsanalyse für .NET und PowerShell Projekte. Es deckt Dependency Scanning, OWASP-Konformität, Code-Review und Severity-Klassifizierung ab.

## Dependency Scanning

### .NET NuGet Vulnerabilities

```bash
# Vulnerabilities including transitive
dotnet list package --vulnerable --include-transitive

# Full audit with details
dotnet audit
```

Für jede gefundene Schwachstelle dokumentiere:
- **CVE-Nummer** und Schweregrad (Critical/High/Medium/Low)
- **Betroffenes Paket** und aktuelle Version
- **Fix-Version** (wenn verfügbar)
- **Workaround** (wenn kein Fix verfügbar)
- **Exploitability:** Ist die Sicherheitslücke praktisch ausnutzbar?

### GitHub Advisory Database
- NuGet MCP: Package-Kontext und bekannte CVEs
- Suche nach Sicherheitslücken in Abhängigkeiten
- Verlinke auf offizielle CVE-Datenbank

## OWASP Top 10 für .NET

### A01: Broken Access Control
- Authorization-Attribute müssen alle Protected Resources haben
- Policy-basierte Authorization statt hardcodierter Roles
- Resource-Level Checks für Object-based Access Control
- JWT/Cookie-Claims korrekt validieren

### A02: Cryptographic Failures
- Hardcoded Secrets scannen (Passwörter, API-Keys, Connection Strings)
- Nur moderne Kryptographie (AES, SHA-256+, nicht MD5/SHA1)
- HTTPS überall erzwingen
- Sichere Schlüssel-Speicherung (Azure Key Vault, nicht appsettings.json)

### A03: Injection
- **SQL Injection:** Raw SQL + User-Input = Risiko; Entity Framework safe
- **XSS (Blazor):** Markup in Components sanitizen
- **Command Injection:** Process.Start mit User-Input prüfen

### A04: Insecure Design
- Missing Rate Limiting (DDoS-Schutz)
- Fehlende Input-Validation auf API-Ebene
- IDOR (Insecure Direct Object Reference): `/users/123` sollte User-ID prüfen
- Fehlende Business-Logic Validation

### A05: Security Misconfiguration
- Debug-Endpoints nicht in Production
- Default-Credentials entfernen
- CORS nicht zu offen (`Access-Control-Allow-Origin: *`)
- Security Headers prüfen (HSTS, X-Frame-Options, etc.)

### A06: Vulnerable Components
- Veraltete NuGet-Pakete (`dotnet list package --outdated`)
- Bekannte CVEs in Dependencies
- Regelmäßige Audit-Runs in CI

### A07: Authentication Failures
- Schwache Passwort-Policy (keine Complexity?)
- Fehlende MFA (Multi-Factor Authentication)
- Session-Management (Timeout, Invalidation)
- Password Spraying / Brute-Force Schutz (Rate Limiting)

### A08: Data Integrity Failures
- Unsichere Deserialisierung (JSON.parse mit Type-Safety prüfen)
- Fehlende Signaturprüfung für wichtige Daten
- Tamper-Detection bei sensiblen Objekten

### A09: Logging & Monitoring Failures
- Keine Sensitive Daten in Logs (Passwords, Tokens, PII)
- Audit-Trails für kritische Operationen
- Error-Handling ohne Information Disclosure

### A10: SSRF (Server-Side Request Forgery)
- Unkontrollierte URL-Parameter (Validation!)
- Server-seitige Redirects nur zu Whitelist
- DNS Rebinding Schutz

## Code Security Review

### Automatische .NET Checks

```csharp
// ❌ RISIKO: Secrets im Code
const string connectionString = "Server=db;Password=secret123";

// ❌ RISIKO: Anonym ohne Begründung
[AllowAnonymous]
[HttpGet("sensitive")]

// ❌ RISIKO: Kein Timeout
var client = new HttpClient();

// ❌ RISIKO: Format String Vulnerability
string.Format(userInput, value)

// ❌ RISIKO: Unkontrollierter Command Execution
Process.Start(userInput)

// ❌ RISIKO: Path Traversal
File.ReadAllText(userSuppliedPath)

// ❌ RISIKO: CSRF nicht geschützt
[HttpPost]
public IActionResult Create(Model m) { }

// ❌ RISIKO: Certificate Validation ignorieren
TrustServerCertificate=true
```

### PowerShell-spezifisch

```powershell
# ❌ RISIKO: Unkontrollierte Code-Ausführung
Invoke-Expression $userInput

# ❌ RISIKO: Unkontrollierte URL
Invoke-RestMethod -Uri $userUrl

# ❌ RISIKO: Credentials im Klartext
$password = "MyPassword123"

# ❌ RISIKO: Fehlende Credential-Validation
function Do-Something { param($Credential) ... }

# ❌ RISIKO: AsPlainText ohne Grund
ConvertTo-SecureString -AsPlainText "secret"
```

## GitHub Actions Security

### Secret-Handling
- Secrets korrekt verwenden (nicht in Logs)
- Secrets-Context nur wo nötig exponieren
- Mask in Output: `::add-mask::$SECRET`

### Third-Party Actions
- Immer auf SHA pinnen, nicht auf Tags
- `uses: owner/repo@commit-sha`
- Reduziert Supply-Chain-Risiken

### Permissions (Least Privilege)
```yaml
permissions:
  contents: read
  pull-requests: read
```

Nicht `write-all` oder `admin`, sondern nur nötige Permissions.

### Pull Request Security
- Nie `pull_request_target` mit checkout des PR-Branches
- `pull_request` ist sicher (read-only für Secrets)

## Severity-Klassifizierung

| Severity | Beschreibung | SLA | Beispiel |
|----------|-------------|-----|---------|
| 🔴 Critical | Aktiv ausnutzbar, Datenverlust/RCE möglich | Sofort fixen | Unauthentizierter SQL Injection |
| 🟠 High | Ausnutzbar unter bestimmten Bedingungen | 1 Sprint | Hardcoded Secret, fehlende Rate Limit |
| 🟡 Medium | Theoretisches Risiko, Hardening-Maßnahme | Nächstes Epic | Veraltetes Package ohne Exploit bekannt |
| 🔵 Low | Best Practice Verletzung, kein direktes Risiko | Backlog | Fehlender Security Header |

## Report-Format

```markdown
## Security Audit Report – [Datum]

### Zusammenfassung
- Kritisch: X
- Hoch: Y
- Mittel: Z
- Niedrig: W

### Findings

#### 🔴 [Titel]
- **Datei:** `path/to/file.cs:42`
- **Problem:** Beschreibung des Risikos
- **Auswirkung:** Was kann passieren?
- **Empfehlung:** Wie fixen?
- **Referenz:** [OWASP-A03](https://owasp.org/...) oder CVE-Link
```

## Related Skills

- owasp-dotnet (für detaillierte OWASP-Patterns)

## Workflow

1. **Codebase scannen:** Dependencies, Secrets, Access Control
2. **Prüfungen durchführen:** dotnet audit, GitLeaks, Code Review
3. **Findings dokumentieren:** Severity, Impact, Referenzen
4. **Report erstellen:** Strukturiert und priorisiert
5. **Delegation:** Handoff an Developer für Fixes (nie selbst implementieren)

## Regeln

- Keine False Positives — nur echte Risiken
- Severity **ehrlich** einschätzen — nicht alles ist Critical
- Immer Fixes delegieren, nie selbst implementieren
- Dokumentation mit konkreten Code-Zeilen
- Exploitability realistisch bewerten
