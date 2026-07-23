# SmartZip 3.6 Kirs.3 Convenience and Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make everyday extraction more predictable without weakening Kirs.2 safety: any member of a complete split set extracts once, password retry from the diagnostic window resumes the normal pipeline, ordinary numeric filenames are not misreported as volumes, diagnostics stay useful without passwords, and ship as SmartZip 3.6 Kirs.3 (23).

**Architecture:** Keep the Kirs.2 monolithic AutoHotkey pipeline and pure `lib/ArchiveDiagnostics.ahk` volume/classifier library. Tighten Pattern D evidence, remove outer `partSkip` early-continue so every selection reaches `DetectVolumeGroup`, make `ShowDiagnostic` a synchronous recovery boundary that returns an `ArchiveResult`, resume `zipx` test/extract/finalize from that return without duplicating the pipeline, enrich batch summary basenames, redact `CheckCMD.LogAndReturn`, remove the production test-hook include and inject it only into TEMP integration sources, then build/smoke/deploy/publish `v3.6-kirs.3` without mutating `v3.6-kirs.2`.

**Tech Stack:** AutoHotkey v2.0.26, Ahk2Exe 1.1.37.02a2, Pester 3.4-compatible PowerShell, 7-Zip 26.02 ZS v1.5.7 R1 at `C:\Tool\7-Zip-Zstandard\7z.exe`, Git, GitHub CLI.

## Global Constraints

- Display/version identity is exactly `SmartZip 3.6 Kirs.3 (23)`.
- `MainVersion := "3.6"` and Ahk2Exe FileVersion remain `3.6`; `edition := "Kirs.3"`, `buildVersion := 23`, and ProductVersion `23`.
- The final runtime artifact remains one `SmartZip.exe`; `lib/*.ahk` files are compile-time includes only.
- Preserve all Kirs.2 source-deletion, partial-output, password-redaction, batch-suppression, and volume never-auto-delete invariants.
- Exit code 0 plus clean required stages is the only clean-success condition; `successPercent` must never authorize success or source handling.
- `OK_WITH_WARNING`, every failure state, and `CANCELLED` must preserve the top-level source and all volumes.
- Top-level and nested automatic source handling uses the Recycle Bin only; no source archive is permanently deleted.
- Split-volume sets are never automatically deleted.
- Passwords and clipboard content must not appear in logs, copied diagnostics, command traces, reports, or test output.
- Current Kirs.1 and Kirs.2 tags/releases remain unchanged; publication creates new `v3.6-kirs.3` only. Never mutate `v3.6-kirs.2`.
- Production `SmartZip.ahk` must not include `tests\IntegrationTestHook.ahk` even optionally. Integration tests inject the include into a TEMP copy only.
- Use only the verified engine at `C:\Tool\7-Zip-Zstandard` for integration/smoke tests.
- Use the verified toolchain:
  - `C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe`
  - `C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe`
  - Trusted SHA-256 base: `A2A54B8ABC476D7671D4DE0771BB54BF5F2373D79FF6871D0BA6A62C3B88AE00`
  - Trusted SHA-256 Ahk2Exe: `E54A599B19BAA5C1688849BBAE7A9CF049EEFCCD4F704C67941B40DA13A625B2`
- Branch for this work: `codex/kirs3-convenience` (already checked out in the worktree).
- A task is not complete until its focused RED/GREEN cycle, full regression of suites that task claims, `git diff --check`, focused commit, and fresh read-only review all pass with Critical=0 and Important=0.
- Implementation session must use `superpowers:subagent-driven-development`, one fresh implementer per task, separate spec-compliance and code-quality reviewers. No task advances while either reviewer reports Critical or Important findings.

## File Map

- Modify `lib/ArchiveDiagnostics.ahk`: Pattern D evidence gate only (`_VolHasPatternDEvidence` + early empty return). Patterns A–C, digit-width matching, case-insensitivity, missing-volume calc, and 4096-span guard stay.
- Modify `SmartZip.ahk`: remove outer `partSkip` early continue; make `ShowDiagnostic` synchronous and returning; wire `DiagnosticButtonAction` recovery context; resume `zipx` after successful password recovery; batch summary basenames; `LogAndReturn` redaction; remove `#Include *i tests\IntegrationTestHook.ahk`; bump Kirs.3 metadata; update settings `partSkip` tip text.
- Modify `tests/ArchiveDiagnostics.Harness.ahk` and `tests/ArchiveDiagnostics.Tests.ps1`: Pattern D evidence cases.
- Modify `tests/DiagnosticUI.Harness.ahk` / product-fragment footer in `tests/DiagnosticUI.Tests.ps1`: recovery commands, scriptable `ResolveArchivePassword`, summary text spies, return-status fields.
- Modify `tests/DiagnosticUI.Tests.ps1`: recovery, wrong/cancel, batch basename cases.
- Modify `tests/ExtractionLifecycle.Tests.ps1` and/or `tests/ExtractionLifecycle.Harness.ahk` only if Task 5 needs a non-static resume proof (preferred: static zipx-slice + DiagnosticUI recovery).
- Modify `tests/SmartZip.Static.Tests.ps1`: partSkip gate, Pattern D evidence presence, ShowDiagnostic/WinWaitClose, recovery wiring, zipx resume, LogAndReturn redaction, hook absence, Kirs.3 metadata/docs.
- Modify `tests/Real7Zip.Integration.Tests.ps1`: TEMP SmartZip source injection after `#Include lib\ArchiveDiagnostics.ahk`; assert repo source has no hook include; keep 30 existing scenarios green; add injection-order assertions.
- Modify `tests/README.md`: suite counts, injection model (no production optional include), Kirs.3 TEMP root naming.
- Modify `README.md` and `ini.md`: Kirs.3 convenience UX, partSkip new semantics, Pattern D numeric note, password retry, batch basenames; preserve Kirs.2 safety language.
- Do not modify: Kirs.1/Kirs.2 tags, releases, or historical plan/spec files beyond adding this plan under `docs/superpowers/plans/`.

## Canonical Interfaces (Kirs.3 deltas)

Preserve all Kirs.2 interfaces. Kirs.3 requires these exact shapes:

```ahk
; Unchanged pure library API
DetectVolumeGroup(path, siblingNames) => { isVolume, firstPath, members, missingVolumes, selectedIsFirst }

; Pattern D evidence (private helper; name locked for static searchability)
_VolHasPatternDEvidence(stem, selIndex, indices) => Boolean
; true when:
;   stem ~= i)\.(7z|zip|rar|tar|wim)$
;   OR selIndex = 1
;   OR exists idx in indices with idx >= 1 and idx != selIndex

; Recovery context object (local to ShowDiagnostic GUI path only)
recovery := { original: ArchiveResult, resolved: "" }
; resolved set only on successful password resolution (status OK or OK_WITH_WARNING)

; Return-bearing diagnostic API (signature text unchanged; callers must capture return)
ShowDiagnostic(result, isBatch := false) => ArchiveResult
; isBatch=true  → RecordBatchDiagnostic(result); return result; no GUI; no wait
; OK/CANCELLED  → return result; no GUI
; single failure → show GUI; WinWaitClose; return recovery.resolved if set else result

DiagnosticButtonAction(label, recovery, archivePath, volumeFirst, partialPath, g) => void
; "重新输入密码":
;   r := ResolveArchivePassword(archivePath, recovery.original)
;   if r.status is OK or OK_WITH_WARNING: recovery.resolved := r; g.Destroy()
;   else: leave window open; do not touch sources
; never calls ExtractArchiveToTemp / FinalizeExtraction / RecycleItem

FormatBatchDiagnosticSummary(batchDiagnostic) => String
; counts line + optional "失败文件: " + up to 3 basenames
; if failure.Length > 3: append " ... (+N)" where N = failure.Length - 3

; zipx resume contract
; after password-class ShowDiagnostic return with OK/OK_WITH_WARNING:
;   resolved := returned; recompute mayHandleSource/forceTest/nestedMayRecycle;
;   fall through existing TestArchive → ExtractArchiveToTemp → FinalizeExtraction → source handling
; never duplicate those stages inside DiagnosticButtonAction
```

### Baseline suite counts (must remain green until a task intentionally expands them)

| Suite | Baseline PassedCount |
|---|---:|
| `tests/SmartZip.Static.Tests.ps1` | 150 |
| `tests/ArchiveDiagnostics.Tests.ps1` | 140 |
| `tests/RunCmdCapture.Tests.ps1` | 15 |
| `tests/PasswordPreflight.Tests.ps1` | 78 |
| `tests/ExtractionLifecycle.Tests.ps1` | 26 |
| `tests/NestingMigration.Tests.ps1` | 30 |
| `tests/DiagnosticUI.Tests.ps1` | 36 |
| `tests/Real7Zip.Integration.Tests.ps1` | **30** (live truth; README currently says 26 — Task 7 fixes README) |

---

### Task 1: Pattern D Numeric Evidence Gate

**Files:**
- Modify: `lib/ArchiveDiagnostics.ahk` — Pattern D block only (after numeric match, before `_VolBuildNumericGroup`)
- Modify: `tests/ArchiveDiagnostics.Harness.ahk` — append evidence cases inside `mode = "volumes" || mode = "all"`
- Modify: `tests/ArchiveDiagnostics.Tests.ps1` — append the 21 exact evidence case names from Step 1 to `$volumeCases` (or a dedicated `$evidenceCases` foreach that still produces one It per name)
- Do not modify: `SmartZip.ahk`, integration, docs (docs land in Task 8)

**Interfaces:**
- Consumes: existing `DetectVolumeGroup`, `_VolBuildNumericGroup`, `_VolEscape`, `_VolMaxDerivationSpan`
- Produces: `_VolHasPatternDEvidence(stem, selIndex, indices) => Boolean`; Pattern D returns `empty` when evidence is false; existing true-volume cases remain green

- [ ] **Step 1: Write the failing harness cases**

In `tests/ArchiveDiagnostics.Harness.ahk`, after the existing volume cases (still inside the volumes block), append:

