---
name: code-security-review
description: "Code Security Review — hardcoded secrets, IDOR, SQL injection, command injection, path traversal, CSRF, authorization flaws. USE FOR: reviewing code for security vulnerabilities, auditing endpoint authorization, validating input handling. DO NOT USE FOR: dependency vulnerabilities (dotnet-dependency-scanning) or OWASP checklist (owasp-dotnet)."
---

# 1. Code Security Review

## 1.1 .NET Patterns

### 1.1.1 Secrets & Authorization
```csharp
// ❌ BAD: Hardcoded secrets + missing [Authorize]
var apiKey = "sk-1234567890";
[HttpPost("/api/users/{id}")]
public async Task<IActionResult> UpdateUser(int id, UserDto dto) { }

// ✅ GOOD: Config + explicit authorization
var apiKey = configuration["ApiKeys:External"];
[Authorize]
[HttpPost("/api/users/{id}")]
public async Task<IActionResult> UpdateUser(int id, UserDto dto) { }
```

### 1.1.2 IDOR & Resource Access
```csharp
// ❌ BAD: No ownership check
[Authorize]
public async Task<IActionResult> GetOrder(int orderId)
{
    return Ok(await db.Orders.FindAsync(orderId));
}

// ✅ GOOD: Verify user ownership
var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
var order = await db.Orders.FirstOrDefaultAsync(
    o => o.Id == orderId && o.UserId == userId);
return order == null ? NotFound() : Ok(order);
```

### 1.1.3 Path Traversal Prevention
```csharp
// ❌ BAD: Direct user input in path
public IActionResult DownloadFile(string filename) =>
    PhysicalFile(Path.Combine("/uploads", filename), "application/octet-stream");

// ✅ GOOD: Validate against whitelist
var basePath = Path.GetFullPath("/uploads");
var filePath = Path.GetFullPath(Path.Combine(basePath, file.StoragePath));
if (!filePath.StartsWith(basePath)) return Forbid();
```

### 1.1.4 CSRF & Certificates
```csharp
// CSRF: Use [ValidateAntiForgeryToken] on POST
[HttpPost]
[ValidateAntiForgeryToken]
public async Task<IActionResult> DeleteUser(int id) { }

// Certs: HttpClientHandler validates by default (never disable)
var client = new HttpClient(new HttpClientHandler());
```

## 1.2 PowerShell Patterns

### 1.2.1 Command Injection & URLs
```powershell
# ❌ BAD: Invoke-Expression (code injection risk)
Invoke-Expression $userInput

# ✅ GOOD: Direct call
& $commandName @args

# ❌ BAD: Unvalidated URLs
Invoke-RestMethod -Uri $userProvidedUrl

# ✅ GOOD: Validate allowlist
if ($url -notmatch '^https://trusted-domain\.com/') { throw }
```

### 1.2.2 Credentials & TLS
```powershell
# ❌ BAD: Plaintext passwords
$cred = New-Object PSCredential ("user", "MyPassword123")

# ✅ GOOD: SecureString
$password = Read-Host -AsSecureString
$password = $env:DB_PASSWORD | ConvertTo-SecureString -AsPlainText -Force

# ✅ GOOD: Enforce TLS 1.2+
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

## 1.3 Security Checklist

- `[Authorize]` on all non-public endpoints
- Resource-level checks (user owns resource)
- No hardcoded secrets (use configuration)
- Parameterized SQL queries only
- Validate file uploads (size, extension, type)
- Whitelist file downloads
- CSRF tokens on state-changing operations
- HTTPS enforced
- Input validation (length, type)
- Logs redacted (no PII)
