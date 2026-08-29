[CmdletBinding()]
param(
    [string]$ClaudeHome,
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
                throw "Could not link '$Destination'. Enable Windows Developer Mode or keep CLAUDE_CONFIG_DIR on the same volume. $($_.Exception.Message)"
            }
        }
    }
    Write-Host "LINKED  $Destination -> $expected"
}

$repositorySkills = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$globalGuidanceSource = Join-Path $repositoryRoot 'install\claude\CLAUDE.md'
if (-not (Test-Path -LiteralPath $globalGuidanceSource -PathType Leaf)) {
    throw "Missing tracked global guidance: $globalGuidanceSource (run install/agents/build-guidance.sh first)"
}

if ([string]::IsNullOrWhiteSpace($ClaudeHome)) {
    $ClaudeHome = $env:CLAUDE_CONFIG_DIR
}
if ([string]::IsNullOrWhiteSpace($ClaudeHome)) {
    $ClaudeHome = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude'
}
$resolvedClaudeHome = Resolve-NormalizedPath -Path $ClaudeHome
$claudeSkills = Join-Path $resolvedClaudeHome 'skills'
$claudeGuidance = Join-Path $resolvedClaudeHome 'CLAUDE.md'
$linkedStateFile = Join-Path $resolvedClaudeHome '.qlblog-linked-skill-targets'
$legacyPrivateStateFile = Join-Path $resolvedClaudeHome '.qlblog-private-skill-targets'

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

[System.IO.Directory]::CreateDirectory($resolvedClaudeHome) | Out-Null

$repositorySystem = Get-Item -Force -LiteralPath (Join-Path $repositorySkills '.system') -ErrorAction SilentlyContinue
if ($null -ne $repositorySystem) {
    throw "Generated .system must not exist in this repository: $($repositorySystem.FullName)"
}

$existingSkillsRoot = Get-Item -Force -LiteralPath $claudeSkills -ErrorAction SilentlyContinue
if ($null -ne $existingSkillsRoot -and (Test-ReparsePoint -Item $existingSkillsRoot)) {
    $targets = @(Get-DirectLinkTargets -Destination $claudeSkills)
    $owned = @($targets | Where-Object {
        $_.Equals($repositorySkills, [System.StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
    if (-not $owned) {
        throw "Refusing to replace a Claude Code skills-root link not owned by this repository: $claudeSkills"
    }
    Remove-Item -LiteralPath $claudeSkills
    $existingSkillsRoot = $null
}
if ($null -ne $existingSkillsRoot -and -not $existingSkillsRoot.PSIsContainer) {
    throw "Claude Code skills path is not a directory: $claudeSkills"
}
[System.IO.Directory]::CreateDirectory($claudeSkills) | Out-Null

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
# skills\codex-only\ depend on Codex-only capabilities (Codex-native subagents
# or Codex-selected external runtimes) and stay linked into Codex only.
function Test-CodexOnlyManifest {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$Manifest)
    $relativeDirectory = [System.IO.Path]::GetRelativePath($repositorySkills, $Manifest.Directory.FullName)
    return ($relativeDirectory -split '[\\/]')[0] -eq 'codex-only'
}

$repositoryManifests = @($allManifests | Where-Object { -not (Test-CodexOnlyManifest -Manifest $_) })
$skippedManifests = @($allManifests | Where-Object { Test-CodexOnlyManifest -Manifest $_ })
$linkedSkillManifests = @(
    foreach ($linkedRoot in $linkedSkillRoots) {
        Get-ChildItem -LiteralPath $linkedRoot -Filter 'SKILL.md' -File -Recurse |
            Where-Object {
                $relativeDirectory = [System.IO.Path]::GetRelativePath($linkedRoot, $_.Directory.FullName)
                $segments = @($relativeDirectory -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })
                -not ($segments | Where-Object { $_.StartsWith('.') }) -and
                    ($segments.Count -eq 0 -or $segments[0] -ne 'codex-only')
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

$eligibleTargets = @($skillManifests | ForEach-Object {
    Resolve-NormalizedPath -Path $_.Directory.FullName
})

# Drops links this repository owns that are stale, newly excluded by the
# codex-only filter, or renamed. Links owned by independent product checkouts
# and anything that is not a link are left untouched.
$repositoryPrefix = (Resolve-NormalizedPath -Path $repositorySkills) + [System.IO.Path]::DirectorySeparatorChar
Get-ChildItem -Force -LiteralPath $claudeSkills | ForEach-Object {
    $entry = $_
    $targets = @(Get-DirectLinkTargets -Destination $entry.FullName)
    $ownedTargets = @($targets | Where-Object {
        $_.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($ownedTargets.Count -eq 0) {
        return
    }
    $target = $ownedTargets[0]
    $stillLinked = (
        (Test-Path -LiteralPath (Join-Path $target 'SKILL.md') -PathType Leaf) -and
        ((Split-Path -Leaf $target) -eq $entry.Name) -and
        (@($eligibleTargets | Where-Object {
            $_.Equals($target, [System.StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0)
    )
    if (-not $stillLinked) {
        Remove-Item -LiteralPath $entry.FullName
        Write-Host "REMOVED qlblog Skill link that is no longer linked here: $($entry.FullName)"
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
        $destination = Join-Path $claudeSkills (Split-Path -Leaf $oldTarget)
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
        -Destination (Join-Path $claudeSkills $manifest.Directory.Name) `
        -Kind Directory `
        -OwnedSourceRoot $repositorySkills
}

Set-Content -LiteralPath $linkedStateFile -Value $linkedTargets -Encoding utf8

$existingGlobalGuidance = Get-Item -Force -LiteralPath $claudeGuidance -ErrorAction SilentlyContinue
if ($null -ne $existingGlobalGuidance -and
    -not (Test-ReparsePoint -Item $existingGlobalGuidance) -and
    @((Get-DirectLinkTargets -Destination $claudeGuidance)).Count -eq 0) {
    if ($existingGlobalGuidance.PSIsContainer -or
        (Get-FileHash -LiteralPath $claudeGuidance).Hash -ne
            (Get-FileHash -LiteralPath $globalGuidanceSource).Hash) {
        throw "Existing global guidance differs: $claudeGuidance"
    }
    $backupRoot = Join-Path $resolvedClaudeHome 'skill-layout-backups'
    [System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDirectory = Join-Path $backupRoot $stamp
    [System.IO.Directory]::CreateDirectory($backupDirectory) | Out-Null
    Move-Item -LiteralPath $claudeGuidance -Destination (Join-Path $backupDirectory 'CLAUDE.md-before-link')
}
New-DirectWorkingTreeLink `
    -Source $globalGuidanceSource `
    -Destination $claudeGuidance `
    -Kind File `
    -OwnedSourceRoot $repositoryRoot `
    -AllowUnknownLinkReplacement

if ($skippedManifests.Count -gt 0) {
    Write-Host "SKIPPED $($skippedManifests.Count) Codex-only Skill(s), still linked into Codex:"
    foreach ($manifest in $skippedManifests) {
        Write-Host "  $([System.IO.Path]::GetRelativePath($repositorySkills, $manifest.Directory.FullName))"
    }
}

Write-Host "QLBLOG_CLAUDE_LINKS_OK ($($repositoryManifests.Count) qlblog Skills + $($linkedSkillManifests.Count) registered linked-only Skills; unrelated external links preserved)"