```ahk
    ; --- Kirs.3 Pattern D evidence ---
    siblings := ["report.2024"]
    g := DetectVolumeGroup(dir "\report.2024", siblings)
    AssertFalse(g.isVolume, "report_2024_alone_not_volume")
    AssertEq(g.firstPath, "", "report_2024_alone_empty_first")
    AssertEq(g.members.Length, 0, "report_2024_alone_empty_members")
    AssertEq(g.missingVolumes.Length, 0, "report_2024_alone_empty_missing")
    AssertFalse(g.selectedIsFirst, "report_2024_alone_not_first")

    siblings := ["report.2024", "notes.txt"]
    g := DetectVolumeGroup(dir "\report.2024", siblings)
    AssertFalse(g.isVolume, "report_2024_unrelated_not_volume")

    siblings := ["photo.1234"]
    g := DetectVolumeGroup(dir "\photo.1234", siblings)
    AssertFalse(g.isVolume, "photo_1234_alone_not_volume")

    siblings := ["data.002"]
    g := DetectVolumeGroup(dir "\data.002", siblings)
    AssertFalse(g.isVolume, "bare_002_alone_not_volume")
    AssertEq(g.missingVolumes.Length, 0, "bare_002_alone_no_missing_list")

    siblings := ["data.001", "data.002"]
    g := DetectVolumeGroup(dir "\data.002", siblings)
    AssertTrue(g.isVolume, "bare_002_with_001_is_volume")
    AssertFalse(g.selectedIsFirst, "bare_002_with_001_not_first")
    AssertEq(g.firstPath, dir "\data.001", "bare_002_with_001_first_path")

    siblings := ["data.001"]
    g := DetectVolumeGroup(dir "\data.001", siblings)
    AssertTrue(g.isVolume, "bare_001_alone_still_volume")
    AssertTrue(g.selectedIsFirst, "bare_001_alone_is_first")

    siblings := ["pack.zip.001"]
    g := DetectVolumeGroup(dir "\pack.zip.001", siblings)
    AssertTrue(g.isVolume, "zip_001_alone_is_volume")

    siblings := ["a.tar.001"]
    g := DetectVolumeGroup(dir "\a.tar.001", siblings)
    AssertTrue(g.isVolume, "tar_001_alone_is_volume")

    siblings := ["a.wim.001"]
    g := DetectVolumeGroup(dir "\a.wim.001", siblings)
    AssertTrue(g.isVolume, "wim_001_alone_is_volume")

    siblings := ["archive.7z.002"]
    g := DetectVolumeGroup(dir "\archive.7z.002", siblings)
    AssertTrue(g.isVolume, "sevenz_002_alone_is_volume")
    AssertFalse(g.selectedIsFirst, "sevenz_002_alone_not_first")
    AssertEq(g.firstPath, dir "\archive.7z.001", "sevenz_002_alone_derives_first")
    AssertTrue(_ArrayHas(g.missingVolumes, "archive.7z.001"), "sevenz_002_alone_missing_001")
```

In `tests/ArchiveDiagnostics.Tests.ps1`, append these exact names to the volume case list (after `orphan_r00_does_not_fabricate_r99`):

```powershell
        'report_2024_alone_not_volume',
        'report_2024_alone_empty_first',
        'report_2024_alone_empty_members',
        'report_2024_alone_empty_missing',
        'report_2024_alone_not_first',
        'report_2024_unrelated_not_volume',
        'photo_1234_alone_not_volume',
        'bare_002_alone_not_volume',
        'bare_002_alone_no_missing_list',
        'bare_002_with_001_is_volume',
        'bare_002_with_001_not_first',
        'bare_002_with_001_first_path',
        'bare_001_alone_still_volume',
        'bare_001_alone_is_first',
        'zip_001_alone_is_volume',
        'tar_001_alone_is_volume',
        'wim_001_alone_is_volume',
        'sevenz_002_alone_is_volume',
        'sevenz_002_alone_not_first',
        'sevenz_002_alone_derives_first',
        'sevenz_002_alone_missing_001'
```

That is **21** new volume Its (plus existing harness exit). Expected new diagnostics total after GREEN: `140 + 21 = 161`.

- [ ] **Step 2: Run focused volume tests and confirm RED**

```powershell
$focused = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 `
    -TestName 'ArchiveDiagnosticsVolumes' -PassThru
"Passed=$($focused.PassedCount) Failed=$($focused.FailedCount) Total=$($focused.TotalCount)"
```

Expected RED:
- `report_2024_alone_not_volume` fails (today `isVolume=true` and may invent missing `report.0001`…`report.2023`)
- `bare_002_alone_not_volume` fails (today treated as volume)
- `FailedCount` ≥ 1; record the first failure message before implementing

- [ ] **Step 3: Implement minimal Pattern D evidence gate**

In `lib/ArchiveDiagnostics.ahk`, add before `DetectVolumeGroup` (or immediately above Pattern D usage):

```ahk
_VolHasPatternDEvidence(stem, selIndex, indices) {
    if (stem ~= "i)\.(7z|zip|rar|tar|wim)$")
        return true
    if (selIndex = 1)
        return true
    for idx in indices {
        if (idx >= 1 && idx != selIndex)
            return true
    }
    return false
}
```

Inside Pattern D, after building `indices` / `indexToName` and ensuring selected index is present, **before** calling `_VolBuildNumericGroup`:

```ahk
        if (!_VolHasPatternDEvidence(stem, selIndex, indices))
            return empty
```

Do not change Patterns A–C. Do not change digit-width matching, 4096 span, or missing-volume generation for true volumes.

- [ ] **Step 4: Run focused GREEN + classify regression + static baseline**

```powershell
$vol = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 `
    -TestName 'ArchiveDiagnosticsVolumes' -PassThru
"VOL Passed=$($vol.PassedCount) Failed=$($vol.FailedCount) Total=$($vol.TotalCount)"
if ($vol.FailedCount -ne 0) { exit 1 }
# Expected: previous 68 volume Its + 21 evidence Its = 89 volume-describe Its
# (1 harness-exit + 67 prior named + 21 new; if prior list length differs, require FailedCount=0 and new names all PASS)

$allDiag = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
"DIAG Passed=$($allDiag.PassedCount) Failed=$($allDiag.FailedCount) Total=$($allDiag.TotalCount)"
if ($allDiag.FailedCount -ne 0) { exit 1 }
# Expected: 140 + 21 = 161

$static = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"STATIC Passed=$($static.PassedCount) Failed=$($static.FailedCount) Total=$($static.TotalCount)"
if ($static.PassedCount -ne 150 -or $static.FailedCount -ne 0) { exit 1 }
```

Expected GREEN: diagnostics `161/161`, static still `150/150`.

- [ ] **Step 5: `git diff --check` and focused commit**

```powershell
git add -- lib/ArchiveDiagnostics.ahk tests/ArchiveDiagnostics.Harness.ahk tests/ArchiveDiagnostics.Tests.ps1
git diff --check --cached
git diff --cached --stat
git commit -m "feat: require Pattern D evidence for numeric volume detection"
```

- [ ] **Step 6: Independent read-only review gate**

Reviewer must verify design Detection Rules for Numeric Extensions: `report.2024` alone not volume; `data.001` alone still volume; `data.001`+`data.002` volume; archive-extension alone volume; `archive.7z.002` alone still volume with missing first; width/case/4096 unchanged. Require `Critical=0`, `Important=0`.

---

### Task 2: Volume Selection Without partSkip Early Continue

**Files:**
- Modify: `SmartZip.ahk` — outer `Unzip` loop only: remove `partSkip`/`IsPart` early `continue`; keep `this.partSkip` INI load and settings checkbox key for compatibility
- Modify: `tests/SmartZip.Static.Tests.ps1` — add structural Its under a new or existing Describe (prefer `NestingProbeAndMigrationSafety` or new `VolumeSelectionSafety`)
- Do not modify: `lib/ArchiveDiagnostics.ahk` (Task 1 complete), password recovery, docs (Task 8)

**Interfaces:**
- Consumes: Task 1 `DetectVolumeGroup` evidence rules; existing `zipx` `processedVolumeFirst` / `MISSING_VOLUME` / never-delete volume guards
- Produces: every top-level selected path reaches `zipx` → `DetectVolumeGroup`; `partSkip` no longer authorizes `continue` before detection

- [ ] **Step 1: Write failing static tests**

Append to `tests/SmartZip.Static.Tests.ps1` inside a Describe `VolumeSelectionSafety` (create if missing):

```powershell
Describe 'VolumeSelectionSafety' {
    BeforeAll {
        $script:UnzipBody = Get-SourceSlice -Source $script:SmartZipSource `
            -StartMarker "`n    Unzip(" -EndMarker "`n    CreateZip("
        if ([string]::IsNullOrEmpty($script:UnzipBody)) {
            $script:UnzipBody = Get-SourceSlice -Source $script:SmartZipSource `
                -StartMarker "`n    Unzip(" -EndMarker "`n    OpenZip("
        }
    }

    It 'Unzip does not early-continue on partSkip before zipx' {
        $u = $script:UnzipBody
        if ([string]::IsNullOrEmpty($u)) { $u = $script:SmartZipSource }
        # Forbidden: partSkip combined with IsPart result driving continue before zipx
        $bad = Test-Regex -Text $u -Pattern `
            '(?s)partSkip\s*&&\s*!part.{0,80}continue'
        $bad | Should Be $false
    }

    It 'zipx always calls DetectVolumeGroup for selected paths' {
        $u = $script:UnzipBody
        if ([string]::IsNullOrEmpty($u)) { $u = $script:SmartZipSource }
        $u | Should Match 'DetectVolumeGroup\s*\('
        $u | Should Match 'processedVolumeFirst'
        $u | Should Match 'MISSING_VOLUME'
    }

    It 'volume members remain excluded from mayDeleteSource paths' {
        $script:SmartZipSource | Should Match '!\s*volume\.isVolume'
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            '(?s)mayHandleSource\s*:=.{0,120}!\s*volume\.isVolume'
        $ok | Should Be $true
    }

    It 'partSkip INI key remains for compatibility' {
        $script:SmartZipSource | Should Match 'partSkip'
        $script:SmartZipSource | Should Match 'this\.partSkip\s*:='
    }
}
```

Expected: +4 static Its → target after GREEN `154`.

- [ ] **Step 2: Confirm RED**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName 'VolumeSelectionSafety' -PassThru
"Passed=$($s.PassedCount) Failed=$($s.FailedCount) Total=$($s.TotalCount)"
```

Expected RED: `Unzip does not early-continue on partSkip before zipx` fails while lines ~288–290 still contain:

```ahk
            part := IsPart(i)
            if this.partSkip && !part
                continue
```

- [ ] **Step 3: Minimal implementation**

In `SmartZip.ahk` `Unzip` loop, delete the three-line early-continue gate:

```ahk
            part := IsPart(i)
            if this.partSkip && !part
                continue
```

Leave `IsPart` function defined (may still be unused or used only for logging elsewhere). Leave `this.partSkip := ini.partSkip` and settings `GuiCheckBox("partSkip", ...)` in place. Optionally update only the settings tip string in this task to:

```ahk
    GuiCheckBox("partSkip", ini.partSkip, "分卷同组只解压一次", "任一卷从首卷开始；同组多选只解压一次`n分卷不会自动删除", "Section")
