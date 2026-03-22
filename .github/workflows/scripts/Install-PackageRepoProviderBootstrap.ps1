<#
.SYNOPSIS
    Centralized bootstrap script for K.PSGallery.PackageRepoProvider installation.

.DESCRIPTION
    This script provides reusable functions to install K.PSGallery.PackageRepoProvider
    and its dependencies from GitHub Packages. It handles:

    1. PSResourceGet V3 protocol limitation: Dependencies are NOT auto-installed
       See: https://github.com/PowerShell/PSResourceGet/issues/1621

    2. PSResourceGet #1402 bug: Module folders are lowercased on Linux/macOS
       See: https://github.com/PowerShell/PSResourceGet/issues/1402

    USAGE:
    ------
    # 1. Dot-source this script to load the functions
    . "$PSScriptRoot/Install-PackageRepoProviderBootstrap.ps1"

    # 2. Bootstrap the PackageRepoProvider
    Install-PackageRepoProvider -Token $env:GH_PACKAGES_TOKEN -Owner 'GrexyLoco'

    # 3. (Optional) Install additional modules via the provider
    Install-ModuleViaPackageRepoProvider -ModuleName 'K.PSGallery.Smartagr' -Token $token -Owner 'GrexyLoco'

.NOTES
    Author: GrexyLoco
    Cross-Platform: Windows, Linux, macOS (PowerShell 7.5+)
    License: MIT

.LINK
    https://github.com/GrexyLoco/K.PSGallery.PackageRepoProvider
#>

#Requires -Version 7.0

Set-StrictMode -Version Latest

