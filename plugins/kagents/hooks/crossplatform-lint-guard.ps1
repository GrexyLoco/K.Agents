#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents PreToolUse-Guard: Prueft .ps1-Dateien auf Cross-Platform-Verstoesse.
.DESCRIPTION
    Matcher: Write-Tool. Analysiert content von .ps1-Dateien auf:
    - Write-Host (statt Write-Output/Verbose/Information/Warning)
    - Hardcoded Windows-Pfade ([A-Z]:\)
    - $env:USERPROFILE (statt $env:HOME / plattformunabhaengig)
    - Get-WmiObject (statt Get-CimInstance)
    - Fehlender #Requires -Version Header
    - Fehlender Set-StrictMode

    PSScriptAnalyzer Opt-In: KAGENTS_LINT_FULL=1
    Break-Glass: KAGENTS_LINT_BYPASS=1
#>

. (Join-Path $PSScriptRoot 'HookHelpers.ps1')
$hookData = Read-HookStdin
if ($hookData['tool_name'] -ne 'Write') { exit 0 }

$toolInput = $hookData['tool_input']
$filePath  = if ($toolInput -is [hashtable] -and $toolInput.ContainsKey('file_path')) { $toolInput['file_path'] } else { '' }
$content   = if ($toolInput -is [hashtable] -and $toolInput.ContainsKey('content'))   { $toolInput['content']   } else { '' }

# Nur .ps1 Dateien
if ($filePath -notmatch '\.ps1$') { exit 0 }
if ($filePath -match '(vendor|node_modules)[/\\]') { exit 0 }

if ($env:KAGENTS_LINT_BYPASS -eq '1') {
    $logFile = Initialize-LogFile
    Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
        timestamp  = (Get-Date -Format 'o')
        session_id = $hookData['session_id']
        event      = 'lint_guard_bypass'
        file_path  = $filePath
    })
    exit 0
}

$violations = [System.Collections.Generic.List[string]]::new()

# Check 1: Write-Host
$lineNum = 0
foreach ($line in ($content -split "`n")) {
    $lineNum++
    if ($line -match '\bWrite-Host\b' -and $line -notmatch '^\s*#') {
        $null = $violations.Add("Z.$lineNum: Write-Host gefunden — je nach Kontext ersetzen durch: Write-Output (Daten), Write-Verbose (Debug), Write-Information (Fortschritt), Write-Warning (Warnungen)")
    }
}

# Check 2: Hardcoded Windows-Pfade
$lineNum = 0
foreach ($line in ($content -split "`n")) {
    $lineNum++
    if ($line -match '[A-Z]:\\' -and $line -notmatch '^\s*#') {
        $null = $violations.Add("Z.$lineNum: Hardcoded Windows-Pfad gefunden — Join-Path verwenden")
    }
}

# Check 3: $env:USERPROFILE
$lineNum = 0
foreach ($line in ($content -split "`n")) {
    $lineNum++
    if ($line -match '\$env:USERPROFILE\b' -and $line -notmatch '^\s*#') {
        $null = $violations.Add("Z.$lineNum: `$env:USERPROFILE — plattformunabhaengig: 'if (`$env:USERPROFILE) { `$env:USERPROFILE } else { `$HOME }'")
    }
}

# Check 4: Get-WmiObject
$lineNum = 0
foreach ($line in ($content -split "`n")) {
    $lineNum++
    if ($line -match '\bGet-WmiObject\b' -and $line -notmatch '^\s*#') {
        $null = $violations.Add("Z.$lineNum: Get-WmiObject — Get-CimInstance verwenden (cross-platform)")
    }
}

# Check 5: Fehlender #Requires Header
if ($content -notmatch '#Requires\s+-Version') {
    $null = $violations.Add("Fehlender Header: '#Requires -Version 7.4' in Zeile 1 erforderlich")
}

# Check 6: Fehlender Set-StrictMode
if ($content -notmatch 'Set-StrictMode') {
    $null = $violations.Add("Fehlender 'Set-StrictMode -Version Latest' nach #Requires-Header")
}

if ($env:KAGENTS_LINT_FULL -eq '1' -and (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) {
    $tempFile = [System.IO.Path]::GetTempFileName() + '.ps1'
    try {
        Set-Content -Path $tempFile -Value $content -Encoding utf8
        $results = Invoke-ScriptAnalyzer -Path $tempFile -Severity Error,Warning
        foreach ($r in $results) {
            $null = $violations.Add("PSScriptAnalyzer Z.$($r.Line): [$($r.Severity)] $($r.RuleName) — $($r.Message)")
        }
    } finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }
}

if ($violations.Count -gt 0) {
    $violationText = ($violations | ForEach-Object { "  - $_" }) -join "`n"
    Write-Output (ConvertTo-Json ([ordered]@{
        decision = 'block'
        reason   = "CrossPlatform Lint Guard — $($violations.Count) Verstoss(e) in '$(Split-Path $filePath -Leaf)':`n$violationText`n`nBreak-Glass: KAGENTS_LINT_BYPASS=1"
    }) -Compress)
    exit 0
}
