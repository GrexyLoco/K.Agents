#!/usr/bin/env pwsh
#Requires -Version 7.4

<#
.SYNOPSIS
    Gemeinsame Funktion fuer das VS Code → VS 2026 Tool-Mapping in Agent-Dateien.

.DESCRIPTION
    Wird per Dot-Sourcing in Install-KAgentsVS.ps1 und Update-KAgentsVS.ps1 eingebunden.
    Transformiert die tools:-Zeile im YAML-Frontmatter von VS Code Tool Sets
    (search, read, edit, execute, web) auf die entsprechenden VS 2026 Einzeltools.

    Mapping:
      search  → code_search, file_search, find_symbol, get_symbols_by_name
      read    → get_file, get_errors, get_output_window_logs
      edit    → create_file, replace_string_in_file, multi_replace_string_in_file, remove_file
      execute → run_command_in_terminal, run_build, run_tests, get_tests
      web     → get_web_pages

    Zusaetzlich werden get_projects_in_solution und get_files_in_project immer ergaenzt.
    githubRepo wird entfernt (in VS 2026 als MCP Server konfiguriert).
#>

Set-StrictMode -Version Latest

# VS Code Tool Sets → VS 2026 Tool-Mapping
$script:VS2026ToolMapping = @{
    'search'  = @('code_search', 'file_search', 'find_symbol', 'get_symbols_by_name')
    'read'    = @('get_file', 'get_errors', 'get_output_window_logs')
    'edit'    = @('create_file', 'replace_string_in_file', 'multi_replace_string_in_file', 'remove_file')
    'execute' = @('run_command_in_terminal', 'run_build', 'run_tests', 'get_tests')
    'web'     = @('get_web_pages')
}

# VS 2026-exklusive Tools, die immer hinzugefuegt werden
$script:VS2026AlwaysAddTools = @('get_projects_in_solution', 'get_files_in_project')

# VS Code Tool Sets, die in VS 2026 nicht gemappt werden (MCP-konfiguriert)
$script:VS2026DropTools = @('githubRepo')

function ConvertTo-VS2026AgentContent {
    <#
    .SYNOPSIS
        Transformiert VS Code Tool Sets in VS 2026 Tool-Namen im Agent-Dateiinhalt.

    .PARAMETER Content
        Der vollstaendige Inhalt einer .agent.md-Datei.

    .OUTPUTS
        Den transformierten Inhalt mit VS 2026 Tool-Namen.
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

    # Tool-Namen aus dem YAML-Array parsen
    $vsCodeTools = $toolsList -split ',' | ForEach-Object {
        $_.Trim().Trim("'").Trim('"')
    } | Where-Object { $_ -and $_ -notin $script:VS2026DropTools }

    # Auf VS 2026 Tool-Namen mappen
    $vs2026Tools = [System.Collections.Generic.List[string]]::new()
    foreach ($tool in $vsCodeTools) {
        if ($script:VS2026ToolMapping.ContainsKey($tool)) {
            foreach ($mapped in $script:VS2026ToolMapping[$tool]) {
                if ($mapped -notin $vs2026Tools) {
                    $vs2026Tools.Add($mapped)
                }
            }
        }
    }

    # VS 2026-exklusive Tools immer hinzufuegen
    foreach ($tool in $script:VS2026AlwaysAddTools) {
        if ($tool -notin $vs2026Tools) {
            $vs2026Tools.Add($tool)
        }
    }

    $newToolsLine = "tools: ['" + ($vs2026Tools -join "', '") + "']"
    return $Content.Replace($toolsLine, $newToolsLine)
}
