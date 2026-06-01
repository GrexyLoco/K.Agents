#Requires -Version 7.4

<#
.SYNOPSIS
    Zeigt den aktuellen ReleaseFlow Train-Status eines GitHub-Repos an.

.DESCRIPTION
    Ermittelt Phase, Version, Branches, Tags, Milestone, blockierende Issues
    und offene PRs des aktuellen ReleaseFlow Release Trains.

.PARAMETER Repo
    GitHub-Repo im Format 'Owner/Repo'. Optional — wird per `gh repo view` ermittelt
    wenn nicht angegeben.

.EXAMPLE
    .\Get-ReleaseTrain.ps1
    # Gibt Train-Status des aktuellen Repos aus

.EXAMPLE
    $train = .\Get-ReleaseTrain.ps1 -Repo 'GrexyLoco/K.Agents'
    $train.Phase
#>
[CmdletBinding()]
param(
    [string]$Repo = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Hilfsfunktionen ────────────────────────────────────────────────────────

function Get-PhaseFromTag {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Tag)

    if ([string]::IsNullOrEmpty($Tag)) { return 'None' }

    if ($Tag -match '-alpha\d+$')       { return 'Alpha'  }
    if ($Tag -match '-freeze$')         { return 'Freeze' }
    if ($Tag -match '-beta\d+$')        { return 'Beta'   }
    if ($Tag -match '^v\d+\.\d+\.\d+$') { return 'Stable' }

    return 'None'
}

function Get-VersionFromTag {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Tag)

    if ([string]::IsNullOrEmpty($Tag)) { return '' }
    if ($Tag -match '^v(\d+\.\d+\.\d+)') {
        return $Matches[1]
    }
    return ''
}

# ─── Hauptlogik ─────────────────────────────────────────────────────────────

