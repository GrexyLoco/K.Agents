# Code-Review-Input 05 — code-reviewer

**Aufgabe:** Reviewe den folgenden Code-Ausschnitt. Nenne konkrete Findings mit Severity (Blocker/Wichtig/Verbesserung/Hinweis), Datei:Zeile, Problem und Empfehlung. Auf Deutsch.
**Datei:** `k.switchboard.net/scripts/install-windows.ps1` (Zeilen 67–130) — *ACL-Rule + Idempotenz (PS)*

```powershell
function New-NetworkServiceAccessRule {
    <#
    .SYNOPSIS
        Erzeugt eine FileSystemAccessRule fuer NetworkService via well-known SID S-1-5-20.

    .DESCRIPTION
        Verwendet [SecurityIdentifier] statt einem lokalisierten Account-String,
        sodass die Regel auf allen Windows-Sprachversionen (en-US, de-DE, …) funktioniert.
        Die well-known SID S-1-5-20 entspricht NT AUTHORITY\NETWORK SERVICE.
        Erfordert keine Administratorrechte — reine .NET-Objekt-Konstruktion.
    #>
    [CmdletBinding()]
    [OutputType([System.Security.AccessControl.FileSystemAccessRule])]
    param()

    $sid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-20')
    return [System.Security.AccessControl.FileSystemAccessRule]::new(
        $sid,
        [System.Security.AccessControl.FileSystemRights]'ReadAndExecute, Synchronize',
        [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
}

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
    param(
        [string]$SourceExe,
        [string]$TargetDir
    )

    if (-not (Test-Path $SourceExe)) {
        throw "EXE nicht gefunden: $SourceExe"
    }

    if ($PSCmdlet.ShouldProcess($TargetDir, 'Installationsverzeichnis erstellen')) {
        $null = New-Item -ItemType Directory -Path $TargetDir -Force
    }

    $destExe = Join-Path $TargetDir 'K.Switchboard.exe'

```
