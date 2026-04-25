#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents PreToolUse-Hook: Scannt tool_input aller Tools auf Secret-Patterns.

.DESCRIPTION
    Prueft bei jedem Tool-Aufruf den serialisierten tool_input auf bekannte Secret-Muster
    und blockiert die Ausfuehrung, wenn ein Pattern passt.

    Geprueft werden folgende Patterns (alle Tools):

      Pattern                 Regex
      ----------------------- ----------------------------------------------------------
      GitHub PAT              ghp_[A-Za-z0-9]{36}
      GitHub Fine-grained PAT github_pat_[A-Za-z0-9_]{82}
      AWS Access Key          AKIA[A-Z0-9]{16}
      AWS Secret Key          (?i)aws.{0,20}[''"][0-9a-zA-Z/+]{40}['"]
      OpenAI Key              sk-[A-Za-z0-9]{48}
      Azure Connection String (?i)(AccountKey|SharedAccessKey|Password)=[A-Za-z0-9+/=]{20,}
      Private Key             -----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----
      JWT                     eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}

    Zusaetzlich bei Bash-Tool-Aufrufen:

      Generic Hex Token       [a-fA-F0-9]{40,}

    Break-Glass-Anleitung:
        Wenn der Scanner einen legitimen Wert faelschlicherweise blockiert, kann der
        Hook einmalig umgangen werden:

            $env:KAGENTS_SECRET_BYPASS = '1'

        Der Bypass-Vorgang wird als 'secret_scanner_bypass' Event in die tagesaktuelle
        Log-Datei geschrieben (JSONL, Pfad: <plugin-root>/logs/<datum>.jsonl).
        Nach der Session bitte die Variable wieder entfernen:

            Remove-Item Env:KAGENTS_SECRET_BYPASS

.NOTES
    Gibt JSON via stdout aus, um den Tool-Aufruf in Claude Code zu blockieren:
        {"decision":"block","reason":"..."}
    Exit-Code 0: kein Block (kein Match oder Bypass).
    Exit-Code 0 + JSON-Block: Tool-Aufruf blockiert, Begruendung an Claude weitergeleitet.

    Issue #26 — PreToolUse ohne Matcher (alle Tools).
#>

. (Join-Path $PSScriptRoot 'HookHelpers.ps1')
$hookData = Read-HookStdin

# --- Break-Glass: KAGENTS_SECRET_BYPASS=1 (VOR allem anderen) ---
if ($env:KAGENTS_SECRET_BYPASS -eq '1') {
    $logFile = Initialize-LogFile
    Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
        timestamp  = (Get-Date -Format 'o')
        session_id = $hookData['session_id']
        event      = 'secret_scanner_bypass'
        tool_name  = $hookData['tool_name']
    })
    exit 0
}

# --- Secret-Patterns ---
$patterns = [ordered]@{
    'GitHub PAT'              = 'ghp_[A-Za-z0-9]{36}'
    'GitHub Fine-grained PAT' = 'github_pat_[A-Za-z0-9_]{82}'
    'AWS Access Key'          = 'AKIA[A-Z0-9]{16}'
    'AWS Secret Key'          = '(?i)aws.{0,20}[''"][0-9a-zA-Z/+]{40}[''"]'
    'OpenAI Key'              = 'sk-[A-Za-z0-9]{48}'
    'Azure Connection String' = '(?i)(AccountKey|SharedAccessKey|Password)=[A-Za-z0-9+/=]{20,}'
    'Private Key'             = '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
    'JWT'                     = 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}'
}

# --- tool_input als JSON-String serialisieren (scannt alle Felder) ---
$inputJson = $hookData['tool_input'] | ConvertTo-Json -Compress -Depth 10

# --- Alle Patterns pruefen ---
foreach ($entry in $patterns.GetEnumerator()) {
    $patternName = $entry.Key
    $regex       = $entry.Value
    if ($inputJson -match $regex) {
        Write-Output (ConvertTo-Json ([ordered]@{
            decision = 'block'
            reason   = "Secret Scanner: Pattern '$patternName' erkannt. Entferne den Secret vor der Ausfuehrung. Break-Glass: KAGENTS_SECRET_BYPASS=1"
        }) -Compress)
        exit 0
    }
}

# --- Generic Hex Token: nur bei Bash-Tool-Aufrufen ---
if ($hookData['tool_name'] -eq 'Bash') {
    if ($inputJson -match '[a-fA-F0-9]{40,}') {
        Write-Output (ConvertTo-Json ([ordered]@{
            decision = 'block'
            reason   = "Secret Scanner: Pattern 'Generic Hex Token' erkannt. Entferne den Secret vor der Ausfuehrung. Break-Glass: KAGENTS_SECRET_BYPASS=1"
        }) -Compress)
        exit 0
    }
}

# Kein Match → kein Output, exit 0
exit 0
