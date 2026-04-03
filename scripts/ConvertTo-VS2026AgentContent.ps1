#!/usr/bin/env pwsh
#Requires -Version 7.4

<#
.SYNOPSIS
    Gemeinsame Funktion fuer die Agent-Datei-Anpassung bei VS Code → VS 2026.

.DESCRIPTION
    Wird per Dot-Sourcing in Install-KAgentsVS.ps1 und Update-KAgentsVS.ps1 eingebunden.
    Entfernt VS Code-spezifische Tools aus der tools:-Zeile im YAML-Frontmatter.

    Die plattformuebergreifenden Tool-Aliase (search, read, edit, execute, web)
    werden von allen Copilot-Clients (VS Code, VS 2026, JetBrains etc.) nativ
    aufgeloest und bleiben unveraendert.

    Entfernt werden:
      githubRepo  → in VS 2026 als MCP Server konfiguriert

    Referenz: https://docs.github.com/en/copilot/reference/custom-agents-configuration#tools
#>

Set-StrictMode -Version Latest

# Tools, die in VS 2026 entfernt werden (MCP-konfiguriert oder nicht verfuegbar)
$script:VS2026DropTools = @('githubRepo')

function ConvertTo-VS2026AgentContent {
    <#
    .SYNOPSIS
        Entfernt VS Code-spezifische Tools aus dem Agent-Dateiinhalt fuer VS 2026.

    .PARAMETER Content
        Der vollstaendige Inhalt einer .agent.md-Datei.

    .OUTPUTS
        Den bereinigten Inhalt ohne VS Code-spezifische Tools.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    if ($Content -notmatch '(?m)^tools:\s*\[(.+)\]') {
        return $Content
    }

    $toolsLine = $Matches[0]
    $toolsList = $Matches[1]

    # Tool-Namen aus dem YAML-Array parsen und VS Code-spezifische entfernen
    $tools = @($toolsList -split ',' | ForEach-Object {
        $_.Trim().Trim("'").Trim('"')
    } | Where-Object { $_ -and $_ -notin $script:VS2026DropTools })

    if ($tools.Count -eq 0) {
        # Keine Tools uebrig → tools-Zeile entfernen
        return $Content.Replace($toolsLine + "`n", '').Replace($toolsLine, '')
    }

    $newToolsLine = "tools: ['" + ($tools -join "', '") + "']"
    return $Content.Replace($toolsLine, $newToolsLine)
}
