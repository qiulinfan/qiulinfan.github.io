---
name: record-windows-playtest
description: Record a bounded Windows Unity playtest as a validated MP4, generate a source-traceable test receipt, and publish both through Google Drive for Desktop. Use after a player-facing build, scene, feature, or fix is ready for independent play evidence; do not use to implement or repair the game.
---

# Record Windows Playtest

Produce reviewable video evidence for an independent Unity playtest on Windows. Pair this Skill with `play-unity-game`: that Skill defines what to test; this Skill records the target window, validates the artifact, and publishes it.

## Boundaries

- Run only on Windows.
- Test an explicit issue, revision, build or scene, and acceptance contract.
- Prefer a standalone Windows player window. Capture the Unity Editor window only when no representative player build exists, and disclose that fallback.
- Record only the named game or Unity window. Never capture the whole desktop, credentials, private messages, notifications, webcam, or microphone.
- Record video without microphone audio. Do not silently add system-wide audio drivers or persistent recording software.
- Do not edit scripts, scenes, prefabs, assets, packages, settings, or design documents. Report defects to the owning agent.
- A local MP4 is not a Drive delivery. Distinguish `VALIDATED_LOCAL`, `SUBMITTED_TO_DRIVEFS`, and any independently confirmed remote state.

## Required Inputs

Before recording, obtain or derive:

- issue ID and test objective;
- exact repository or build path and target revision;
- scene, build, or launch instructions;
- observable acceptance cases, including reset or recovery when stateful;
- exact capture window title;
- planned recording duration;
- Google Drive for Desktop destination, defaulting to `G:\My Drive\Dreamweaver Playtests`.

If the issue does not identify a playable target or acceptance contract, return `BLOCKED` instead of inventing one.

## Workflow

### 1. Establish a clean test target

Use `play-unity-game` to inspect project guidance, choose the closest player-like input path, clear stale diagnostics, and confirm that the target is ready to play. Record the exact revision. Do not accept the implementer's prose as evidence.

For player-visible stateful work, plan at least:

1. intended path;
2. one invalid or boundary action;
3. recovery from that action;
4. reset or reload;
5. a second complete intended path after reset.

### 2. Preflight the Windows recorder

Confirm all of the following:

```powershell
Get-Command ffmpeg, ffprobe -ErrorAction SilentlyContinue
Get-Process GoogleDriveFS -ErrorAction SilentlyContinue
Test-Path -LiteralPath 'G:\My Drive\Dreamweaver Playtests'
Get-Process | Where-Object { $_.MainWindowTitle -eq '<exact window title>' } |
  Select-Object Id, ProcessName, MainWindowTitle
```

Do not print unrelated window titles. If `ffmpeg` is not on `PATH`, the bundled script also searches the standard WinGet FFmpeg package directory under `%LOCALAPPDATA%`.

### 3. Start a bounded capture

Keep staging outside the game repository when possible. The script starts FFmpeg in a hidden background process and stops automatically at the requested duration:

```powershell
$start = & '<skill-dir>\scripts\Invoke-WindowsPlaytestCapture.ps1' `
  -Action Start `
  -WindowTitle '<exact window title>' `
  -OutputDirectory '<absolute staging directory>' `
  -BaseName '<issue-id>-playtest' `
  -DurationSeconds 180 `
  -Framerate 30 | ConvertFrom-Json
```

Retain `$start.state_path`. Never broaden capture from an unresolved window title to the desktop.

### 4. Play the acceptance cases

Immediately execute the planned cases with player-like input. Keep the target visible and unminimized. Narration is optional and is not captured by this workflow; make state changes readable through the game UI and the written receipt.

If a crash, hang, or blocker occurs, preserve the recording and finish it with verdict `FAIL` or `BLOCKED`. Do not repair the defect.

### 5. Validate and publish

After FFmpeg reaches its bounded duration, finalize the evidence:

```powershell
$result = & '<skill-dir>\scripts\Invoke-WindowsPlaytestCapture.ps1' `
  -Action Complete `
  -StatePath $start.state_path `
  -IssueId '<issue-id>' `
  -Revision '<commit, changelist, or build identifier>' `
  -Verdict PASS `
  -Summary '<short evidence-based result>' `
  -DriveRoot 'G:\My Drive\Dreamweaver Playtests' `
  -DriveFolderUrl 'https://drive.google.com/drive/folders/1u2owlWVnaR-969vBL1vw8M_9j0-X4mTO' |
  ConvertFrom-Json
```

The completion action waits for recording to finish, validates a readable video stream with `ffprobe`, computes SHA-256, verifies the copied bytes, and writes a JSON receipt beside the MP4. It never overwrites a prior run.

Use `-SkipPublish` only for diagnostics. A skipped or unavailable Drive delivery must not be described as uploaded.

### 6. Return the handoff

Report:

- verdict: `PASS`, `FAIL`, or `BLOCKED`;
- issue, target revision, tested scene or build, and input path;
- acceptance cases attempted and observed results;
- capture mode: standalone player or Unity Editor fallback;
- MP4 filename, duration, resolution, and SHA-256;
- receipt filename;
- Drive folder URL and relative path;
- delivery state exactly as returned by the script;
- defects with reproduction steps and owner routing.

`SUBMITTED_TO_DRIVEFS` means the verified files were committed to the mounted Drive for Desktop directory while `GoogleDriveFS` was running. Claim remote visibility only when a Drive API, connector, or browser check independently observes the uploaded file.

## Failure Rules

- Missing or ambiguous target window: stop before recording.
- Recorder exits early, MP4 is unreadable, or video stream is missing: evidence is invalid; retry once after diagnosing the recorder only.
- Game defect: preserve evidence, report it, and hand off; do not fix it.
- Drive mount or process unavailable: keep the validated local files, return `VALIDATED_LOCAL`, and report the exact delivery blocker.
- Hash mismatch after copy: remove only the incomplete run directory created by the current invocation, retain local evidence, and return failure.
- Never mark the production issue accepted merely because a video exists; the observed behavior must satisfy the acceptance contract.

## Language Alignment

Match user-facing explanations, prompts, receipts, and handoffs to the user's language unless they request another language. Preserve commands, identifiers, structured keys and action codes, hashes, paths, and raw errors unchanged.

## Script

`scripts/Invoke-WindowsPlaytestCapture.ps1` provides the bounded `Start` and validated `Complete` actions. Run it directly rather than reimplementing FFmpeg argument handling or Drive publication in ad hoc shell commands.