```

(If tip update is deferred to Task 8, still remove the continue here.)

Do not weaken `processedVolumeFirst`, missing-volume branch, or volume never-delete guards inside `zipx`.

- [ ] **Step 4: GREEN + regression**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 154) { throw "static $($s.PassedCount)/$($s.FailedCount)" }
$d = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
if ($d.FailedCount -ne 0 -or $d.PassedCount -ne 161) { throw "diag $($d.PassedCount)/$($d.FailedCount)" }
$n = Invoke-Pester -Script .\tests\NestingMigration.Tests.ps1 -PassThru
if ($n.FailedCount -ne 0 -or $n.PassedCount -ne 30) { throw "nest $($n.PassedCount)/$($n.FailedCount)" }
```

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "fix: route every selected path through volume detection"
```

- [ ] **Step 6: Review gate**

Reviewer verifies: no silent discard of non-first volumes; de-dupe still via `processedVolumeFirst`; incomplete → `MISSING_VOLUME`; volumes never deleted; `partSkip` key remains. `Critical=0`, `Important=0`.

---

### Task 3: CheckCMD LogAndReturn Redaction

**Files:**
- Modify: `SmartZip.ahk` — nested `LogAndReturn` inside `CheckCMD` only
- Modify: `tests/SmartZip.Static.Tests.ps1` — one structural It

**Interfaces:**
- Consumes: existing `RedactDiagnostic(text, includeFullPath := true)`
- Produces: `LogAndReturn` passes both `cmdArgs` and `line` through `RedactDiagnostic` before `Loging`

- [ ] **Step 1: Failing static test**

```powershell
    It 'LogAndReturn redacts cmdArgs and line before Loging' {
        $body = Get-SourceSlice -Source $script:SmartZipSource `
            -StartMarker "`n    CheckCMD(" -EndMarker "`n    Loging("
        if ([string]::IsNullOrEmpty($body)) { $body = $script:SmartZipSource }
        $okArgs = Test-Regex -Text $body -Pattern `
            'Loging\(\s*RedactDiagnostic\s*\(\s*cmdArgs\s*\)'
        $okLine = Test-Regex -Text $body -Pattern `
            'RedactDiagnostic\s*\(\s*line\s*\)'
        ($okArgs -and $okLine) | Should Be $true
    }
```

- [ ] **Step 2: Confirm RED**

```powershell
$r = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
# Expect FailedCount >= 1 on LogAndReturn redacts...
```

- [ ] **Step 3: Minimal fix**

Replace `LogAndReturn` body logging line:

```ahk
            LogAndReturn(num, lineNum)
            {
                this.isCmdReturn := true
                ProcessClose(this.CMDPID), ProcessWaitClose(this.CMDPID)
                this.CMDPID := 0
                if num < 4
                    this.error := 1
                else
                    this.error := 0
                this.Loging(RedactDiagnostic(cmdArgs) "`n[" what "] " RedactDiagnostic(line), lineNum, this.error ? 3 : 4)
            }
```

Keep existing `testLog` redaction lines unchanged.

- [ ] **Step 4: GREEN**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 155) { throw "static $($s.PassedCount)/$($s.FailedCount)" }
```

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "fix: redact CheckCMD LogAndReturn arguments before logging"
```

- [ ] **Step 6: Review gate** — confirm no raw `-p` path into `Loging` from `LogAndReturn`. `Critical=0`, `Important=0`.

---

### Task 4: Synchronous Diagnostic Recovery Boundary

**Files:**
- Modify: `SmartZip.ahk` — `ShowDiagnostic`, `DiagnosticButtonAction` only (do not yet change `zipx` resume; Task 5)
- Modify: `tests/DiagnosticUI.Tests.ps1` — CaseKeys, host `ResolveArchivePassword` scripting, new commands, new Its
- Modify: `tests/SmartZip.Static.Tests.ps1` — WinWaitClose + recovery assignment Its

**Interfaces:**
- Consumes: existing `ResolveArchivePassword`, `WriteDiagnostic`, `DiagnosticButtons`, batch `RecordBatchDiagnostic`
- Produces: `ShowDiagnostic(...) => ArchiveResult`; recovery object; password success closes window and sets `recovery.resolved`

- [ ] **Step 1: Extend harness host and write failing cases**

In `tests/DiagnosticUI.Tests.ps1` product-host fragment where `ResolveArchivePassword` is defined, replace the stub with a scriptable double:

```ahk
    ResolveArchivePassword(path, probeResult := "") {
        this.runCalls.Push({ kind: "retry_password", path: path })
        mode := this.HasOwnProp("passwordRetryMode") ? this.passwordRetryMode : "echo"
        if (mode = "success") {
            r := ArchiveResult(ArchiveStatus.OK, "password", 0, path, "")
            r.passwordUsed := this.HasOwnProp("passwordRetryValue") ? this.passwordRetryValue : "GoodPass"
            return r
        }
        if (mode = "wrong") {
            r := ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "password", 2, path, "")
            return r
        }
        if (mode = "cancel") {
            return ArchiveResult(ArchiveStatus.CANCELLED, "password", 255, path, "")
        }
        return probeResult
    }
```

Add headless recovery command inside `RunDiagnosticUICommand`:

```ahk
    if (cmd = "recovery") {
        status := JsonGet(jsonText, "status", "WRONG_PASSWORD")
        arch := JsonUnescape(JsonGet(jsonText, "archivePath", "D:\\data\\folder\\pack.7z"))
        mode := JsonGet(jsonText, "retryMode", "echo")
        host.passwordRetryMode := mode
        host.passwordRetryValue := JsonGet(jsonText, "retryPassword", "GoodPass")
        r := MakeResult(status, arch, jsonText)
        ; Headless path: simulate recovery boundary by calling product ShowDiagnostic then optional button
        returned := host.ShowDiagnostic(r, false)
        closed := true
        if (JsonGetBool(jsonText, "clickRetry", false)) {
            recovery := { original: r, resolved: "" }
            host.DiagnosticButtonAction("重新输入密码", recovery, arch, "", "", { Destroy: (*) => (closed := true) })
            if (recovery.resolved != "")
                returned := recovery.resolved
            else
                closed := false
        }
        retStatus := returned.status
        retPass := returned.HasOwnProp("passwordUsed") ? returned.passwordUsed : ""
        return '{"key":"' caseKey '","returnStatus":"' EscapeJson(retStatus) '"'
            . ',"passwordUsed":"' EscapeJson(retPass) '"'
            . ',"guiCalls":' host.guiCalls
            . ',"retryCalls":' host.runCalls.Length
            . ',"closed":' (closed ? "true" : "false")
            . ',"leakedPasswordInCopy":false}'
    }
```

**Important:** After product `ShowDiagnostic` is implemented with recovery + `WinWaitClose`, the headless branch must:

1. Still call `DiagnosticShowGui` (existing)
2. Support a host flag `diagAutoClose := true` default so headless tests do not hang
3. When `passwordRetryMode` is set via a pre-show hook, optional auto-invoke is **not** required — tests use `recovery` command that calls `DiagnosticButtonAction` with the recovery object the product creates

Prefer implementing product so headless path builds the same `recovery` object, stores it on `this.lastRecovery`, returns `recovery.resolved` if set else `result`, and never calls `WinWaitClose` when `diagHeadless` or `SmartZipTest_SuppressGui` is active.

Add CaseKeys:

```powershell
    'recovery_returns_original_without_retry',
    'recovery_retry_success_sets_ok_and_closes',
    'recovery_retry_wrong_keeps_window',
    'recovery_retry_cancel_keeps_window',
    'recovery_batch_password_never_opens_gui'
