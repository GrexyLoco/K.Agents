#Requires -Version 7.4
<#
.SYNOPSIS
    Prüft ob K.Switchboard korrekt eingerichtet und erreichbar ist.

.DESCRIPTION
    Prüft den Health-Status von K.Switchboard, ob Ollama erreichbar ist,
    und zeigt die aktuellen Tages-Kosten- und Token-Statistiken an.

.PARAMETER SwitchboardUrl
    Basis-URL des K.Switchboard-Servers. Standard: http://localhost:3456

.PARAMETER OllamaUrl
    Basis-URL der Ollama-Instanz. Standard: http://localhost:11434

.EXAMPLE
    .\verify-setup.ps1

.EXAMPLE
    .\verify-setup.ps1 -SwitchboardUrl "http://localhost:4000"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SwitchboardUrl = 'http://localhost:3456',

    [Parameter()]
    [string]$OllamaUrl = 'http://localhost:11434'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-EndpointCheck {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Url,
        [string]$Label
    )

    try {
        $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 3 -ErrorAction Stop
        Write-Information "  [OK]     $Label" -InformationAction Continue
        return $response
    }
    catch {
        Write-Information "  [FEHLER] $Label ($Url)" -InformationAction Continue
        Write-Verbose "  Details: $_"
        return $null
    }
}

function Show-CostStats {
    [CmdletBinding()]
    param([pscustomobject]$Stats)

    if ($null -eq $Stats) {
        return
    }

    Write-Output ''
    Write-Output "  === Tageskosten ($($Stats.date)) ==="

    $modelNames = $Stats.models.PSObject.Properties.Name
    if ($modelNames.Count -eq 0) {
        Write-Output "  Noch keine Nutzung heute erfasst."
        return
    }

    foreach ($modelName in $modelNames) {
        $model = $Stats.models.$modelName
        $costFormatted = '{0:F6}' -f $model.cost_usd
        Write-Output (
            "  {0,-30}  In: {1,8}  Out: {2,8}  Kosten: {3} USD" -f
            $modelName,
            $model.input_tokens,
            $model.output_tokens,
            $costFormatted
        )
    }

    Write-Output ''
    Write-Output ("  Gesamt heute: {0:F6} USD" -f $Stats.total_cost_usd)
}

# --- Hauptlogik ---

Write-Output ''
Write-Output '============================================'
Write-Output '  K.Switchboard Verifikation'
Write-Output '============================================'
Write-Output ''
Write-Output 'Erreichbarkeit:'

$healthUrl = "$SwitchboardUrl/health"
$statsUrl  = "$SwitchboardUrl/stats"
$ollamaUrl = "$OllamaUrl/api/version"

$switchboardHealth = Invoke-EndpointCheck -Url $healthUrl -Label "K.Switchboard ($SwitchboardUrl)"
$ollamaHealth      = Invoke-EndpointCheck -Url $ollamaUrl -Label "Ollama ($OllamaUrl)"

# Kosten-Statistiken nur anzeigen wenn Switchboard läuft
if ($null -ne $switchboardHealth) {
    $statsData = Invoke-EndpointCheck -Url $statsUrl -Label 'Stats-Endpoint'
    Show-CostStats -Stats $statsData
}

# Status-Zusammenfassung
Write-Output ''
Write-Output '============================================'
Write-Output '  Status-Zusammenfassung'
Write-Output '============================================'
Write-Output "  K.Switchboard : $(if ($null -ne $switchboardHealth) { 'Läuft' } else { 'Nicht erreichbar' })"
Write-Output "  Ollama         : $(if ($null -ne $ollamaHealth) { 'Läuft' } else { 'Nicht erreichbar' })"

if ($null -eq $switchboardHealth) {
    Write-Output ''
    Write-Output 'K.Switchboard starten:'
    Write-Output '  k-switchboard'
    Write-Output '  # oder:'
    Write-Output '  python -m k_switchboard'
}

if ($null -eq $ollamaHealth) {
    Write-Output ''
    Write-Output 'Ollama starten:'
    Write-Output '  ollama serve'
    Write-Output '  # Modelle laden: ollama pull llama3.2:3b'
}

Write-Output ''
