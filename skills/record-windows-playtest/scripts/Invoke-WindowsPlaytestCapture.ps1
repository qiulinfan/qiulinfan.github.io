[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Start', 'Complete')]
    [string]$Action,

    [string]$WindowTitle,
    [string]$OutputDirectory,
    [string]$BaseName = 'playtest',

    [ValidateRange(10, 1800)]
    [int]$DurationSeconds = 180,

    [ValidateRange(15, 60)]
    [int]$Framerate = 30,

    [string]$StatePath,
    [string]$IssueId,
    [string]$Revision,

    [ValidateSet('PASS', 'FAIL', 'BLOCKED')]
    [string]$Verdict,

    [string]$Summary,
    [string]$DriveRoot = 'G:\My Drive\Dreamweaver Playtests',
    [string]$DriveFolderUrl = 'https://drive.google.com/drive/folders/1u2owlWVnaR-969vBL1vw8M_9j0-X4mTO',
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

function Resolve-MediaTool {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    $wingetRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $wingetRoot) {
        $candidate = Get-ChildItem -LiteralPath $wingetRoot -Recurse -Filter "$Name.exe" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like '*Gyan.FFmpeg*' } |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }

    throw "$Name was not found on PATH or in the standard WinGet FFmpeg package directory."
}

function ConvertTo-SafeName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $safe = $Value -replace '[^A-Za-z0-9._-]', '_'
    $safe = $safe.Trim(' ', '.', '_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        throw "The value '$Value' cannot be converted to a safe file name."
    }
    return $safe
}

function Write-JsonResult {
    param([Parameter(Mandatory = $true)]$Value)
    $Value | ConvertTo-Json -Depth 12 -Compress
}

if ($Action -eq 'Start') {
    if ([string]::IsNullOrWhiteSpace($WindowTitle)) {
        throw 'WindowTitle is required for Action=Start.'
    }
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        throw 'OutputDirectory is required for Action=Start.'
    }

    $matches = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq $WindowTitle })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one visible window with title '$WindowTitle'; found $($matches.Count)."
    }

    $ffmpeg = Resolve-MediaTool -Name 'ffmpeg'
    $safeBaseName = ConvertTo-SafeName -Value $BaseName
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
    [System.IO.Directory]::CreateDirectory($resolvedOutputDirectory) | Out-Null

    $runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $videoPath = Join-Path $resolvedOutputDirectory "$safeBaseName-$runId.mp4"
    $captureStatePath = Join-Path $resolvedOutputDirectory "$safeBaseName-$runId.capture.json"
    if ((Test-Path -LiteralPath $videoPath) -or (Test-Path -LiteralPath $captureStatePath)) {
        throw "Refusing to overwrite an existing capture for run '$runId'."
    }

    $arguments = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-nostdin',
        '-n',
        '-f', 'gdigrab',
        '-draw_mouse', '0',
        '-framerate', $Framerate.ToString([Globalization.CultureInfo]::InvariantCulture),
        '-i', "title=$WindowTitle",
        '-t', $DurationSeconds.ToString([Globalization.CultureInfo]::InvariantCulture),
        '-an',
        '-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2',
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-crf', '23',
        '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart',
        $videoPath
    )

    $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = $ffmpeg
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    foreach ($argument in $arguments) {
        [void]$processInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::Start($processInfo)
    Start-Sleep -Milliseconds 750
    if ($process.HasExited) {
        throw "ffmpeg exited before recording began (exit code $($process.ExitCode))."
    }

    $startedUtc = [DateTime]::UtcNow
    $state = [ordered]@{
        schema_version   = 1
        status           = 'RECORDING'
        ffmpeg_pid       = $process.Id
        ffmpeg_path      = $ffmpeg
        source_process   = $matches[0].ProcessName
        source_window    = $WindowTitle
        video_path       = $videoPath
        state_path       = $captureStatePath
        started_utc      = $startedUtc.ToString('o')
        expected_end_utc = $startedUtc.AddSeconds($DurationSeconds).ToString('o')
        duration_seconds = $DurationSeconds
        framerate        = $Framerate
    }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $captureStatePath -Encoding utf8NoBOM
    Write-JsonResult -Value $state
    exit 0
}