# ═══════════════════════════════════════════════════════════════════════════════════════════════════
# 🔧 Repair-PSResourceGetCase - PSResourceGet #1402 Workaround
# ═══════════════════════════════════════════════════════════════════════════════════════════════════
function Repair-PSResourceGetCase {
    <#
    .SYNOPSIS
        Fixes PSResourceGet #1402 case-sensitivity issue on Linux/macOS.

    .DESCRIPTION
        PSResourceGet installs modules in lowercase directories on case-sensitive
        filesystems (Linux/macOS), causing Import-Module to fail.

        This function:
        1. Renames the module directory to match the proper PascalCase name
        2. Fixes subfolder names (Private, Public, Classes, etc.)
        3. Fixes known file names that are lowercased

    .PARAMETER ModuleName
        The properly-cased module name (e.g., 'K.PSGallery.PesterTestDiscovery').

    .EXAMPLE
        Repair-PSResourceGetCase -ModuleName 'K.PSGallery.PackageRepoProvider.GitHub'

    .OUTPUTS
        None. Renames folders/files in-place.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    # Only needed on case-sensitive filesystems
    if (-not ($IsLinux -or $IsMacOS)) {
        Write-Information -InformationAction Continue "   ℹ️  Skipping case-fix (not Linux/macOS)"
        return
    }

    $modulesPath = Join-Path $HOME '.local/share/powershell/Modules'
    $lowercasePath = Join-Path $modulesPath $ModuleName.ToLower()
    $correctPath = Join-Path $modulesPath $ModuleName

    Write-Information -InformationAction Continue "   🔍 Repair-PSResourceGetCase: Checking $ModuleName"
    Write-Verbose "lowercasePath = $lowercasePath (exists: $(Test-Path $lowercasePath))"
    Write-Verbose "correctPath = $correctPath (exists: $(Test-Path $correctPath))"

    # ═══════════════════════════════════════════════════════════════════════════
    # Step 1: Fix main module folder name
    # ═══════════════════════════════════════════════════════════════════════════
    if ((Test-Path $lowercasePath) -and -not (Test-Path $correctPath)) {
        Write-Information -InformationAction Continue "   🔧 Fixing PSResourceGet #1402: Renaming '$($ModuleName.ToLower())' → '$ModuleName'"
        Rename-Item -Path $lowercasePath -NewName $ModuleName -Force
    }
    elseif (Test-Path $correctPath) {
        Write-Information -InformationAction Continue "   ✅ Module folder already has correct case: $ModuleName"
    }
    else {
        Write-Warning "   ⚠️ Module folder not found at expected locations!"
        return
    }

    # Re-check paths after potential rename
    $moduleRoot = if (Test-Path $correctPath) { $correctPath } elseif (Test-Path $lowercasePath) { $lowercasePath } else { $null }

    if (-not $moduleRoot -or -not (Test-Path $moduleRoot)) {
        Write-Warning "   ⚠️ Module root not found after rename attempt!"
        return
    }

    # ═══════════════════════════════════════════════════════════════════════════
    # Step 2: Fix subfolders AND files - PSResourceGet lowercases everything!
    # ═══════════════════════════════════════════════════════════════════════════
    $versionFolders = @(Get-ChildItem -Path $moduleRoot -Directory -ErrorAction SilentlyContinue)
    Write-Verbose "Found $($versionFolders.Count) version folder(s): $($versionFolders.Name -join ', ')"

    foreach ($versionFolder in $versionFolders) {
        Write-Verbose "Processing version folder: $($versionFolder.FullName)"

        # Fix common subfolders that may be lowercased
        $subfolderNames = @('Private', 'Public', 'Classes', 'Enums', 'Types')
        foreach ($subfolderName in $subfolderNames) {
            $lowercaseSubfolder = Join-Path $versionFolder.FullName $subfolderName.ToLower()
            $correctSubfolder = Join-Path $versionFolder.FullName $subfolderName

            $lowercaseExists = Test-Path $lowercaseSubfolder
            $correctExists = Test-Path $correctSubfolder

            if ($lowercaseExists -and -not $correctExists) {
                Write-Information -InformationAction Continue "   🔧 Fixing subfolder case: '$($subfolderName.ToLower())' → '$subfolderName'"
                Rename-Item -Path $lowercaseSubfolder -NewName $subfolderName -Force
            }

            # Step 3: Fix files in subfolder (e.g., safelogging.ps1 → SafeLogging.ps1)
            $subfolderPath = if (Test-Path $correctSubfolder) { $correctSubfolder } elseif (Test-Path $lowercaseSubfolder) { $lowercaseSubfolder } else { $null }
            if ($subfolderPath -and (Test-Path $subfolderPath)) {
                # Known files that need case correction
                $knownFiles = @{
                    'safelogging.ps1' = 'SafeLogging.ps1'
                }
                foreach ($lowercaseFile in $knownFiles.Keys) {
                    $lowercaseFilePath = Join-Path $subfolderPath $lowercaseFile
                    $correctFileName = $knownFiles[$lowercaseFile]
                    $correctFilePath = Join-Path $subfolderPath $correctFileName

                    if ((Test-Path $lowercaseFilePath) -and -not (Test-Path $correctFilePath)) {
                        Write-Information -InformationAction Continue "   🔧 Fixing file case: '$lowercaseFile' → '$correctFileName'"
                        Rename-Item -Path $lowercaseFilePath -NewName $correctFileName -Force
                    }
                }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════════
# 📦 Install-PackageRepoProvider - Bootstrap from GitHub Packages
# ═══════════════════════════════════════════════════════════════════════════════════════════════════
function Install-PackageRepoProvider {
    <#
    .SYNOPSIS
        Bootstraps K.PSGallery.PackageRepoProvider (and dependencies) from GitHub Packages.

    .DESCRIPTION
        PSResourceGet V3 protocol limitation: Dependencies are NOT auto-installed.
        This function manually installs modules in dependency order:

        1. K.PSGallery.PackageRepoProvider.GitHub (dependency)
        2. K.PSGallery.PackageRepoProvider (main aggregator)

        Also applies PSResourceGet #1402 workaround for Linux/macOS lowercase folder bug.

    .PARAMETER Token
        GitHub Personal Access Token with read:packages scope.

    .PARAMETER Owner
        GitHub username or organization that owns the packages.

    .EXAMPLE
        Install-PackageRepoProvider -Token $env:GH_PACKAGES_TOKEN -Owner 'GrexyLoco'

    .OUTPUTS
        None. Installs and imports modules globally.

    .NOTES
        Requires: PowerShell 7.5+, Microsoft.PowerShell.PSResourceGet
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'CI/CD context: Token from GitHub Actions secret')]
    param(
        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$Owner
    )

    Write-Information -InformationAction Continue "📦 Bootstrapping K.PSGallery.PackageRepoProvider from GitHub Packages..."
    Write-Information -InformationAction Continue "⚠️  PSResourceGet V3 protocol: Installing dependencies manually..."

    # Create credential for GitHub Packages
    $secureToken = ConvertTo-SecureString $Token -AsPlainText -Force
    $credential = [PSCredential]::new($Owner, $secureToken)

    # Register GitHub Packages as PSResource repository (for bootstrap)
    $tempRepoName = 'GHPackages-Bootstrap'
    $uri = "https://nuget.pkg.github.com/$Owner/index.json"

    # Remove if exists
    Unregister-PSResourceRepository -Name $tempRepoName -ErrorAction SilentlyContinue

    # Register
    Write-Information -InformationAction Continue "📝 Registering temporary repository: $tempRepoName"
    Register-PSResourceRepository -Name $tempRepoName -Uri $uri -Trusted -ErrorAction Stop

    try {
        # ═══════════════════════════════════════════════════════════════════════
        # Step 1: Install GitHub Provider FIRST (dependency)
        # ═══════════════════════════════════════════════════════════════════════
        $githubProvider = 'K.PSGallery.PackageRepoProvider.GitHub'
        Write-Information -InformationAction Continue "📥 [1/2] Installing $githubProvider (dependency)..."

        Install-PSResource -Name $githubProvider `
            -Repository $tempRepoName `
            -Credential $credential `
            -Scope CurrentUser `
            -TrustRepository `
            -ErrorAction Stop

        Repair-PSResourceGetCase -ModuleName $githubProvider

        # Import GitHub Provider to verify it works after case-fix
        # NOTE: -Global is required! ScriptsToProcess loads into caller's scope.
        #       Without -Global, functions from SafeLogging.ps1 would be lost when this function ends.
        Import-Module $githubProvider -Force -Global -ErrorAction Stop
        $ghVersion = (Get-Module -Name $githubProvider).Version
        Write-Information -InformationAction Continue "✅ $githubProvider v$ghVersion installed and imported"

        # ═══════════════════════════════════════════════════════════════════════
        # Step 2: Install Aggregator (main module)
        # ═══════════════════════════════════════════════════════════════════════
        $aggregator = 'K.PSGallery.PackageRepoProvider'
        Write-Information -InformationAction Continue "📥 [2/2] Installing $aggregator..."

        Install-PSResource -Name $aggregator `
            -Repository $tempRepoName `
            -Credential $credential `
            -Scope CurrentUser `
            -TrustRepository `
            -ErrorAction Stop

        Repair-PSResourceGetCase -ModuleName $aggregator

        # Import the aggregator module (this loads the GitHub provider as NestedModule)
        # NOTE: -Global is CRITICAL! ScriptsToProcess loads SafeLogging.ps1 into caller's scope.
        #       Without -Global, Write-SafeErrorLog etc. would be lost when this function ends.
        Import-Module $aggregator -Force -Global -ErrorAction Stop

        $aggVersion = (Get-Module -Name $aggregator).Version
        Write-Information -InformationAction Continue "✅ $aggregator v$aggVersion installed and imported"
    }
    finally {
        # Cleanup temp repository
        Unregister-PSResourceRepository -Name $tempRepoName -ErrorAction SilentlyContinue
    }
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════════
# 📦 Install-ModuleViaPackageRepoProvider - Install additional modules after bootstrap
# ═══════════════════════════════════════════════════════════════════════════════════════════════════
function Install-ModuleViaPackageRepoProvider {
    <#
    .SYNOPSIS
        Installs a module from GitHub Packages using K.PSGallery.PackageRepoProvider.

    .DESCRIPTION
        Uses PackageRepoProvider to install module, then applies Repair-PSResourceGetCase
        workaround for Linux/macOS.

        PREREQUISITES: Call Install-PackageRepoProvider first!

    .PARAMETER ModuleName
        The module to install from GitHub Packages.

    .PARAMETER Token
        GitHub Personal Access Token with read:packages scope.

    .PARAMETER Owner
        GitHub username or organization that owns the packages.

    .EXAMPLE
        Install-ModuleViaPackageRepoProvider -ModuleName 'K.PSGallery.Smartagr' -Token $env:GH_PACKAGES_TOKEN -Owner 'GrexyLoco'

    .OUTPUTS
        None. Installs and imports module globally.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'CI/CD context: Token from GitHub Actions secret')]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$Owner
    )

    # Verify PackageRepoProvider is available
    if (-not (Get-Module -Name 'K.PSGallery.PackageRepoProvider' -ErrorAction SilentlyContinue)) {
        throw "K.PSGallery.PackageRepoProvider is not loaded. Call Install-PackageRepoProvider first!"
    }

    Write-Information -InformationAction Continue "📥 Installing $ModuleName via PackageRepoProvider..."

    # Register repo using PackageRepoProvider
    $repoName = 'GitHubPackages'
    $uri = "https://nuget.pkg.github.com/$Owner/index.json"

    # Check if already registered
    $existingRepo = Get-PSResourceRepository -Name $repoName -ErrorAction SilentlyContinue
    if (-not $existingRepo) {
        Register-PackageRepo -RepositoryName $repoName -RegistryUri $uri -Token $Token -ErrorAction Stop
    }

    # Install the module
    $secureToken = ConvertTo-SecureString $Token -AsPlainText -Force
    $credential = [PSCredential]::new($Owner, $secureToken)

    Install-PSResource -Name $ModuleName `
        -Repository $repoName `
        -Credential $credential `
        -Scope CurrentUser `
        -TrustRepository `
        -ErrorAction Stop

    # Apply case-fix for Linux/macOS
    Repair-PSResourceGetCase -ModuleName $ModuleName

    # Import globally
    Import-Module $ModuleName -Force -Global -ErrorAction Stop

    $version = (Get-Module -Name $ModuleName).Version
    Write-Information -InformationAction Continue "✅ $ModuleName v$version installed and imported"
}