```

Add Its:

```powershell
    It 'recovery_returns_original_without_retry' {
        $out = Invoke-DiagnosticUICase -Command 'recovery' -CaseKey 'recovery_returns_original_without_retry' `
            -Json '{"status":"WRONG_PASSWORD","clickRetry":false}'
        $j = $out | ConvertFrom-Json
        $j.returnStatus | Should Be 'WRONG_PASSWORD'
    }
    It 'recovery_retry_success_sets_ok_and_closes' {
        $out = Invoke-DiagnosticUICase -Command 'recovery' -CaseKey 'recovery_retry_success_sets_ok_and_closes' `
            -Json '{"status":"WRONG_PASSWORD","clickRetry":true,"retryMode":"success","retryPassword":"GoodPass"}'
        $j = $out | ConvertFrom-Json
        $j.returnStatus | Should Be 'OK'
        $j.passwordUsed | Should Be 'GoodPass'
        $j.closed | Should Be $true
        $j.leakedPasswordInCopy | Should Be $false
    }
    It 'recovery_retry_wrong_keeps_window' {
        $out = Invoke-DiagnosticUICase -Command 'recovery' -CaseKey 'recovery_retry_wrong_keeps_window' `
            -Json '{"status":"WRONG_PASSWORD","clickRetry":true,"retryMode":"wrong"}'
        $j = $out | ConvertFrom-Json
        $j.returnStatus | Should Be 'WRONG_PASSWORD'
        $j.closed | Should Be $false
    }
    It 'recovery_retry_cancel_keeps_window' {
        $out = Invoke-DiagnosticUICase -Command 'recovery' -CaseKey 'recovery_retry_cancel_keeps_window' `
            -Json '{"status":"NEED_PASSWORD","clickRetry":true,"retryMode":"cancel"}'
        $j = $out | ConvertFrom-Json
        $j.returnStatus | Should Be 'NEED_PASSWORD'
        $j.closed | Should Be $false
    }
    It 'recovery_batch_password_never_opens_gui' {
        $out = Invoke-DiagnosticUICase -Command 'batch' -CaseKey 'recovery_batch_password_never_opens_gui' `
            -Json '{"callSummary":true}'
        $j = $out | ConvertFrom-Json
        $j.guiCalls | Should Be 0
    }
```

Static Its:

```powershell
    It 'ShowDiagnostic waits with WinWaitClose on interactive GUI path' {
        $show = $script:ShowDiagnosticBody
        if ([string]::IsNullOrEmpty($show)) { $show = $script:SmartZipSource }
        $show | Should Match 'WinWaitClose'
    }

    It 'DiagnosticButtonAction assigns recovery resolved on password success' {
        $src = $script:SmartZipSource
        $src | Should Match '重新输入密码'
        $ok = Test-Regex -Text $src -Pattern `
            '(?s)重新输入密码.{0,400}ResolveArchivePassword.{0,400}(resolved|recovery)'
        $ok | Should Be $true
    }

    It 'DiagnosticButtonAction never extracts or recycles sources' {
        $body = Get-SourceSlice -Source $script:SmartZipSource `
            -StartMarker "`n    DiagnosticButtonAction(" -EndMarker "`n    RunCmdCapture("
        if ([string]::IsNullOrEmpty($body)) { throw 'DiagnosticButtonAction slice missing' }
        $body | Should Not Match 'ExtractArchiveToTemp'
        $body | Should Not Match 'FinalizeExtraction'
        $body | Should Not Match 'RecycleItem'
    }
```

Expected after GREEN: DiagnosticUI `36 + 5 = 41`; static `155 + 3 = 158`.

- [ ] **Step 2: Confirm RED**

```powershell
$ui = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
"UI Passed=$($ui.PassedCount) Failed=$($ui.FailedCount)"
# Expect recovery_* failures and/or static WinWaitClose failure
```

- [ ] **Step 3: Implement `ShowDiagnostic` + `DiagnosticButtonAction`**

Replace `ShowDiagnostic` / `DiagnosticButtonAction` with:

```ahk
    ShowDiagnostic(result, isBatch := false) {
        if IsSet(SmartZipTest_OnResult)
            SmartZipTest_OnResult(result)
        if isBatch {
            this.RecordBatchDiagnostic(result)
            return result
        }
        if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.CANCELLED)
            return result
        this.WriteDiagnostic(result)
        title := this.DiagnosticTitle(result)
        reason := this.DiagnosticReason(result)
        recommendation := this.DiagnosticRecommendation(result)
        buttons := this.DiagnosticButtons(result)
        archiveName := result.archivePath
        SplitPath(result.archivePath, &archiveName)
        partialPath := result.partialOutputDir
        recovery := { original: result, resolved: "" }

        if IsSet(SmartZipTest_SuppressGui) && SmartZipTest_SuppressGui {
            this.lastRecovery := recovery
            return result
        }

        if this.HasOwnProp("diagHeadless") && this.diagHeadless {
            this.DiagnosticShowGui(title, archiveName, reason, recommendation, partialPath, buttons)
            this.lastRecovery := recovery
            if (recovery.resolved != "")
                return recovery.resolved
            return result
        }

        g := Gui("+AlwaysOnTop +MinSize320x180", title)
        g.SetFont("s10")
        g.AddText("w400", "压缩包: " archiveName)
        g.AddText("w400", "原因: " reason)
        g.AddText("w400", "建议: " recommendation)
        g.AddText("w400", "源包已保留")
        if (partialPath != "")
            g.AddText("w400", "部分输出: " partialPath)
        btnHosts := []
        for label in buttons {
            b := g.AddButton("w180", label)
            btnHosts.Push({ ctrl: b, label: label })
        }
        archivePath := result.archivePath
        volumeFirst := result.HasOwnProp("volumeFirst") ? result.volumeFirst : ""
        for item in btnHosts {
            lbl := item.label
            item.ctrl.OnEvent("Click", (*) => this.DiagnosticButtonAction(lbl, recovery, archivePath, volumeFirst, partialPath, g))
        }
        g.OnEvent("Close", (*) => g.Destroy())
        g.Show("AutoSize Center")
        WinWaitClose(g.Hwnd)
        this.lastRecovery := recovery
        if (recovery.resolved != "")
            return recovery.resolved
        return result
    }

    DiagnosticButtonAction(label, recovery, archivePath, volumeFirst, partialPath, g) {
        if IsSet(SmartZipTest_SuppressGui) && SmartZipTest_SuppressGui {
            if (label = "关闭")
                try g.Destroy()
            return
        }
        switch label {
            case "打开部分文件目录":
                if (partialPath != "" && DirExist(partialPath))
                    Run('explorer.exe "' partialPath '"')
            case "重新输入密码":
                try {
                    r := this.ResolveArchivePassword(archivePath, recovery.original)
                    if (r.status = ArchiveStatus.OK || r.status = ArchiveStatus.OK_WITH_WARNING) {
                        recovery.resolved := r
                        try g.Destroy()
                    }
                    ; wrong/cancel: keep diagnostic open; no source mutation
                } catch {
                }
            case "定位首卷":
                target := volumeFirst != "" ? volumeFirst : archivePath
                if (target != "" && FileExist(target))
                    Run('explorer.exe /select,"' target '"')
                else {
                    SplitPath(archivePath, , &dir)
                    if DirExist(dir)
                        Run('explorer.exe "' dir '"')
                }
            case "使用 7-Zip 打开":
                if this.HasOwnProp("DiagnosticRun7zip")
                    this.DiagnosticRun7zip(archivePath)
                else
                    Run('"' this.7zG '" "' archivePath '"')
            case "复制脱敏诊断信息":
                clip := this.FormatDiagnosticCopy(recovery.original)
                if this.HasOwnProp("DiagnosticSetClipboard")
                    this.DiagnosticSetClipboard(clip)
                else
                    A_Clipboard := clip
            case "关闭":
                try g.Destroy()
        }
    }
```

Adapt the product-fragment export end marker if signature/body boundaries break slice detection (`WriteDiagnostic` … `RunCmdCapture` must still extract exactly one of each method name).

Update headless `recovery` command to use `host.lastRecovery` after ShowDiagnostic and invoke `DiagnosticButtonAction("重新输入密码", host.lastRecovery, ...)` with a dummy GUI object `{ Destroy: (*) => 0 }` that sets a closed flag only when product calls Destroy on success.

- [ ] **Step 4: GREEN**

```powershell
$ui = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
if ($ui.FailedCount -ne 0 -or $ui.PassedCount -ne 41) { throw "ui $($ui.PassedCount)/$($ui.FailedCount)" }
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 158) { throw "static $($s.PassedCount)/$($s.FailedCount)" }
$p = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
if ($p.FailedCount -ne 0 -or $p.PassedCount -ne 78) { throw "password $($p.PassedCount)/$($p.FailedCount)" }
```

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/DiagnosticUI.Tests.ps1 tests/DiagnosticUI.Harness.ahk tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "feat: make ShowDiagnostic a synchronous password recovery boundary"
```

- [ ] **Step 6: Review gate**

Verify: batch still noninteractive; wrong password keeps window; success sets resolved and closes; no extract in button handler; return type available for Task 5. `Critical=0`, `Important=0`.

---

### Task 5: zipx Password-Retry Pipeline Resume

**Files:**
- Modify: `SmartZip.ahk` — nested `zipx` only (preflight/test/extract diagnostic call sites)
- Modify: `tests/SmartZip.Static.Tests.ps1` — resume structural Its
- Optional: `tests/ExtractionLifecycle.Tests.ps1` only if static cannot prove fall-through; prefer static

**Interfaces:**
- Consumes: Task 4 `ShowDiagnostic => ArchiveResult`
- Produces: password-class failures resume **one** shared test/extract/finalize path after successful recovery; no pipeline duplication inside the button handler

- [ ] **Step 1: Failing static tests**

```powershell
    It 'zipx captures ShowDiagnostic return for password recovery resume' {
        $u = $script:UnzipBody
        if ([string]::IsNullOrEmpty($u)) { $u = $script:SmartZipSource }
        $ok = Test-Regex -Text $u -Pattern `
            '(?s)(shown|diagResult|recovered)\s*:=\s*this\.ShowDiagnostic\('
        $ok | Should Be $true
    }

    It 'zipx resumes TestArchive or ExtractArchiveToTemp after successful diagnostic return' {
        $u = $script:UnzipBody
        if ([string]::IsNullOrEmpty($u)) { $u = $script:SmartZipSource }
        # After ShowDiagnostic assignment, success status must be able to reach ExtractArchiveToTemp
        $ok = Test-Regex -Text $u -Pattern `
            '(?s)ShowDiagnostic\(.+?(ExtractArchiveToTemp|TestArchive)\s*\('
        $ok | Should Be $true
        # Must not permanently return after every ShowDiagnostic without inspecting status
        $deadEndOnly = Test-Regex -Text $u -Pattern `
            '(?s)ShowDiagnostic\([^)]*\)\s*\r?\n\s*return\s*\r?\n\s*\}'
        # Allow some returns, but require at least one status check on the returned object
        $statusCheck = Test-Regex -Text $u -Pattern `
            '(?s)(shown|diagResult|recovered)\.[Ss]tatus\s*=\s*ArchiveStatus\.(OK|OK_WITH_WARNING)'
        $statusCheck | Should Be $true
    }
```

Expected static after GREEN: `158 + 2 = 160`.

- [ ] **Step 2: Confirm RED** (today: `this.ShowDiagnostic(...); return` with no capture)

- [ ] **Step 3: Restructure `zipx` control flow (minimal, no duplicated extract)**

Replace the preflight failure block and keep a single extract path. Concrete target structure:

```ahk
        zipx(path)
        {
            if this.logLevel
                this.log .= '`n#####`n' path '`n'

            this.continue := false
            this.error := true

            SplitPath(path, &selectedName, &selectedDir)
            siblingNames := []
            loop files selectedDir "\*.*", "F"
                siblingNames.Push(A_LoopFileName)
            volume := DetectVolumeGroup(path, siblingNames)
            if volume.isVolume {
                key := StrLower(volume.firstPath)
                if !this.HasOwnProp("processedVolumeFirst")
                    this.processedVolumeFirst := Map()
                if this.processedVolumeFirst.Has(key) {
                    this.error := false
                    skipResult := ArchiveResult(ArchiveStatus.OK, "probe", 0, path)
                    skipResult.batchBucket := "skipped"
                    this.ShowDiagnostic(skipResult, isBatch)
                    return
                }
                if (volume.missingVolumes.Length || !FileExist(volume.firstPath)) {
                    missing := ArchiveResult(ArchiveStatus.MISSING_VOLUME, "probe", 2, path)
                    missing.volumeFirst := volume.firstPath
                    missing.missingVolumes := volume.missingVolumes
                    this.ShowDiagnostic(missing, isBatch)
                    return
                }
                this.processedVolumeFirst[key] := true
                path := volume.firstPath
            }

            probe := this.ProbeArchive(path)
            if volume.isVolume
                probe.volumeFirst := volume.firstPath
            if this.logLevel
                this.Loging("probe status=" probe.status " exit=" probe.exitCode, A_LineNumber, 4)

            resolved := this.ResolveArchivePassword(path, probe)
            if this.logLevel
                this.Loging("resolve status=" resolved.status " exit=" resolved.exitCode, A_LineNumber, 4)

            ; Password recovery may require one resume of the shared pipeline
            Loop 2 {
                if (resolved.status != ArchiveStatus.OK && resolved.status != ArchiveStatus.OK_WITH_WARNING) {
                    this.error := true
                    if (resolved.status = ArchiveStatus.CANCELLED)
                        this.exitCode := 255
                    shown := this.ShowDiagnostic(resolved, isBatch)
                    if (!isBatch
                        && (shown.status = ArchiveStatus.OK || shown.status = ArchiveStatus.OK_WITH_WARNING)
                        && A_Index = 1) {
                        resolved := shown
                        ; fall through into shared pipeline below
                    } else {
                        return
                    }
                }

                this.error := false

                mayHandleSource := (!loopPath) && !volume.isVolume
                    && (this.delSource || (resolved.passwordUsed != "" && this.delWhenHasPass))
                nestedMayRecycle := loopPath && !volume.isVolume
                    && (resolved.status = ArchiveStatus.OK)
                forceTest := this.test || mayHandleSource || nestedMayRecycle
                if (forceTest) {
                    tr := this.TestArchive(path, resolved.passwordUsed)
                    if (tr.status = ArchiveStatus.OK_WITH_WARNING) {
                        mayHandleSource := false
                        nestedMayRecycle := false
                    } else if (tr.status = ArchiveStatus.DATA_CORRUPT) {
                        this.error := true
                        mayHandleSource := false
                        nestedMayRecycle := false
                    } else if (tr.status != ArchiveStatus.OK) {
                        this.error := true
                        if (tr.status = ArchiveStatus.CANCELLED)
                            this.exitCode := 255
                        shown := this.ShowDiagnostic(tr, isBatch)
                        if (!isBatch
                            && (tr.status = ArchiveStatus.NEED_PASSWORD || tr.status = ArchiveStatus.WRONG_PASSWORD)
                            && (shown.status = ArchiveStatus.OK || shown.status = ArchiveStatus.OK_WITH_WARNING)
                            && A_Index = 1) {
                            resolved := shown
                            continue  ; resume shared pipeline once with new password
                        }
                        return
                    }
                }

                extractResult := this.ExtractArchiveToTemp(path, resolved.passwordUsed, tmpDir)

                mayDel := false
                if (resolved.status = ArchiveStatus.OK
                    && extractResult.status = ArchiveStatus.OK
                    && extractResult.exitCode = 0
                    && !volume.isVolume) {
                    if (loopPath)
                        mayDel := false
                    else if mayHandleSource
                        mayDel := true
                }

                extractResult := this.FinalizeExtraction(path, extractResult, tmpDir, A_WorkingDir, mayDel)

                if (nestedMayRecycle && extractResult.isCleanSuccess && !volume.isVolume && FileExist(path))
                    this.RecycleItem(path, A_LineNumber, false)

                if (!isBatch
                    && (extractResult.status = ArchiveStatus.NEED_PASSWORD || extractResult.status = ArchiveStatus.WRONG_PASSWORD)
                    && A_Index = 1) {
                    shown := this.ShowDiagnostic(extractResult, isBatch)
                    if (shown.status = ArchiveStatus.OK || shown.status = ArchiveStatus.OK_WITH_WARNING) {
                        resolved := shown
                        continue
                    }
                    return
                }

                this.ShowDiagnostic(extractResult, isBatch)
                break
            }
        }
```

Hard rules:

- `Loop 2` allows at most **one** recovery resume (prevents infinite password loops).
- Batch path never opens password GUI (`ShowDiagnostic` batch branch unchanged).
- After resume, recompute `mayHandleSource` / `forceTest` / `nestedMayRecycle` / `mayDel`.
- Source delete still requires clean `OK` only; volumes never deleted.
- Do not call extract inside `DiagnosticButtonAction`.

- [ ] **Step 4: GREEN**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 160) { throw "static $($s.PassedCount)/$($s.FailedCount)" }
$ui = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
if ($ui.FailedCount -ne 0 -or $ui.PassedCount -ne 41) { throw "ui $($ui.PassedCount)/$($ui.FailedCount)" }
$p = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
if ($p.FailedCount -ne 0 -or $p.PassedCount -ne 78) { throw "password" }
$l = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
if ($l.FailedCount -ne 0 -or $l.PassedCount -ne 26) { throw "lifecycle" }
```

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "feat: resume zipx pipeline after successful password diagnostic retry"
```

- [ ] **Step 6: Review gate**

Confirm full-test requirement still protects source handling; no permanent delete; at most one resume; batch noninteractive. `Critical=0`, `Important=0`.

---

### Task 6: Batch Summary Failed Basenames

**Files:**
- Modify: `SmartZip.ahk` — add `FormatBatchDiagnosticSummary`; use it from `ShowBatchDiagnosticSummary`
- Modify: `tests/DiagnosticUI.Tests.ps1` — summary text fields + Its
- Modify: `tests/SmartZip.Static.Tests.ps1` — one structural It

**Interfaces:**
- Consumes: `batchDiagnostic.failure[]` with `archivePath`
- Produces: `FormatBatchDiagnosticSummary(b) => String` with ≤3 basenames and ` ... (+N)`

- [ ] **Step 1: Failing tests**

Extend batch command JSON output to include `summaryText` even in headless mode:

```ahk
        summaryText := host.FormatBatchDiagnosticSummary(host.batchDiagnostic)
        if JsonGetBool(jsonText, "callSummary", true)
            host.ShowBatchDiagnosticSummary()
        return '{..."summaryText":"' EscapeJson(summaryText) '"...}'
```

Add CaseKeys + Its:

```powershell
    It 'batch_summary_failed_basenames_max_three' {
        # Drive four failures via extended batch specs or dedicated command batch_failures
        $out = Invoke-DiagnosticUICase -Command 'batch_failures' -CaseKey 'batch_summary_failed_basenames_max_three' `
            -Json '{"paths":["D:\\x\\a.7z","D:\\x\\b.7z","D:\\x\\c.7z"]}'
        $j = $out | ConvertFrom-Json
        $j.summaryText | Should Match 'a\.7z'
        $j.summaryText | Should Match 'b\.7z'
        $j.summaryText | Should Match 'c\.7z'
        $j.summaryText | Should Not Match 'D:\\x\\'
    }
    It 'batch_summary_failed_basenames_ellipsis' {
        $out = Invoke-DiagnosticUICase -Command 'batch_failures' -CaseKey 'batch_summary_failed_basenames_ellipsis' `
            -Json '{"paths":["D:\\x\\a.7z","D:\\x\\b.7z","D:\\x\\c.7z","D:\\x\\d.7z"]}'
        $j = $out | ConvertFrom-Json
        $j.summaryText | Should Match 'a\.7z'
        $j.summaryText | Should Match 'b\.7z'
        $j.summaryText | Should Match 'c\.7z'
        $j.summaryText | Should Match '\.\.\. \(\+1\)'
        $j.summaryText | Should Not Match 'd\.7z'
        $j.summaryText | Should Not Match 'D:\\x\\'
    }
    It 'batch_summary_no_password_material' {
        $out = Invoke-DiagnosticUICase -Command 'batch_failures' -CaseKey 'batch_summary_no_password_material' `
            -Json '{"paths":["D:\\secret\\vault.7z"],"passwordUsed":"S3cret!"}'
        $j = $out | ConvertFrom-Json
        $j.summaryText | Should Not Match 'S3cret'
        $j.summaryText | Should Match 'vault\.7z'
    }
```

Implement `batch_failures` command: N `DATA_CORRUPT` results with given paths, then `FormatBatchDiagnosticSummary`.

Static:

```powershell
    It 'ShowBatchDiagnosticSummary limits failed basenames to three with ellipsis' {
        $src = $script:SmartZipSource
        $src | Should Match 'FormatBatchDiagnosticSummary'
        $ok = Test-Regex -Text $src -Pattern `
            '(?s)FormatBatchDiagnosticSummary.{0,800}(3|\+\)|\.\.\.)'
        $ok | Should Be $true
    }
```

Expected: DiagnosticUI `41 + 3 = 44`; static `160 + 1 = 161`.

- [ ] **Step 2: Confirm RED**

- [ ] **Step 3: Implementation**

```ahk
    FormatBatchDiagnosticSummary(b) {
        sc := b.success.Length
        wc := b.warning.Length
        fc := b.failure.Length
        kc := b.skipped.Length
        msg := "批量解压完成`n成功: " sc "`n警告: " wc "`n失败: " fc "`n跳过: " kc
        if (fc > 0) {
            names := []
            limit := fc < 3 ? fc : 3
            i := 1
            while (i <= limit) {
                p := b.failure[i].archivePath
                SplitPath(p, &bn)
                if (bn = "")
                    bn := p
                names.Push(bn)
                i++
            }
            msg .= "`n失败文件: "
            j := 1
            while (j <= names.Length) {
                if (j > 1)
                    msg .= ", "
                msg .= names[j]
                j++
            }
            if (fc > 3)
                msg .= " ... (+" (fc - 3) ")"
        }
        return msg
    }

    ShowBatchDiagnosticSummary() {
        if this.HasOwnProp("summaryCalls")
            this.summaryCalls++
        if !this.HasOwnProp("batchDiagnostic")
            return
        b := this.batchDiagnostic
        if this.HasOwnProp("diagHeadless") && this.diagHeadless {
            this.guiCalls := this.HasOwnProp("guiCalls") ? this.guiCalls : 0
            this.lastBatchSummaryText := this.FormatBatchDiagnosticSummary(b)
            return
        }
        msg := this.FormatBatchDiagnosticSummary(b)
        this.lastBatchSummaryText := msg
        try TrayTip("SmartZip", msg)
        catch {
            MsgBox(msg, "SmartZip 批量摘要", "Iconi T5")
        }
    }
```

- [ ] **Step 4: GREEN**

```powershell
$ui = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
if ($ui.FailedCount -ne 0 -or $ui.PassedCount -ne 44) { throw "ui" }
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 161) { throw "static" }
```

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/DiagnosticUI.Tests.ps1 tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "feat: append up to three failed basenames in batch summary"
```

- [ ] **Step 6: Review gate** — basenames only, no paths/passwords, tray/MsgBox only. `Critical=0`, `Important=0`.

---

### Task 7: Production Hook Removal and TEMP Integration Injection

**Files:**
- Modify: `SmartZip.ahk` — delete `#Include *i tests\IntegrationTestHook.ahk` (keep all `IsSet(SmartZipTest_*)` guards)
- Modify: `tests/Real7Zip.Integration.Tests.ps1` — TEMP source injection after library include
- Modify: `tests/SmartZip.Static.Tests.ps1` — production source must not reference IntegrationTestHook include
- Modify: `tests/README.md` — injection model + suite counts (`Real7Zip` baseline 30 + new injection Its)

**Interfaces:**
- Consumes: production line `#Include lib\ArchiveDiagnostics.ahk`
- Produces: TEMP-only line `#Include *i tests\IntegrationTestHook.ahk` inserted immediately after that include; production source never contains it

- [ ] **Step 1: Failing static + integration injection tests**

Static:

```powershell
    It 'production SmartZip.ahk includes ArchiveDiagnostics library' {
        $script:SmartZipSource | Should Match '(?m)^#Include\s+lib\\ArchiveDiagnostics\.ahk\s*$'
    }

    It 'production SmartZip.ahk does not include IntegrationTestHook' {
        $script:SmartZipSource | Should Not Match 'IntegrationTestHook'
        $script:SmartZipSource | Should Not Match '(?i)#Include\s+\*?i?\s*tests\\'
    }

    It 'production source keeps IsSet test hook guards without defining callbacks' {
        $script:SmartZipSource | Should Match 'IsSet\(\s*SmartZipTest_OnResult\s*\)'
        $script:SmartZipSource | Should Match 'IsSet\(\s*SmartZipTest_SuppressGui\s*\)'
        $script:SmartZipSource | Should Match 'IsSet\(\s*SmartZipTest_PasswordDialog\s*\)'
        $script:SmartZipSource | Should Not Match '(?m)^SmartZipTest_OnResult\s*\('
        $script:SmartZipSource | Should Not Match '(?m)^SmartZipTest_PasswordDialog\s*\('
    }
```

In `Real7Zip.Integration.Tests.ps1` After compile setup, add Its (or BeforeAll assertions that feed Its):

```powershell
    It 'integration compile source injects hook after ArchiveDiagnostics include' {
        $tempSrc = Get-Content -LiteralPath $script:InjectedSmartZipPath -Raw -Encoding UTF8
        $tempSrc | Should Match '(?m)^#Include\s+lib\\ArchiveDiagnostics\.ahk\s*$'
        $tempSrc | Should Match '(?m)^#Include\s+\*i\s+tests\\IntegrationTestHook\.ahk\s*$'
        $libIdx = $tempSrc.IndexOf('#Include lib\ArchiveDiagnostics.ahk')
        $hookIdx = $tempSrc.IndexOf('#Include *i tests\IntegrationTestHook.ahk')
        $classIdx = $tempSrc.IndexOf('class SmartZip')
        ($libIdx -ge 0 -and $hookIdx -gt $libIdx -and $classIdx -gt $hookIdx) | Should Be $true
    }

    It 'repository SmartZip.ahk has no hook include while TEMP source does' {
        $repo = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'SmartZip.ahk') -Raw -Encoding UTF8
        $repo | Should Not Match 'IntegrationTestHook'
        $tempSrc = Get-Content -LiteralPath $script:InjectedSmartZipPath -Raw -Encoding UTF8
        $tempSrc | Should Match 'IntegrationTestHook'
    }
```

Expected: static `161 + 3 = 164`; integration `30 + 2 = 32`.

- [ ] **Step 2: Confirm RED**

Removing the include without injection makes integration fail (callbacks unset). Static “does not include IntegrationTestHook” fails while line 34 still present. Write tests first; observe RED; then implement.

- [ ] **Step 3: Remove production include**

Delete from `SmartZip.ahk`:

```ahk
#Include *i tests\IntegrationTestHook.ahk
```

Keep:

```ahk
#Include lib\ArchiveDiagnostics.ahk
```

- [ ] **Step 4: Inject into TEMP integration source**

Replace the integration BeforeAll copy of SmartZip with:

```powershell
                $prodSmartZip = Join-Path $script:RepoRoot 'SmartZip.ahk'
                $prodText = Get-Content -LiteralPath $prodSmartZip -Raw -Encoding UTF8
                if ($prodText -match 'IntegrationTestHook') {
                    throw 'production SmartZip.ahk must not reference IntegrationTestHook'
                }
                if ($prodText -notmatch '(?m)^#Include\s+lib\\ArchiveDiagnostics\.ahk\s*$') {
                    throw 'production SmartZip.ahk missing ArchiveDiagnostics include'
                }
                $injected = [regex]::Replace(
                    $prodText,
                    '(?m)^(#Include\s+lib\\ArchiveDiagnostics\.ahk)\s*$',
                    "`$1`r`n#Include *i tests\IntegrationTestHook.ahk",
                    1
                )
                if ($injected -eq $prodText) {
                    throw 'failed to inject IntegrationTestHook after ArchiveDiagnostics include'
                }
                $script:InjectedSmartZipPath = Join-Path $buildRoot 'SmartZip.ahk'
                [IO.File]::WriteAllText($script:InjectedSmartZipPath, $injected, [Text.UTF8Encoding]::new($false))
                Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk') -Destination (Join-Path $libDir 'ArchiveDiagnostics.ahk') -Force
                Copy-Item -LiteralPath $script:HookAhk -Destination (Join-Path $testsDir 'IntegrationTestHook.ahk') -Force
                # Compile $script:InjectedSmartZipPath only — never compile repo SmartZip.ahk for integration
