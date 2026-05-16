#Requires -Version 7.4
<#
.SYNOPSIS
    Spike-Verifikation: Wird Copilot Chat (VS Code) über K.Switchboard geroutet?

.DESCRIPTION
    Prüft empirisch, ob VS Code Copilot Chat die Umgebungsvariable ANTHROPIC_BASE_URL
    berücksichtigt und Anfragen über K.Switchboard routet.

    Erwartetes Ergebnis: Nein.
    Architektur-Grund: VS Code Copilot Chat verwendet einen eigenen Endpoint
    (api.githubcopilot.com) und ist kein Anthropic-API-Client. ANTHROPIC_BASE_URL
    hat darauf keine Auswirkung.

    Dieses Skript:
    1. Startet K.Switchboard im Debug-Modus (Hintergrund-Job).
    2. Zeigt Anweisungen für den manuellen Test in VS Code.
    3. Liest nach dem Test das Debug-Log und prüft auf eingehende /v1/messages-Requests.

.PARAMETER SwitchboardUrl
    K.Switchboard-URL. Standard: http://localhost:3456

.PARAMETER PythonExe
    Pfad zum Python-Executable. Standard: python (aus PATH)

.EXAMPLE
    .\Test-CopilotChatRouting.ps1
#>

[CmdletBinding()]
param(
    [string]$SwitchboardUrl = 'http://localhost:3456',
    [string]$PythonExe = 'python'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir  = Join-Path $env:APPDATA 'K.Switchboard' 'logs'
$LogFile = Join-Path $LogDir 'k-switchboard.log'

# --- Sicherstellen, dass Log-Verzeichnis existiert ---
if (-not (Test-Path $LogDir)) {
    $null = New-Item -ItemType Directory -Path $LogDir -Force
}

# --- Prüfen ob Switchboard bereits läuft ---
$alreadyRunning = $false
try {
    $null = Invoke-RestMethod -Uri "$SwitchboardUrl/health" -Method Get -TimeoutSec 2 -ErrorAction Stop
    $alreadyRunning = $true
    Write-Information 'K.Switchboard läuft bereits.' -InformationAction Continue
}
catch {
    Write-Information 'K.Switchboard nicht erreichbar — starte im Debug-Modus...' -InformationAction Continue
}

# --- Switchboard im Hintergrund mit Debug-Logging starten ---
$job = $null
if (-not $alreadyRunning) {
    $env:LOG_LEVEL = 'DEBUG'
    $packageDir = Join-Path $PSScriptRoot '..'
    $packageDir = [System.IO.Path]::GetFullPath($packageDir)

    $job = Start-Job -ScriptBlock {
        param($python, $dir, $logLevel)
        $env:LOG_LEVEL = $logLevel
        Set-Location $dir
        & $python -m k_switchboard 2>&1
    } -ArgumentList $PythonExe, $packageDir, 'DEBUG'

    # Kurz warten bis Switchboard bereit ist
    $ready = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $null = Invoke-RestMethod -Uri "$SwitchboardUrl/health" -Method Get -TimeoutSec 1 -ErrorAction Stop
            $ready = $true
            break
        }
        catch { }
    }

    if (-not $ready) {
        Write-Error 'K.Switchboard konnte nicht gestartet werden. Manuell starten: k-switchboard --log-level DEBUG'
        if ($null -ne $job) { Remove-Job -Job $job -Force }
        exit 1
    }
    Write-Information 'K.Switchboard gestartet (Debug-Modus).' -InformationAction Continue
}

# Zeitstempel vor dem Test merken
$testStartTime = Get-Date

Write-Output ''
Write-Output '================================================================'
Write-Output '  Spike-Test: Copilot Chat Routing'
Write-Output '================================================================'
Write-Output ''
Write-Output 'Schritte:'
Write-Output '  1. Stelle sicher, dass ANTHROPIC_BASE_URL=http://localhost:3456'
Write-Output '     als User-Umgebungsvariable gesetzt ist (Systemsteuerung →'
Write-Output '     Umgebungsvariablen ODER:'
Write-Output '     [System.Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL","User")'
Write-Output ''
Write-Output '  2. Starte VS Code KOMPLETT NEU (damit die Env-Variable geladen wird).'
Write-Output ''
Write-Output '  3. Öffne Copilot Chat in VS Code.'
Write-Output ''
Write-Output '  4. Wähle ein Claude-Modell (z.B. Claude Sonnet).'
Write-Output ''
Write-Output '  5. Sende eine einfache Anfrage, z.B.: "Hallo, antworte mit einem Wort."'
Write-Output ''
Write-Output '  6. Kehre zu diesem Terminal zurück und drücke ENTER.'
Write-Output ''
Write-Output "Aktuelles ANTHROPIC_BASE_URL (User-Scope):"
$currentUrl = [System.Environment]::GetEnvironmentVariable('ANTHROPIC_BASE_URL', 'User')
Write-Output "  $(if ($currentUrl) { $currentUrl } else { '(nicht gesetzt)' })"
Write-Output ''
Read-Host 'Test abgeschlossen? ENTER drücken'
Write-Output ''

# --- Log auswerten ---
Write-Output 'Werte K.Switchboard-Log aus...'
Write-Output ''

$incomingRequests = @()

if (Test-Path $LogFile) {
    $logLines = Get-Content $LogFile -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '/v1/messages' } |
        Where-Object {
            # Nur Log-Einträge nach Teststart
            if ($_ -match '"time"\s*:\s*"([^"]+)"') {
                try { [datetime]$matches[1] -gt $testStartTime } catch { $true }
            }
            else { $true }
        }
    $incomingRequests = @($logLines)
}

if ($incomingRequests.Count -gt 0) {
    Write-Output "  [POSITIV] $($incomingRequests.Count) /v1/messages-Request(s) eingegangen."
    Write-Output ''
    Write-Output '  Ergebnis: Copilot Chat routet ÜBER K.Switchboard.'
    Write-Output '  → Issue A Punkt 4 muss angepasst werden!'
    Write-Output ''
    $incomingRequests | Select-Object -First 5 | Write-Output
}
else {
    Write-Output '  [NEGATIV] Keine /v1/messages-Requests im Log nach Teststart.'
    Write-Output ''
    Write-Output '  Erwartetes Ergebnis bestätigt:'
    Write-Output '  VS Code Copilot Chat routet NICHT über K.Switchboard.'
    Write-Output '  Copilot Chat verwendet api.githubcopilot.com direkt'
    Write-Output '  und ignoriert ANTHROPIC_BASE_URL.'
    Write-Output ''
    Write-Output '  → Issue A Punkt 4 kann wie geplant dokumentiert werden.'
}

Write-Output '================================================================'

# --- Aufräumen ---
if ($null -ne $job) {
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    Write-Output ''
    Write-Output 'K.Switchboard (Hintergrund-Job) gestoppt.'
}
