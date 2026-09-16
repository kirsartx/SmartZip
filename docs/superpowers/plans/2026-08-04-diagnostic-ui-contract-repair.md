# DiagnosticUI Contract Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** Repair the DiagnosticUI test double so generic and known-extension \`NOT_ARCHIVE\` diagnostics exercise the current production contract.

**Architecture:** Keep \`SmartZip.ahk\` unchanged. Extend \`DiagnosticUIHost\` with the configured-extension seam used by \`SmartZip.IsArchive\`, make the reason command accept an optional archive path, add one focused known-extension case, and update gate counts.

**Tech Stack:** PowerShell 5.1, Pester 3.4, AutoHotkey v2, Git.

## Global Constraints

- Do not modify production \`SmartZip.ahk\`.
- Preserve the existing user-owned LF-only change in \`tests/RunCmdCapture.Fragment.ahk\`.
- Use AutoHotkey only from \`%TEMP%\\ahk_tools\\ahk-v2\`; do not install system-wide.
- Match production extension semantics: \`SplitPath\` supplies strings without a leading dot; exact membership uses \`this.ext\`; regex membership uses \`this.extExp\`.
- Run \`git diff --check\` after edits.

---

### Task 1: Prepare the isolated AutoHotkey v2 toolchain

**Files:** none in the repository. Temporary target: \`%TEMP%\\ahk_tools\\ahk-v2\`.

- [ ] **Step 1: Check for the executable**

~~~powershell
$ahkRoot = Join-Path $env:TEMP 'ahk_tools\\ahk-v2'
Get-ChildItem -LiteralPath $ahkRoot -Recurse -File -Filter 'AutoHotkey64.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
~~~

Expected: a path, or no output.

- [ ] **Step 2: Download only when absent**

~~~powershell
$ahkRoot = Join-Path $env:TEMP 'ahk_tools\\ahk-v2'
$zipPath = Join-Path $env:TEMP 'smartzip-ahk-v2.zip'
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/AutoHotkey/AutoHotkey/releases/latest'
$asset = $release.assets | Where-Object { $_.name -match '^AutoHotkey.*\.zip$' -and $_.name -notmatch 'Source' } | Select-Object -First 1
if (-not $asset) { throw 'Official AutoHotkey v2 ZIP asset was not found.' }
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
New-Item -ItemType Directory -Path $ahkRoot -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $ahkRoot -Force
$ahkExe = Get-ChildItem -LiteralPath $ahkRoot -Recurse -File -Filter 'AutoHotkey64.exe' | Select-Object -First 1 -ExpandProperty FullName
if (-not $ahkExe) { throw 'AutoHotkey64.exe was not found after extraction.' }
$ahkExe
~~~

Expected: a path under \`%TEMP%\\ahk_tools\\ahk-v2\`.

---

### Task 2: Add and observe the failing regression test

**Files:** Modify \`tests/DiagnosticUI.Tests.ps1\` after the table-driven reason loop near lines 812-821.

- [ ] **Step 1: Add this RED case**

~~~powershell
    It 'reason_NOT_ARCHIVE_known_archive_extension' {
        $out = Invoke-DiagnosticUICase -Command 'reason' -CaseKey 'reason_NOT_ARCHIVE_known_archive_extension' -Json '{"status":"NOT_ARCHIVE","archivePath":"D:\\data\\folder\\pack.7z"}' -StageDir $script:StageDir
        (Get-JsonField $out 'reason') | Should Be '压缩包文件头可能已损坏或不完整。'
        (Get-JsonField $out 'recommendation') | Should Be '请重新下载或复制完整源文件，或用 7-Zip 打开检查。'
    }
~~~

- [ ] **Step 2: Run the focused suite**

~~~powershell
$r = Invoke-Pester -Script '.\\tests\\DiagnosticUI.Tests.ps1' -PassThru
$r | Select-Object PassedCount, FailedCount, SkippedCount
~~~

Expected: the new case fails because \`DiagnosticUIHost\` has no \`IsArchive\` method.

---

### Task 3: Add the minimal test-host contract

**Files:** Modify \`tests/DiagnosticUI.Tests.ps1\` in \`DiagnosticUIHost\` and the \`reason\` branch of \`RunDiagnosticUICommand\`.

- [ ] **Step 1: Add this state and method after \`sevenZipVersion\`**

~~~ahk
    ext := Map("7z", true, "zip", true, "rar", true)
    extExp := []
    IsArchive(ext) {
        ext := StrLower(ext)
        if !ext
            return false
        if this.ext.Has(ext)
            return true
        for i in this.extExp
            if ext ~= "i)" i
                return true
        return false
    }
~~~

- [ ] **Step 2: Replace the fixed reason fixture with optional path input**

~~~ahk
        archivePath := JsonUnescape(JsonGet(jsonText, "archivePath", "D:\\data\\folder\\plain.txt"))
        r := MakeResult(status, archivePath, jsonText)
~~~

The default \`.txt\` path keeps the table-driven mapping generic; the new test supplies \`.7z\` explicitly.

- [ ] **Step 3: Verify GREEN**

~~~powershell
$r = Invoke-Pester -Script '.\\tests\\DiagnosticUI.Tests.ps1' -PassThru
if ($r.FailedCount -ne 0) { throw 'DiagnosticUI focused suite failed.' }
$r | Select-Object PassedCount, FailedCount, SkippedCount
~~~

Expected: \`PassedCount = 53\`, \`FailedCount = 0\`.

---

### Task 4: Update gate documentation and continuity state

**Files:** \`tests/README.md\`, \`docs/continuity/ACTIVE_TASK.md\`, \`docs/continuity/DECISIONS.md\`.

- [ ] **Step 1:** Change \`DiagnosticUI.Tests.ps1\` from \`52\` to \`53\` and the overall total from \`647/647\` to \`648/648\` in \`tests/README.md\`; leave all other counts unchanged.
- [ ] **Step 2:** Record exact focused/full results, changed files, and the preserved user-owned fragment in \`ACTIVE_TASK.md\`. Record the no-leading-dot extension decision in \`DECISIONS.md\`.
- [ ] **Step 3: Validate formatting**

~~~powershell
git diff --check
~~~

Expected: exit code 0; only the known line-ending warning is acceptable.

---

### Task 5: Run the complete contract gate

**Files:** none beyond Task 4.

- [ ] **Step 1:** Run the exact eight-suite loop from \`tests/README.md\`, with \`DiagnosticUI.Tests.ps1=53\`; expect \`184/184\`, \`193/193\`, \`15/15\`, \`98/98\`, \`39/39\`, \`30/30\`, \`53/53\`, and \`36/36\`, then a clean diff check and the documented 7-Zip probe.
- [ ] **Step 2: Inspect the final worktree**

~~~powershell
git status --short
git diff --stat
git diff --check
~~~

Expected: intended test/documentation changes plus pre-existing \`M tests/RunCmdCapture.Fragment.ahk\`; no production \`SmartZip.ahk\` change.
