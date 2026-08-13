# Local LaTeX Environment Fallback

Use this runbook only when the user explicitly requests a standalone `.tex`
project or a locally compiled PDF. The normal qlblog notes and web workflow
remains Typst-first. Do not run this setup merely because a note contains
LaTeX source.

This fallback is local-only. Never add or restore MkDocs, `gh-deploy`, a PDF
iframe, a PDF Pages pipeline, or committed build artifacts.

## Contents

- [Re-check official sources](#re-check-official-sources)
- [Safety contract](#safety-contract)
- [Read-only preflight](#read-only-preflight)
- [Choose one installation owner](#choose-one-installation-owner)
- [Install by environment](#install-by-environment)
- [Verify the distribution](#verify-the-distribution)
- [Configure VS Code](#configure-vs-code)
- [Run the smoke test](#run-the-smoke-test)
- [Maintain and troubleshoot](#maintain-and-troubleshoot)
- [Return a completion receipt](#return-a-completion-receipt)

## Re-check official sources

Open the relevant official pages immediately before executing an installer or
package-manager command. Verify the current download, supported operating
systems, package names, prerequisites, installation size, update policy, and
checksums or signatures where supplied. Installer details change; this file is
not authority for a current binary.

- TeX Live: [home](https://tug.org/texlive/),
  [network installer](https://tug.org/texlive/acquire-netinstall.html),
  [quick install](https://tug.org/texlive/quickinstall.html), and
  [`tlmgr`](https://tug.org/texlive/tlmgr.html)
- macOS: [MacTeX](https://tug.org/mactex/)
- Native Windows: [TeX Live on Windows](https://tug.org/texlive/windows.html)
- Distribution packages:
  [Debian `texlive-full`](https://packages.debian.org/stable/tex/texlive-full),
  [Ubuntu `texlive-full`](https://packages.ubuntu.com/search?keywords=texlive-full),
  [Fedora `texlive-scheme-full`](https://packages.fedoraproject.org/pkgs/texlive/texlive-scheme-full/),
  and [Fedora `latexmk`](https://packages.fedoraproject.org/pkgs/latexmk/latexmk/)
- VS Code: [extension management](https://code.visualstudio.com/docs/configure/extensions/extension-marketplace)
  and [WSL development](https://code.visualstudio.com/docs/remote/wsl)
- LaTeX Workshop: [official repository](https://github.com/James-Yu/LaTeX-Workshop),
  [compile configuration](https://github.com/James-Yu/LaTeX-Workshop/wiki/Compile),
  and [Marketplace entry](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop)
- Ultra Math Preview:
  [Marketplace entry](https://marketplace.visualstudio.com/items?itemName=yfzhao.ultra-math-preview)

Record which pages were checked and the check date in the completion receipt.

## Safety contract

Follow this contract before changing the machine or a project:

1. Run only the read-only preflight first. Detect native Windows versus WSL;
   do not infer one from the other.
2. Report the observed OS, architecture, shell, command paths and versions,
   existing TeX distributions, installation owner, available disk space, and
   only the existence and metadata of project-level VS Code and `latexmk`
   configuration. Never print an original configuration file during preflight.
3. Review configuration values only through the sanitized-review procedure
   below. Never send raw settings, comments, command arguments, environment
   blocks, URLs, tokens, API keys, secrets, passwords, cookies, or authorization
   headers into tool output. If a safe excerpt is unavailable, report that fact
   and stop before proposing a merge.
4. Report the exact proposed installer, scope, packages, expected current
   download/installed size, PATH changes, configuration changes, and commands.
5. Obtain explicit confirmation before installing a full TeX scheme. Full
   MacTeX and full TeX Live are multi-gigabyte installations; never hide that
   cost or rely on an old hard-coded size.
6. Treat a MacTeX installation and a change of the active TeX distribution as
   two separate approvals. Before running the MacTeX installer, disclose that
   the official package makes a newly installed release active through the TeX
   Distribution data structure behind `/Library/TeX/texbin`, report the current
   selection, and obtain explicit permission for that switch. Without switch
   permission, do not run the installer; only report and stop.
7. Preserve existing releases and independently installed distributions. Do
   not uninstall one, delete its tree, or switch the machine-wide default
   without separate confirmation.
8. Let exactly one owner update a given distribution. Do not mix `apt`, `dnf`,
   Homebrew, a TUG installer, MacTeX, or an unrelated `tlmgr` against the same
   installation.
9. Never overwrite `.vscode/settings.json`, `.vscode/extensions.json`, a
   workspace file, `latexmkrc`, or any other existing project configuration.
   Inspect it and propose a key-by-key merge.
10. Do not enable `-shell-escape` unless the user explicitly needs it and the
   document and invoked programs are trusted. Compile untrusted documents in a
   disposable, constrained workspace.
11. Keep generated PDF, SyncTeX, logs, and auxiliary files in an ignored build
   directory or an OS temporary directory. Do not commit them.
12. Match explanations, prompts, confirmation requests, and handoffs to the
    user's language unless the user requests another language. Keep commands,
    identifiers, structured keys, and raw errors unchanged.

Stop after the report if ownership is ambiguous, the requested environment is
ambiguous, the full-install confirmation is absent, MacTeX activation-switch
permission is absent, or an existing configuration cannot be reviewed and
merged safely.

## Read-only preflight

### macOS, Linux, or WSL

Run from the target environment, not from a different host shell:

```sh
uname -a
test -r /etc/os-release && sed -n '1,20p' /etc/os-release
test -r /proc/version && sed -n '1p' /proc/version
command -v lualatex latexmk kpsewhich tlmgr code || true
lualatex --version 2>/dev/null | sed -n '1p'
latexmk -v 2>/dev/null | sed -n '1,2p'
kpsewhich --version 2>/dev/null | sed -n '1p'
kpsewhich -var-value=TEXMFROOT 2>/dev/null
kpsewhich -var-value=TEXMFHOME 2>/dev/null
tlmgr info scheme-full 2>/dev/null | sed -n '1,20p'
test -d /usr/local/texlive && find /usr/local/texlive \
  -mindepth 1 -maxdepth 1 -type d -print
df -h .
```

On macOS, also record the active-distribution links without changing them:

```sh
for tex_link in /Library/TeX/texbin /Library/TeX/Root \
  /Library/TeX/Distributions/.DefaultTeX; do
  if [ -L "$tex_link" ]; then
    printf '%s -> ' "$tex_link"
    readlink "$tex_link"
  elif [ -e "$tex_link" ]; then
    printf '%s: exists but is not a symbolic link\n' "$tex_link"
  else
    printf '%s: absent\n' "$tex_link"
  fi
done
```

On Debian or Ubuntu, also inspect package ownership:

```sh
dpkg-query -W -f='${Package}: ${Status}\n' texlive-full latexmk 2>/dev/null || true
apt-cache policy texlive-full latexmk
```

On Fedora, use:

```sh
rpm -q texlive-scheme-full latexmk || true
dnf --cacheonly info texlive-scheme-full latexmk || true
```

Inspect only the existence, type, readability, and byte count of target-project
configuration. Do not use `cat`, `sed`, `head`, `tail`, `rg`, or a non-quiet
`grep` on the original files:

```sh
for config_path in .vscode/settings.json .vscode/extensions.json \
  .latexmkrc latexmkrc; do
  if [ -L "$config_path" ]; then
    printf '%s: symbolic link; target withheld pending ownership review\n' \
      "$config_path"
  elif [ -f "$config_path" ]; then
    config_bytes=$(wc -c < "$config_path" | tr -d '[:space:]')
    if [ -r "$config_path" ]; then config_readable=yes; else config_readable=no; fi
    printf '%s: regular file; bytes=%s; readable=%s\n' \
      "$config_path" "$config_bytes" "$config_readable"
  elif [ -e "$config_path" ]; then
    printf '%s: exists but is not a regular file\n' "$config_path"
  else
    printf '%s: absent\n' "$config_path"
  fi
done
```

### Native Windows PowerShell

Run in PowerShell, not inside WSL:

```powershell
Get-ComputerInfo | Select-Object OsName,OsVersion,OsArchitecture
Get-Command lualatex,latexmk,kpsewhich,tlmgr,code -All -ErrorAction SilentlyContinue
where.exe lualatex 2>$null
where.exe latexmk 2>$null
where.exe kpsewhich 2>$null
lualatex --version 2>$null | Select-Object -First 1
latexmk -v 2>$null | Select-Object -First 2
kpsewhich --version 2>$null | Select-Object -First 1
kpsewhich -var-value=TEXMFROOT 2>$null
kpsewhich -var-value=TEXMFHOME 2>$null
tlmgr info scheme-full 2>$null | Select-Object -First 20
wsl.exe --status
Get-PSDrive -PSProvider FileSystem
$configPaths = @(
  '.vscode/settings.json',
  '.vscode/extensions.json',
  '.latexmkrc',
  'latexmkrc'
)
foreach ($configPath in $configPaths) {
  $configItem = Get-Item -LiteralPath $configPath -Force `
    -ErrorAction SilentlyContinue
  if ($null -eq $configItem) {
    [pscustomobject]@{ Path = $configPath; Type = 'absent' }
    continue
  }
  $configType = if ($configItem.LinkType) {
    'symbolic-link-target-withheld'
  } elseif ($configItem.PSIsContainer) {
    'directory'
  } else {
    'regular-file'
  }
  [pscustomobject]@{
    Path = $configPath
    Type = $configType
    Bytes = if ($configItem.PSIsContainer) { $null } else { $configItem.Length }
    LastWriteTime = $configItem.LastWriteTime
    Attributes = $configItem.Attributes
  }
}
```

Multiple results from `where.exe` or `Get-Command -All` are material. Report
their order; do not silently choose one.

### Sanitized configuration review

Keep originals out of tool output. Start with a value-free structural summary
that reports only whether fixed, relevant identifiers occur. The quiet searches
below inspect bytes locally but emit only constant labels chosen by this
runbook; they never emit matching lines or values.

On macOS, Linux, or WSL:

```sh
if [ -f .vscode/settings.json ] && [ ! -L .vscode/settings.json ]; then
  for config_key in \
    latex-workshop.latex.tools \
    latex-workshop.latex.recipes \
    latex-workshop.latex.outDir \
    latex-workshop.latex.autoBuild.run \
    latex-workshop.message.error.show \
    latex-workshop.message.warning.show; do
    if LC_ALL=C grep -Fq -- "\"$config_key\"" .vscode/settings.json; then
      printf '.vscode/settings.json: key present: %s; value withheld\n' \
        "$config_key"
    fi
  done
fi

if [ -f .vscode/extensions.json ] && [ ! -L .vscode/extensions.json ]; then
  for extension_id in James-Yu.latex-workshop yfzhao.ultra-math-preview; do
    if LC_ALL=C grep -Fq -- "$extension_id" .vscode/extensions.json; then
      printf '.vscode/extensions.json: identifier present: %s\n' \
        "$extension_id"
    fi
  done
fi

for latexmk_path in .latexmkrc latexmkrc; do
  [ -f "$latexmk_path" ] && [ ! -L "$latexmk_path" ] || continue
  for latexmk_identifier in '$pdf_mode' '$lualatex' '$out_dir' '$aux_dir'; do
    if LC_ALL=C grep -Fq -- "$latexmk_identifier" "$latexmk_path"; then
      printf '%s: identifier present: %s; value withheld\n' \
        "$latexmk_path" "$latexmk_identifier"
    fi
  done
done
```

On native Windows PowerShell, use `Select-String -Quiet`; never omit `-Quiet`
when the input is an original configuration file:

```powershell
$settingsPath = '.vscode/settings.json'
$settingsKeys = @(
  'latex-workshop.latex.tools',
  'latex-workshop.latex.recipes',
  'latex-workshop.latex.outDir',
  'latex-workshop.latex.autoBuild.run',
  'latex-workshop.message.error.show',
  'latex-workshop.message.warning.show'
)
$settingsItem = Get-Item -LiteralPath $settingsPath -Force `
  -ErrorAction SilentlyContinue
if ($null -ne $settingsItem -and -not $settingsItem.LinkType -and
    -not $settingsItem.PSIsContainer) {
  foreach ($settingsKey in $settingsKeys) {
    $present = Select-String -LiteralPath $settingsPath -SimpleMatch -Quiet `
      -Pattern ('"' + $settingsKey + '"')
    if ($present) {
      '{0}: key present: {1}; value withheld' -f $settingsPath, $settingsKey
    }
  }
}

$extensionsPath = '.vscode/extensions.json'
$extensionsItem = Get-Item -LiteralPath $extensionsPath -Force `
  -ErrorAction SilentlyContinue
if ($null -ne $extensionsItem -and -not $extensionsItem.LinkType -and
    -not $extensionsItem.PSIsContainer) {
  foreach ($extensionId in @(
    'James-Yu.latex-workshop',
    'yfzhao.ultra-math-preview'
  )) {
    $present = Select-String -LiteralPath $extensionsPath -SimpleMatch -Quiet `
      -Pattern $extensionId
    if ($present) {
      '{0}: identifier present: {1}' -f $extensionsPath, $extensionId
    }
  }
}

foreach ($latexmkPath in @('.latexmkrc', 'latexmkrc')) {
  $latexmkItem = Get-Item -LiteralPath $latexmkPath -Force `
    -ErrorAction SilentlyContinue
  if ($null -eq $latexmkItem -or $latexmkItem.LinkType -or
      $latexmkItem.PSIsContainer) { continue }
  $latexmkIdentifiers = @('$pdf_mode', '$lualatex', '$out_dir', '$aux_dir')
  foreach ($latexmkIdentifier in $latexmkIdentifiers) {
    $present = Select-String -LiteralPath $latexmkPath -SimpleMatch -Quiet `
      -Pattern $latexmkIdentifier
    if ($present) {
      '{0}: identifier present: {1}; value withheld' -f `
        $latexmkPath, $latexmkIdentifier
    }
  }
}
```

If that summary is insufficient for a key-by-key merge, use this hard boundary:

1. Ask the project owner to create a new sanitized excerpt outside any
   Agent-controlled terminal, tool call, transcript, or chat. Do not ask for a
   raw paste. Remove comments and unrelated blocks; replace every scalar value,
   command argument, environment value, URL query/user-info component, header,
   and credential-like string with `<redacted>`. Restore only the individual
   non-secret values that the owner affirms are necessary for the merge.
2. Obtain the sanitized excerpt's new path and the owner's explicit statement
   that it contains no token, API key, secret, password, cookie, authorization
   header, or other credential. Do not treat an automated secret scan as proof.
3. Check that new file's type and byte count without reading it. Then display at
   most the exact relevant block and no more than 120 lines from the sanitized
   file. Never point `sed`, `Get-Content`, `Select-String` without `-Quiet`, or
   another content-emitting command at the original.
4. If a needed value remains redacted, ask the owner about that one setting in
   plain language. Do not widen the excerpt or infer the value. If the owner
   cannot provide a safe excerpt, report the conflicting key names from the
   value-free summary and stop without editing configuration.

## Choose one installation owner

Classify the exact distribution before installing or updating it:

| Environment and route | Distribution owner | Use for updates |
| --- | --- | --- |
| macOS full MacTeX | MacTeX/TUG | TeX Live Utility or that distribution's bundled `tlmgr` |
| Native Windows official TeX Live | TUG installer | That installation's TeX Live Manager or `tlmgr` |
| Debian or Ubuntu packages | APT distribution packages | `apt` only |
| Fedora packages | DNF distribution packages | `dnf` only |
| WSL distro packages | The WSL distribution's package manager | The package manager inside that WSL distro only |

Do not use system-mode `tlmgr` to modify APT- or DNF-owned files. Do not point
an older TeX Live release at a newer release repository to force an in-place
cross-release upgrade. Install a new TUG/MacTeX release alongside the old one,
verify it, and switch the selected distribution only with approval.

## Install by environment

Execute exactly one applicable path after the user approves the reported
scope, size, and changes.

### macOS: MacTeX

1. Re-check the generic MacTeX page above for current macOS support, package
   size, download, and verification instructions.
2. Prefer the full official MacTeX package for a predictable `ctexart`,
   LuaLaTeX, and `latexmk` environment. If the user declines the full package,
   record the smaller selection and do not claim full-scheme verification.
3. Report the preflight targets of `/Library/TeX/texbin`, `/Library/TeX/Root`,
   and `/Library/TeX/Distributions/.DefaultTeX`. Explain that the official
   MacTeX package selects a newly installed release as the active distribution
   even though the old release remains installed.
4. Ask separately: may the installer make the new MacTeX release active? Do not
   infer this permission from approval of the download, multi-gigabyte install,
   administrator prompt, or preservation plan. If permission is absent or
   declined, do not execute the installer or attempt an undocumented bypass;
   report the proposed install and activation effect, then stop.
5. After both install and activation-switch permissions are explicit, install
   the signed package with the standard macOS installer. Preserve every older
   TeX distribution; MacTeX supports parallel releases.
6. Open a new terminal so `/Library/TeX/texbin` and the selected distribution
   resolve afresh. Record all three link targets again, verify that any change
   matches the authorization, and then run the verification section.

Do not add a second Homebrew-managed TeX distribution as a convenience
fallback.

### Native Windows: official TeX Live installer

1. Re-check the TUG Windows page, then download the current
   `install-tl-windows.exe` through the official TUG/CTAN link.
2. Ask whether the installation is per-user or machine-wide. Prefer the
   non-administrator path unless the user explicitly needs a shared install.
3. Select the full scheme only after the size confirmation. Keep the install
   directory free of unsupported path characters as required by the current
   Windows documentation.
4. Let the installer manage its own Windows PATH entry. Preserve older TeX
   Live directories and open a new PowerShell session before verification.

Do not substitute MiKTeX, WinGet, Chocolatey, Scoop, or a WSL installation
without an explicit change of plan.

### Debian or Ubuntu

Use the distribution packages so APT remains the sole owner. Re-check that the
packages exist for the target release, report APT's transaction, and obtain
confirmation before elevation:

```sh
sudo apt update
sudo apt install texlive-full latexmk
```

The `texlive-full` metapackage, not `tlmgr info scheme-full`, is the full-scheme
proof for this route.

### Fedora

Use the Fedora packages so DNF remains the sole owner. Re-check the official
package pages, report DNF's transaction, and obtain confirmation before
elevation:

```sh
sudo dnf install texlive-scheme-full latexmk
```

The `texlive-scheme-full` RPM, not `tlmgr info scheme-full`, is the full-scheme
proof for this route.

### WSL

Treat each WSL distribution as an independent Linux machine:

1. Confirm the named WSL distribution and run preflight inside it.
2. Use that distribution's APT or DNF path above. A native Windows TeX install
   does not satisfy WSL, and a WSL TeX install does not satisfy native Windows.
3. Confirm `command -v lualatex latexmk kpsewhich` resolves Linux binaries, not
   `.exe` files or paths imported from `/mnt/c`.
4. Open the folder through VS Code's WSL connection. Install workspace
   extensions in the WSL extension host when VS Code marks them as remote.
5. Keep `TEXMFHOME`, configuration, caches, and build output on their owning
   side. Do not share or splice Windows and WSL TeX trees.

## Verify the distribution

Treat the read-only preflight, the checks below, and the disposable smoke build
as one doctor pass. A doctor pass never grants permission to install, update,
remove, or switch a distribution.

Run every command in the same shell and environment that will build the
document:

```sh
command -v lualatex latexmk kpsewhich
lualatex --version | sed -n '1p'
latexmk -v | sed -n '1,2p'
kpsewhich --version | sed -n '1p'
kpsewhich -var-value=TEXMFROOT
kpsewhich -var-value=TEXMFHOME
kpsewhich ctexart.cls
kpsewhich amsmath.sty
```

The PowerShell equivalents are:

```powershell
Get-Command lualatex,latexmk,kpsewhich | Select-Object Name,Source
lualatex --version | Select-Object -First 1
latexmk -v | Select-Object -First 2
kpsewhich --version | Select-Object -First 1
kpsewhich -var-value=TEXMFROOT
kpsewhich -var-value=TEXMFHOME
kpsewhich ctexart.cls
kpsewhich amsmath.sty
```

Require all three commands, non-empty `TEXMFROOT` and `TEXMFHOME`, and resolved
paths for both classes/packages. Treat the paths as diagnostic data: do not
create files in `TEXMFROOT`; use `TEXMFHOME` for user-owned local additions.

Verify the selected full scheme according to its owner:

```sh
# MacTeX or a TUG-owned TeX Live installation: require "installed: Yes".
tlmgr info scheme-full

# Debian or Ubuntu: require both packages to be installed.
dpkg-query -W -f='${Package}: ${Status}\n' texlive-full latexmk

# Fedora: require both RPM queries to succeed.
rpm -q texlive-scheme-full latexmk
```

If the user approved a smaller scheme, skip the full-scheme claim but still
require the command, class/package, and smoke-test checks.

## Configure VS Code

Recommend these exact extension identifiers:

- `James-Yu.latex-workshop` for building, PDF viewing, diagnostics, and SyncTeX
- `yfzhao.ultra-math-preview` for lightweight formula-at-cursor preview

Install them through the Extensions view, or after confirming the intended VS
Code installation and local/remote extension host:

```sh
code --install-extension James-Yu.latex-workshop
code --install-extension yfzhao.ultra-math-preview
code --list-extensions
```

When this Skill generates a project for the explicit local-PDF path, its
project-scoped `.vscode/settings.json` and `.vscode/extensions.json` are already
copied with the project. Open those files and verify them; do not copy a second
configuration over them. The intended recipe uses `latexmk` with LuaLaTeX,
writes to `build/latex/`, builds on save, enables SyncTeX, and keeps error and
warning diagnostics visible.

For an existing or adjacent project, merge manually:

1. Determine whether each setting is user-, workspace-, or folder-scoped.
2. Use the sanitized-review procedure above to compare the existing keys with
   the proposed project settings. Show a manually composed key-level change
   plan containing only fixed key names, sanitized existing states, and proposed
   non-secret values. Never emit a raw file or raw `git diff` of configuration.
3. Add extension recommendations as a de-duplicated union. Do not replace the
   entire `recommendations` array.
4. Preserve unrelated settings. JSON arrays do not merge automatically: append
   only the missing `latex-workshop.latex.tools` tool and its matching recipe,
   using unique names if the project already defines tools or recipes.
5. Resolve conflicting engine, output-directory, root-file, auto-build, or
   cleaning choices with the project owner. Do not silently change them.
6. Keep `latex-workshop.message.error.show` and
   `latex-workshop.message.warning.show` enabled. Do not suppress diagnostics
   to make a broken build appear successful.
7. Validate the edited JSON/JSONC in VS Code and inspect the Problems panel
   before claiming the merge is complete.

## Run the smoke test

Create a new disposable directory under the OS temporary directory, save the
following as `smoke-test.tex`, and keep all output in its `build/` subdirectory:

```tex
\documentclass[UTF8,fontset=fandol]{ctexart}
\usepackage{amsmath}

\title{Local LuaLaTeX Smoke Test}
\author{Human and Agent Verification}
\date{}

\begin{document}
\maketitle

Hello, local LaTeX. 中文排版验证成功时，这一行应正常显示。

\[
  \int_0^1 x^2\,\mathrm{d}x = \frac{1}{3}.
\]
\end{document}
```

Compile from that disposable directory:

```sh
mkdir -p build
latexmk -lualatex -interaction=nonstopmode -halt-on-error \
  -file-line-error -synctex=1 -outdir=build smoke-test.tex
test -s build/smoke-test.pdf
test -s build/smoke-test.synctex.gz
```

PowerShell:

```powershell
New-Item -ItemType Directory -Force build | Out-Null
latexmk -lualatex -interaction=nonstopmode -halt-on-error `
  -file-line-error -synctex=1 -outdir=build smoke-test.tex
if (-not (Test-Path build/smoke-test.pdf)) { throw "PDF smoke test failed" }
if (-not (Test-Path build/smoke-test.synctex.gz)) { throw "SyncTeX smoke test failed" }
```

Require a zero exit status and non-empty PDF and SyncTeX files. Open the PDF in
LaTeX Workshop, save the source once to exercise the on-save recipe, and test
one forward/reverse SyncTeX jump. Report the disposable path, then remove it
only after resolving the exact path and confirming it is not a repository or
user project.

## Maintain and troubleshoot

- **A command is missing:** open a fresh terminal and the VS Code integrated
  terminal, then compare command paths. Repair the owning distribution or PATH;
  do not add an unrelated second distribution.
- **Commands come from different roots:** stop and identify the selected
  distribution. Fix PATH or the MacTeX distribution selection, then rerun the
  complete verification. Do not continue with a mixed toolchain.
- **`ctexart.cls` or `amsmath.sty` is missing:** install or repair it through
  the same distribution owner. Never use a TUG `tlmgr` to patch an APT/DNF
  installation.
- **`tlmgr` rejects an update across releases:** do not override its repository
  safeguards. Use the matching release manager or install the new release in
  parallel.
- **A user package is needed:** place it under the reported `TEXMFHOME`, not
  `TEXMFROOT`, and refresh only the user tree if the package instructions
  require it. Never run an editor as administrator to bypass permissions.
- **CLI succeeds but VS Code fails:** compare the integrated-terminal paths,
  reload the VS Code window, confirm the correct local or WSL extension host,
  and inspect LaTeX Workshop output and Problems. Do not hide errors.
- **A project build fails after configuration changes:** reproduce with the
  exact CLI recipe in a fresh output directory. Revisit the manual merge rather
  than replacing the project's configuration.
- **WSL resolves Windows executables:** remove inherited Windows TeX paths from
  the WSL build context and use the Linux-owned installation. Do not share
  `TEXMFROOT` or `TEXMFHOME` across the boundary.
- **Stale auxiliary files are suspected:** first build in a new disposable
  output directory. Clean only a precisely identified generated directory;
  never issue a broad recursive deletion.
- **Updating:** show the proposed package/release changes, preserve prior
  installations, obtain confirmation, update through the owner in the table,
  and rerun command, TEXMF, full-scheme, and smoke checks.

## Return a completion receipt

Return a concise, evidence-backed receipt in the user's language containing:

```text
environment: <macOS | native Windows | Debian/Ubuntu | Fedora | WSL distro>
architecture: <value>
distribution: <name and release>
distribution_owner: <MacTeX/TUG | APT | DNF>
official_sources_checked: <URLs and date>
approved_scope: <full scheme or explicitly selected smaller scheme>
changes_made: <installer/packages, PATH, VS Code files/extensions>
preserved_installations: <paths/releases or none found>
active_distribution_before: <resolved selection or not applicable>
active_distribution_change_approved: <yes | no | not applicable>
active_distribution_after: <resolved selection or not applicable>
lualatex: <resolved path and version>
latexmk: <resolved path and version>
kpsewhich: <resolved path and version>
TEXMFROOT: <resolved value>
TEXMFHOME: <resolved value>
full_scheme_evidence: <tlmgr, dpkg-query, or rpm result; or not claimed>
doctor_result: <checks run and pass/fail evidence>
vscode_merge: <generated config verified or manual keys merged>
smoke_command: <exact command>
smoke_result: <exit status, PDF path, SyncTeX path>
unresolved_warnings: <none or exact warnings>
web_pipeline_changes: none
```

Do not report success from an installer's exit code alone. Completion requires
the resolved binaries, TEXMF values, owner-specific scheme evidence, successful
LuaLaTeX smoke build, and honest disclosure of any warning.