if ([string]::IsNullOrWhiteSpace($StatePath)) {
    throw 'StatePath is required for Action=Complete.'
}
if ([string]::IsNullOrWhiteSpace($IssueId)) {
    throw 'IssueId is required for Action=Complete.'
}
if ([string]::IsNullOrWhiteSpace($Revision)) {
    throw 'Revision is required for Action=Complete.'
}
if ([string]::IsNullOrWhiteSpace($Verdict)) {
    throw 'Verdict is required for Action=Complete.'
}
if ([string]::IsNullOrWhiteSpace($Summary)) {
    throw 'Summary is required for Action=Complete.'
}
if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    throw "Capture state file does not exist: $StatePath"
}

$state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
if ($state.schema_version -ne 1 -or $state.status -ne 'RECORDING') {
    throw "Unsupported or already completed capture state: $StatePath"
}

$process = Get-Process -Id ([int]$state.ffmpeg_pid) -ErrorAction SilentlyContinue
if ($process) {
    $expectedEnd = [DateTimeOffset]$state.expected_end_utc
    $remaining = [Math]::Max(0, [Math]::Ceiling(($expectedEnd - [DateTimeOffset]::UtcNow).TotalSeconds))
    $waitMilliseconds = [int](($remaining + 90) * 1000)
    if (-not $process.WaitForExit($waitMilliseconds)) {
        throw "ffmpeg did not finish within the bounded wait for PID $($state.ffmpeg_pid)."
    }
    $process.Refresh()
    $exitCode = $process.ExitCode
    if (($null -ne $exitCode) -and ($exitCode -ne 0)) {
        throw "ffmpeg exited with code $exitCode."
    }
}

$videoPath = [System.IO.Path]::GetFullPath([string]$state.video_path)
if (-not (Test-Path -LiteralPath $videoPath -PathType Leaf)) {
    throw "Recorded video does not exist: $videoPath"
}
$videoFile = Get-Item -LiteralPath $videoPath
if ($videoFile.Length -le 0) {
    throw "Recorded video is empty: $videoPath"
}

$ffprobe = Resolve-MediaTool -Name 'ffprobe'
$probeText = & $ffprobe -v error -show_streams -show_format -of json -- $videoPath
if ($LASTEXITCODE -ne 0) {
    throw "ffprobe could not read the recorded video (exit code $LASTEXITCODE)."
}
$probe = $probeText | ConvertFrom-Json
$videoStream = @($probe.streams | Where-Object { $_.codec_type -eq 'video' }) | Select-Object -First 1
if (-not $videoStream) {
    throw 'The recorded artifact contains no readable video stream.'
}
$duration = [double]::Parse([string]$probe.format.duration, [Globalization.CultureInfo]::InvariantCulture)
if ($duration -lt 3.0) {
    throw "The recorded artifact is too short to be valid evidence ($duration seconds)."
}

$sourceHash = (Get-FileHash -LiteralPath $videoPath -Algorithm SHA256).Hash.ToLowerInvariant()
$safeIssueId = ConvertTo-SafeName -Value $IssueId
$runId = ([DateTimeOffset]$state.started_utc).UtcDateTime.ToString('yyyyMMddTHHmmssZ')
$finalVideoName = "$safeIssueId-$runId.mp4"
$receiptName = "$safeIssueId-$runId.receipt.json"
$relativeDirectory = Join-Path $safeIssueId $runId
$localReceiptPath = Join-Path ([System.IO.Path]::GetDirectoryName($videoPath)) $receiptName

