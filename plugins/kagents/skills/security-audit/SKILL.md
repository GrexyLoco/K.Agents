---
name: security-audit
description: Sicherheitsanalyse — Dependency Scanning, OWASP Top 10, NuGet Vulnerabilities, Code Security Review, Severity-Klassifizierung
---

# 1. Security-Audit Skill

## 1.1 Übersicht

Dieses Skill behandelt systematische Sicherheitsanalyse für .NET und PowerShell Projekte. Es deckt Dependency Scanning, OWASP-Konformität, Code-Review und Severity-Klassifizierung ab.

## 1.2 Dependency Scanning

### 1.2.1 .NET NuGet Vulnerabilities

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

### 1.2.2 GitHub Advisory Database
- NuGet MCP: Package-Kontext und bekannte CVEs
- Suche nach Sicherheitslücken in Abhängigkeiten
- Verlinke auf offizielle CVE-Datenbank

## 1.3 OWASP Top 10 für .NET

### 1.3.1 A01: Broken Access Control
- Authorization-Attribute müssen alle Protected Resources haben
- Policy-basierte Authorization statt hardcodierter Roles
- Resource-Level Checks für Object-based Access Control
- JWT/Cookie-Claims korrekt validieren

### 1.3.2 A02: Cryptographic Failures
- Hardcoded Secrets scannen (Passwörter, API-Keys, Connection Strings)
- Nur moderne Kryptographie (AES, SHA-256+, nicht MD5/SHA1)
- HTTPS überall erzwingen
- Sichere Schlüssel-Speicherung (Azure Key Vault, nicht appsettings.json)

### 1.3.3 A03: Injection
- **SQL Injection:** Raw SQL + User-Input = Risiko; Entity Framework safe
- **XSS (Blazor):** Markup in Components sanitizen
- **Command Injection:** Process.Start mit User-Input prüfen

### 1.3.4 A04: Insecure Design
- Missing Rate Limiting (DDoS-Schutz)
- Fehlende Input-Validation auf API-Ebene
- IDOR (Insecure Direct Object Reference): `/users/123` sollte User-ID prüfen
- Fehlende Business-Logic Validation

### 1.3.5 A05: Security Misconfiguration
- Debug-Endpoints nicht in Production
- Default-Credentials entfernen
- CORS nicht zu offen (`Access-Control-Allow-Origin: *`)
- Security Headers prüfen (HSTS, X-Frame-Options, etc.)

### 1.3.6 A06: Vulnerable Components
- Veraltete NuGet-Pakete (`dotnet list package --outdated`)
- Bekannte CVEs in Dependencies
- Regelmäßige Audit-Runs in CI

### 1.3.7 A07: Authentication Failures
- Schwache Passwort-Policy (keine Complexity?)
- Fehlende MFA (Multi-Factor Authentication)
- Session-Management (Timeout, Invalidation)
- Password Spraying / Brute-Force Schutz (Rate Limiting)

### 1.3.8 A08: Data Integrity Failures
- Unsichere Deserialisierung (JSON.parse mit Type-Safety prüfen)
- Fehlende Signaturprüfung für wichtige Daten
- Tamper-Detection bei sensiblen Objekten

### 1.3.9 A09: Logging & Monitoring Failures
- Keine Sensitive Daten in Logs (Passwords, Tokens, PII)
- Audit-Trails für kritische Operationen
- Error-Handling ohne Information Disclosure

### 1.3.10 A10: SSRF (Server-Side Request Forgery)
- Unkontrollierte URL-Parameter (Validation!)
- Server-seitige Redirects nur zu Whitelist
- DNS Rebinding Schutz

## 1.4 Code Security Review

### 1.4.1 Automatische .NET Checks

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

### 1.4.2 PowerShell-spezifisch

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

## 1.5 GitHub Actions Security

### 1.5.1 Secret-Handling
- Secrets korrekt verwenden (nicht in Logs)
- Secrets-Context nur wo nötig exponieren
- Mask in Output: `::add-mask::$SECRET`

### 1.5.2 Third-Party Actions
- Immer auf SHA pinnen, nicht auf Tags
- `uses: owner/repo@commit-sha`
- Reduziert Supply-Chain-Risiken

### 1.5.3 Permissions (Least Privilege)
```yaml
permissions:
  contents: read
  pull-requests: read
```

Nicht `write-all` oder `admin`, sondern nur nötige Permissions.

### 1.5.4 Pull Request Security
- Nie `pull_request_target` mit checkout des PR-Branches
- `pull_request` ist sicher (read-only für Secrets)

## 1.6 Severity-Klassifizierung

| Severity | Beschreibung | SLA | Beispiel |
|----------|-------------|-----|---------|
| 🔴 Critical | Aktiv ausnutzbar, Datenverlust/RCE möglich | Sofort fixen | Unauthentizierter SQL Injection |
| 🟠 High | Ausnutzbar unter bestimmten Bedingungen | 1 Sprint | Hardcoded Secret, fehlende Rate Limit |
| 🟡 Medium | Theoretisches Risiko, Hardening-Maßnahme | Nächstes Epic | Veraltetes Package ohne Exploit bekannt |
| 🔵 Low | Best Practice Verletzung, kein direktes Risiko | Backlog | Fehlender Security Header |

## 1.7 Report-Format

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

## 1.8 Related Skills

- owasp-dotnet (für detaillierte OWASP-Patterns)

## 1.9 Workflow

1. **Codebase scannen:** Dependencies, Secrets, Access Control
2. **Prüfungen durchführen:** dotnet audit, GitLeaks, Code Review
3. **Findings dokumentieren:** Severity, Impact, Referenzen
4. **Report erstellen:** Strukturiert und priorisiert
5. **Delegation:** Handoff an Developer für Fixes (nie selbst implementieren)

## 1.10 Regeln

- Keine False Positives — nur echte Risiken
- Severity **ehrlich** einschätzen — nicht alles ist Critical
- Immer Fixes delegieren, nie selbst implementieren
- Dokumentation mit konkreten Code-Zeilen
- Exploitability realistisch bewerten
