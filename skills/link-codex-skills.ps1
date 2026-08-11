[CmdletBinding()]
param(
    [string]$CodexHome,
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

$skillManifests = @(
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
    if ($ownedTargets.Count -gt 0 -and
        -not (Test-Path -LiteralPath (Join-Path $ownedTargets[0] 'SKILL.md') -PathType Leaf)) {
        Remove-Item -LiteralPath $_.FullName
        Write-Host "REMOVED stale qlblog Skill link: $($_.FullName)"
    }
}

foreach ($manifest in $skillManifests) {
    New-DirectWorkingTreeLink `
        -Source $manifest.Directory.FullName `
        -Destination (Join-Path $codexSkills $manifest.Directory.Name) `
        -Kind Directory `
        -OwnedSourceRoot $repositorySkills
}

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

Write-Host "QLBLOG_LINKS_OK ($($skillManifests.Count) Skills; Codex .system and external product links preserved)"