function Invoke-GetReleaseTrain {
    [CmdletBinding()]
    param([string]$Repo = '')

    # Repo ermitteln
    if ([string]::IsNullOrEmpty($Repo)) {
        $Repo = (gh repo view --json nameWithOwner -q .nameWithOwner 2>$null).Trim()
    }
    if ([string]::IsNullOrEmpty($Repo)) {
        Write-Error 'Kein Repo ermittelt. Bitte -Repo angeben oder gh auth login ausfuehren.'
        return
    }

    # ── 1. Release-Liste holen ───────────────────────────────────────────────
    $releaseJson = gh release list --repo $Repo --json tagName,isDraft,isPrerelease --limit 20 2>$null
    $releases    = if ($releaseJson) { $releaseJson | ConvertFrom-Json } else { @() }

    # Neuesten Non-Draft Release-Tag finden (Fallback-Quelle)
    $latestTag = ''
    foreach ($rel in $releases) {
        if (-not $rel.isDraft) {
            $latestTag = $rel.tagName
            break
        }
    }

    # ── 1b. Aktiven Train ermitteln (offener Milestone + dev/ + release/-Branch) ──
    $activeTrain = $null
    $openMilestonesJson = gh api "repos/$Repo/milestones?state=open" 2>$null
    $openMilestones     = if ($openMilestonesJson) { $openMilestonesJson | ConvertFrom-Json } else { @() }

    # Nur Milestones der Form vX.Y.Z beachten; hoechste SemVer gewinnt
    $trainCandidates = @($openMilestones | Where-Object { $_.title -match '^v\d+\.\d+\.\d+$' })
    foreach ($ms in ($trainCandidates | Sort-Object {
        $t = $_.title -replace '^v', ''
        [System.Version]$t
    } -Descending)) {
        $msVersion = $ms.title -replace '^v', ''
        $devCandidate     = "dev/v${msVersion}"
        $releaseCandidate = "release/v${msVersion}"
        gh api "repos/$Repo/branches/$devCandidate"     2>$null | Out-Null
        $devExists     = $LASTEXITCODE -eq 0
        gh api "repos/$Repo/branches/$releaseCandidate" 2>$null | Out-Null
        $releaseExists = $LASTEXITCODE -eq 0
        if ($devExists -and $releaseExists) {
            $activeTrain = [PSCustomObject]@{
                Version         = $msVersion
                DevBranch       = $devCandidate
                ReleaseBranch   = $releaseCandidate
                MilestoneTitle  = $ms.title
                MilestoneUrl    = $ms.html_url
            }
            break
        }
    }

    # ── 2. Phase + Version ───────────────────────────────────────────────────
    if ($activeTrain) {
        # Aktiver Train gefunden: Phase aus Pre-Release-Tags des Trains bestimmen
        $version = $activeTrain.Version
        $trainPreReleaseTags = @($releases | Where-Object {
            $_.isPrerelease -and (-not $_.isDraft) -and ($_.tagName -match "^v${version}-")
        } | ForEach-Object { $_.tagName })

        if ($trainPreReleaseTags.Count -eq 0) {
            # Kein Pre-Release-Tag vorhanden: Phase ist Alpha (frisch geplanter Train)
            $phase = 'Alpha'
        } else {
            # Mehrere Pre-Release-Tags eines Trains koennen gleichzeitig existieren
            # (Tags werden nicht geloescht, z.B. -freeze UND -beta1). Die Reihenfolge
            # aus `gh release list` ist NICHT garantiert — daher die fortgeschrittenste
            # Phase ueber ein explizites Ranking bestimmen statt [0] zu nehmen.
            $phaseRank = @{ Alpha = 1; Freeze = 2; Beta = 3; Stable = 4 }
            $mostAdvancedPhase = $trainPreReleaseTags |
                ForEach-Object { Get-PhaseFromTag $_ } |
                Where-Object  { $phaseRank.ContainsKey($_) } |
                Sort-Object   { $phaseRank[$_] } -Descending |
                Select-Object -First 1
            $phase = if ($mostAdvancedPhase) { $mostAdvancedPhase } else { 'Alpha' }
        }
    } else {
        # Kein aktiver Train: Fallback auf letzten Non-Draft-Tag
        $phase   = Get-PhaseFromTag $latestTag
        $version = Get-VersionFromTag $latestTag
    }

    # ── 3. Branch-Namen ableiten ─────────────────────────────────────────────
    $devBranch     = if ($version) { "dev/v${version}" }     else { $null }
    $releaseBranch = if ($version) { "release/v${version}" } else { $null }

    # ReleaseBranch nur setzen wenn er remote existiert
    # (bei aktivem Train bereits verifiziert; Fallback-Pfad prueft neu)
    if ($activeTrain) {
        # Branches bereits geprueft — direkt aus Train uebernehmen
        $devBranch     = $activeTrain.DevBranch
        $releaseBranch = $activeTrain.ReleaseBranch
    } elseif ($releaseBranch) {
        gh api "repos/$Repo/branches/$releaseBranch" 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { $releaseBranch = $null }
    }

    # ── 4. AllowedBranches + PushAllowed aus Phase ───────────────────────────
    switch ($phase) {
        'Alpha'  {
            $allowedBranches = 'feature/*, fix/*'
            $allowedTarget   = $devBranch
            $pushAllowed     = 'YES'
        }
        'Freeze' {
            $allowedBranches = 'fix/* only'
            $allowedTarget   = $releaseBranch
            $pushAllowed     = 'NO'
        }
        'Beta'   {
            $allowedBranches = 'fix/* only'
            $allowedTarget   = $releaseBranch
            $pushAllowed     = 'YES'
        }
        default  {
            $allowedBranches = 'none'
            $allowedTarget   = $null
            $pushAllowed     = 'NO'
        }
    }

    # ── 5. Milestone ─────────────────────────────────────────────────────────
    $milestone = $null
    if ($activeTrain) {
        # Milestone-Daten aus dem aktiven Train uebernehmen (bereits ermittelt)
        $milestone = [PSCustomObject]@{
            Title = $activeTrain.MilestoneTitle
            Url   = $activeTrain.MilestoneUrl
        }
    } elseif ($version) {
        $milestonesJson = gh api "repos/$Repo/milestones" 2>$null
        $milestones     = if ($milestonesJson) { $milestonesJson | ConvertFrom-Json } else { @() }

        foreach ($ms in $milestones) {
            if ($ms.title -eq "v${version}") {
                $milestone = [PSCustomObject]@{
                    Title = $ms.title
                    Url   = $ms.html_url
                }
                break
            }
        }
    }

    # ── 6. BlockingIssues (im Milestone, OHNE Label 'phase:in-alpha') ────────
    $blockingIssues = @()
    if ($milestone -and $version) {
        $issuesJson = gh issue list --repo $Repo --milestone "v${version}" --state open `
            --json number,title,url,labels 2>$null
        $issues = if ($issuesJson) { $issuesJson | ConvertFrom-Json } else { @() }

        foreach ($issue in $issues) {
            $labelNames = $issue.labels | ForEach-Object { $_.name }
            if ($labelNames -notcontains 'phase:in-alpha') {
                $blockingIssues += [PSCustomObject]@{
                    Number = $issue.number
                    Title  = $issue.title
                    Url    = $issue.url
                }
            }
        }
    }

    # ── 7. Offene PRs ────────────────────────────────────────────────────────
    $openPRsJson = gh pr list --repo $Repo --state open --json number,title,url 2>$null
    $openPRsRaw  = if ($openPRsJson) { $openPRsJson | ConvertFrom-Json } else { @() }
    $openPRs = @($openPRsRaw | ForEach-Object {
        [PSCustomObject]@{
            Number = $_.number
            Title  = $_.title
            Url    = $_.url
        }
    })

    # ── 8. Result-Objekt ─────────────────────────────────────────────────────
    $result = [PSCustomObject]@{
        Phase           = $phase
        Version         = $version
        DevBranch       = $devBranch
        ReleaseBranch   = $releaseBranch
        LatestTag       = $latestTag
        AllowedBranches = $allowedBranches
        AllowedTarget   = $allowedTarget
        PushAllowed     = $pushAllowed
        Milestone       = $milestone
        BlockingIssues  = $blockingIssues
        OpenPRs         = $openPRs
    }

    # Tabellenausgabe (via Out-Host — kein Pipeline-Pollution)
    $result | Format-List | Out-Host

    if ($result.BlockingIssues.Count -gt 0) {
        Write-Warning "Blocking Issues ($($result.BlockingIssues.Count)):"
        foreach ($bi in $result.BlockingIssues) {
            Write-Warning "  #$($bi.Number) $($bi.Title)  $($bi.Url)"
        }
    }

    if ($result.OpenPRs.Count -gt 0) {
        Write-Information "Open PRs ($($result.OpenPRs.Count)):" -InformationAction Continue
        foreach ($pr in $result.OpenPRs) {
            Write-Information "  #$($pr.Number) $($pr.Title)  $($pr.Url)" -InformationAction Continue
        }
    }

    return $result
}

# ─── Entry Point: nur ausfuehren wenn nicht dot-sourced ─────────────────────
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-GetReleaseTrain @PSBoundParameters
}
