#Requires -Version 7.4
<#
.SYNOPSIS
    Installiert K.Switchboard als Windows-Dienst oder geplanten Task.

.DESCRIPTION
    Installiert das k-switchboard Python-Paket via pip, kopiert die
    Beispielkonfiguration nach %APPDATA%\K.Switchboard\config.yaml (wenn noch
    nicht vorhanden) und registriert den Server optional als geplanten Windows-Task
    oder Windows-Dienst.

    Modi (exklusiv, einer muss angegeben werden – oder keiner für nur Installation):
      -AsTask            Geplanter Task, startet bei Anmeldung im Hintergrund (Standard-Modus).
      -AsTask -Interactive  Wie -AsTask, aber mit sichtbarem Konsolenfenster (Debugging).
      -AsService         Echter Windows-Dienst via pywin32 (erfordert Administratorrechte).
      -Unregister        Entfernt Task UND Dienst (idempotent).

.PARAMETER PythonExe
    Pfad zum Python-Executable. Standard: python (aus PATH).

.PARAMETER AsTask
    Registriert k-switchboard als geplanten Windows-Task (AtLogon-Trigger).
    Standard-Ausführungsmodus: Hintergrund (kein Konsolenfenster).
    Mit -Interactive: sichtbares Konsolenfenster (zum Debuggen).

.PARAMETER Interactive
    Nur in Kombination mit -AsTask: startet den Task mit sichtbarem Konsolenfenster.

.PARAMETER AsService
    Registriert k-switchboard als echten Windows-Dienst via pywin32.
    Erfordert Administratorrechte. Installiert pywin32 automatisch.

.PARAMETER Unregister
    Entfernt den geplanten Task und/oder den Windows-Dienst (idempotent).
    Kein Fehler wenn weder Task noch Dienst existieren.

.EXAMPLE
    .\install-windows.ps1

.EXAMPLE
    .\install-windows.ps1 -AsTask

.EXAMPLE
    .\install-windows.ps1 -AsTask -Interactive

.EXAMPLE
    .\install-windows.ps1 -AsService

.EXAMPLE
    .\install-windows.ps1 -Unregister

.EXAMPLE
    .\install-windows.ps1 -AsTask -PythonExe "C:\Python312\python.exe"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$PythonExe = 'python',

    [Parameter()]
    [switch]$AsTask,

    [Parameter()]
    [switch]$Interactive,

    [Parameter()]
    [switch]$AsService,

    [Parameter()]
    [switch]$Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TaskName    = 'K.Switchboard'
$script:ServiceName = 'KSwitchboard'

# --- Hilfsfunktionen ---

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
    <#
    .SYNOPSIS
        Registriert K.Switchboard als geplanten Windows-Task.

    .PARAMETER PythonPath
        Absoluter Pfad zum Python-Executable.

    .PARAMETER UseInteractive
        Wenn gesetzt, wird das Konsolenfenster sichtbar angezeigt (Debugging-Modus).
        Standard: Hintergrund-Modus (kein Konsolenfenster).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$PythonPath,
        [switch]$UseInteractive
    )

    if ($UseInteractive) {
        # Sichtbares Konsolenfenster (python.exe)
        $executablePath = $PythonPath
        $arguments      = '-m k_switchboard'
    }
    else {
        # Hintergrund-Modus: pythonw.exe falls vorhanden, sonst PowerShell-Wrapper
        $pythonwPath = $PythonPath -replace '\\python\.exe$', '\pythonw.exe'
        if (Test-Path $pythonwPath) {
            $executablePath = $pythonwPath
            $arguments      = '-m k_switchboard'
        }
        else {
            # Fallback: PowerShell-Wrapper mit -WindowStyle Hidden
            $executablePath = 'pwsh.exe'
            $arguments      = "-NonInteractive -WindowStyle Hidden -Command `"& '$PythonPath' -m k_switchboard`""
        }
    }

    $action = New-ScheduledTaskAction `
        -Execute $executablePath `
        -Argument $arguments

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

    if ($PSCmdlet.ShouldProcess($script:TaskName, 'Geplanten Task registrieren')) {
        Register-ScheduledTask `
            -TaskName $script:TaskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Force | Out-Null

        $modeLabel = if ($UseInteractive) { 'Interaktiv (Konsole sichtbar)' } else { 'Hintergrund (keine Konsole)' }
        Write-Output "Geplanter Task '$($script:TaskName)' erstellt ($modeLabel)."
        Write-Output "K.Switchboard startet automatisch bei der naechsten Windows-Anmeldung."
        Write-Output "Manuell starten:   Start-ScheduledTask -TaskName '$($script:TaskName)'"
        Write-Output "Manuell stoppen:   Stop-ScheduledTask  -TaskName '$($script:TaskName)'"
        Write-Output "Deinstallieren:    .\install-windows.ps1 -Unregister"
    }
}

