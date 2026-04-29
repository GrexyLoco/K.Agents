---
name: powershell-module-publishing
description: PowerShell-Modul Publishing — Manifest Design, GitHub Packages, PowerShell Gallery, Versioning. USE FOR: designing publishable modules, configuring module feeds, automating version bumps. DO NOT USE FOR: module testing (use pester-patterns) or module design patterns (use powershell-module-design).
---

# PowerShell Module Publishing

## Manifest-Struktur (.psd1)

```powershell
@{
    RootModule        = 'MyModule.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '12345678-1234-1234-1234-123456789012'
    
    Author            = 'Your Name'
    Description       = 'Module description'
    
    FunctionsToExport = @('Public-Function1', 'Public-Function2')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    
    RequiredModules   = @(
        @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
    )
    
    PrivateData = @{
        PSData = @{
            Tags          = @('automation', 'deployment')
            LicenseUri    = 'https://github.com/user/module/blob/main/LICENSE'
            ProjectUri    = 'https://github.com/user/module'
            ReleaseNotes  = 'Release notes here'
        }
    }
}
```

**Key Fields:**  
- **RootModule:** Entry point (.psm1 file).  
- **ModuleVersion:** Semantic versioning (MAJOR.MINOR.PATCH).  
- **GUID:** Unique module identifier; regenerate for module renames only.  
- **FunctionsToExport:** Public API; rest become private.

## Public/Private Function Separation

```powershell
# public/Get-Item.ps1
function Get-Item {
    param([string]$Name)
    # Public logic
}

# private/Invoke-Helper.ps1
function Invoke-Helper {
    param([string]$Input)
    # Internal helper
}

# MyModule.psm1
$PublicFuncs  = @(Get-ChildItem -Path $PSScriptRoot/public -Filter *.ps1)
$PrivateFuncs = @(Get-ChildItem -Path $PSScriptRoot/private -Filter *.ps1)

($PublicFuncs + $PrivateFuncs) | ForEach-Object { . $_.FullName }

Export-ModuleMember -Function $PublicFuncs.BaseName
```

**Pattern:** Organize into `public/` and `private/` subdirectories; dot-source in .psm1.  
**Benefits:** Clear API boundary, easier testing, reduced namespace pollution.

## Dependency Management

```powershell
# Manifest: RequiredModules
RequiredModules = @(
    @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.15.0'; }
    @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0'; }
)

# Runtime check
if (-not (Get-Module -Name 'Az.Accounts' -ListAvailable)) {
    Install-Module -Name 'Az.Accounts' -MinimumVersion '2.15.0' -Force
}
```

**Specify versions** in manifest for reproducible installs.  
**Use ModuleVersion (minimum)** for flexibility; pin exact versions only if required.

## Module Publishing: GitHub Packages vs. PowerShell Gallery

| Aspect | GitHub Packages | PowerShell Gallery |
|--------|-----------------|-------------------|
| Access | Org/private, OR public | Public only |
| Auth | GitHub token (PAT, OIDC) | API key |
| Cost | Free (GitHub) | Free |
| Discoverability | Low (organization) | High (registry) |
| Use Case | Internal tools, private modules | Community/OSS modules |

**GitHub Packages (NuGet feed):**
```powershell
$Feed = 'https://nuget.pkg.github.com/YourOrg/index.json'
Register-PSRepository -Name 'GitHubModules' -SourceLocation $Feed `
    -PublishLocation $Feed -InstallationPolicy Trusted
Publish-Module -Path . -Repository 'GitHubModules' `
    -NuGetApiKey $env:GITHUB_TOKEN
```

**PowerShell Gallery:**
```powershell
Publish-Module -Path . -NuGetApiKey $env:PS_GALLERY_KEY
```

## Feed Authentication (CI/CD)

```yaml
# GitHub Actions
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  PS_GALLERY_KEY: ${{ secrets.PS_GALLERY_API_KEY }}

steps:
  - name: Publish to GitHub Packages
    run: |
      $Feed = 'https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json'
      Register-PSRepository -Name 'GitHub' -SourceLocation $Feed -PublishLocation $Feed -Force
      Publish-Module -Path . -Repository 'GitHub' -NuGetApiKey $env:GITHUB_TOKEN
```

**For GitHub Packages:** Use `GITHUB_TOKEN` (auto-provided, no setup needed).  
**For PowerShell Gallery:** Use repository-scoped secret; rotate periodically.

---

**Publishing Workflow:**  
1. Bump ModuleVersion in .psd1.  
2. Run Pester tests locally + in CI.  
3. Create GitHub Release (tag = v{ModuleVersion}).  
4. CI publishes to target repository.