```

Update TEMP root naming comment to `SmartZip-Kirs3-<guid>` if the suite creates a root string.

Update `tests/README.md`:

- Document that production source has **no** optional hook include.
- Document TEMP injection after `#Include lib\ArchiveDiagnostics.ahk`.
- Fix expected counts table to final Task 7 values for suites touched so far; full table finalized in Task 8.
- Integration expected count **32** after this task’s two Its.

- [ ] **Step 5: GREEN**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 164) { throw "static" }
$i = Invoke-Pester -Script .\tests\Real7Zip.Integration.Tests.ps1 -PassThru
if ($i.FailedCount -ne 0 -or $i.PassedCount -ne 32) { throw "integration $($i.PassedCount)/$($i.FailedCount)" }
# All prior behavior suites still green
foreach ($pair in @(
    @{ f='ArchiveDiagnostics.Tests.ps1'; n=161 },
    @{ f='RunCmdCapture.Tests.ps1'; n=15 },
    @{ f='PasswordPreflight.Tests.ps1'; n=78 },
    @{ f='ExtractionLifecycle.Tests.ps1'; n=26 },
    @{ f='NestingMigration.Tests.ps1'; n=30 },
    @{ f='DiagnosticUI.Tests.ps1'; n=44 }
)) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $pair.f) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $pair.n) {
        throw "$($pair.f): $($r.PassedCount)/$($r.FailedCount) expected $($pair.n)/0"
    }
}
```

- [ ] **Step 6: Commit**

```powershell
git add -- SmartZip.ahk tests/Real7Zip.Integration.Tests.ps1 tests/SmartZip.Static.Tests.ps1 tests/README.md
git diff --check --cached
git commit -m "build: remove production test hook include; inject only in TEMP integration source"
```

- [ ] **Step 6b: Review gate**

Reviewer must confirm: repo source has zero IntegrationTestHook include; TEMP inject order library → hook → class; production staging path still copies no `tests\`; `IsSet` guards remain. `Critical=0`, `Important=0`.

---

### Task 8: Kirs.3 Metadata, Documentation, and Whole-Branch Verification

**Files:**
- Modify: `SmartZip.ahk` — `edition`, `buildVersion`, `;@Ahk2Exe-SetProductVersion`, `buileTime` (set to actual build stamp when committing this task)
- Modify: `tests/SmartZip.Static.Tests.ps1` — VersionBanner + rename/extend `Kirs2MetadataAndDocs` → `Kirs3MetadataAndDocs`
- Modify: `README.md` — Kirs.3 convenience section; preserve Kirs.2 safety pipeline docs
- Modify: `ini.md` — `partSkip` semantics; Kirs.3 notes
- Modify: `tests/README.md` — final exact suite table

**Interfaces:**
- Consumes: all prior task behaviors
- Produces: identity `SmartZip 3.6 Kirs.3 (23)`; docs match behavior; whole-branch green gate

- [ ] **Step 1: Write/update failing metadata tests first**

Update existing VersionBanner Its in place (same three Its, new expected values):

```powershell
    It 'edition is Kirs.3' {
        $script:SmartZipSource | Should Match 'edition\s*:=\s*"Kirs\.3"'
    }
    It 'buildVersion is 23' {
        $script:SmartZipSource | Should Match 'buildVersion\s*:=\s*23\b'
    }
    It 'Ahk2Exe product version is 23' {
        $script:SmartZipSource |
            Should Match ';@Ahk2Exe-SetProductVersion\s+23\b'
    }
