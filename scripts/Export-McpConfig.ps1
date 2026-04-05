#Requires -Version 7.4

<#
.SYNOPSIS
    Exportiert die K.Agents MCP-Server Konfiguration fuer VS Code Copilot Chat.

.DESCRIPTION
    Erzeugt eine .vscode/mcp.json im Zielverzeichnis mit den gleichen
    MCP-Servern, die das Claude Code Plugin mitbringt:
    - Microsoft Learn (Docs-Suche, API-Referenzen)
    - NuGet (Package-Versionen, Kompatibilitaet)
    - GitHub (Issues, PRs, Repos)

    VS Code Copilot Chat liest MCP-Server aus .vscode/mcp.json automatisch.

.PARAMETER TargetPath
    Zielprojekt-Verzeichnis. Standard: aktuelles Verzeichnis.

.PARAMETER Force
    Ueberschreibt eine bestehende .vscode/mcp.json ohne Rueckfrage.

.EXAMPLE
    .\Export-McpConfig.ps1
    # Erzeugt .vscode/mcp.json im aktuellen Verzeichnis

.EXAMPLE
    .\Export-McpConfig.ps1 -TargetPath "C:\MyProject"

.EXAMPLE
    .\Export-McpConfig.ps1 -WhatIf
    # Zeigt was erzeugt wuerde
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TargetPath = (Get-Location),
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vscodePath = Join-Path $TargetPath '.vscode'
$mcpFile = Join-Path $vscodePath 'mcp.json'

if ((Test-Path $mcpFile) -and -not $Force) {
    Write-Warning "Datei existiert bereits: $mcpFile"
    Write-Warning "Nutze -Force zum Ueberschreiben."
    return
}

# VS Code MCP-Format (servers statt mcpServers, inputs fuer Credentials)
$mcpConfig = [ordered]@{
    inputs = @(
        [ordered]@{
            id          = 'github-token'
            type        = 'promptString'
            description = 'GitHub Personal Access Token fuer MCP'
            password    = $true
        }
    )
    servers = [ordered]@{
        'k-agents-microsoftdocs' = [ordered]@{
            type = 'http'
            url  = 'https://learn.microsoft.com/api/mcp'
        }
        'k-agents-nuget'        = [ordered]@{
            command = 'npx'
            args    = @('-y', 'nuget-mcp-server')
        }
        'k-agents-github'       = [ordered]@{
            type    = 'http'
            url     = 'https://api.githubcopilot.com/mcp/'
            headers = [ordered]@{
                Authorization = 'Bearer ${input:github-token}'
            }
        }
    }
}

if ($PSCmdlet.ShouldProcess($mcpFile, 'MCP-Konfiguration fuer VS Code erzeugen')) {
    if (-not (Test-Path $vscodePath)) {
        New-Item -ItemType Directory -Path $vscodePath -Force | Out-Null
    }

    $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content $mcpFile -Encoding utf8
    Write-Output "MCP-Konfiguration erzeugt: $mcpFile"
    Write-Output ''
    Write-Output 'Enthaltene Server:'
    Write-Output '  - k-agents-microsoftdocs (Microsoft Learn Docs)'
    Write-Output '  - k-agents-nuget         (NuGet Package Intelligence)'
    Write-Output '  - k-agents-github         (GitHub MCP)'
}