$delivery = [ordered]@{
    state         = 'VALIDATED_LOCAL'
    submitted_utc = $null
    base_url      = $DriveFolderUrl
    relative_path = $null
    drivefs_path  = $null
}

$destinationVideoPath = $null
$destinationReceiptPath = $null
if (-not $SkipPublish) {
    if (-not (Get-Process GoogleDriveFS -ErrorAction SilentlyContinue)) {
        throw 'GoogleDriveFS is not running; the local video remains validated but was not published.'
    }
    if (-not (Test-Path -LiteralPath $DriveRoot -PathType Container)) {
        throw "Google Drive for Desktop destination is unavailable: $DriveRoot"
    }

    $resolvedDriveRoot = [System.IO.Path]::GetFullPath($DriveRoot)
    $destinationDirectory = Join-Path $resolvedDriveRoot $relativeDirectory
    if (Test-Path -LiteralPath $destinationDirectory) {
        throw "Refusing to overwrite an existing Drive run directory: $destinationDirectory"
    }
    [System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null

    $destinationVideoPath = Join-Path $destinationDirectory $finalVideoName
    Copy-Item -LiteralPath $videoPath -Destination $destinationVideoPath
    $destinationHash = (Get-FileHash -LiteralPath $destinationVideoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($destinationHash -ne $sourceHash) {
        throw "Drive copy hash mismatch for $destinationVideoPath"
    }

    $delivery.state = 'SUBMITTED_TO_DRIVEFS'
    $delivery.submitted_utc = [DateTime]::UtcNow.ToString('o')
    $delivery.relative_path = (Join-Path $relativeDirectory $finalVideoName)
    $delivery.drivefs_path = $destinationVideoPath
}

$receipt = [ordered]@{
    schema_version = 1
    issue_id       = $IssueId
    revision       = $Revision
    verdict        = $Verdict
    summary        = $Summary
    capture        = [ordered]@{
        mode             = 'WINDOW_VIDEO_ONLY'
        source_process   = $state.source_process
        source_window    = $state.source_window
        started_utc      = $state.started_utc
        duration_seconds = [Math]::Round($duration, 3)
        width            = [int]$videoStream.width
        height           = [int]$videoStream.height
        codec            = [string]$videoStream.codec_name
        pixel_format     = [string]$videoStream.pix_fmt
        framerate        = [string]$videoStream.avg_frame_rate
        bytes            = $videoFile.Length
        sha256           = $sourceHash
        local_path       = $videoPath
    }
    delivery       = $delivery
    completed_utc  = [DateTime]::UtcNow.ToString('o')
}
$receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $localReceiptPath -Encoding utf8NoBOM

if (-not $SkipPublish) {
    $destinationReceiptPath = Join-Path ([System.IO.Path]::GetDirectoryName($destinationVideoPath)) $receiptName
    Copy-Item -LiteralPath $localReceiptPath -Destination $destinationReceiptPath
}

$state.status = 'COMPLETED'
$state | Add-Member -NotePropertyName completed_utc -NotePropertyValue $receipt.completed_utc -Force
$state | Add-Member -NotePropertyName receipt_path -NotePropertyValue $localReceiptPath -Force
$state | Add-Member -NotePropertyName delivery_state -NotePropertyValue $delivery.state -Force
$state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding utf8NoBOM

Write-JsonResult -Value ([ordered]@{
    status                = 'COMPLETED'
    verdict               = $Verdict
    delivery_state        = $delivery.state
    video_path            = $videoPath
    receipt_path          = $localReceiptPath
    sha256                = $sourceHash
    duration_seconds      = [Math]::Round($duration, 3)
    width                 = [int]$videoStream.width
    height                = [int]$videoStream.height
    drive_folder_url      = $DriveFolderUrl
    drive_relative_path   = $delivery.relative_path
    drive_video_path      = $destinationVideoPath
    drive_receipt_path    = $destinationReceiptPath
})