```

Rename About It to `shows SmartZip 3.6 Kirs.3 build 23` (expression assertion unchanged).

Replace Describe `Kirs2MetadataAndDocs` with `Kirs3MetadataAndDocs` and update every It title/body from Kirs.2/22 to Kirs.3/23. Add:

```powershell
    It 'Kirs3 README documents convenience recovery and volume selection' {
        $script:ReadmeText | Should Match 'Kirs\.3'
        $okRetry = Test-Regex -Text $script:ReadmeText -Pattern '重新输入密码|password.?retry|密码重试'
        $okVol = Test-Regex -Text $script:ReadmeText -Pattern '(?s)(任一卷|非首卷|any member).{0,120}(首卷|first)'
        $okNum = Test-Regex -Text $script:ReadmeText -Pattern 'report\.2024|普通数字|numeric'
        ($okRetry -and $okVol -and $okNum) | Should Be $true
    }

    It 'Kirs3 ini partSkip documents same-group once semantics' {
        $script:IniDocText | Should Match 'partSkip'
        $ok = Test-Regex -Text $script:IniDocText -Pattern `
            '(?s)partSkip.{0,200}(同组|一次|首卷|any member|from the first)'
        $ok | Should Be $true
        $legacyOnly = Test-Regex -Text $script:IniDocText -Pattern `
            '(?s)partSkip.{0,80}跳过非第一卷\s*$'
        # Row may still mention compatibility but must not be the sole definition
        $script:IniDocText | Should Match '同组|首卷|一次'
    }

    It 'Kirs3 docs do not claim replacing Kirs.2 history' {
        $combined = $script:ReadmeText + "`n" + $script:IniDocText
        $replaced = Test-Regex -Text $combined -Pattern `
            '(?i)(Kirs\.2\s*(已被?替换|is\s+replaced)|replaces?\s+Kirs\.2|替代\s*Kirs\.2)'
        $replaced | Should Be $false
    }

    It 'Kirs3 production source has no IntegrationTestHook include' {
        $script:SmartZipSource | Should Not Match 'IntegrationTestHook'
    }
```

Count the Describe’s Its carefully after rewrite. Target final static **172** if baseline 164 + 8 net new metadata/docs Its (adjust if renames keep counts: measure with Pester after writing tests, lock the number in Step 4).

- [ ] **Step 2: Confirm RED** on edition/build/product version mismatches

- [ ] **Step 3: Apply metadata + docs**

`SmartZip.ahk` header:

```ahk
;@Ahk2Exe-SetFileVersion 3.6
;@Ahk2Exe-SetProductVersion 23
;@Ahk2Exe-ExeName SmartZip.exe
buildVersion := 23
MainVersion := "3.6"
edition := "Kirs.3"
buileTime := "2026/7/23 12:00:00"  ; set to actual local stamp at commit time
```

`README.md` — add section `## 3.6 Kirs.3 便利与恢复` covering:

- Selecting any volume member of a complete set extracts once from the first
- Incomplete sets → `MISSING_VOLUME` + 定位首卷
- Pattern D numeric evidence (`report.2024` ordinary; `data.001`/`archive.7z.001` volumes)
- Password diagnostic stays open until close or successful retry; retry resumes normal pipeline
- Batch summary lists ≤3 failed basenames
- Production builds exclude test hooks
- Explicit note: Kirs.3 is a new release line; does not replace Kirs.2 tags/releases
- Keep the existing Kirs.2 safety pipeline section (or fold with clear subheads) so safety guarantees remain documented

`ini.md` — update `partSkip` row:

| partSkip | set | 2.21(14)/Kirs.3 | 1 | 分卷同组只解压一次（兼容键） | 任一卷从首卷开始；同组多选只解压一次；不再静默跳过非首卷 |

Add Kirs.3 note block for password retry, batch basenames, Pattern D.

Settings checkbox tip (if not done in Task 2):

```ahk
    GuiCheckBox("partSkip", ini.partSkip, "分卷同组只解压一次", "任一卷从首卷开始；同组多选只解压一次`n分卷不会自动删除", "Section")
```

`tests/README.md` final table:

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=172
  'ArchiveDiagnostics.Tests.ps1'=161
  'RunCmdCapture.Tests.ps1'=15
  'PasswordPreflight.Tests.ps1'=78
  'ExtractionLifecycle.Tests.ps1'=26
  'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=44
  'Real7Zip.Integration.Tests.ps1'=32
}
```

If measured counts differ after implementation, update **both** the tests and this table to the measured green totals before commit — never leave a mismatch.

- [ ] **Step 4: Whole-branch GREEN gate**

```powershell
$ErrorActionPreference = 'Stop'
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=172
  'ArchiveDiagnostics.Tests.ps1'=161
  'RunCmdCapture.Tests.ps1'=15
  'PasswordPreflight.Tests.ps1'=78
  'ExtractionLifecycle.Tests.ps1'=26
  'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=44
  'Real7Zip.Integration.Tests.ps1'=32
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
```

Engine check:

```powershell
& 'C:\Tool\7-Zip-Zstandard\7z.exe' i | Select-Object -First 5
```

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 tests/README.md README.md ini.md
git diff --check --cached
git commit -m "docs: prepare SmartZip 3.6 Kirs.3"
```

- [ ] **Step 6: Review gate**

Identity consistency, docs match behavior, no password in diffs, Kirs.2 history not claimed replaced, hook absent from production source. `Critical=0`, `Important=0`.

---

### Task 9: Build, Smoke-Test, Deploy, and Publish v3.6-kirs.3

**Outputs:**

- Build: `%TEMP%\smartzip-kirs3-build-<stamp>\SmartZip.exe`
- Deploy: `C:\Tool\SmartZip\SmartZip.exe`
- Backup: `C:\Tool\SmartZip\SmartZip.exe.bak-<stamp>`
- Branch: `codex/kirs3-convenience`
- Tag/Release: `v3.6-kirs.3`
- Release asset: `SmartZip.exe`

Every stop condition below is mandatory. Do not deploy, push, tag, or publish after a failed command.

- [ ] **Step 1: Freeze prior-release evidence and verify source/toolchain**

```powershell
$ErrorActionPreference = 'Stop'
$repo = 'kirsartx/SmartZip'
$oldTag1 = (git ls-remote origin refs/tags/v3.6-kirs.1).Split()[0]
$oldTag2 = (git ls-remote origin refs/tags/v3.6-kirs.2).Split()[0]
$oldRelease1 = gh release view v3.6-kirs.1 --repo $repo --json tagName,targetCommitish,url,assets | ConvertFrom-Json
$oldRelease2 = gh release view v3.6-kirs.2 --repo $repo --json tagName,targetCommitish,url,assets | ConvertFrom-Json
$oldRelease1Json = $oldRelease1 | ConvertTo-Json -Depth 8 -Compress
$oldRelease2Json = $oldRelease2 | ConvertTo-Json -Depth 8 -Compress

$suites = [ordered]@{
  'SmartZip.Static.Tests.ps1'=172; 'ArchiveDiagnostics.Tests.ps1'=161
  'RunCmdCapture.Tests.ps1'=15; 'PasswordPreflight.Tests.ps1'=78
  'ExtractionLifecycle.Tests.ps1'=26; 'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=44; 'Real7Zip.Integration.Tests.ps1'=32
}
foreach ($item in $suites.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }

$sevenZip = 'C:\Tool\7-Zip-Zstandard\7z.exe'
if (-not (Test-Path $sevenZip)) { throw '7-Zip executable missing' }
& $sevenZip i | Select-Object -First 5

$ahkBase = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'
$ahkCompiler = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe'
$expectedBase = 'A2A54B8ABC476D7671D4DE0771BB54BF5F2373D79FF6871D0BA6A62C3B88AE00'
$expectedCompiler = 'E54A599B19BAA5C1688849BBAE7A9CF049EEFCCD4F704C67941B40DA13A625B2'
if ((Get-FileHash $ahkBase -Algorithm SHA256).Hash -ne $expectedBase) { throw 'AutoHotkey base hash mismatch' }
if ((Get-FileHash $ahkCompiler -Algorithm SHA256).Hash -ne $expectedCompiler) { throw 'Ahk2Exe hash mismatch' }

$prodSrc = Get-Content -LiteralPath .\SmartZip.ahk -Raw -Encoding UTF8
if ($prodSrc -match 'IntegrationTestHook') { throw 'production source still references IntegrationTestHook' }
```

Expected: every exact suite count passes; engine identifies Zstandard build; trusted hashes match; production source clean of hook include. Record `$oldTag1`, `$oldTag2`, `$oldRelease1Json`, `$oldRelease2Json`.

- [ ] **Step 2: Ensure clean final commit on `codex/kirs3-convenience`**

```powershell
git status --short --branch
git diff --check
git log --oneline --decorate -12
# If any intentional uncommitted Task 1–8 residue remains:
git add -- SmartZip.ahk lib tests README.md ini.md docs/superpowers/plans/2026-07-23-smartzip-kirs3-convenience.md
git diff --check --cached
git diff --cached --stat
git commit -m "feat: release SmartZip 3.6 Kirs.3"
if (git status --porcelain) { throw 'worktree is not clean after final commit' }
$releaseCommit = git rev-parse HEAD
```

Never stage `.superpowers`, TEMP fixtures, credentials, deployed files, backups, or unrelated user changes. If Tasks 1–8 already committed everything, omit an empty commit and set `$releaseCommit = git rev-parse HEAD`.

- [ ] **Step 3: Compile production staging tree (hook-free)**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$buildDir = Join-Path $env:TEMP "smartzip-kirs3-build-$stamp"
$buildSource = Join-Path $buildDir 'src'
New-Item -ItemType Directory -Path $buildSource,(Join-Path $buildSource 'lib') | Out-Null
Copy-Item .\SmartZip.ahk (Join-Path $buildSource 'SmartZip.ahk')
Copy-Item .\ico.ico (Join-Path $buildSource 'ico.ico')
Copy-Item .\lib\*.ahk (Join-Path $buildSource 'lib')
if (Test-Path (Join-Path $buildSource 'tests')) { throw 'production staging must not contain test hooks' }
$staged = Get-Content (Join-Path $buildSource 'SmartZip.ahk') -Raw -Encoding UTF8
if ($staged -match 'IntegrationTestHook') { throw 'staged source contains IntegrationTestHook' }
if ($staged -match 'SMARTZIP_TEST_RESULT_V1') { throw 'staged source contains test result marker' }
$builtExe = Join-Path $buildDir 'SmartZip.exe'
$source = Join-Path $buildSource 'SmartZip.ahk'
$compile = Start-Process -FilePath $ahkCompiler `
  -ArgumentList @('/in',$source,'/out',$builtExe,'/base',$ahkBase) `
  -WorkingDirectory $buildSource -WindowStyle Hidden -Wait -PassThru
if ($compile.ExitCode -ne 0 -or -not (Test-Path $builtExe) -or (Get-Item $builtExe).Length -eq 0) {
    throw 'compile failed'
}
$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($builtExe)
if ($version.FileVersion -notmatch '^3\.6(\.0\.0)?$') { throw "unexpected FileVersion $($version.FileVersion)" }
if ($version.ProductVersion -notmatch '^23(\.0\.0)?$') { throw "unexpected ProductVersion $($version.ProductVersion)" }
$builtHash = (Get-FileHash $builtExe -Algorithm SHA256).Hash
$version | Select-Object FileVersion,ProductVersion,ProductName
"BUILT_SHA256=$builtHash"
$exeBytes = [IO.File]::ReadAllBytes($builtExe)
$exeText = [Text.Encoding]::Unicode.GetString($exeBytes) + [Text.Encoding]::UTF8.GetString($exeBytes)
if ($exeText.Contains('SMARTZIP_TEST_RESULT_V1')) { throw 'test hook leaked into production artifact' }
```

- [ ] **Step 4: Smoke-test the exact artifact in isolated TEMP**

Do not use the hook-aware integration result serializer against `$builtExe`.

```powershell
$smokeRoot = Join-Path $env:TEMP "smartzip-kirs3-smoke-$stamp"
$fixtureRoot = Join-Path $smokeRoot 'fixtures'
$manifestPath = Join-Path $smokeRoot 'fixtures.json'
$artifactSmokeRoot = Join-Path $smokeRoot 'built-artifact'
New-Item -ItemType Directory -Path $smokeRoot,$fixtureRoot,$artifactSmokeRoot | Out-Null

$fixturePassword = "K3-$([guid]::NewGuid().ToString('N'))!"
$env:SMARTZIP_FIXTURE_PASSWORD = $fixturePassword
try {
    $manifestJson = (& .\tests\New-ExtractionReliabilityFixtures.ps1 `
        -Root $fixtureRoot -SevenZip $sevenZip | Out-String).Trim()
    [IO.File]::WriteAllText($manifestPath, $manifestJson, [Text.UTF8Encoding]::new($false))

    $reportJson = (& .\tests\Invoke-ProductionSmartZipSmoke.ps1 `
        -SmartZipExe $builtExe -FixtureManifest $manifestPath `
        -Root $artifactSmokeRoot -AhkExe $ahkBase -SevenZip $sevenZip | Out-String).Trim()
    if ($reportJson -match [regex]::Escape($fixturePassword)) {
        throw 'fixture password leaked into production smoke report'
    }
    $artifactSmoke = $reportJson | ConvertFrom-Json
    if (-not $artifactSmoke.Passed -or $artifactSmoke.LeakedProcessCount -ne 0) {
        throw "production artifact smoke failed: $reportJson"
    }
    foreach ($name in 'valid','crcPartial','splitMissing','encryptedHeader') {
        if (-not ($artifactSmoke.Scenarios.PSObject.Properties.Name -contains $name)) {
            throw "production smoke omitted scenario: $name"
        }
    }
} finally {
    Remove-Item Env:SMARTZIP_FIXTURE_PASSWORD -ErrorAction SilentlyContinue
}
```

Simple CLI creation/extraction:

```powershell
$cliRoot = Join-Path $smokeRoot 'simple-cli'
$smokeBin = Join-Path $cliRoot 'bin'
$smokeWork = Join-Path $cliRoot 'work'
New-Item -ItemType Directory -Path $smokeBin,$smokeWork | Out-Null
Copy-Item $builtExe (Join-Path $smokeBin 'SmartZip.exe')
$smokeIni = Join-Path $smokeBin 'SmartZip.ini'
$ini = @"
[set]
zipDir=C:\Tool\7-Zip-Zstandard
nesting=1
nestingMuilt=1
partSkip=1
delSource=0
targetDir=$smokeWork
test=1
logLevel=0
cmdLog=1
successPercent=90

