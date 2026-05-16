#Requires -Version 7.4
<#
.SYNOPSIS
    Installiert K.Switchboard als Windows-Dienst oder geplanten Task.

.DESCRIPTION
    Installiert das k-switchboard Python-Paket via pip, kopiert die
    Beispielkonfiguration nach %APPDATA%\K.Switchboard\config.yaml (wenn noch
    nicht vorhanden) und registriert den Server optional als geplanten Windows-Task.
    Gibt Hinweise zur Konfiguration des Claude-Clients aus.

.PARAMETER PythonExe
    Pfad zum Python-Executable. Standard: python (aus PATH)

.PARAMETER AsTask
    Wenn gesetzt, wird k-switchboard als geplanter Task bei Windows-Anmeldung gestartet.

.EXAMPLE
    .\install-windows.ps1

.EXAMPLE
    .\install-windows.ps1 -AsTask -PythonExe "C:\Python312\python.exe"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$PythonExe = 'python',

    [Parameter()]
    [switch]$AsTask
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PythonVersion {
    [CmdletBinding()]
    param([string]$PythonPath)

    try {
        $versionOutput = & $PythonPath --version 2>&1
        return ($versionOutput -match 'Python 3\.(1[1-9]|[2-9]\d)')
    }
    catch {
        return $false
    }
}

function Install-DefaultConfig {
    [CmdletBinding()]
    param([string]$ConfigDir)

    $configFile = Join-Path $ConfigDir 'config.yaml'

    if (-not (Test-Path $configFile)) {
        Write-Verbose "Erstelle Konfigurationsverzeichnis: $ConfigDir"
        $null = New-Item -ItemType Directory -Path $ConfigDir -Force

        $exampleConfig = Join-Path $PSScriptRoot '..' 'config.example.yaml'
        $exampleConfig = [System.IO.Path]::GetFullPath($exampleConfig)

        if (Test-Path $exampleConfig) {
            Copy-Item -Path $exampleConfig -Destination $configFile
            Write-Output "Konfiguration erstellt: $configFile"
            Write-Output "Bitte anpassen: anthropic_base_url, Modell-Aliase und Fallback-Ketten."
        }
        else {
            Write-Warning "Beispielkonfiguration nicht gefunden: $exampleConfig"
            Write-Warning "Bitte manuell erstellen: $configFile"
        }
    }
    else {
        Write-Verbose "Konfiguration bereits vorhanden: $configFile"
    }
}

function Register-SwitchboardTask {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$PythonPath,
        [string]$TaskName = 'K.Switchboard'
    )

    $action = New-ScheduledTaskAction `
        -Execute $PythonPath `
        -Argument '-m k_switchboard'

    $trigger = New-ScheduledTaskTrigger -AtLogOn

    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew

    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive `
        -RunLevel Highest

    if ($PSCmdlet.ShouldProcess($TaskName, 'Geplanten Task registrieren')) {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Force | Out-Null

        Write-Output "Geplanter Task '$TaskName' erstellt."
        Write-Output "K.Switchboard startet automatisch bei der nächsten Windows-Anmeldung."
        Write-Output "Manuell starten: Start-ScheduledTask -TaskName '$TaskName'"
    }
}

# --- Hauptlogik ---

Write-Output ''
Write-Output '============================================'
Write-Output '  K.Switchboard Installation (Windows)'
Write-Output '============================================'
Write-Output ''

# Python-Version prüfen
Write-Output "Prüfe Python-Version ($PythonExe)..."
if (-not (Test-PythonVersion -PythonPath $PythonExe)) {
    Write-Error @"
Python 3.11 oder neuer nicht gefunden.
Bitte Python installieren: https://www.python.org/downloads/
Anschließend erneut ausführen oder -PythonExe Parameter angeben.
"@
    exit 1
}
Write-Output "Python-Version OK."
Write-Output ''

# Paket installieren
Write-Output "Installiere k-switchboard Paket..."
$packageDir = Join-Path $PSScriptRoot '..'
$packageDir = [System.IO.Path]::GetFullPath($packageDir)

& $PythonExe -m pip install --quiet --upgrade $packageDir
if ($LASTEXITCODE -ne 0) {
    Write-Error "pip install fehlgeschlagen (Exit-Code: $LASTEXITCODE)"
    exit 1
}
Write-Output "Paket erfolgreich installiert."
Write-Output ''

# Konfigurationsdatei einrichten
$configDir = Join-Path $env:APPDATA 'K.Switchboard'
Install-DefaultConfig -ConfigDir $configDir

# Als geplanten Task registrieren (optional)
if ($AsTask) {
    Write-Output ''
    Write-Output 'Registriere als geplanten Windows-Task...'
    $resolvedPython = & $PythonExe -c "import sys; print(sys.executable)" 2>&1
    Register-SwitchboardTask -PythonPath $resolvedPython.Trim()
}
else {
    Write-Output ''
    Write-Output '--- Manueller Start ---'
    Write-Output '  k-switchboard'
    Write-Output ''
    Write-Output '--- Als geplanten Task installieren ---'
    Write-Output "  .\install-windows.ps1 -AsTask"
}

# Hinweise zur Claude-Client-Konfiguration
Write-Output ''
Write-Output '============================================'
Write-Output '  Claude-Client konfigurieren'
Write-Output '============================================'
Write-Output ''
Write-Output 'API-URL in deinem Claude-Client auf folgende URL setzen:'
Write-Output '  http://localhost:3456'
Write-Output ''
Write-Output 'Umgebungsvariable (PowerShell):'
Write-Output '  $env:ANTHROPIC_BASE_URL = "http://localhost:3456"'
Write-Output ''
Write-Output 'Umgebungsvariable (persistent, System):'
Write-Output '  [System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://localhost:3456", "User")'
Write-Output ''
Write-Output "Konfigurationsdatei:"
Write-Output "  $(Join-Path $configDir 'config.yaml')"
Write-Output ''
Write-Output "Stats-Endpoint (nach dem Start):"
Write-Output '  http://localhost:3456/stats'
Write-Output ''
Write-Output 'Installation abgeschlossen.'
