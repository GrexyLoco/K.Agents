---
name: owasp-dotnet
description: OWASP Top 10 for .NET and PowerShell — injection (SQL, XSS, Invoke-Expression), broken access control ([Authorize], CORS), cryptographic failures (bcrypt, no MD5/SHA1), vulnerable dependencies (dotnet audit), SecureString, TLS 1.2+. USE FOR: reviewing code for security vulnerabilities, auditing dependencies, checking OWASP compliance. DO NOT USE FOR: general code quality review (use code-reviewer agent) or dependency updates (use security-auditor agent).

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