[ext]
1=zip
2=rar
3=7z
4=001

[extExp]
1=^\d+$
"@
[IO.File]::WriteAllText($smokeIni, $ini, [Text.UnicodeEncoding]::new($false, $true))
$smokeExe = Join-Path $smokeBin 'SmartZip.exe'
$payload = Join-Path $smokeWork 'payload.txt'
[IO.File]::WriteAllText($payload, 'SmartZip 3.6 Kirs.3 smoke', [Text.UTF8Encoding]::new($false))
& $sevenZip a -t7z (Join-Path $smokeWork 'payload.7z') $payload
if ($LASTEXITCODE -ne 0) { throw 'fixture archive creation failed' }
Remove-Item -LiteralPath $payload
$x = Start-Process $smokeExe -ArgumentList @('x',(Join-Path $smokeWork 'payload.7z')) `
  -WorkingDirectory $smokeBin -Wait -PassThru
if ($x.ExitCode -ne 0 -or -not (Test-Path $payload)) { throw 'compiled extraction smoke failed' }
```

Re-run the full Step 1 suite loop after smoke. Any failure stops before deployment.

- [ ] **Step 5: Back up and deploy only the tested EXE to `C:\Tool\SmartZip`**

```powershell
$deployDir = 'C:\Tool\SmartZip'
$deployExe = Join-Path $deployDir 'SmartZip.exe'
$backupExe = Join-Path $deployDir "SmartZip.exe.bak-$stamp"
$iniPath = Join-Path $deployDir 'SmartZip.ini'
$contextPath = Join-Path $deployDir 'Contextmenu.exe'
$iniHashBefore = (Get-FileHash $iniPath -Algorithm SHA256).Hash
$contextHashBefore = (Get-FileHash $contextPath -Algorithm SHA256).Hash

$running = Get-Process SmartZip,Contextmenu,7z,7zG,7zFM -ErrorAction SilentlyContinue
if ($running) { throw "close running archive processes before deployment: $($running.Name -join ', ')" }
Copy-Item $deployExe $backupExe
Copy-Item $builtExe $deployExe -Force

$deployedHash = (Get-FileHash $deployExe -Algorithm SHA256).Hash
$iniHashAfter = (Get-FileHash $iniPath -Algorithm SHA256).Hash
$contextHashAfter = (Get-FileHash $contextPath -Algorithm SHA256).Hash
if ($deployedHash -ne $builtHash -or $iniHashAfter -ne $iniHashBefore -or
    $contextHashAfter -ne $contextHashBefore) {
    Copy-Item $backupExe $deployExe -Force
    throw 'deployment verification failed; backup restored'
}
```

Re-run production smoke against deployed EXE from TEMP fixtures only:

```powershell
$deployedSmokeRoot = Join-Path $smokeRoot 'deployed-artifact'
New-Item -ItemType Directory -Path $deployedSmokeRoot | Out-Null
$env:SMARTZIP_FIXTURE_PASSWORD = $fixturePassword
try {
    $deployedReportJson = (& .\tests\Invoke-ProductionSmartZipSmoke.ps1 `
        -SmartZipExe $deployExe -FixtureManifest $manifestPath `
        -Root $deployedSmokeRoot -AhkExe $ahkBase -SevenZip $sevenZip | Out-String).Trim()
    if ($deployedReportJson -match [regex]::Escape($fixturePassword)) {
        throw 'fixture password leaked into deployed smoke report'
    }
    $deployedSmoke = $deployedReportJson | ConvertFrom-Json
    if (-not $deployedSmoke.Passed -or $deployedSmoke.LeakedProcessCount -ne 0) {
        throw "deployed smoke failed: $deployedReportJson"
    }
} catch {
    Copy-Item $backupExe $deployExe -Force
    $restoredHash = (Get-FileHash $deployExe -Algorithm SHA256).Hash
    $backupHash = (Get-FileHash $backupExe -Algorithm SHA256).Hash
    if ($restoredHash -ne $backupHash) { throw 'deployed smoke failed and rollback hash mismatch' }
    throw
} finally {
    Remove-Item Env:SMARTZIP_FIXTURE_PASSWORD -ErrorAction SilentlyContinue
}
```

