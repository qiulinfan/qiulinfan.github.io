[CmdletBinding()]
param(
    [string]$CodexHome,
    [string]$LinkedSkillRepositoriesFile,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$RelativeTo
    )

    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        if ([string]::IsNullOrWhiteSpace($RelativeTo)) {
            throw "Relative path has no base: $Path"
        }
        $Path = Join-Path $RelativeTo $Path
    }
    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)][System.IO.FileSystemInfo]$Item)
    return ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

function Get-DirectLinkTargets {
    param([Parameter(Mandatory = $true)][string]$Destination)

    $item = Get-Item -Force -LiteralPath $Destination
    if ($item.LinkType -in @('SymbolicLink', 'Junction')) {
        $rawTarget = @($item.Target) | Select-Object -First 1
        if (-not [string]::IsNullOrWhiteSpace([string]$rawTarget)) {
            return @(
                Resolve-NormalizedPath -Path ([string]$rawTarget) -RelativeTo (Split-Path -Parent $Destination)
            )
        }
    }
    elseif ($item.LinkType -eq 'HardLink') {
        $volumeRoot = [System.IO.Path]::GetPathRoot($Destination).TrimEnd('\')
        $rawTargets = @(& fsutil.exe hardlink list $Destination 2>$null)
        if ($LASTEXITCODE -eq 0) {
            return @(
                $rawTargets |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    ForEach-Object {
                        Resolve-NormalizedPath -Path ($volumeRoot + ([string]$_).Trim())
                    }
            )
        }
    }
    return @()
}

function New-DirectWorkingTreeLink {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][ValidateSet('Directory', 'File')][string]$Kind,
        [Parameter(Mandatory = $true)][string]$OwnedSourceRoot,
        [switch]$AllowUnknownLinkReplacement
    )

    $expected = Resolve-NormalizedPath -Path $Source
    $existing = Get-Item -Force -LiteralPath $Destination -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        $targets = @(Get-DirectLinkTargets -Destination $Destination)
        $owned = @($targets | Where-Object {
            $_.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0
        if ($owned) {
            Write-Host "OK      $Destination -> $expected"
            return
        }
        if ($targets.Count -eq 0 -and -not (Test-ReparsePoint -Item $existing)) {
            throw "Refusing to replace a real file or directory: $Destination"
        }
        $ownedPrefix = (Resolve-NormalizedPath -Path $OwnedSourceRoot) +
            [System.IO.Path]::DirectorySeparatorChar
        $ownedConflict = @($targets | Where-Object {
            $_.StartsWith($ownedPrefix, [System.StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0
        if (-not $ownedConflict -and -not $AllowUnknownLinkReplacement) {
            throw "Refusing to replace a link not owned by qlblog: $Destination"
        }
        if (-not $Force) {
            throw "Conflicting link exists: $Destination (use -Force to replace only this link)"
        }
        Remove-Item -LiteralPath $Destination
    }

    if ($Kind -eq 'Directory') {
        New-Item -ItemType Junction -Path $Destination -Target $expected | Out-Null
    }
    else {
        try {
            New-Item -ItemType SymbolicLink -Path $Destination -Target $expected -ErrorAction Stop | Out-Null
        }
        catch {
            try {
                New-Item -ItemType HardLink -Path $Destination -Target $expected -ErrorAction Stop | Out-Null
            }
            catch {
                throw "Could not link '$Destination'. Enable Windows Developer Mode or keep CODEX_HOME on the same volume. $($_.Exception.Message)"
            }
        }
    }
    Write-Host "LINKED  $Destination -> $expected"
}

$repositorySkills = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$globalAgentsSource = Join-Path $repositoryRoot 'install\codex\AGENTS.md'
if (-not (Test-Path -LiteralPath $globalAgentsSource -PathType Leaf)) {
    throw "Missing tracked global guidance: $globalAgentsSource"
}

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $CodexHome = $env:CODEX_HOME
}
if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $CodexHome = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
}
$resolvedCodexHome = Resolve-NormalizedPath -Path $CodexHome
$codexSkills = Join-Path $resolvedCodexHome 'skills'
$codexAgents = Join-Path $resolvedCodexHome 'AGENTS.md'
$linkedStateFile = Join-Path $resolvedCodexHome '.qlblog-linked-skill-targets'
$legacyPrivateStateFile = Join-Path $resolvedCodexHome '.qlblog-private-skill-targets'

if ([string]::IsNullOrWhiteSpace($LinkedSkillRepositoriesFile)) {
    $LinkedSkillRepositoriesFile = $env:QLBLOG_LINKED_SKILL_REPOSITORIES_FILE
}
$defaultLinkedSkillRepositoriesFile = Join-Path $repositorySkills 'linked-skill-repositories.tsv'
if ([string]::IsNullOrWhiteSpace($LinkedSkillRepositoriesFile)) {
    $LinkedSkillRepositoriesFile = $defaultLinkedSkillRepositoriesFile
}
else {
    $LinkedSkillRepositoriesFile = Resolve-NormalizedPath -Path $LinkedSkillRepositoriesFile -RelativeTo $repositoryRoot
}

[System.IO.Directory]::CreateDirectory($resolvedCodexHome) | Out-Null

$repositorySystem = Get-Item -Force -LiteralPath (Join-Path $repositorySkills '.system') -ErrorAction SilentlyContinue
if ($null -ne $repositorySystem) {
    throw "Codex-generated .system must not exist in this repository: $($repositorySystem.FullName)"
}

$existingSkillsRoot = Get-Item -Force -LiteralPath $codexSkills -ErrorAction SilentlyContinue
if ($null -ne $existingSkillsRoot -and (Test-ReparsePoint -Item $existingSkillsRoot)) {
    $targets = @(Get-DirectLinkTargets -Destination $codexSkills)
    $owned = @($targets | Where-Object {
        $_.Equals($repositorySkills, [System.StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
    if (-not $owned) {
        throw "Refusing to replace a Codex skills-root link not owned by this repository: $codexSkills"
    }
    Remove-Item -LiteralPath $codexSkills
    $existingSkillsRoot = $null
}
if ($null -ne $existingSkillsRoot -and -not $existingSkillsRoot.PSIsContainer) {
    throw "Codex skills path is not a directory: $codexSkills"
}
[System.IO.Directory]::CreateDirectory($codexSkills) | Out-Null

$allManifests = @(
    Get-ChildItem -LiteralPath $repositorySkills -Filter 'SKILL.md' -File -Recurse |
        Where-Object {
            $relativeDirectory = [System.IO.Path]::GetRelativePath(
                $repositorySkills,
                $_.Directory.FullName
            )
            -not (($relativeDirectory -split '[\\/]') | Where-Object { $_.StartsWith('.') })
        } |
        Sort-Object FullName
)

$linkedSkillRoots = @()
if (-not (Test-Path -LiteralPath $LinkedSkillRepositoriesFile -PathType Leaf)) {
    throw "Missing linked-only Skill repository registry: $LinkedSkillRepositoriesFile"
}
$linkedSkillRoots = @(
    Get-Content -LiteralPath $LinkedSkillRepositoriesFile |
        ForEach-Object { ([string]$_).TrimEnd("`r") } |
        Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') } |
        ForEach-Object {
            $fields = @($_ -split "`t")
            if ($fields.Count -ne 4 -or @($fields | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
                throw 'Invalid linked-only Skill registry row: expected four non-empty tab-separated fields'
            }
            $repositoryName, $cloneUrl, $checkoutPath, $skillRoot = $fields
            if ([System.IO.Path]::IsPathRooted($checkoutPath) -or $checkoutPath.StartsWith('~')) {
                throw "Linked-only Skill checkout must be relative to qlblog: $checkoutPath"
            }
            $checkoutRoot = Resolve-NormalizedPath -Path $checkoutPath -RelativeTo $repositoryRoot
            $resolvedRoot = Resolve-NormalizedPath -Path (Join-Path $checkoutRoot $skillRoot)
            if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
                throw "Linked-only Skill repository is not checked out: $repositoryName. Clone $cloneUrl into $checkoutRoot, then rerun this linker."
            }
                $repositoryPrefixForCheck = $repositorySkills + [System.IO.Path]::DirectorySeparatorChar
                if ($resolvedRoot.Equals($repositorySkills, [System.StringComparison]::OrdinalIgnoreCase) -or
                    $resolvedRoot.StartsWith($repositoryPrefixForCheck, [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw "Linked-only Skill root must be outside qlblog skills/: $resolvedRoot"
                }
                $resolvedRoot
        } |
        Sort-Object -Unique
)

# Runtime scope is declared by directory, not by name: Skills under
# skills\claude-only\ depend on Claude Code-only capabilities and stay linked
# into Claude Code only.
function Test-ClaudeOnlyManifest {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$Manifest)
    $relativeDirectory = [System.IO.Path]::GetRelativePath($repositorySkills, $Manifest.Directory.FullName)
    return ($relativeDirectory -split '[\\/]')[0] -eq 'claude-only'
}

$repositoryManifests = @($allManifests | Where-Object { -not (Test-ClaudeOnlyManifest -Manifest $_) })
$skippedManifests = @($allManifests | Where-Object { Test-ClaudeOnlyManifest -Manifest $_ })
$linkedSkillManifests = @(
    foreach ($linkedRoot in $linkedSkillRoots) {
        Get-ChildItem -LiteralPath $linkedRoot -Filter 'SKILL.md' -File -Recurse |
            Where-Object {
                $relativeDirectory = [System.IO.Path]::GetRelativePath($linkedRoot, $_.Directory.FullName)
                $segments = @($relativeDirectory -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })
                -not ($segments | Where-Object { $_.StartsWith('.') }) -and
                    ($segments.Count -eq 0 -or $segments[0] -ne 'claude-only')
            }
    }
)
$skillManifests = @($repositoryManifests + $linkedSkillManifests | Sort-Object FullName -Unique)

$duplicateDirectories = @($skillManifests | Group-Object { $_.Directory.Name } | Where-Object Count -gt 1)
if ($duplicateDirectories.Count -gt 0) {
    throw "Duplicate Skill directory names cannot be flattened: $($duplicateDirectories.Name -join ', ')"
}
$metadataNames = @($skillManifests | ForEach-Object {
    $match = Select-String -LiteralPath $_.FullName -Pattern '^name:\s*(.+)\s*$' | Select-Object -First 1
    if ($null -eq $match) {
        throw "Skill is missing frontmatter name: $($_.FullName)"
    }
    $match.Matches[0].Groups[1].Value.Trim()
})
$duplicateMetadata = @($metadataNames | Group-Object | Where-Object Count -gt 1)
if ($duplicateMetadata.Count -gt 0) {
    throw "Duplicate Skill names are ambiguous: $($duplicateMetadata.Name -join ', ')"
}

$repositoryPrefix = (Resolve-NormalizedPath -Path $repositorySkills) + [System.IO.Path]::DirectorySeparatorChar
Get-ChildItem -Force -LiteralPath $codexSkills | ForEach-Object {
    $targets = @(Get-DirectLinkTargets -Destination $_.FullName)
    $ownedTargets = @($targets | Where-Object {
        $_.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($ownedTargets.Count -gt 0) {
        $ownedRelative = [System.IO.Path]::GetRelativePath($repositorySkills, $ownedTargets[0])
        $ownedClaudeOnly = ($ownedRelative -split '[\\/]')[0] -eq 'claude-only'
        if ($ownedClaudeOnly -or
            -not (Test-Path -LiteralPath (Join-Path $ownedTargets[0] 'SKILL.md') -PathType Leaf)) {
            Remove-Item -LiteralPath $_.FullName
            Write-Host "REMOVED stale qlblog Skill link: $($_.FullName)"
        }
    }
}

$linkedTargets = @($linkedSkillManifests | ForEach-Object {
    Resolve-NormalizedPath -Path $_.Directory.FullName
})
if (-not (Test-Path -LiteralPath $linkedStateFile) -and (Test-Path -LiteralPath $legacyPrivateStateFile -PathType Leaf)) {
    Move-Item -LiteralPath $legacyPrivateStateFile -Destination $linkedStateFile
    Write-Host "MIGRATED legacy private Skill link state: $linkedStateFile"
}
if (Test-Path -LiteralPath $linkedStateFile -PathType Leaf) {
    foreach ($oldTarget in @(Get-Content -LiteralPath $linkedStateFile | Where-Object { $_ })) {
        $stillManaged = @($linkedTargets | Where-Object {
            $_.Equals($oldTarget, [System.StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0
        if ($stillManaged) { continue }
        $destination = Join-Path $codexSkills (Split-Path -Leaf $oldTarget)
        $existing = Get-Item -Force -LiteralPath $destination -ErrorAction SilentlyContinue
        if ($null -eq $existing -or -not (Test-ReparsePoint -Item $existing)) { continue }
        $targets = @(Get-DirectLinkTargets -Destination $destination)
        if (@($targets | Where-Object {
            $_.Equals($oldTarget, [System.StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0) {
            Remove-Item -LiteralPath $destination
            Write-Host "REMOVED stale registered linked-only Skill link: $destination"
        }
    }
}

foreach ($manifest in $skillManifests) {
    New-DirectWorkingTreeLink `
        -Source $manifest.Directory.FullName `
        -Destination (Join-Path $codexSkills $manifest.Directory.Name) `
        -Kind Directory `
        -OwnedSourceRoot $repositorySkills
}

Set-Content -LiteralPath $linkedStateFile -Value $linkedTargets -Encoding utf8

$existingGlobalAgents = Get-Item -Force -LiteralPath $codexAgents -ErrorAction SilentlyContinue
if ($null -ne $existingGlobalAgents -and
    -not (Test-ReparsePoint -Item $existingGlobalAgents) -and
    @((Get-DirectLinkTargets -Destination $codexAgents)).Count -eq 0) {
    if ($existingGlobalAgents.PSIsContainer -or
        (Get-FileHash -LiteralPath $codexAgents).Hash -ne
            (Get-FileHash -LiteralPath $globalAgentsSource).Hash) {
        throw "Existing global guidance differs: $codexAgents"
    }
    $backupRoot = Join-Path $resolvedCodexHome 'skill-layout-backups'
    [System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDirectory = Join-Path $backupRoot $stamp
    [System.IO.Directory]::CreateDirectory($backupDirectory) | Out-Null
    Move-Item -LiteralPath $codexAgents -Destination (Join-Path $backupDirectory 'AGENTS.md-before-link')
}
New-DirectWorkingTreeLink `
    -Source $globalAgentsSource `
    -Destination $codexAgents `
    -Kind File `
    -OwnedSourceRoot $repositoryRoot `
    -AllowUnknownLinkReplacement

if ($skippedManifests.Count -gt 0) {
    Write-Host "SKIPPED $($skippedManifests.Count) Claude Code-only Skill(s), linked into Claude Code only:"
    foreach ($manifest in $skippedManifests) {
        Write-Host "  $([System.IO.Path]::GetRelativePath($repositorySkills, $manifest.Directory.FullName))"
    }
}
Write-Host "QLBLOG_LINKS_OK ($($repositoryManifests.Count) qlblog Skills + $($linkedSkillManifests.Count) registered linked-only Skills; Codex .system and unrelated external links preserved)"
