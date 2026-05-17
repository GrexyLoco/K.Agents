#Requires -Version 7.4
<#
.SYNOPSIS
    Installiert K.Switchboard als Windows-Dienst oder portabel.

.DESCRIPTION
    Kopiert K.Switchboard.exe nach %LOCALAPPDATA%\K.Switchboard\ und
    registriert den Dienst optional als Windows-Service via sc.exe.

    Der Dienst läuft unter dem NetworkService-Konto mit verzögertem
    automatischen Start (Automatic Delayed). Intern nutzt die EXE
    Microsoft.Extensions.Hosting.WindowsServices — pywin32 oder andere
    Python-Abhängigkeiten werden nicht benötigt.

    Modi:
      (kein Parameter)   Nur portabel installieren (EXE kopieren).
      -AsService         Windows-Dienst via sc.exe registrieren + starten.
      -Unregister        Dienst stoppen und entfernen (idempotent).

.PARAMETER ExePath
    Pfad zur K.Switchboard.exe. Standard: K.Switchboard.exe im selben Ordner wie das Skript.

.PARAMETER AsService
    Registriert K.Switchboard als Windows-Dienst (erfordert Administratorrechte).

.PARAMETER Unregister
    Stoppt und entfernt den Windows-Dienst (idempotent, kein Fehler wenn nicht vorhanden).

.EXAMPLE
    .\install-windows.ps1

.EXAMPLE
    .\install-windows.ps1 -AsService

.EXAMPLE
    .\install-windows.ps1 -AsService -ExePath "C:\Downloads\K.Switchboard.exe"

.EXAMPLE
    .\install-windows.ps1 -Unregister
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ExePath = '',

    [Parameter()]
    [switch]$AsService,

    [Parameter()]
    [switch]$Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ServiceName = 'K.Switchboard'
$script:InstallDir  = Join-Path $env:LOCALAPPDATA 'K.Switchboard'

# --- Hilfsfunktionen ---

function Get-DefaultExePath {
    [CmdletBinding()]
    param()

    $scriptDir  = $PSScriptRoot
    $candidate  = Join-Path $scriptDir 'K.Switchboard.exe'
    if (Test-Path $candidate) {
        return $candidate
    }
    return ''
}

function Assert-AdminRights {
    [CmdletBinding()]
    param()

    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Für -AsService werden Administratorrechte benötigt. Starte PowerShell als Administrator.'
    }
}

function Install-Portable {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SourceExe)

    if (-not (Test-Path $SourceExe)) {
        throw "EXE nicht gefunden: $SourceExe"
    }

    if ($PSCmdlet.ShouldProcess($script:InstallDir, 'Installationsverzeichnis erstellen')) {
        $null = New-Item -ItemType Directory -Path $script:InstallDir -Force
    }

    $destExe = Join-Path $script:InstallDir 'K.Switchboard.exe'

    if ($PSCmdlet.ShouldProcess($destExe, 'EXE kopieren')) {
        Copy-Item -Path $SourceExe -Destination $destExe -Force
        Write-Output "K.Switchboard.exe installiert: $destExe"
    }

    return $destExe
}

function Register-WindowsService {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$ExeFullPath)

    Assert-AdminRights

    # Vorhandenen Dienst zuerst entfernen (idempotent)
    $existing = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Write-Verbose "Vorhandener Dienst wird zuerst entfernt..."
        Unregister-WindowsService -Quiet
    }

    if ($PSCmdlet.ShouldProcess($script:ServiceName, 'Windows-Dienst registrieren')) {
        # sc.exe: Docs: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create
        $scArgs = @(
            'create', $script:ServiceName,
            'binPath=', "`"$ExeFullPath`"",
            'start=', 'delayed-auto',
            'obj=', 'NT AUTHORITY\NetworkService',
            'DisplayName=', 'K.Switchboard AI Proxy'
        )
        $result = & sc.exe @scArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "sc.exe create fehlgeschlagen (Exit $LASTEXITCODE): $result"
        }

        # Beschreibung setzen
        & sc.exe description $script:ServiceName 'K.Switchboard — KI-Proxy für Anthropic und Ollama (K.Agents)' | Out-Null

        Write-Output "Dienst '$($script:ServiceName)' registriert."

        # Dienst starten
        if ($PSCmdlet.ShouldProcess($script:ServiceName, 'Windows-Dienst starten')) {
            Start-Service -Name $script:ServiceName
            Write-Output "Dienst '$($script:ServiceName)' gestartet."
            Write-Output "Status prüfen:     Get-Service $($script:ServiceName)"
            Write-Output "Health-Check:      Invoke-RestMethod http://localhost:3456/health"
            Write-Output "Deinstallieren:    .\install-windows.ps1 -Unregister"
        }
    }
}

function Unregister-WindowsService {
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$Quiet)

    Assert-AdminRights

    $existing = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        if (-not $Quiet) {
            Write-Output "Dienst '$($script:ServiceName)' ist nicht registriert — nichts zu tun."
        }
        return
    }

    # Dienst stoppen falls er läuft
    if ($existing.Status -ne 'Stopped') {
        if ($PSCmdlet.ShouldProcess($script:ServiceName, 'Dienst stoppen')) {
            Stop-Service -Name $script:ServiceName -Force -ErrorAction SilentlyContinue
            Write-Verbose "Dienst gestoppt."
        }
    }

    # Dienst löschen: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-delete
    if ($PSCmdlet.ShouldProcess($script:ServiceName, 'Dienst entfernen')) {
        $result = & sc.exe delete $script:ServiceName 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "sc.exe delete fehlgeschlagen (Exit $LASTEXITCODE): $result"
        }
        Write-Output "Dienst '$($script:ServiceName)' entfernt."
    }
}

# --- Hauptlogik ---

# EXE-Pfad auflösen
if ($ExePath -eq '') {
    $ExePath = Get-DefaultExePath
}
if ($ExePath -ne '' -and -not [System.IO.Path]::IsPathRooted($ExePath)) {
    $ExePath = Join-Path $PWD $ExePath
}

if ($Unregister) {
    Unregister-WindowsService
    Write-Output ''
    Write-Output 'Manuelle Bereinigung (optional):'
    Write-Output "  Remove-Item -Recurse -Force `"$($script:InstallDir)`""
    Write-Output "  Remove-Item -Recurse -Force `"$env:APPDATA\K.Switchboard`""
    Write-Output "  Remove-Item -Recurse -Force `"$env:ProgramData\K.Switchboard`""
    return
}

if ($ExePath -eq '') {
    throw 'K.Switchboard.exe nicht gefunden. Gib -ExePath an oder lege die EXE neben das Skript.'
}

$installedExe = Install-Portable -SourceExe $ExePath

if ($AsService) {
    Register-WindowsService -ExeFullPath $installedExe
}
else {
    Write-Output ''
    Write-Output 'Portabel installiert. Ausführen mit:'
    Write-Output "  & `"$installedExe`""
    Write-Output ''
    Write-Output 'Als Dienst installieren:'
    Write-Output "  .\install-windows.ps1 -AsService -ExePath `"$ExePath`""
}