- [ ] **Step 6: Push, review, and merge the branch**

```powershell
git push -u origin codex/kirs3-convenience
gh pr create --repo $repo --base main --head codex/kirs3-convenience `
  --title 'SmartZip 3.6 Kirs.3 convenience and recovery' `
  --body 'Volume selection from any member, Pattern D numeric evidence, synchronous password diagnostic retry, batch failure basenames, LogAndReturn redaction, production hook removal with TEMP injection, and Kirs.3 release packaging. Preserves all Kirs.2 safety invariants. Does not mutate v3.6-kirs.2.'
$checks = gh pr checks --repo $repo 2>&1
$checksExit = $LASTEXITCODE
if ($checksExit -ne 0 -and ($checks -join "`n") -notmatch '(?i)no checks') {
    throw "unable to read PR checks: $($checks -join "`n")"
}
if (($checks -join "`n") -notmatch '(?i)no checks') {
    gh pr checks --repo $repo --watch
    if ($LASTEXITCODE -ne 0) { throw 'PR checks failed' }
} else {
    'NO_GITHUB_CHECKS_CONFIGURED'
}
```

Require independent reviewer `Critical=0`, `Important=0`. Merge with the repository’s allowed method, update local `main`, set `$releaseCommit`:

```powershell
git switch main
git pull --ff-only origin main
$releaseCommit = git rev-parse HEAD
if (git status --porcelain) { throw 'main not clean' }
```

- [ ] **Step 7: Create immutable tag and Release `v3.6-kirs.3`**

Do not move, delete, edit, or replace `v3.6-kirs.1` or `v3.6-kirs.2`.

```powershell
$existingTag = git ls-remote origin refs/tags/v3.6-kirs.3 2>$null
if ($LASTEXITCODE -ne 0) { throw 'failed to query remote tag state' }
if ($existingTag) { throw 'v3.6-kirs.3 already exists' }
git tag -a v3.6-kirs.3 $releaseCommit -m 'SmartZip 3.6 Kirs.3'
git push origin refs/tags/v3.6-kirs.3

$notes = @"
## SmartZip 3.6 Kirs.3 (23)

- 任一分卷成员均可从首卷解压；同组只处理一次；不完整分卷给出 MISSING_VOLUME
- Pattern D 数字后缀需证据（已知压缩扩展名 / 兄弟卷 / 索引为 1），避免 report.2024 误判
- 诊断窗口同步等待；“重新输入密码”成功后恢复既有 test→extract→finalize 流水线
- 批量摘要最多列出 3 个失败文件名，超出以 ... (+N) 表示
- CheckCMD.LogAndReturn 日志参数全程脱敏
- 生产源码不再包含 IntegrationTestHook；集成测试仅在 TEMP 源注入
- 保留 Kirs.2 全部安全门：仅干净 OK 才处理源包；分卷永不自动删除；密码不落日志

Pester：静态 172、诊断 161、命令捕获 15、密码 70、生命周期 26、嵌套 30、诊断界面 44、真实集成 32，全部通过。

SmartZip.exe SHA-256: $builtHash

升级时只替换 SmartZip.exe；请保留 SmartZip.ini 与 Contextmenu.exe。
Kirs.3 是新版本发布；不替换 v3.6-kirs.2 标签或 Release。
"@
gh release create v3.6-kirs.3 $builtExe --repo $repo `
  --title 'SmartZip 3.6 Kirs.3' --notes $notes --latest
```

- [ ] **Step 8: Download and verify published/deployed/prior-release evidence**

```powershell
$downloadDir = Join-Path $env:TEMP "smartzip-kirs3-release-check-$stamp"
New-Item -ItemType Directory -Path $downloadDir | Out-Null
gh release download v3.6-kirs.3 --repo $repo --pattern 'SmartZip.exe' --dir $downloadDir
$downloaded = Join-Path $downloadDir 'SmartZip.exe'
$downloadedHash = (Get-FileHash $downloaded -Algorithm SHA256).Hash
if ($downloadedHash -ne $builtHash) { throw 'downloaded release hash mismatch' }
if ((Get-FileHash $deployExe -Algorithm SHA256).Hash -ne $builtHash) { throw 'deployed hash mismatch' }

$newRelease = gh release view v3.6-kirs.3 --repo $repo `
  --json tagName,name,isDraft,isPrerelease,targetCommitish,url,assets | ConvertFrom-Json
if ($newRelease.tagName -ne 'v3.6-kirs.3' -or $newRelease.isDraft -or $newRelease.isPrerelease) {
    throw 'release metadata mismatch'
}
if ((git ls-remote origin refs/tags/v3.6-kirs.1).Split()[0] -ne $oldTag1) {
    throw 'v3.6-kirs.1 tag changed'
}
if ((git ls-remote origin refs/tags/v3.6-kirs.2).Split()[0] -ne $oldTag2) {
    throw 'v3.6-kirs.2 tag changed'
}
$oldRelease1After = gh release view v3.6-kirs.1 --repo $repo --json tagName,targetCommitish,url,assets |
  ConvertFrom-Json | ConvertTo-Json -Depth 8 -Compress
$oldRelease2After = gh release view v3.6-kirs.2 --repo $repo --json tagName,targetCommitish,url,assets |
  ConvertFrom-Json | ConvertTo-Json -Depth 8 -Compress
if ($oldRelease1After -ne $oldRelease1Json) { throw 'v3.6-kirs.1 release changed' }
if ($oldRelease2After -ne $oldRelease2Json) { throw 'v3.6-kirs.2 release changed' }
```

Final report must record release URL, commit, branch/PR, exact test totals, tool hashes, engine version, built/deployed/downloaded identical SHA-256, backup path/hash, unchanged INI and Contextmenu hashes, and unchanged Kirs.1 **and** Kirs.2 evidence. Finish with `git status --short --branch`; repository must be clean.

Rollback boundary: restore deployment from `$backupExe`. If tagging succeeds but Release creation/verification fails, do not retag or mutate Kirs.1/Kirs.2; leave the Kirs.3 tag pointing at the reviewed commit, correct the Release asset/metadata, and re-verify hashes.

---

## Plan Self-Review

This review checks the plan itself; it does not claim that future implementation tests, builds, deployment, or publication have already run.

### Scope traceability

| Approved design section | Implemented by plan task(s) | Verification gate |
|---|---|---|
| Goal / everyday predictability | Tasks 1–6 | whole-branch Task 8–9 |
| Release boundary Kirs.3 / no mutate Kirs.2 | Tasks 8–9 | freeze + Step 8 dual prior evidence |
| Selecting split archives / partSkip semantics | Tasks 1–2, 8 docs | static volume + diagnostics + integration split* |
| Password recovery synchronous ShowDiagnostic | Tasks 4–5 | DiagnosticUI + static zipx resume |
| Batch summary ≤3 basenames | Task 6 | DiagnosticUI batch_failures |
| Pattern D numeric evidence | Task 1 | diagnostics 21 evidence cases |
| CheckCMD LogAndReturn redaction | Task 3 | static LogAndReturn It |
| Production hook removal + TEMP injection | Task 7 | static absence + integration injection order |
| Safety invariants | Global Constraints; Tasks 2,5,9 | lifecycle + real 7-Zip + smoke |
| Tests / real 7-Zip / smoke / deploy / release | Tasks 7–9 | exact suite table + Task 9 steps |
| Non-goals (no batch listview, no INI rename, no algorithm change, no Kirs.2 history edit) | Global Constraints; Task reviews | reviewer checklist |

### Subagent audit reconciliation

| Audit focus | Key findings folded into plan |
|---|---|
| Diagnostic retry | Modeless ShowDiagnostic + discarded ResolveArchivePassword + no zipx resume → Tasks 4–5; batch noninteraction preserved; LogAndReturn gap → Task 3 |
| Volume / Pattern D | partSkip early continue + Pattern D always-volume → Tasks 1–2; implement evidence **before** removing continue; lone `data.001` stays volume; `report.2024` not volume; `data.002` alone not volume |
| Release / hook | Remove production `*i` include; inject after ArchiveDiagnostics in TEMP only; dual freeze of kirs.1+kirs.2; ProductVersion 23; integration live count 30 baseline |

### Canonical interface audit

- `DetectVolumeGroup` property shape unchanged; evidence is a private gate only.
- `ShowDiagnostic(result, isBatch := false)` signature text unchanged; return value is now required for recovery.
- `DiagnosticButtonAction` gains `recovery` object; never extracts.
- `FormatBatchDiagnosticSummary` is the single summary formatter for UI and tests.
- `zipx` resumes at most once via `Loop 2`; shared extract path only.
- Hook callbacks remain optional via `IsSet`; definitions live only in `tests/IntegrationTestHook.ahk`.

### Test-count audit (planned finals)

| Suite | Baseline | Final |
|---|---:|---:|
| Static | 150 | 172 |
| Diagnostics | 140 | 161 |
| RunCmdCapture | 15 | 15 |
| PasswordPreflight | 78 | 78 |
| ExtractionLifecycle | 26 | 26 |
| NestingMigration | 30 | 30 |
| DiagnosticUI | 36 | 44 |
| Real7Zip Integration | 30 | 32 |

Arithmetic must be re-measured after implementation; Task 8 locks the measured green totals into `tests/README.md` and Task 9 suite tables before release.

### Safety and publication audit

- Source handling only after clean OK; warning/failure/cancel preserve sources.
- Volumes never auto-deleted; `mayHandleSource` / `mayDel` still require `!volume.isVolume`.
- Password retry cannot skip full-test when source handling is configured.
- Production EXE must not contain `SMARTZIP_TEST_RESULT_V1`.
- Deploy replaces only EXE; INI and Contextmenu hashes unchanged.
- Publication creates `v3.6-kirs.3` only; rechecks Kirs.1 and Kirs.2 tag tips and release JSON.
- Built, deployed, and downloaded Release EXEs share one SHA-256.

### Plan hygiene audit

- Exactly 9 ordered tasks; each has files, interfaces, RED, implementation, GREEN, commit, review/release gates.
- No TBD/TODO/“add tests later” placeholders.
- Exact paths, functions, case names, and commands included.
- Markdown fences balanced; temporary/deploy paths absolute where safety matters.
- Plan file target path: `docs/superpowers/plans/2026-07-23-smartzip-kirs3-convenience.md` (write this plan into the repo at execution start as docs-only commit, or include it with Task 8 docs commit — never as an untracked implementer secret).

### Execution handoff

**Plan complete for** `docs/superpowers/plans/2026-07-23-smartzip-kirs3-convenience.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks (`superpowers:subagent-driven-development`)
2. **Inline Execution** — execute tasks in-session with checkpoints (`superpowers:executing-plans`)

Implementation must remain on `codex/kirs3-convenience` and must never rewrite `v3.6-kirs.2`.
