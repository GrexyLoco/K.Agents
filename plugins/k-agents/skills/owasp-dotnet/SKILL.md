---
name: owasp-dotnet
description: OWASP Top 10 Prüfpunkte für .NET und PowerShell. Nutze diesen Skill bei Security Reviews und Code-Audits.
---

# OWASP Top 10 für .NET

## Schnell-Checkliste

### A01 Broken Access Control
- [ ] `[Authorize]` auf allen nicht-öffentlichen Endpoints
- [ ] Policy-basierte Authorization statt Role-Checks
- [ ] Resource-Level Checks (User kann nur eigene Daten sehen)
- [ ] CORS korrekt konfiguriert (nicht `AllowAny`)

### A02 Cryptographic Failures
- [ ] Keine Secrets im Code (Connection Strings, API Keys)
- [ ] HTTPS erzwungen (`UseHttpsRedirection`)
- [ ] Passwörter mit bcrypt/Argon2 gehasht
- [ ] Kein MD5/SHA1 für Security-relevante Hashes

### A03 Injection
- [ ] Keine String-Interpolation in SQL (`FromSqlRaw` mit Parametern)
- [ ] Blazor: Kein `MarkupString` mit User-Input
- [ ] Keine `Process.Start` mit User-Input
- [ ] PowerShell: Kein `Invoke-Expression` mit User-Input

### A05 Security Misconfiguration
- [ ] `ASPNETCORE_ENVIRONMENT` nicht `Development` in Prod
- [ ] Keine Debug-Endpoints in Prod (Swagger nur in Dev)
- [ ] Error Details nicht an Client exponieren
- [ ] Default-Credentials geändert

### A06 Vulnerable Components
```bash
dotnet list package --vulnerable --include-transitive
dotnet audit
```

## PowerShell-spezifisch
- [ ] Keine Credentials im Klartext
- [ ] `SecureString` für Passwörter
- [ ] TLS 1.2+ erzwingen: `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12`
- [ ] Keine unkontrollierten URLs in `Invoke-RestMethod`