function Register-SwitchboardService {
    <#
    .SYNOPSIS
        Registriert K.Switchboard als echten Windows-Dienst via pywin32.

    .PARAMETER PythonPath
        Absoluter Pfad zum Python-Executable.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$PythonPath
    )

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error '-AsService erfordert Administratorrechte. Bitte PowerShell als Administrator starten.'
        return
    }

    # pywin32 installieren
    Write-Output "Installiere pywin32 (Windows-Extras)..."
    & $PythonPath -m pip install --quiet pywin32
    if ($LASTEXITCODE -ne 0) {
        Write-Error "pywin32 Installation fehlgeschlagen."
        return
    }

    if ($PSCmdlet.ShouldProcess($script:ServiceName, 'Windows-Dienst registrieren')) {
        & $PythonPath -m k_switchboard.service_main install
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Dienst-Registrierung fehlgeschlagen (Exit-Code: $LASTEXITCODE)"
            return
        }

        Start-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
        Write-Output "Windows-Dienst '$($script:ServiceName)' registriert und gestartet."
        Write-Output "Status pruefen:    Get-Service -Name '$($script:ServiceName)'"
        Write-Output "Dienst-Konsole:    services.msc"
        Write-Output "Deinstallieren:    .\install-windows.ps1 -Unregister"
    }
}

function Unregister-Switchboard {
    <#
    .SYNOPSIS
        Entfernt geplanten Task und Windows-Dienst (idempotent).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Task entfernen
    $taskExists = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue
    if ($taskExists) {
        if ($PSCmdlet.ShouldProcess($script:TaskName, 'Geplanten Task entfernen')) {
            Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false
            Write-Output "Geplanter Task '$($script:TaskName)' entfernt."
        }
    }
    else {
        Write-Output "Geplanter Task '$($script:TaskName)' nicht gefunden (bereits entfernt oder nie installiert)."
    }

    # Dienst entfernen
    $serviceExists = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
    if ($serviceExists) {
        if ($PSCmdlet.ShouldProcess($script:ServiceName, 'Windows-Dienst entfernen')) {
            Stop-Service -Name $script:ServiceName -Force -ErrorAction SilentlyContinue
            & sc.exe delete $script:ServiceName | Out-Null
            Write-Output "Windows-Dienst '$($script:ServiceName)' entfernt."
        }
    }
    else {
        Write-Output "Windows-Dienst '$($script:ServiceName)' nicht gefunden (bereits entfernt oder nie installiert)."
    }
}

# --- Hauptlogik ---

Write-Output ''
Write-Output '============================================'
Write-Output '  K.Switchboard Installation (Windows)'
Write-Output '============================================'
Write-Output ''

# Unregister-Pfad: kein Python/Paket noetig
if ($Unregister) {
    Write-Output 'Entferne K.Switchboard-Registrierungen...'
    Unregister-Switchboard
    Write-Output ''
    Write-Output 'Deinstallation abgeschlossen.'
    exit 0
}

# Python-Version pruefen
Write-Output "Pruefe Python-Version ($PythonExe)..."
if (-not (Test-PythonVersion -PythonPath $PythonExe)) {
    Write-Error @"
Python 3.11 oder neuer nicht gefunden.
Bitte Python installieren: https://www.python.org/downloads/
Anschliessend erneut ausfuehren oder -PythonExe Parameter angeben.
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

# Registrierungs-Modus
if ($AsTask) {
    Write-Output ''
    Write-Output 'Registriere als geplanten Windows-Task...'
    $resolvedPython = (& $PythonExe -c "import sys; print(sys.executable)" 2>&1).Trim()
    Register-SwitchboardTask -PythonPath $resolvedPython -UseInteractive:$Interactive
}
elseif ($AsService) {
    Write-Output ''
    Write-Output 'Registriere als Windows-Dienst...'
    $resolvedPython = (& $PythonExe -c "import sys; print(sys.executable)" 2>&1).Trim()
    Register-SwitchboardService -PythonPath $resolvedPython
}
else {
    Write-Output ''
    Write-Output '--- Manueller Start ---'
    Write-Output '  python -m k_switchboard'
    Write-Output ''
    Write-Output '--- Automatisch starten (Task, Hintergrund) ---'
    Write-Output "  .\install-windows.ps1 -AsTask"
    Write-Output ''
    Write-Output '--- Automatisch starten (Task, Konsole sichtbar) ---'
    Write-Output "  .\install-windows.ps1 -AsTask -Interactive"
    Write-Output ''
    Write-Output '--- Als Windows-Dienst installieren ---'
    Write-Output "  .\install-windows.ps1 -AsService    (erfordert Admin)"
    Write-Output ''
    Write-Output '--- Deinstallieren ---'
    Write-Output "  .\install-windows.ps1 -Unregister"
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
Write-Output 'Umgebungsvariable (persistent):'
Write-Output '  [System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://localhost:3456", "User")'
Write-Output ''
Write-Output "Konfigurationsdatei:"
Write-Output "  $(Join-Path $configDir 'config.yaml')"
Write-Output ''
Write-Output "Stats-Endpoint (nach dem Start):"
Write-Output '  http://localhost:3456/stats'
Write-Output ''
Write-Output 'Installation abgeschlossen.'

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
