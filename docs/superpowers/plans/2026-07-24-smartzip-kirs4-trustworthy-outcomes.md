# SmartZip 3.6 Kirs.4 Trustworthy Outcomes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SmartZip's final state match the real extraction outcome: explicit `outputState` promotion authority, accurate exit-code-`1` warning classification, encrypted-CRC password-retry eligibility without mislabeling ordinary corruption, honest ambiguous diagnostics, accurate settings copy, and ship as SmartZip 3.6 Kirs.4 (24).

**Architecture:** Keep the Kirs.3 monolithic AutoHotkey pipeline and pure `lib/ArchiveDiagnostics.ahk` classifier/volume library. Extend `ArchiveResult` with an explicit outcome contract (`outputState`, `passwordRetryEligible`, `encryptionEvidence`, `retainedOutputDir`). Make `FinalizeExtraction` the sole post-extract assigner of non-default `outputState` via overridable `IsolatePartialOutput`. Make `zipx` return `ArchiveResult` on every path and make outer `Unzip` promote only when `outputState = "usable"`. Tighten `Classify7zResult` and `ExtractArchiveToTemp` so exit code `1` becomes `OK_WITH_WARNING` only with same-process warning evidence. Separate recovery eligibility from final status for encrypted CRC. Then build/smoke/deploy/publish `v3.6-kirs.4` without mutating Kirs.1–Kirs.3.

**Tech Stack:** AutoHotkey v2.0.26, Ahk2Exe 1.1.37.02a2, Pester 3.4-compatible PowerShell, 7-Zip 26.02 ZS v1.5.7 R1 at `C:\Tool\7-Zip-Zstandard\7z.exe`, Git, GitHub CLI.

## Global Constraints

- Display/version identity is exactly `SmartZip 3.6 Kirs.4 (24)`.
- `MainVersion := "3.6"` and Ahk2Exe FileVersion remain `3.6`; `edition := "Kirs.4"`, `buildVersion := 24`, and ProductVersion `24`.
- Final tag/release identity is exactly `v3.6-kirs.4`. Never mutate `v3.6-kirs.1`, `v3.6-kirs.2`, or `v3.6-kirs.3` tags, releases, or artifacts.
- The final runtime artifact remains one `SmartZip.exe`; `lib/*.ahk` files are compile-time includes only.
- Preserve all Kirs.1–Kirs.3 source-deletion, partial-output, password-redaction, full-test, batch-suppression, and volume never-auto-delete invariants.
- Exit code `0` plus clean required stages is the only clean-success condition; `successPercent`, file size, and extracted-size ratios must never authorize success or source handling.
- `OK_WITH_WARNING`, every failure state, and `CANCELLED` must preserve the top-level source and all volumes.
- Top-level and nested automatic source handling uses the Recycle Bin only; no source archive is permanently deleted.
- Split-volume sets are never automatically recycled.
- With normal testing disabled, source handling and nested recycling still require the forced full test.
- Passwords and clipboard content must not appear in logs, copied diagnostics, command traces, reports, or test output.
- Partial output is either isolated and discoverable or left in a clearly reported temporary location; it is never silently promoted.
- Production `SmartZip.ahk` must not include `tests\IntegrationTestHook.ahk` even optionally. Integration tests inject the include into a TEMP copy only.
- Batch and multi-select flows open no interactive password prompt (preflight dialog, diagnostic retry UI, or encrypted-CRC retry UI).
- Use only the verified engine at `C:\Tool\7-Zip-Zstandard\7z.exe` for integration/smoke tests.
- Use the verified toolchain:
  - `C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe`
  - `C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe`
  - Trusted SHA-256 base: `A2A54B8ABC476D7671D4DE0771BB54BF5F2373D79FF6871D0BA6A62C3B88AE00`
  - Trusted SHA-256 Ahk2Exe: `E54A599B19BAA5C1688849BBAE7A9CF049EEFCCD4F704C67941B40DA13A625B2`
- Deploy only after verified production build, with backup and rollback on smoke failure.
- Branch for this work: create/use `codex/kirs4-trustworthy-outcomes` (or the session worktree branch); never commit on a dirty unrelated tree.
- A task is not complete until its focused RED/GREEN cycle, full regression of suites that task claims, `git diff --check`, focused commit, and fresh read-only review all pass with Critical=0 and Important=0.
- Implementation session must use `superpowers:subagent-driven-development`, one fresh implementer per task, separate spec-compliance and code-quality reviewers. No task advances while either reviewer reports Critical or Important findings.

## File Map

- Modify `lib/ArchiveDiagnostics.ahk`: `ArchiveResult` construction defaults for `outputState`, `passwordRetryEligible`, `encryptionEvidence`, `retainedOutputDir`; `Classify7zResult` exit-code-`1` warning branch; encryption-evidence detection; `passwordRetryEligible` on encrypted `DATA_CORRUPT`.
- Modify `SmartZip.ahk`:
  - `ExtractArchiveToTemp` same-process classification (GUI exit `1` never borrows follow-up `7z t` warning text).
  - New overridable `IsolatePartialOutput(tempDir, partialPath)` and `TempDirHasPromotableOutput(tempDir)`.
  - `FinalizeExtraction` sole assigner of non-default `outputState` / verified quarantine / `retainedOutputDir`.
  - `zipx` returns `ArchiveResult` on every path; outer `Unzip` promotes only when `outputState = "usable"`.
  - Carry probe `encryptionEvidence` onto later extract/test `DATA_CORRUPT` results when needed.
  - `ResolveArchivePassword` accepts `passwordRetryEligible`; batch never opens `ShowPasswordDialog`.
  - `DiagnosticButtons` / reason / recommendation for encrypted-CRC eligibility and ambiguity copy.
  - zipx resume budget accepts eligible encrypted-CRC recovery the same way as password statuses (one resume).
  - Settings copy: full-test wording, noninteractive volume-once explanation, recycle-bin source wording.
  - Kirs.4 metadata (`edition`, `buildVersion`, ProductVersion, `buileTime`).
- Modify `tests/ArchiveDiagnostics.Harness.ahk` and `tests/ArchiveDiagnostics.Tests.ps1`: field defaults, exit-`1` warning/hard-error, encryption evidence, retry eligibility cases.
- Modify `tests/PasswordPreflight.Harness.ahk` and `tests/PasswordPreflight.Tests.ps1`: eligible `DATA_CORRUPT` enters resolve; generic corrupt still passthrough; batch noninteractive short-circuit.
- Modify `tests/ExtractionLifecycle.Harness.ahk` and `tests/ExtractionLifecycle.Tests.ps1`: `outputState` matrix, verified quarantine, real forced isolation failure through a blocked target path, and Extract same-process exit-`1` cases.
- Modify `tests/DiagnosticUI.Tests.ps1`: extend `MakeResult` and `RunDiagnosticUICommand`; add encrypted-CRC retry button, ambiguity copy, batch noninteraction, and unresolved eligible diagnostic cases.
- Modify `tests/SmartZip.Static.Tests.ps1`: outer promotion gate, zipx returns, IsolatePartialOutput presence, Extract same-process rule, settings strings, Kirs.4 metadata/docs.
- Modify `tests/IntegrationTestHook.ahk`: expose `outputState` and `retainedOutputDir` in `SMARTZIP_TEST_RESULT_V1` JSON (still omit `passwordUsed`).
- Modify `tests/Real7Zip.Integration.Tests.ps1`: assert `outputState` on key scenarios; keep TEMP injection contracts.
- Preserve `tests/Invoke-ProductionSmartZipSmoke.ps1` / `tests/ProductionSmokeUI.ahk`; their existing crcPartial normal-target-contamination and hook-free assertions remain mandatory in Tasks 8–10.
- Modify `tests/README.md`: suite counts, Kirs.4 TEMP root naming note if changed, outcome-contract notes.
- Modify `README.md` and `ini.md`: Kirs.4 trustworthy-outcomes UX/settings accuracy; preserve Kirs.2/Kirs.3 historical sections.
- Do not modify: Kirs.1–Kirs.3 tags/releases, historical plan/spec files beyond adding this plan, product build artifacts under `C:\Tool\SmartZip`, or unrelated tracked files outside this map.

## Canonical Interfaces (Kirs.4 deltas)

Preserve all Kirs.3 interfaces. Kirs.4 requires these exact shapes:

```ahk
; ArchiveResult construction defaults (lib/ArchiveDiagnostics.ahk)
class ArchiveResult {
    __New(status, stage, exitCode := -1, archivePath := "", output := "") {
        this.outputState := "none"              ; none | usable | quarantined | quarantine_failed
        this.passwordRetryEligible := false
        this.encryptionEvidence := false
        this.retainedOutputDir := ""
    }
}

; Classify7zResult(stage, exitCode, output, archivePath := "") => ArchiveResult
; - Recognized warning evidence only:
;     i)^Warnings?:\s*[1-9]  |  WARNINGS:  |  There are data after the end of archive
; - Exit 1 + recognized warning evidence + no hard-error evidence => OK_WITH_WARNING
; - Exit 1 without sufficient warning evidence, or with any hard-error evidence => failure status
; - Exit 1 never becomes clean OK; never sets isCleanSuccess/mayDeleteSource true
; - Case-insensitive "in encrypted file" => encryptionEvidence := true
; - stage probe line i)^Encrypted\s*=\s*\+ keeps NEED_PASSWORD and also sets encryptionEvidence := true
; - status DATA_CORRUPT && encryptionEvidence => passwordRetryEligible := true (status unchanged)
; - Explicit wrong-password phrases still beat CRC (WRONG_PASSWORD; no passwordRetryEligible needed)

; Product isolation seam (SmartZip class)
TempDirHasPromotableOutput(tempDir) => Boolean
; true when tempDir exists and contains any DF entry

IsolatePartialOutput(tempDir, partialPath) => String
; attempts DirMove then MoveItem fallback; returns the verified actual isolated path
; only when DirExist(actualPath) && !TempDirHasPromotableOutput(tempDir);
; returns "" on failure

FinalizeExtraction(path, result, tempDir, targetDir, mayDeleteSource) => ArchiveResult
; sole assigner of non-default outputState after an extraction attempt:
;   OK + exit 0            => outputState "usable"; source recycle only if mayDeleteSource && isCleanSuccess
;   OK_WITH_WARNING        => outputState "usable"; never source-handle
;   fail + empty temp      => outputState "none"; remove empty temp only; preserve source
;   fail + isolate ok      => outputState "quarantined"; partialOutputDir = verified path
;   fail + isolate fail    => outputState "quarantine_failed"; partialOutputDir empty unless a real
;                            partial dir already exists; retainedOutputDir = actual retained location
; never uses size/ratio heuristics

; zipx(path) nested function => ArchiveResult  (every path returns)
; Unzip outer promotion sole authority:
;   zipResult := zipx(i)
;   if (zipResult.outputState != "usable")
;       continue
;   ; existing AfterUnzip / MoveItem / nesting only for usable

; ResolveArchivePassword(path, probeResult) => ArchiveResult
; enters recovery when:
;   status in (NEED_PASSWORD, WRONG_PASSWORD)
;   OR passwordRetryEligible = true
; batch (this.muilt = true): never ShowPasswordDialog; try empty + stored candidates only;
; unresolved returns last non-success result (status preserved; for eligible DATA_CORRUPT stay DATA_CORRUPT)

; DiagnosticButtons(result, allowPasswordRetry := true) => Array
; "重新输入密码" when allowPasswordRetry and
;   (NEED_PASSWORD | WRONG_PASSWORD | result.passwordRetryEligible)

; DiagnosticReason / DiagnosticRecommendation for DATA_CORRUPT + passwordRetryEligible:
; ambiguous wording: password may be wrong OR encrypted data may be damaged

; Nested recycle remains: nestedMayRecycle && extractResult.isCleanSuccess && !volume
; and only after clean OK — never because output merely exists / usable alone
```

### Baseline suite counts (must remain green until a task intentionally expands them)

| Suite | Baseline PassedCount |
|---|---:|
| `tests/SmartZip.Static.Tests.ps1` | 172 |
| `tests/ArchiveDiagnostics.Tests.ps1` | 161 |
| `tests/RunCmdCapture.Tests.ps1` | 15 |
| `tests/PasswordPreflight.Tests.ps1` | 78 |
| `tests/ExtractionLifecycle.Tests.ps1` | 26 |
| `tests/NestingMigration.Tests.ps1` | 30 |
| `tests/DiagnosticUI.Tests.ps1` | 46 |
| `tests/Real7Zip.Integration.Tests.ps1` | 32 |

The exact task totals below are normative. Task 9 writes the final table to `tests/README.md`.

---

### Task 1: ArchiveResult Defaults and Classifier Trust Signals

**Files:**
- Modify: `lib/ArchiveDiagnostics.ahk` — `ArchiveResult.__New`, `Classify7zResult` only
- Modify: `tests/ArchiveDiagnostics.Harness.ahk` — classify-mode assertions
- Modify: `tests/ArchiveDiagnostics.Tests.ps1` — append exact case names to `$caseNames`
- Do not modify: `SmartZip.ahk`, integration, docs (later tasks)

**Interfaces:**
- Consumes: existing `ArchiveStatus`, `Classify7zResult` priority ladder, recognized warning detectors
- Produces: four new `ArchiveResult` defaults; exit-`1` pure-warning → `OK_WITH_WARNING`; encryption evidence + `passwordRetryEligible` on encrypted `DATA_CORRUPT`; generic CRC still ineligible

- [ ] **Step 1: Write the failing harness cases**

In `tests/ArchiveDiagnostics.Harness.ahk`, inside the classify block after the existing `ArchiveResult` default asserts (after `result_may_delete_source_warning_false`), append:

```ahk
    ; --- Kirs.4 ArchiveResult defaults ---
    k4 := ArchiveResult(ArchiveStatus.UNKNOWN_ERROR, "probe", -1, "C:\\tmp\\x.7z", "")
    AssertEq(k4.outputState, "none", "result_output_state_default")
    AssertFalse(k4.passwordRetryEligible, "result_password_retry_eligible_default")
    AssertFalse(k4.encryptionEvidence, "result_encryption_evidence_default")
    AssertEq(k4.retainedOutputDir, "", "result_retained_output_dir_default")

    ; Exit 1 + pure warning evidence => OK_WITH_WARNING
    r := Classify7zResult("test", 1, "Everything is Ok`nWarnings: 1`nThere are data after the end of archive`n")
    AssertEq(r.status, ArchiveStatus.OK_WITH_WARNING, "exit1_pure_warning_ok_with_warning")
    AssertFalse(r.isCleanSuccess, "exit1_warning_not_clean_success")
    AssertFalse(r.mayDeleteSource, "exit1_warning_no_delete")

    r := Classify7zResult("test", 1, "WARNINGS:`nThere are data after the end of archive`n")
    AssertEq(r.status, ArchiveStatus.OK_WITH_WARNING, "exit1_WARNINGS_token_ok_with_warning")

    ; Exit 1 + hard-error evidence => not warning success
    r := Classify7zResult("test", 1, "ERROR: CRC Failed`nWarnings: 1`n")
    AssertEq(r.status, ArchiveStatus.DATA_CORRUPT, "exit1_hard_error_beats_warning")
    AssertFalse(r.isCleanSuccess, "exit1_hard_error_not_clean")

    r := Classify7zResult("extract", 1, "ERROR: Headers Error`n")
    AssertEq(r.status, ArchiveStatus.HEADER_CORRUPT, "exit1_header_corrupt_not_warning")

    ; Exit 1 with no recognized warning evidence => failure (not OK / not OK_WITH_WARNING)
    r := Classify7zResult("extract", 1, "Sub items Errors: 1`n")
    AssertTrue(r.status != ArchiveStatus.OK && r.status != ArchiveStatus.OK_WITH_WARNING, "exit1_no_warning_evidence_not_success")

    ; Exit 1 never clean OK even if output looks clean
    r := Classify7zResult("extract", 1, "Everything is Ok`n")
    AssertTrue(r.status != ArchiveStatus.OK, "exit1_everything_ok_text_not_clean_ok")
    AssertFalse(r.isCleanSuccess, "exit1_never_clean_success")

    ; Generic CRC / Data Error: DATA_CORRUPT, no retry eligibility
    r := Classify7zResult("test", 2, "ERROR: CRC Failed`nSub items Errors: 1`n")
    AssertEq(r.status, ArchiveStatus.DATA_CORRUPT, "generic_crc_still_data_corrupt")
    AssertFalse(r.encryptionEvidence, "generic_crc_no_encryption_evidence")
    AssertFalse(r.passwordRetryEligible, "generic_crc_not_retry_eligible")

    r := Classify7zResult("test", 2, "ERROR: Data Error`n")
    AssertEq(r.status, ArchiveStatus.DATA_CORRUPT, "generic_data_error_still_data_corrupt")
    AssertFalse(r.passwordRetryEligible, "generic_data_error_not_retry_eligible")

    ; Encrypted file phrase: DATA_CORRUPT + encryptionEvidence + passwordRetryEligible
    r := Classify7zResult("extract", 2, "ERROR: CRC Failed in encrypted file`nData Error`n")
    AssertEq(r.status, ArchiveStatus.DATA_CORRUPT, "encrypted_crc_stays_data_corrupt")
    AssertTrue(r.encryptionEvidence, "encrypted_crc_sets_encryption_evidence")
    AssertTrue(r.passwordRetryEligible, "encrypted_crc_retry_eligible")
    AssertFalse(r.isCleanSuccess, "encrypted_crc_not_clean")

    r := Classify7zResult("test", 2, "ERROR: Data Error in encrypted file`n")
    AssertEq(r.status, ArchiveStatus.DATA_CORRUPT, "encrypted_data_error_stays_data_corrupt")
    AssertTrue(r.encryptionEvidence, "encrypted_data_error_encryption_evidence")
    AssertTrue(r.passwordRetryEligible, "encrypted_data_error_retry_eligible")

    ; Wrong password still beats encrypted CRC wording
    r := Classify7zResult("test", 2, "ERROR: CRC Failed in encrypted file. Wrong password?`n")
    AssertEq(r.status, ArchiveStatus.WRONG_PASSWORD, "wrong_password_beats_encrypted_crc")
    AssertFalse(r.passwordRetryEligible, "wrong_password_not_password_retry_eligible_flag")

    ; Probe Encrypted = + keeps NEED_PASSWORD and sets encryptionEvidence
    r := Classify7zResult("probe", 0, "Type = zip`nPath = payload.txt`nEncrypted = +`n")
    AssertEq(r.status, ArchiveStatus.NEED_PASSWORD, "probe_encrypted_plus_still_need_password")
    AssertTrue(r.encryptionEvidence, "probe_encrypted_plus_sets_encryption_evidence")
```

In `tests/ArchiveDiagnostics.Tests.ps1`, append these exact names to `$caseNames` (after the last existing classify name, before volume-only lists):

```powershell
        'result_output_state_default',
        'result_password_retry_eligible_default',
        'result_encryption_evidence_default',
        'result_retained_output_dir_default',
        'exit1_pure_warning_ok_with_warning',
        'exit1_warning_not_clean_success',
        'exit1_warning_no_delete',
        'exit1_WARNINGS_token_ok_with_warning',
        'exit1_hard_error_beats_warning',
        'exit1_hard_error_not_clean',
        'exit1_header_corrupt_not_warning',
        'exit1_no_warning_evidence_not_success',
        'exit1_everything_ok_text_not_clean_ok',
        'exit1_never_clean_success',
        'generic_crc_still_data_corrupt',
        'generic_crc_no_encryption_evidence',
        'generic_crc_not_retry_eligible',
        'generic_data_error_still_data_corrupt',
        'generic_data_error_not_retry_eligible',
        'encrypted_crc_stays_data_corrupt',
        'encrypted_crc_sets_encryption_evidence',
        'encrypted_crc_retry_eligible',
        'encrypted_crc_not_clean',
        'encrypted_data_error_stays_data_corrupt',
        'encrypted_data_error_encryption_evidence',
        'encrypted_data_error_retry_eligible',
        'wrong_password_beats_encrypted_crc',
        'wrong_password_not_password_retry_eligible_flag',
        'probe_encrypted_plus_still_need_password',
        'probe_encrypted_plus_sets_encryption_evidence'
```

- [ ] **Step 2: Run tests to verify RED**

```powershell
$r = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
# Expect FailedCount > 0. New Its fail with harness FAIL <name> for missing fields / wrong exit-1 behavior.
$r.FailedCount
$r.PassedCount
```

Expected: FAIL on the new case names (missing `outputState` property or wrong status/eligibility). Existing 161 cases remain PASS until implementation accidentally regresses them.

- [ ] **Step 3: Minimal implementation in `lib/ArchiveDiagnostics.ahk`**

Update `ArchiveResult.__New` to append defaults after existing field init:

```ahk
        this.tempOutputDir := ""
        this.partialOutputDir := ""
        this.isCleanSuccess := (status = ArchiveStatus.OK)
        this.mayDeleteSource := (status = ArchiveStatus.OK)
        this.output := output
        this.outputState := "none"
        this.passwordRetryEligible := false
        this.encryptionEvidence := false
        this.retainedOutputDir := ""
```

In `Classify7zResult` line scan loop, after the data-corrupt detector, add encryption-evidence detection (do not change status here):

```ahk
        if (InStr(trimmed, "CRC Failed") || InStr(trimmed, "Data Error")) {
            hasDataCorrupt := true
            isErr := true
        }
        if (trimmed ~= "i)in encrypted file") {
            result.encryptionEvidence := true
        }
```

When probe sets need-password from `Encrypted = +`, also set evidence:

```ahk
        if (stage = "probe" && trimmed ~= "i)^Encrypted\s*=\s*\+") {
            hasNeedPassword := true
            result.encryptionEvidence := true
        }
```

Replace the success tail of the priority ladder (the `exitCode = 0` warning/OK branches and following IO/unknown) with:

```ahk
    } else if (hasNotArchive) {
        result.status := ArchiveStatus.NOT_ARCHIVE
    } else if (exitCode = 0 && (hasWarning || result.warningLines.Length > 0)) {
        result.status := ArchiveStatus.OK_WITH_WARNING
    } else if (exitCode = 0) {
        result.status := ArchiveStatus.OK
    } else if (exitCode = 1 && (hasWarning || result.warningLines.Length > 0)
        && !hasMissingVolume && !hasNeedPassword && !hasWrongPassword
        && !hasUnsupported && !hasTruncated && !hasHeaderCorrupt
        && !hasDataCorrupt && !hasNotArchive && !hasIoError
        && result.errorLines.Length = 0) {
        ; Exit 1 warning success only with recognized warning evidence and no hard-error evidence
        result.status := ArchiveStatus.OK_WITH_WARNING
    } else if (hasIoError) {
        result.status := ArchiveStatus.IO_ERROR
    } else {
        result.status := ArchiveStatus.UNKNOWN_ERROR
    }

    result.isCleanSuccess := (result.status = ArchiveStatus.OK)
    result.mayDeleteSource := (result.status = ArchiveStatus.OK)
    result.passwordUsed := ""
    if (result.status = ArchiveStatus.DATA_CORRUPT && result.encryptionEvidence)
        result.passwordRetryEligible := true
    else
        result.passwordRetryEligible := false
    return result
```

Hard-error branches above this tail must remain first so exit `1` with CRC/header/etc. never becomes warning success. Exit `1` never sets `isCleanSuccess`.

- [ ] **Step 4: Run tests to verify GREEN**

```powershell
$r = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
if ($r.FailedCount -ne 0 -or $r.PassedCount -ne 191) {
    throw "diag expected 191/0, got $($r.PassedCount)/$($r.FailedCount)"
}
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 172) { throw "static regression" }
```

Expected: ArchiveDiagnostics **191/0** (baseline 161 + 30 new case names); static still **172/0**.

- [ ] **Step 5: Commit**

```powershell
git add -- lib/ArchiveDiagnostics.ahk tests/ArchiveDiagnostics.Harness.ahk tests/ArchiveDiagnostics.Tests.ps1
git diff --check --cached
git commit -m "feat: add outcome defaults, exit-1 warning class, encrypted-CRC eligibility"
```

- [ ] **Step 6: Review gate**

Fresh implementer done; dispatch separate spec-compliance and code-quality reviewers. Verify: generic CRC not retry-eligible; wrong-password still beats CRC; exit 1 never clean OK; no size heuristics. `Critical=0`, `Important=0`.

---

### Task 2: Same-Process Extract Classification

**Files:**
- Modify: `SmartZip.ahk` — `ExtractArchiveToTemp` only
- Modify: `tests/ExtractionLifecycle.Harness.ahk` — pure same-process decision mirror with the same three assertion names
- Modify: `tests/ExtractionLifecycle.Tests.ps1` — product-host cases for scripted exit 1
- Modify: `tests/SmartZip.Static.Tests.ps1` — structural rule that exit-1 path does not classify solely from follow-up `t` warning text as success

**Interfaces:**
- Consumes: Task 1 `Classify7zResult` exit-1 rules
- Produces: GUI extract exit `1` without extract-stdout capture remains a failure (output isolated later); exit `0` may still use follow-up `7z t` text; hard failures still use `t` text for detailed status

- [ ] **Step 1: Write the failing product-lifecycle cases**

In the product footer of `tests/ExtractionLifecycle.Tests.ps1` (after existing exit2 CRC cases), append host-driven cases:

```ahk
; Kirs.4: GUI extract exit 1 must not become OK_WITH_WARNING from a later 7z t warning-only capture
host.Reset()
host.scriptedExit := 1
host.scriptedCap := { exitCode: 0, output: "Everything is Ok`nWarnings: 1`nThere are data after the end of archive`n", cancelled: false }
e1path := host.workRoot "\a\warnish.7z"
e1tmp := host.workRoot "\tmp\e1"
try DirCreate(host.workRoot "\a")
if !FileExist(e1path)
    FileAppend("w", e1path, "UTF-8")
try DirCreate(e1tmp)
host.SeedFile(e1tmp "\partial.bin", "x")
erE1 := host.ExtractArchiveToTemp(e1path, "", e1tmp)
AssertTrue(erE1.status != ArchiveStatus.OK && erE1.status != ArchiveStatus.OK_WITH_WARNING, "gui_exit1_not_borrow_test_warning_success")
AssertEq(erE1.isCleanSuccess, false, "gui_exit1_not_clean")

; Exit 0 extract + t warning text may still be OK_WITH_WARNING
host.Reset()
host.scriptedExit := 0
host.scriptedCap := { exitCode: 0, output: "Everything is Ok`nWarnings: 1`nThere are data after the end of archive`n", cancelled: false }
e0path := host.workRoot "\a\trail.7z"
e0tmp := host.workRoot "\tmp\e0"
if !FileExist(e0path)
    FileAppend("t", e0path, "UTF-8")
try DirCreate(e0tmp)
host.SeedFile(e0tmp "\ok.bin", "x")
erE0 := host.ExtractArchiveToTemp(e0path, "", e0tmp)
AssertEq(erE0.status, ArchiveStatus.OK_WITH_WARNING, "gui_exit0_test_warning_ok_with_warning")
AssertEq(erE0.isCleanSuccess, false, "gui_exit0_warning_not_clean")

; Exit 2 + t CRC still DATA_CORRUPT (existing path remains)
host.Reset()
host.scriptedExit := 2
host.scriptedCap := { exitCode: 2, output: "ERROR: CRC Failed`n", cancelled: false }
e2path := host.workRoot "\a\badcrc.7z"
e2tmp := host.workRoot "\tmp\e2"
if !FileExist(e2path)
    FileAppend("b", e2path, "UTF-8")
try DirCreate(e2tmp)
erE2 := host.ExtractArchiveToTemp(e2path, "", e2tmp)
AssertEq(erE2.status, ArchiveStatus.DATA_CORRUPT, "gui_exit2_crc_still_data_corrupt")
```

In `tests/ExtractionLifecycle.Harness.ahk`, add this pure mirror and the same three behavioral assertions:

```ahk
ClassifyGuiExtractForOracle(extractExit, testOutput) {
    if (extractExit = 255)
        return ArchiveResult(ArchiveStatus.CANCELLED, "extract", 255)
    detail := Classify7zResult("extract", extractExit, testOutput)
    if (extractExit != 1)
        return detail
    if (detail.status != ArchiveStatus.OK && detail.status != ArchiveStatus.OK_WITH_WARNING)
        return detail
    result := ArchiveResult(ArchiveStatus.UNKNOWN_ERROR, "extract", 1)
    result.isCleanSuccess := false
    result.mayDeleteSource := false
    return result
}

oe1 := ClassifyGuiExtractForOracle(1, "Everything is Ok`nWarnings: 1`nThere are data after the end of archive`n")
AssertTrue(oe1.status != ArchiveStatus.OK && oe1.status != ArchiveStatus.OK_WITH_WARNING, "gui_exit1_not_borrow_test_warning_success")
AssertEq(oe1.isCleanSuccess, false, "gui_exit1_not_clean")
oe0 := ClassifyGuiExtractForOracle(0, "Everything is Ok`nWarnings: 1`nThere are data after the end of archive`n")
AssertEq(oe0.status, ArchiveStatus.OK_WITH_WARNING, "gui_exit0_test_warning_ok_with_warning")
oe2 := ClassifyGuiExtractForOracle(2, "ERROR: CRC Failed`n")
AssertEq(oe2.status, ArchiveStatus.DATA_CORRUPT, "gui_exit2_crc_still_data_corrupt")
```

Append exactly these four names to the shared `$cases` list in `tests/ExtractionLifecycle.Tests.ps1`: `gui_exit1_not_borrow_test_warning_success`, `gui_exit1_not_clean`, `gui_exit0_test_warning_ok_with_warning`, and `gui_exit2_crc_still_data_corrupt`. Both oracle and product maps must emit all four.

Also add static tests:

```powershell
    It 'ExtractArchiveToTemp does not classify GUI exit 1 success from follow-up test warning text alone' {
        $b = $script:ExtractArchiveToTempBody
        # Must special-case extractExit = 1 (or non-zero without extract capture) before borrowing t output as warning success
        $ok = Test-Regex -Text $b -Pattern '(?s)extractExit\s*=\s*1|exitCode\s*=\s*1'
        $ok | Should Be $true
        # Must still re-test via console capture for diagnostics on other paths
        $b | Should Match ' t '
    }
```

- [ ] **Step 2: Confirm RED**

```powershell
$l = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
$l.FailedCount   # > 0 expected: current code classifies exit 1 + t warnings as OK_WITH_WARNING
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
# new static It fails until ExtractArchiveToTemp special-cases exit 1
```

- [ ] **Step 3: Implement `ExtractArchiveToTemp` same-process rule**

Replace the classification block after `extractExit := this.exitCode` with:

```ahk
        extractExit := this.exitCode
        result := ""
        if (extractExit = 255) {
            result := ArchiveResult(ArchiveStatus.CANCELLED, "extract", 255, path)
        } else {
            ; Follow-up console test is a different process. Use its text for hard-error detail
            ; and for exit-0 warning detection, but never promote GUI exit 1 to OK_WITH_WARNING
            ; solely because the later test printed warning evidence.
            cmd := this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"'
            cap := this.RunCmdCapture(cmd, "UTF-8")
            if this.cmdLog
                this.testLog .= '`n#####`n' RedactDiagnostic(cmd) '`n'
            if (extractExit = 1) {
                ; No GUI extract stdout capture available: exit 1 remains failure.
                ; Classify with empty extract text first so t-warning text cannot invent success.
                result := Classify7zResult("extract", extractExit, "", path)
                detail := Classify7zResult("extract", extractExit, cap.output, path)
                if (detail.status != ArchiveStatus.OK && detail.status != ArchiveStatus.OK_WITH_WARNING) {
                    result := detail
                    result.exitCode := extractExit
                } else {
                    result.exitCode := extractExit
                    if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.OK_WITH_WARNING)
                        result.status := ArchiveStatus.UNKNOWN_ERROR
                    result.isCleanSuccess := false
                    result.mayDeleteSource := false
                    result.passwordRetryEligible := false
                }
                ; Carry encryption / hard-error detail flags when detail is a real failure
                if (detail.encryptionEvidence)
                    result.encryptionEvidence := true
                if (detail.status = ArchiveStatus.DATA_CORRUPT && result.encryptionEvidence)
                    result.passwordRetryEligible := true
                if (detail.errorLines.Length) {
                    result.errorLines := detail.errorLines
                    result.output := detail.output
                }
            } else {
                result := Classify7zResult("extract", extractExit, cap.output, path)
                result.exitCode := extractExit
            }
        }
        result.tempOutputDir := tempDir
        if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.OK_WITH_WARNING)
            result.passwordUsed := password
        result.isCleanSuccess := (result.status = ArchiveStatus.OK && result.exitCode = 0)
        result.mayDeleteSource := result.isCleanSuccess
        return result
```

Preserve cancel path and tempOutputDir assignment. Do not introduce size-ratio checks.

- [ ] **Step 4: GREEN**

```powershell
$l = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
if ($l.FailedCount -ne 0 -or $l.PassedCount -ne 30) {
    throw "lifecycle expected 30/0, got $($l.PassedCount)/$($l.FailedCount)"
}
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 173) {
    throw "static expected 173/0, got $($s.PassedCount)/$($s.FailedCount)"
}
$d = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
if ($d.FailedCount -ne 0 -or $d.PassedCount -ne 191) { throw "diag" }
```

Expected: lifecycle **30/0** (26 + 4 dual-mapped names); static **173/0** (172 + 1 structural It).

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/ExtractionLifecycle.Tests.ps1 tests/ExtractionLifecycle.Harness.ahk tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "fix: do not promote GUI exit 1 using follow-up test warning text"
```

- [ ] **Step 6: Review gate**

Confirm exit 0 warning path still works; exit 2 CRC still DATA_CORRUPT; no size heuristics. `Critical=0`, `Important=0`.

---

### Task 3: IsolatePartialOutput and FinalizeExtraction outputState

**Files:**
- Modify: `SmartZip.ahk` — add `TempDirHasPromotableOutput`, `IsolatePartialOutput`; rewrite `FinalizeExtraction` outcome assignment
- Modify: `tests/ExtractionLifecycle.Harness.ahk` — oracle `outputState` / quarantine_failed decisions
- Modify: `tests/ExtractionLifecycle.Tests.ps1` — product host override for forced isolation failure; assert `outputState`, `retainedOutputDir`, `partialOutputDir`

**Interfaces:**
- Consumes: Task 1 field defaults
- Produces: verified `usable` / `quarantined` / `none` / `quarantine_failed`; overridable isolation seam for deterministic failure

- [ ] **Step 1: Write failing oracle + product cases**

Extend `FinalizeDecision` in the oracle harness to set:

```ahk
FinalizeDecision(path, result, tempDir, targetDir, mayDeleteSource, tempHasOutput, isNested := false, isVolumeMember := false, isolateOk := true) {
    out := {
        status: result.status,
        exitCode: result.exitCode,
        sourceAction: "none",
        tempAction: "keep",
        partialName: "",
        diagnostic: "",
        isCleanSuccess: (result.status = ArchiveStatus.OK && result.exitCode = 0),
        outputState: "none",
        retainedOutputDir: ""
    }
    if (result.status = ArchiveStatus.OK && result.exitCode = 0) {
        out.tempAction := "keep"
        out.outputState := "usable"
        if (isVolumeMember)
            out.sourceAction := "none"
        else if (isNested && out.isCleanSuccess)
            out.sourceAction := "recycle_nested"
        else if (!isNested && mayDeleteSource && out.isCleanSuccess)
            out.sourceAction := "recycle"
        else
            out.sourceAction := "none"
        return out
    }
    if (result.status = ArchiveStatus.OK_WITH_WARNING) {
        out.tempAction := "keep"
        out.outputState := "usable"
        out.sourceAction := "none"
        out.isCleanSuccess := false
        return out
    }
    if (tempHasOutput) {
        if (isolateOk) {
            out.tempAction := "partial"
            out.outputState := "quarantined"
            SplitPath(path, , , , &nameNoExt)
            out.partialName := nameNoExt "_解压不完整_" FormatTime(, "yyyyMMdd-HHmmss")
            out.sourceAction := "none"
            return out
        }
        out.tempAction := "keep"
        out.outputState := "quarantine_failed"
        out.retainedOutputDir := tempDir
        out.partialName := ""
        out.sourceAction := "none"
        return out
    }
    out.tempAction := "remove_empty"
    out.outputState := "none"
    out.sourceAction := "none"
    return out
}
```

Add oracle asserts:

```ahk
AssertEq(d1.outputState, "usable", "ok_output_state_usable")
AssertEq(d3.outputState, "usable", "warn_output_state_usable")
AssertEq(d4.outputState, "quarantined", "exit2_output_state_quarantined")
AssertEq(d5.outputState, "none", "fail_empty_output_state_none")
dQf := FinalizeDecision("D:\\a\\pack.zip", r4, "D:\\tmp\\stuck", "D:\\out", true, true, false, false, false)
AssertEq(dQf.outputState, "quarantine_failed", "isolate_fail_output_state_quarantine_failed")
AssertEq(dQf.retainedOutputDir, "D:\\tmp\\stuck", "isolate_fail_retained_temp")
AssertEq(dQf.sourceAction, "none", "isolate_fail_preserves_source")
AssertEq(dQf.tempAction, "keep", "isolate_fail_keeps_temp_not_promoted_by_finalize")
```

In `New-ExtractionLifecycleProductHost`, widen the production slice and its definition checks. Do not duplicate these methods in `LifecycleHost`; the host must execute the sliced production definitions:

```powershell
$startMarker = "`n    TempDirHasPromotableOutput("
$endMarker = "`n    RunCmdCapture("
$body = Get-SourceSlice -Source $src -StartMarker $startMarker -EndMarker $endMarker
if ([string]::IsNullOrEmpty($body)) {
    throw 'lifecycle methods not found in SmartZip.ahk (TempDirHasPromotableOutput..RunCmdCapture)'
}
$method = $body.TrimStart("`r", "`n")
foreach ($name in @(
        'TempDirHasPromotableOutput',
        'IsolatePartialOutput',
        'ExtractArchiveToTemp',
        'FinalizeExtraction',
        'WriteDiagnostic'
    )) {
    $matches = [regex]::Matches($method, '(?m)^    ' + [regex]::Escape($name) + '\s*\(')
    if ($matches.Count -ne 1) {
        throw "expected exactly one $name method definition in product slice, found $($matches.Count)"
    }
}
```

Before Task 3 implementation this product export fails because the two new start methods do not exist; that is the expected RED.

Product footer cases:

```ahk
; Force real isolation failure: targetDir is a file, so neither DirMove nor MoveItem
; can create a child incomplete directory beneath it.
blockedTarget := host.workRoot "\blocked-target"
try FileDelete(blockedTarget)
try DirDelete(blockedTarget, 1)
FileAppend("not-a-directory", blockedTarget, "UTF-8")
rFail := ArchiveResult(ArchiveStatus.DATA_CORRUPT, "extract", 2, p1)
rFail.output := "ERROR: CRC Failed`n"
stuck := host.workRoot "\tmp\stuck"
dStuck := RunFinalizeCase(host, p1, rFail, stuck, blockedTarget, true, true, false, false)
AssertEq(dStuck.outputState, "quarantine_failed", "isolate_fail_output_state_quarantine_failed")
AssertTrue(dStuck.retainedOutputDir != "", "isolate_fail_retained_temp")
AssertEq(dStuck.sourceAction, "none", "isolate_fail_preserves_source")
AssertEq(dStuck.tempAction, "keep", "isolate_fail_keeps_temp_not_promoted_by_finalize")

; success / warning / partial / empty states
AssertEq(d1.outputState, "usable", "ok_output_state_usable")
AssertEq(d3.outputState, "usable", "warn_output_state_usable")
AssertEq(d4.outputState, "quarantined", "exit2_output_state_quarantined")
AssertEq(d5.outputState, "none", "fail_empty_output_state_none")
```

Extend `RunFinalizeCase` / `TempActionFrom` to read `fr.outputState`, `fr.retainedOutputDir`, and include them in `out`. Map product isolation-fail asserts to the shared names `isolate_fail_output_state_quarantine_failed`, `isolate_fail_retained_temp`, `isolate_fail_preserves_source`, and `isolate_fail_keeps_temp_not_promoted_by_finalize`.

Use these exact additions in `RunFinalizeCase`:

```ahk
    out := {
        sourceAction: SourceActionFrom(host, path, isNested),
        tempAction: TempActionFrom(host, fr, tempDir),
        isCleanSuccess: fr.isCleanSuccess,
        outputState: fr.outputState,
        retainedOutputDir: fr.retainedOutputDir,
        partialName: "",
        diagnostic: ""
    }
```

Append exactly the eight Task 3 names to the existing shared Pester `$cases` list. Task 2 already appended its four names, so do not add them again.

- [ ] **Step 2: Confirm RED**

```powershell
$l = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
# Fails: FinalizeExtraction does not set outputState; isolation always assigns partialOutputDir
```

- [ ] **Step 3: Implement isolation helpers and FinalizeExtraction**

Insert both helpers immediately above `ExtractArchiveToTemp` in `SmartZip.ahk`, so the widened product-host slice captures them before `FinalizeExtraction`:

```ahk
    TempDirHasPromotableOutput(tempDir) {
        if !DirExist(tempDir)
            return false
        loop files tempDir "\*.*", "DF"
            return true
        return false
    }

    IsolatePartialOutput(tempDir, partialPath) {
        movedPath := partialPath
        try DirMove(tempDir, partialPath)
        catch {
            try movedPath := this.MoveItem(tempDir, partialPath, 1, A_LineNumber)
            catch
                return ""
        }
        if (StrLower(movedPath) = StrLower(tempDir))
            return ""
        return (DirExist(movedPath) && !this.TempDirHasPromotableOutput(tempDir))
            ? movedPath : ""
    }
```

Replace `FinalizeExtraction` body with:

```ahk
    FinalizeExtraction(path, result, tempDir, targetDir, mayDeleteSource) {
        result.isCleanSuccess := (result.status = ArchiveStatus.OK && result.exitCode = 0)
        result.mayDeleteSource := result.isCleanSuccess && mayDeleteSource
        ; Default remains construction "none" until this method assigns post-extract state
        if !result.HasOwnProp("outputState") || result.outputState = ""
            result.outputState := "none"
        result.retainedOutputDir := ""

        tempHasOutput := this.TempDirHasPromotableOutput(tempDir)

        if (result.status = ArchiveStatus.OK && result.exitCode = 0) {
            result.outputState := "usable"
            if (mayDeleteSource && result.isCleanSuccess)
                this.RecycleItem(path, A_LineNumber)  ; Recycle Bin only
            return result
        }

        if (result.status = ArchiveStatus.OK_WITH_WARNING) {
            result.outputState := "usable"
            return result
        }

        if (tempHasOutput) {
            SplitPath(path, , , , &nameNoExt)
            stamp := FormatTime(, "yyyyMMdd-HHmmss")
            partial := this.PathDupl(targetDir "\" nameNoExt "_解压不完整_" stamp, 1)
            isolatedPath := this.IsolatePartialOutput(tempDir, partial)
            if (isolatedPath != "") {
                result.outputState := "quarantined"
                result.partialOutputDir := isolatedPath
                result.retainedOutputDir := ""
                this.WriteDiagnostic(result)
                return result
            }
            result.outputState := "quarantine_failed"
            result.partialOutputDir := DirExist(partial) ? partial : ""
            result.retainedOutputDir := tempDir
            this.WriteDiagnostic(result)
            return result
        }

        if DirExist(tempDir)
            this.RecycleItem(tempDir, A_LineNumber, true)
        result.outputState := "none"
        return result
    }
```

Place both helpers immediately above `ExtractArchiveToTemp`; the widened product-host slice from Step 1 then captures exactly one definition of each required method.

- [ ] **Step 4: GREEN**

```powershell
$l = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
if ($l.FailedCount -ne 0 -or $l.PassedCount -ne 38) {
    throw "lifecycle expected 38/0, got $($l.PassedCount)/$($l.FailedCount)"
}
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 173) { throw "static" }
```

Expected lifecycle **38/0** = Task 2’s 30 + 8 dual-mapped names (`ok_output_state_usable`, `warn_output_state_usable`, `exit2_output_state_quarantined`, `fail_empty_output_state_none`, `isolate_fail_output_state_quarantine_failed`, `isolate_fail_retained_temp`, `isolate_fail_preserves_source`, `isolate_fail_keeps_temp_not_promoted_by_finalize`). Use those exact shared oracle/product names (do not add separate `product_*` duplicates).

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/ExtractionLifecycle.Harness.ahk tests/ExtractionLifecycle.Tests.ps1 tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "feat: verified quarantine and explicit FinalizeExtraction outputState"
```

- [ ] **Step 6: Review gate**

Quarantine success requires verified isolation; failed isolation reports retained temp; source never recycled on quarantine_failed. `Critical=0`, `Important=0`.

---

### Task 4: zipx Returns ArchiveResult and Outer Promotion Gate

**Files:**
- Modify: `SmartZip.ahk` — nested `zipx` returns; outer `Unzip` captures and gates on `outputState`; carry probe encryption evidence onto extract `DATA_CORRUPT`; nested recycle still clean-OK only
- Modify: `tests/SmartZip.Static.Tests.ps1` — outer gate, zipx return on all paths, no `DirExist(tmpDir)` sole authority
- Modify: `tests/NestingMigration.Tests.ps1` only if zipx slice patterns break; keep nested recycle invariants green

**Interfaces:**
- Consumes: Task 3 `outputState` contract
- Produces: promotion only for `usable`; every zipx path returns `ArchiveResult`; nested `Unzip` still works; volume skip / missing / early fail stay `outputState "none"`

- [ ] **Step 1: Failing static tests**

```powershell
    It 'zipx returns ArchiveResult on success and failure paths' {
        $u = $script:UnzipBody
        $ok = Test-Regex -Text $u -Pattern '(?s)zipx\s*\([^)]*\)\s*\{.{0,200}return\s+\w+'
        $ok | Should Be $true
        # multiple explicit returns of result objects
        $returns = [regex]::Matches($u, '(?m)^\s+return\s+(skipResult|missing|resolved|shown|extractResult|result)\b')
        ($returns.Count -ge 3) | Should Be $true
    }

    It 'outer Unzip promotes only when outputState is usable' {
        $u = $script:UnzipBody
        $ok = Test-Regex -Text $u -Pattern 'outputState\s*=\s*["'']usable["'']|outputState\s*!=\s*["'']usable["'']'
        $ok | Should Be $true
        # Must not use bare DirExist(tmpDir) as sole continue gate without outputState
        $legacyOnly = Test-Regex -Text $u -Pattern '(?s)zipx\([^)]*\)\s*\r?\n\s*if\s*!\s*DirExist\(tmpDir\)'
        $legacyOnly | Should Be $false
    }

    It 'FinalizeExtraction is the only post-extract outputState assigner referenced after ExtractArchiveToTemp' {
        $u = $script:UnzipBody
        $ok = Test-Regex -Text $u -Pattern '(?s)ExtractArchiveToTemp\(.+?FinalizeExtraction\('
        $ok | Should Be $true
    }
```

- [ ] **Step 2: Confirm RED**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
# New Its fail: zipx is void; gate is DirExist(tmpDir)
```

- [ ] **Step 3: Implement zipx returns + outer gate**

Outer loop in `Unzip` — replace `zipx(i)` / `DirExist` block start:

```ahk
            zipResult := zipx(i)
            if this.addDir2Pass
                this.password.RemoveAt(this.password.Length)

            ; Kirs.4: outputState is the sole promotion authority (not temp directory existence).
            if (zipResult.outputState != "usable")
                continue
```

The existing `loop files tmpDir "\*.*", "RDF"` followed by `AfterUnzip(A_LoopFileFullPath)`, single-entry move, multi-entry move, and nesting calls remain immediately after this new gate without another success predicate.

Make these exact `zipx` return-site replacements:

| Existing terminal action | Replacement |
|---|---|
| processed volume: `this.ShowDiagnostic(skipResult, isBatch)` then bare `return` | `this.ShowDiagnostic(skipResult, isBatch)` then `return skipResult` |
| missing volume: `this.ShowDiagnostic(missing, isBatch)` then bare `return` | `this.ShowDiagnostic(missing, isBatch)` then `return missing` |
| unresolved probe/password result: `shown := this.ShowDiagnostic(resolved, isBatch)` and no successful resume | `return shown` |
| failed forced test: `shown := this.ShowDiagnostic(tr, isBatch, A_Index = 1)` and no successful resume | `return shown` |
| extract password/eligible failure: `shown := this.ShowDiagnostic(extractResult, isBatch, A_Index = 1)` and no successful resume | `return shown` |
| finalized terminal result: `this.ShowDiagnostic(extractResult, isBatch, A_Index = 1)` then `break` | `this.ShowDiagnostic(extractResult, isBatch, A_Index = 1)` then `return extractResult` |

Inside the existing `zipx(path)` function, replace only the existing `if volume.isVolume` block with the block below. Do not replace or close the surrounding `zipx` function:

```ahk
            if volume.isVolume {
                key := StrLower(volume.firstPath)
                if this.processedVolumeFirst.Has(key) {
                    this.error := false
                    skipResult := ArchiveResult(ArchiveStatus.OK, "probe", 0, path)
                    skipResult.batchBucket := "skipped"
                    this.ShowDiagnostic(skipResult, isBatch)
                    return skipResult
                }
                if (volume.missingVolumes.Length || !FileExist(volume.firstPath)) {
                    missing := ArchiveResult(ArchiveStatus.MISSING_VOLUME, "probe", 2, path)
                    missing.volumeFirst := volume.firstPath
                    missing.missingVolumes := volume.missingVolumes
                    this.ShowDiagnostic(missing, isBatch)
                    return missing
                }
                this.processedVolumeFirst[key] := true
                path := volume.firstPath
            }
```

At the unresolved probe boundary, extend the existing predicate and return the shown result when recovery does not succeed:

```ahk
                shown := this.ShowDiagnostic(resolved, isBatch, A_Index = 1)
                if (!isBatch
                    && (resolved.status = ArchiveStatus.NEED_PASSWORD
                        || resolved.status = ArchiveStatus.WRONG_PASSWORD
                        || resolved.passwordRetryEligible)
                    && (shown.status = ArchiveStatus.OK || shown.status = ArchiveStatus.OK_WITH_WARNING)
                    && A_Index = 1) {
                    resolved := shown
                    continue
                }
                return shown
```

Inside the forced-test `DATA_CORRUPT` branch, carry probe evidence and offer the one-budget retry before deciding whether to extract salvageable output:

```ahk
                    } else if (tr.status = ArchiveStatus.DATA_CORRUPT) {
                        if (probe.encryptionEvidence) {
                            tr.encryptionEvidence := true
                            tr.passwordRetryEligible := true
                        }
                        if (!isBatch && tr.passwordRetryEligible && A_Index = 1) {
                            shown := this.ShowDiagnostic(tr, isBatch, true)
                            if (shown.status = ArchiveStatus.OK || shown.status = ArchiveStatus.OK_WITH_WARNING) {
                                resolved := shown
                                continue
                            }
                            return shown
                        }
                        ; Generic corruption, or batch encrypted corruption: extract only to salvage,
                        ; then FinalizeExtraction isolates any partial output.
                        this.error := true
                        mayHandleSource := false
                        nestedMayRecycle := false
```

In the forced-test non-`DATA_CORRUPT` failure branch, extend the existing password predicate and return the shown result:

```ahk
                        shown := this.ShowDiagnostic(tr, isBatch, A_Index = 1)
                        if (!isBatch
                            && (tr.status = ArchiveStatus.NEED_PASSWORD
                                || tr.status = ArchiveStatus.WRONG_PASSWORD
                                || tr.passwordRetryEligible)
                            && (shown.status = ArchiveStatus.OK || shown.status = ArchiveStatus.OK_WITH_WARNING)
                            && A_Index = 1) {
                            resolved := shown
                            continue
                        }
                        return shown
```

Immediately after `ExtractArchiveToTemp`, before `FinalizeExtraction`, carry proven probe encryption context:

```ahk
                if (extractResult.status = ArchiveStatus.DATA_CORRUPT && probe.encryptionEvidence) {
                    extractResult.encryptionEvidence := true
                    extractResult.passwordRetryEligible := true
                }
```

After finalization, extend the existing extract-result retry block:

```ahk
                if (!isBatch
                    && (extractResult.status = ArchiveStatus.NEED_PASSWORD
                        || extractResult.status = ArchiveStatus.WRONG_PASSWORD
                        || extractResult.passwordRetryEligible)
                    && A_Index = 1) {
                    shown := this.ShowDiagnostic(extractResult, isBatch, true)
                    if (shown.status = ArchiveStatus.OK || shown.status = ArchiveStatus.OK_WITH_WARNING) {
                        resolved := shown
                        continue
                    }
                    return shown
                }

                this.ShowDiagnostic(extractResult, isBatch, A_Index = 1)
                return extractResult
```

After the existing `Loop 2`, add a defensive return:

```ahk
            fallback := ArchiveResult(ArchiveStatus.UNKNOWN_ERROR, "extract", -1, path)
            return fallback
```

Keep `Loop 2` as the single resume budget. Nested recycle still requires `extractResult.isCleanSuccess`, not mere `usable`.

Hard rules:

- `quarantined`, `none`, and `quarantine_failed` never enter MoveItem destination naming.
- `usable` does not mean already published; outer MoveItem still runs.
- Volume members never source-recycled.
- `isCleanSuccess` and `outputState` are not interchangeable.

- [ ] **Step 4: GREEN**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 176) {
    throw "static expected 176/0, got $($s.PassedCount)/$($s.FailedCount)"
}
$l = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
if ($l.FailedCount -ne 0 -or $l.PassedCount -ne 38) { throw "lifecycle" }
$n = Invoke-Pester -Script .\tests\NestingMigration.Tests.ps1 -PassThru
if ($n.FailedCount -ne 0 -or $n.PassedCount -ne 30) { throw "nesting" }
$d = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
if ($d.FailedCount -ne 0 -or $d.PassedCount -ne 46) { throw "ui" }
```

Expected static **176/0** (173 + 3 structural Its from Step 1).

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 tests/NestingMigration.Tests.ps1
git diff --check --cached
git commit -m "feat: promote extraction only when outputState is usable"
```

- [ ] **Step 6: Review gate**

Failed quarantine cannot reach destination; volume skip returns `none`; nested recycle clean-only. `Critical=0`, `Important=0`.

---

### Task 5: ResolveArchivePassword Accepts passwordRetryEligible

**Files:**
- Modify: `SmartZip.ahk` — `ResolveArchivePassword` entry gate + batch noninteractive path
- Modify: `tests/PasswordPreflight.Harness.ahk` — eligible DATA_CORRUPT cases; batch flag cases
- Modify: `tests/PasswordPreflight.Tests.ps1` — case name list updates

**Interfaces:**
- Consumes: Task 1 `passwordRetryEligible`; Task 4 carry of probe evidence
- Produces: eligible `DATA_CORRUPT` runs candidate/dialog tests; generic `DATA_CORRUPT` still passthrough; batch never opens dialog

- [ ] **Step 1: Failing harness cases**

In `tests/PasswordPreflight.Harness.ahk`, keep existing `resolve_passthrough_DATA_CORRUPT` / `resolve_no_test_calls_DATA_CORRUPT` for **ineligible** generic corrupt. Add:

```ahk
; Eligible encrypted CRC: enters resolve and tests passwords
probeEnc := ArchiveResult(ArchiveStatus.DATA_CORRUPT, "extract", 2, "C:\\enc.7z", "ERROR: CRC Failed in encrypted file`n")
probeEnc.encryptionEvidence := true
probeEnc.passwordRetryEligible := true
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2, "C:\\enc.7z", "ERROR: CRC Failed in encrypted file`n"),
    "right-enc", ArchiveResult(ArchiveStatus.OK, "test", 0, "C:\\enc.7z", "Everything is Ok`n")
)
host.password := ["right-enc"]
host.dialogOverride := { action: "cancel", password: "" }
host.muilt := false
rEnc := host.ResolveArchivePassword("C:\\enc.7z", probeEnc)
AssertEq(rEnc.status, ArchiveStatus.OK, "resolve_eligible_data_corrupt_accepts_password")
AssertTrue(host.testCalls.Length > 0, "resolve_eligible_data_corrupt_runs_tests")

; Eligible but wrong/cancel: remains DATA_CORRUPT
probeEnc2 := ArchiveResult(ArchiveStatus.DATA_CORRUPT, "extract", 2, "C:\\enc2.7z", "ERROR: CRC Failed in encrypted file`n")
probeEnc2.encryptionEvidence := true
probeEnc2.passwordRetryEligible := true
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2, "C:\\enc2.7z", "ERROR: CRC Failed in encrypted file`n"),
    "nope", ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2, "C:\\enc2.7z", "ERROR: CRC Failed in encrypted file`n")
)
host.password := ["nope"]
host.dialogOverride := { action: "cancel", password: "" }
rEnc2 := host.ResolveArchivePassword("C:\\enc2.7z", probeEnc2)
AssertEq(rEnc2.status, ArchiveStatus.DATA_CORRUPT, "resolve_eligible_cancel_keeps_data_corrupt")

; Batch: never opens dialog even for NEED_PASSWORD after candidates fail
host.muilt := true
host.dialogCalls := 0
probeNeed := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2, "C:\\b.7z", "Enter password (will not be echoed):`n")
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\b.7z", "ERROR: Wrong password?`n")
)
host.password := []
host.dialogOverride := { action: "use", password: "should-not-run" }
rBatch := host.ResolveArchivePassword("C:\\b.7z", probeNeed)
AssertTrue(rBatch.status = ArchiveStatus.NEED_PASSWORD || rBatch.status = ArchiveStatus.WRONG_PASSWORD, "batch_resolve_no_success_without_candidates")
AssertEq(host.dialogCalls, 0, "batch_resolve_never_opens_password_dialog")
host.muilt := false
```

In the generated `PasswordPreflightHost` class, add `dialogCalls := 0`; in `ResetPasswordState`, add `this.dialogCalls := 0`; replace the harness wrapper with:

```ahk
PasswordPreflight_ShowPasswordDialog(this, path) {
    this.dialogCalls++
    if IsObject(this.dialogOverride)
        return this.dialogOverride
    return { action: "cancel", password: "" }
}
```

Append the five Pester names for the new harness keys; keep generic DATA_CORRUPT passthrough names green.

- [ ] **Step 2: Confirm RED**

```powershell
$p = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
# Eligible path currently short-circuits; batch still may open dialog
```

- [ ] **Step 3: Implement ResolveArchivePassword**

```ahk
    ResolveArchivePassword(path, probeResult) {
        st := probeResult.status
        eligible := (st = ArchiveStatus.NEED_PASSWORD || st = ArchiveStatus.WRONG_PASSWORD
            || (probeResult.HasOwnProp("passwordRetryEligible") && probeResult.passwordRetryEligible))
        if !eligible
            return probeResult

        emptyTry := this.TestArchive(path, "")
        if (emptyTry.status = ArchiveStatus.OK || emptyTry.status = ArchiveStatus.OK_WITH_WARNING)
            return emptyTry
        if (emptyTry.status != ArchiveStatus.NEED_PASSWORD && emptyTry.status != ArchiveStatus.WRONG_PASSWORD
            && !(emptyTry.HasOwnProp("passwordRetryEligible") && emptyTry.passwordRetryEligible)
            && emptyTry.status != ArchiveStatus.DATA_CORRUPT)
            return emptyTry

        last := emptyTry
        for pwd in this.BuildPasswordCandidates(path) {
            r := this.TestArchive(path, pwd)
            last := r
            if (r.status = ArchiveStatus.OK || r.status = ArchiveStatus.OK_WITH_WARNING)
                return r
            if (r.status = ArchiveStatus.CANCELLED)
                return r
            if (r.status != ArchiveStatus.NEED_PASSWORD && r.status != ArchiveStatus.WRONG_PASSWORD
                && !(r.HasOwnProp("passwordRetryEligible") && r.passwordRetryEligible)
                && r.status != ArchiveStatus.DATA_CORRUPT)
                return r
        }

        ; Batch / multi-select: never interactive password UI
        if (this.HasOwnProp("muilt") && this.muilt)
            return last

        dlg := this.ShowPasswordDialog(path)
        if (dlg.action = "cancel" || dlg.password = "") {
            if (probeResult.passwordRetryEligible)
                return probeResult  ; keep DATA_CORRUPT ambiguity; do not relabel cancel
            return ArchiveResult(ArchiveStatus.CANCELLED, "password", -1, path, "")
        }

        r := this.TestArchive(path, dlg.password)
        if (r.status = ArchiveStatus.OK || r.status = ArchiveStatus.OK_WITH_WARNING) {
            if (dlg.action = "save")
                this.RememberPassword(dlg.password)
            return r
        }
        if (probeResult.passwordRetryEligible && r.status = ArchiveStatus.DATA_CORRUPT)
            return r
        if (r.status = ArchiveStatus.NEED_PASSWORD || r.status = ArchiveStatus.WRONG_PASSWORD)
            return r
        return r
    }
```

Ensure `TestArchive` classification can set `passwordRetryEligible` on encrypted CRC outputs (Task 1 already does via `Classify7zResult`). When candidates produce generic non-password hard errors, still stop as today.

- [ ] **Step 4: GREEN**

```powershell
$p = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
if ($p.FailedCount -ne 0 -or $p.PassedCount -ne 83) {
    throw "password expected 83/0, got $($p.PassedCount)/$($p.FailedCount)"
}
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 176) { throw "static" }
$ui = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
if ($ui.FailedCount -ne 0 -or $ui.PassedCount -ne 46) { throw "ui" }
```

Expected password **83/0** (78 + 5 new names: eligible accept, eligible runs tests, eligible cancel keeps DATA_CORRUPT, batch no success without candidates, batch never opens dialog).

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/PasswordPreflight.Harness.ahk tests/PasswordPreflight.Tests.ps1
git diff --check --cached
git commit -m "feat: resolve passwords for encrypted-CRC eligibility; batch never prompts"
```

- [ ] **Step 6: Review gate**

Generic CRC still passthrough; eligible path tests passwords; batch dialogCalls=0; cancel on eligible keeps DATA_CORRUPT. `Critical=0`, `Important=0`.

---

### Task 6: Diagnostic UI Encrypted-CRC Recovery and Ambiguity Copy

**Files:**
- Modify: `SmartZip.ahk` — `DiagnosticButtons`, `DiagnosticReason`, `DiagnosticRecommendation`, and `ShowDiagnostic` retained-output path display
- Modify: `tests/DiagnosticUI.Tests.ps1` — CaseKeys, `MakeResult`, headless command input, and five Its
- Modify: `tests/SmartZip.Static.Tests.ps1` — widen the existing password-button structural assertion to include eligible encrypted corruption

**Interfaces:**
- Consumes: Task 5 resolver; Task 1 eligibility flags
- Produces: retry button for eligible DATA_CORRUPT; ambiguity reason/recommendation; batch still noninteractive; one-budget resume already wired in Task 4

- [ ] **Step 1: Failing UI tests**

Add CaseKeys and Its:

```powershell
    It 'button_retry_password_eligible_data_corrupt' {
        $out = Invoke-DiagnosticUICase -Command 'buttons' -CaseKey 'button_retry_password_eligible_data_corrupt' `
            -Json '{"status":"DATA_CORRUPT","passwordRetryEligible":true,"encryptionEvidence":true}'
        $j = $out | ConvertFrom-Json
        ($j.buttons -join '|') | Should Match '重新输入密码'
    }

    It 'button_no_retry_generic_data_corrupt' {
        $out = Invoke-DiagnosticUICase -Command 'buttons' -CaseKey 'button_no_retry_generic_data_corrupt' `
            -Json '{"status":"DATA_CORRUPT","passwordRetryEligible":false}'
        $j = $out | ConvertFrom-Json
        ($j.buttons -join '|') | Should Not Match '重新输入密码'
    }

    It 'reason_data_corrupt_eligible_ambiguous' {
        $out = Invoke-DiagnosticUICase -Command 'reason' -CaseKey 'reason_data_corrupt_eligible_ambiguous' `
            -Json '{"status":"DATA_CORRUPT","passwordRetryEligible":true}'
        $j = $out | ConvertFrom-Json
        $j.reason | Should Match '密码'
        $j.reason | Should Match '损坏'
        $j.recommendation | Should Match '密码'
        $j.recommendation | Should Match '损坏|重新'
    }

    It 'recovery_eligible_data_corrupt_success_closes' {
        $out = Invoke-DiagnosticUICase -Command 'recovery' -CaseKey 'recovery_eligible_data_corrupt_success_closes' `
            -Json '{"status":"DATA_CORRUPT","passwordRetryEligible":true,"retryMode":"success","clickRetry":true}'
        $j = $out | ConvertFrom-Json
        $j.returnStatus | Should Be 'OK'
        $j.closed | Should Be $true
    }

    It 'recovery_batch_eligible_never_opens_gui' {
        $out = Invoke-DiagnosticUICase -Command 'recovery' -CaseKey 'recovery_batch_eligible_never_opens_gui' `
            -Json '{"status":"DATA_CORRUPT","passwordRetryEligible":true,"isBatch":true}'
        $j = $out | ConvertFrom-Json
        $j.guiCalls | Should Be 0
    }

    It 'batch_summary_marks_encrypted_crc_as_password_check_or_damage' {
        $out = Invoke-DiagnosticUICase -Command 'batch_failures' `
            -CaseKey 'batch_summary_marks_encrypted_crc_as_password_check_or_damage' `
            -Json '{"paths":["D:\\x\\encrypted.7z"],"passwordRetryEligible":true}' `
            -StageDir $script:StageDir
        $summary = Get-JsonField $out 'summaryText'
        $summary | Should Match '密码'
        $summary | Should Match '损坏'
        (Get-JsonField $out 'guiCalls') | Should Be '0'
    }
```

Append the six names to `$script:CaseKeys`. In the generated AHK footer, extend `MakeResult` inside `if (extra != "")`:

```ahk
        if JsonGetBool(extra, "passwordRetryEligible", false)
            r.passwordRetryEligible := true
        if JsonGetBool(extra, "encryptionEvidence", false)
            r.encryptionEvidence := true
        if RegExMatch(extra, '"retainedOutputDir"\s*:\s*"([^"]*)"', &m8)
            r.retainedOutputDir := JsonUnescape(m8[1])
```

Pass the JSON flags into the reason command:

```ahk
        r := MakeResult(status, "D:\\data\\folder\\pack.7z", jsonText)
```

In the recovery command, honor batch input:

```ahk
        isBatch := JsonGetBool(jsonText, "isBatch", false)
        returned := host.ShowDiagnostic(r, isBatch)
```

The existing click block remains guarded by `clickRetry`; the batch case does not set it and therefore cannot invoke the button handler.

In the `batch_failures` command, mark the first synthetic failure eligible when requested:

```ahk
        eligibleBatchFailure := JsonGetBool(jsonText, "passwordRetryEligible", false)
        for index, p in paths {
            r := MakeResult(ArchiveStatus.DATA_CORRUPT, p)
            if (eligibleBatchFailure && index = 1) {
                r.passwordRetryEligible := true
                r.encryptionEvidence := true
            }
            if (pw != "")
                r.passwordUsed := JsonUnescape(pw)
            host.ShowDiagnostic(r, true)
        }
```

- [ ] **Step 2: Confirm RED**

```powershell
$ui = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
```

- [ ] **Step 3: Implement UI copy and buttons**

```ahk
    ; Replace only the existing DATA_CORRUPT arm in DiagnosticReason:
    case ArchiveStatus.DATA_CORRUPT:
        if (result.HasOwnProp("passwordRetryEligible") && result.passwordRetryEligible)
            return "CRC 或数据校验失败；密码可能不正确，或加密数据已损坏。"
        return "CRC 或数据校验失败。"

    ; Replace only the existing DATA_CORRUPT arm in DiagnosticRecommendation:
    case ArchiveStatus.DATA_CORRUPT:
        if (result.HasOwnProp("passwordRetryEligible") && result.passwordRetryEligible)
            return "可重新输入密码重试；若仍失败，请保留源包并检查“不完整”目录中的可用文件。"
        return "请检查“不完整”目录中的可用文件，并重新获取源包。"

    DiagnosticButtons(result, allowPasswordRetry := true) {
        buttons := []
        if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.CANCELLED)
            return buttons
        partialPath := result.partialOutputDir
        if (partialPath = "" && result.HasOwnProp("retainedOutputDir"))
            partialPath := result.retainedOutputDir
        if (partialPath != "" && DirExist(partialPath))
            buttons.Push("打开部分文件目录")
        if (allowPasswordRetry
            && (result.status = ArchiveStatus.NEED_PASSWORD
                || result.status = ArchiveStatus.WRONG_PASSWORD
                || (result.HasOwnProp("passwordRetryEligible") && result.passwordRetryEligible)))
            buttons.Push("重新输入密码")
        if (result.status = ArchiveStatus.MISSING_VOLUME)
            buttons.Push("定位首卷")
        buttons.Push("使用 7-Zip 打开")
        buttons.Push("复制脱敏诊断信息")
        buttons.Push("关闭")
        return buttons
    }
```

Before `return msg` in `FormatBatchDiagnosticSummary`, append an ambiguity cue when any failed item is eligible:

```ahk
        needsPasswordCheck := false
        for failed in b.failure {
            if (failed.passwordRetryEligible) {
                needsPasswordCheck := true
                break
            }
        }
        if needsPasswordCheck
            msg .= "`n提示: 部分加密文件需要检查密码，也可能已损坏。"
        return msg
```

In `ShowDiagnostic`, replace the local partial-path assignment with:

```ahk
        partial := result.partialOutputDir
        if (partial = "" && result.outputState = "quarantine_failed"
            && result.retainedOutputDir != "")
            partial := result.retainedOutputDir
```

Pass that `partial` value to `DiagnosticButtons`, `DiagnosticShowGui`, and `DiagnosticButtonAction` exactly as the current `partialOutputDir` local is passed, so users can open the retained location.

`DiagnosticButtonAction` for `重新输入密码` already calls `ResolveArchivePassword` — Task 5 makes eligible results work. Keep no extract/finalize/recycle in the button handler.

Replace the existing static It named `password retry limited to NEED_PASSWORD and WRONG_PASSWORD` with:

```powershell
    It 'password retry is limited to password states or eligible encrypted corruption' {
        $btn = $script:DiagnosticButtonsBody
        if ([string]::IsNullOrEmpty($btn)) { $btn = $script:SmartZipSource }
        $btn | Should Match 'NEED_PASSWORD'
        $btn | Should Match 'WRONG_PASSWORD'
        $btn | Should Match 'passwordRetryEligible'
        $btn | Should Match '重新输入密码'
    }
```

- [ ] **Step 4: GREEN**

```powershell
$ui = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
if ($ui.FailedCount -ne 0 -or $ui.PassedCount -ne 52) {
    throw "ui expected 52/0, got $($ui.PassedCount)/$($ui.FailedCount)"
}
$p = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
if ($p.FailedCount -ne 0 -or $p.PassedCount -ne 83) { throw "password" }
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 176) { throw "static" }
```

Expected DiagnosticUI **52/0** (46 + 6 Its from Step 1).

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/DiagnosticUI.Tests.ps1 tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "feat: encrypted-CRC diagnostic retry and ambiguous recovery copy"
```

- [ ] **Step 6: Review gate**

Generic DATA_CORRUPT has no retry button; eligible has button; batch guiCalls=0; eligible batch summary says password check or damage; passwords never appear in copy or summary. `Critical=0`, `Important=0`.

---

### Task 7: Settings Accuracy

**Files:**
- Modify: `SmartZip.ahk` — settings tab controls/labels/tips only (no new INI keys; no page redesign)
- Modify: `tests/SmartZip.Static.Tests.ps1` — settings string assertions

**Interfaces:**
- Consumes: existing `ini.partSkip`, `ini.test`, `ini.delSource`, `ini.delWhenHasPass`, nesting keys
- Produces: accurate labels; `partSkip` not presented as an effective runtime switch; source wording uses 移入回收站; full-test behavior described; nesting recycle described separately

- [ ] **Step 1: Failing static tests**

```powershell
    It 'settings describe full archive test behavior instead of empty experimental flag' {
        $src = $script:SmartZipSource
        $src | Should Not Match '启用测试中的功能'
        $src | Should Not Match '当前没有测试中功能'
        $ok = Test-Regex -Text $src -Pattern '完整.*测试|强制.*测试|解压前测试|test.*archive'
        $ok | Should Be $true
    }

    It 'settings present volume once-processing as noninteractive explanation' {
        $src = $script:SmartZipSource
        # partSkip INI key must remain for compatibility
        $src | Should Match 'partSkip'
        # Must not use GuiCheckBox("partSkip" as an effective user switch presentation
        $legacy = Test-Regex -Text $src -Pattern 'GuiCheckBox\(\s*"partSkip"'
        $legacy | Should Be $false
        $ok = Test-Regex -Text $src -Pattern '同组只解压一次|任一卷从首卷'
        $ok | Should Be $true
    }

    It 'settings source handling wording uses recycle bin language' {
        $src = $script:SmartZipSource
        $ok = Test-Regex -Text $src -Pattern '移入回收站'
        $ok | Should Be $true
        # Tips still state clean success only and volumes never auto-handled
        $ok2 = Test-Regex -Text $src -Pattern '(?s)(完全|干净|成功).{0,40}(回收站|移入)'
        $ok2 | Should Be $true
    }

    It 'settings keep nested recycle description separate from top-level source recycle' {
        $src = $script:SmartZipSource
        $src | Should Match 'nesting'
        $src | Should Match 'nestingMuilt'
        $ok = Test-Regex -Text $src -Pattern '嵌套'
        $ok | Should Be $true
    }
```

- [ ] **Step 2: Confirm RED**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
```

- [ ] **Step 3: Update settings UI copy**

Replace the source/nesting/test/volume controls block with accurate non-redesign copy. Keep `ini` read/write for `partSkip` elsewhere; settings page shows explanation only:

```ahk
    GuiCheckBox("nesting", ini.nesting, "解压嵌套压缩包", "嵌套源包仅在完全干净成功后移入回收站，且仅针对单文件", "Section")
    GuiCheckBox("nestingMuilt", ini.nestingMuilt, "解压嵌套文件夹", "只检查第一层文件夹；嵌套源包仅在完全干净成功后移入回收站", "x+170 yp")
    GuiCheckBox("delSource", ini.delSource, "解压后将源文件移入回收站", "仅在完全干净成功（无警告）时处理；警告与失败均保留源包；分卷永不自动处理")
    GuiCheckBox("delWhenHasPass", ini.delWhenHasPass, "仅将含密码的源文件移入回收站", "不需要选中上方源文件选项；同样仅完全干净成功时生效", "yp x+90")

    ; Tab 3 — volume / test
    set.AddText("Section w420", "分卷：同组成员始终只处理一次（从首卷开始）。此项为说明，不是可关闭开关。兼容保留 ini 键 partSkip。")
    ; Keep runtime default behavior: Unzip still reads this.partSkip := ini.partSkip for compatibility
    ; but does not use it as an early-continue switch (Kirs.3 already removed that).
    GuiCheckBox("test", ini.test, "解压前完整测试压缩包", "启用后始终先完整测试；即使关闭，源文件处理与嵌套回收仍会强制完整测试")
    GuiCheckBox("cmdLog", ini.cmdLog, "启用测试日志", "检查文件时的测试日志,与下文的日志等级无关")
```

Remove the `GuiCheckBox` call whose first argument is `"partSkip"` from the settings page. Preserve:

- `ini` schema key `partSkip`
- `this.partSkip := ini.partSkip` load if still present (harmless compatibility)
- `ini.setWrite("partSkip", 1)` migration default if present

Do not rename INI keys. Do not redesign tabs.

- [ ] **Step 4: GREEN**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 180) {
    throw "static expected 180/0, got $($s.PassedCount)/$($s.FailedCount)"
}
```

Expected static **180/0** (176 + 4 settings Its). Volume selection tests that require the `partSkip` INI key presence must still pass.

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
git diff --check --cached
git commit -m "fix: align settings labels with full-test and recycle-bin behavior"
```

- [ ] **Step 6: Review gate**

No new INI keys; partSkip not an effective checkbox; recycle wording accurate; nesting separate. `Critical=0`, `Important=0`.

---

### Task 8: Integration outputState and Production Smoke Strengthening

**Files:**
- Modify: `tests/IntegrationTestHook.ahk` — JSON fields `outputState`, `retainedOutputDir`
- Modify: `tests/Real7Zip.Integration.Tests.ps1` — assert outcome states on key fixtures
- Verify without modifying: `tests/Invoke-ProductionSmartZipSmoke.ps1` and `tests/ProductionSmokeUI.ahk` — retain existing hook-free crcPartial/no-normal-target checks
- Do not reintroduce production hook includes

**Interfaces:**
- Consumes: product `outputState` from Tasks 3–4; `ShowDiagnostic` → `SmartZipTest_OnResult`
- Produces: integration JSON exposes outcome state; real fixtures exercise usable / quarantined / none

- [ ] **Step 1: Failing integration assertions**

Update hook JSON builder:

```ahk
    outputState := "none"
    if result.HasOwnProp("outputState")
        outputState := result.outputState
    retained := ""
    if result.HasOwnProp("retainedOutputDir")
        retained := result.retainedOutputDir
    json := "{"
        . '"marker":"SMARTZIP_TEST_RESULT_V1",'
        . '"status":"' esc(status) '",'
        . '"stage":"' esc(stage) '",'
        . '"exitCode":' exitCode ','
        . '"isCleanSuccess":' isClean ','
        . '"mayDeleteSource":' mayDelete ','
        . '"outputState":"' esc(outputState) '",'
        . '"archiveBaseName":"' esc(baseName) '",'
        . '"partialOutputDir":"' esc(partial) '",'
        . '"retainedOutputDir":"' esc(retained) '",'
        . '"warning":"' esc(warnJoined) '",'
        . '"error":"' esc(errJoined) '",'
        . '"output":"' esc(SubStr(redOutput, 1, 2048)) '"'
        . "}"
```

Add Its (names exact):

```powershell
    It 'valid fixture reports usable outputState' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'kirs4-output' -Scenario 'valid' -DelSource 0 -PasswordMode 'none'
        $run.Result.outputState | Should Be 'usable'
        $run.Result.status | Should Be 'OK'
    }

    It 'trailingWarning fixture reports usable not clean' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'kirs4-output' -Scenario 'trailingWarning' -DelSource 0 -PasswordMode 'none'
        $run.Result.outputState | Should Be 'usable'
        $run.Result.isCleanSuccess | Should Be $false
        Assert-SourcePreserved $run
    }

    It 'crcPartial fixture reports quarantined and not normal target' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'kirs4-output' -Scenario 'crcPartial' -DelSource 0 -PasswordMode 'none'
        $run.Result.outputState | Should Be 'quarantined'
        $run.Result.status | Should Be 'DATA_CORRUPT'
        $run.PartialDirs.Count | Should Be 1
        $bad = @($run.TargetInventory | Where-Object {
            $_ -notmatch '_解压不完整_' -and
            ($_ -match 'alpha\.txt$' -or $_ -match 'beta\.txt$' -or
             $_ -match 'alpha\.bin$' -or $_ -match 'beta\.bin$')
        })
        $bad.Count | Should Be 0
    }

    It 'missing volume reports none and no promotion' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'kirs4-output' -Scenario 'splitMissing' -DelSource 0 -PasswordMode 'none'
        $run.Result.outputState | Should Be 'none'
        $run.Result.status | Should Be 'MISSING_VOLUME'
        Assert-AllVolumeMembersPresent -Run $run -FixtureKey 'splitMissing'
    }
```

Keep the two TEMP-injection contracts and the existing production smoke scenarios green. Do not add the hook serializer to production smoke.

- [ ] **Step 2: Confirm RED**

```powershell
$i = Invoke-Pester -Script .\tests\Real7Zip.Integration.Tests.ps1 -PassThru
# Fails until hook emits outputState and product sets it end-to-end
```

- [ ] **Step 3: Hook + any tiny product glue**

Implement hook fields (Step 1). If clean OK paths call `ShowDiagnostic` and early-return before Finalize sets state, ensure zipx still returns finalized `extractResult` with `outputState` and that `SmartZipTest_OnResult` receives the finalized result (existing end-of-loop `ShowDiagnostic(extractResult)`). No production include of the hook.

- [ ] **Step 4: GREEN**

```powershell
$i = Invoke-Pester -Script .\tests\Real7Zip.Integration.Tests.ps1 -PassThru
if ($i.FailedCount -ne 0 -or $i.PassedCount -ne 36) {
    throw "integration expected 36/0, got $($i.PassedCount)/$($i.FailedCount)"
}
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($s.FailedCount -ne 0 -or $s.PassedCount -ne 180) { throw "static" }
$hookHits = Select-String -Path .\SmartZip.ahk -Pattern 'IntegrationTestHook' -SimpleMatch
if ($hookHits) { throw 'production source still references IntegrationTestHook' }
```

Expected integration **36/0** (32 + 4 outputState Its).

- [ ] **Step 5: Commit**

```powershell
git add -- tests/IntegrationTestHook.ahk tests/Real7Zip.Integration.Tests.ps1
git diff --check --cached
git commit -m "test: expose outputState in integration results and assert fixtures"
```

- [ ] **Step 6: Review gate**

No password in JSON; production source hook-free; usable/quarantined/none covered. `Critical=0`, `Important=0`.

---

### Task 9: Kirs.4 Metadata, Documentation, and Whole-Branch Verification

**Files:**
- Modify: `SmartZip.ahk` — `edition`, `buildVersion`, `;@Ahk2Exe-SetProductVersion`, `buileTime`
- Modify: `tests/SmartZip.Static.Tests.ps1` — VersionBanner + `Kirs4MetadataAndDocs`
- Modify: `README.md` — Kirs.4 trustworthy-outcomes section; preserve Kirs.2/Kirs.3 history
- Modify: `ini.md` — settings accuracy notes; partSkip compatibility; recycle wording
- Modify: `tests/Real7Zip.Integration.Tests.ps1` — rename the TEMP root prefix from `SmartZip-Kirs3-` to `SmartZip-Kirs4-`
- Modify: `tests/README.md` — final exact suite table and `SmartZip-Kirs4-` TEMP root prefix

**Interfaces:**
- Consumes: all prior task behaviors
- Produces: identity `SmartZip 3.6 Kirs.4 (24)`; docs match behavior; whole-branch green gate

- [ ] **Step 1: Failing metadata tests**

```powershell
    It 'edition is Kirs.4' {
        $script:SmartZipSource | Should Match 'edition\s*:=\s*"Kirs\.4"'
    }
    It 'buildVersion is 24' {
        $script:SmartZipSource | Should Match 'buildVersion\s*:=\s*24\b'
    }
    It 'Ahk2Exe product version is 24' {
        $script:SmartZipSource |
            Should Match ';@Ahk2Exe-SetProductVersion\s+24\b'
    }
    It 'Ahk2Exe file version remains 3.6' {
        $script:SmartZipSource |
            Should Match ';@Ahk2Exe-SetFileVersion\s+3\.6\b'
    }
```

These replace the existing Kirs.3 expectations in `VersionBanner`; also replace its build-time It with:

```powershell
    It 'buileTime matches the Kirs.4 build timestamp' {
        $script:SmartZipSource |
            Should Match 'buileTime\s*:=\s*"2026/7/24 05:00:00"'
    }
```

Rename `Kirs3MetadataAndDocs` to `Kirs4MetadataAndDocs` and update its existing Kirs.3 identity Its to Kirs.4 / 24. Preserve its Kirs.2/Kirs.3 historical documentation assertions. Append exactly two new Its:

```powershell
    It 'Kirs4 README documents trustworthy outcomes' {
        $script:ReadmeText | Should Match 'Kirs\.4'
        $okOut = Test-Regex -Text $script:ReadmeText -Pattern 'outputState|可用输出|不完整|quarantine|隔离'
        $okExit = Test-Regex -Text $script:ReadmeText -Pattern '退出码\s*1|exit code\s*1|警告'
        $okEnc = Test-Regex -Text $script:ReadmeText -Pattern '加密|CRC|密码'
        ($okOut -and $okExit -and $okEnc) | Should Be $true
    }

    It 'Kirs4 docs do not claim replacing Kirs.3 history' {
        $combined = $script:ReadmeText + "`n" + $script:IniDocText
        $replaced = Test-Regex -Text $combined -Pattern `
            '(?i)(Kirs\.3\s*(已被?替换|is\s+replaced)|replaces?\s+Kirs\.3|替代\s*Kirs\.3)'
        $replaced | Should Be $false
    }

```

Update the existing Kirs.3 `partSkip` documentation It so it additionally requires `回收站|移入回收站`; rename the existing production-hook It to Kirs.4 without adding a duplicate. This preserves all earlier documentation coverage and adds exactly two static Its.

- [ ] **Step 2: Confirm RED**

```powershell
$s = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
```

- [ ] **Step 3: Apply metadata + docs**

`SmartZip.ahk` header:

```ahk
;@Ahk2Exe-SetFileVersion 3.6
;@Ahk2Exe-SetProductVersion 24
;@Ahk2Exe-ExeName SmartZip.exe
buildVersion := 24
MainVersion := "3.6"
edition := "Kirs.4"
buileTime := "2026/7/24 05:00:00"
```

`README.md` — add `## 3.6 Kirs.4 可信结果` covering:

- Explicit `outputState` promotion: only `usable` publishes normally
- Quarantine verification and `quarantine_failed` retained temp reporting
- Exit code `1` warning only with same-process warning evidence
- Encrypted CRC may offer password retry; generic CRC does not; unresolved stays ambiguous
- Batch never interactive password
- Settings accuracy (full test, volume-once explanation, 移入回收站)
- Production builds exclude test hooks
- Explicit note: Kirs.4 is a new release line; does not replace Kirs.1–Kirs.3 tags/releases
- Keep Kirs.3 convenience and Kirs.2 safety sections

`ini.md` — update source/test/partSkip rows for recycle-bin and compatibility wording; add Kirs.4 note block.

`tests/Real7Zip.Integration.Tests.ps1` and `tests/README.md` — replace the literal TEMP prefix `SmartZip-Kirs3-` with `SmartZip-Kirs4-`; the GUID suffix generation remains unchanged.

- [ ] **Step 4: Whole-branch GREEN gate**

```powershell
$ErrorActionPreference = 'Stop'
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=182
  'ArchiveDiagnostics.Tests.ps1'=191
  'RunCmdCapture.Tests.ps1'=15
  'PasswordPreflight.Tests.ps1'=83
  'ExtractionLifecycle.Tests.ps1'=38
  'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=52
  'Real7Zip.Integration.Tests.ps1'=36
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
& 'C:\Tool\7-Zip-Zstandard\7z.exe' i | Select-Object -First 5
```

Final static **182/0** = 180 (after Task 7) + 2 new documentation Its. VersionBanner and existing Kirs.3 metadata Its are updated in place and do not change the count.

Write the same table into `tests/README.md` before commit.

- [ ] **Step 5: Commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 tests/Real7Zip.Integration.Tests.ps1 tests/README.md README.md ini.md
git diff --check --cached
git commit -m "docs: prepare SmartZip 3.6 Kirs.4 trustworthy outcomes"
```

- [ ] **Step 6: Review gate**

Identity consistency, docs match behavior, no password in diffs, Kirs.1–3 history not claimed replaced, hook absent. `Critical=0`, `Important=0`.

---

### Task 10: Build, Smoke-Test, Deploy, and Publish v3.6-kirs.4

**Outputs:**

- Build: `%TEMP%\smartzip-kirs4-build-$stamp\SmartZip.exe`
- Deploy: `C:\Tool\SmartZip\SmartZip.exe`
- Backup: `C:\Tool\SmartZip\SmartZip.exe.bak-$stamp`
- Branch: `codex/kirs4-trustworthy-outcomes`
- Tag/Release: `v3.6-kirs.4`
- Release asset: `SmartZip.exe`

Every stop condition below is mandatory. Do not deploy, push, tag, or publish after a failed command.

- [ ] **Step 1: Freeze prior-release evidence and verify source/toolchain**

```powershell
$ErrorActionPreference = 'Stop'
$repo = 'kirsartx/SmartZip'
$oldTag1 = (git ls-remote origin refs/tags/v3.6-kirs.1).Split()[0]
$oldTag2 = (git ls-remote origin refs/tags/v3.6-kirs.2).Split()[0]
$oldTag3 = (git ls-remote origin refs/tags/v3.6-kirs.3).Split()[0]
$oldRelease1 = gh release view v3.6-kirs.1 --repo $repo --json tagName,targetCommitish,url,assets | ConvertFrom-Json
$oldRelease2 = gh release view v3.6-kirs.2 --repo $repo --json tagName,targetCommitish,url,assets | ConvertFrom-Json
$oldRelease3 = gh release view v3.6-kirs.3 --repo $repo --json tagName,targetCommitish,url,assets | ConvertFrom-Json
$oldRelease1Json = $oldRelease1 | ConvertTo-Json -Depth 8 -Compress
$oldRelease2Json = $oldRelease2 | ConvertTo-Json -Depth 8 -Compress
$oldRelease3Json = $oldRelease3 | ConvertTo-Json -Depth 8 -Compress

$suites = [ordered]@{
  'SmartZip.Static.Tests.ps1'=182
  'ArchiveDiagnostics.Tests.ps1'=191
  'RunCmdCapture.Tests.ps1'=15
  'PasswordPreflight.Tests.ps1'=83
  'ExtractionLifecycle.Tests.ps1'=38
  'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=52
  'Real7Zip.Integration.Tests.ps1'=36
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
if ($prodSrc -notmatch 'edition\s*:=\s*"Kirs\.4"') { throw 'edition not Kirs.4' }
if ($prodSrc -notmatch 'buildVersion\s*:=\s*24\b') { throw 'buildVersion not 24' }
```

Record `$oldTag1/2/3` and release JSON snapshots. Suite counts must match Task 9 / `tests/README.md`.

- [ ] **Step 2: Ensure clean final commit on the Kirs.4 branch**

```powershell
git status --short --branch
git diff --check
git log --oneline --decorate -12
if (git status --porcelain) {
    throw 'worktree is not clean; return to the owning task instead of staging broad paths'
}
$releaseCommit = git rev-parse HEAD
```

Never stage `.superpowers`, TEMP fixtures, credentials, deployed files, backups, or unrelated user changes. Every implementation file must already belong to a reviewed focused commit from Tasks 1–9.

- [ ] **Step 3: Compile production staging tree (hook-free)**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$buildDir = Join-Path $env:TEMP "smartzip-kirs4-build-$stamp"
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
if ($version.ProductVersion -notmatch '^24(\.0\.0)?$') { throw "unexpected ProductVersion $($version.ProductVersion)" }
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
$smokeRoot = Join-Path $env:TEMP "smartzip-kirs4-smoke-$stamp"
$fixtureRoot = Join-Path $smokeRoot 'fixtures'
$manifestPath = Join-Path $smokeRoot 'fixtures.json'
$artifactSmokeRoot = Join-Path $smokeRoot 'built-artifact'
New-Item -ItemType Directory -Path $smokeRoot,$fixtureRoot,$artifactSmokeRoot | Out-Null

$fixturePassword = "K4-$([guid]::NewGuid().ToString('N'))!"
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
[IO.File]::WriteAllText($payload, 'SmartZip 3.6 Kirs.4 smoke', [Text.UTF8Encoding]::new($false))
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

Re-run production smoke against deployed EXE from TEMP fixtures only; on failure restore backup:

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
$branchTip = git rev-parse HEAD
git push -u origin codex/kirs4-trustworthy-outcomes
$prUrl = gh pr create --repo $repo --base main --head codex/kirs4-trustworthy-outcomes `
  --title 'SmartZip 3.6 Kirs.4 trustworthy outcomes' `
  --body 'Explicit outputState promotion, verified quarantine, exit-code-1 warning accuracy, encrypted-CRC password-retry eligibility with ambiguous diagnostics, batch noninteractive password paths, settings accuracy, and Kirs.4 release packaging. Preserves all Kirs.1–Kirs.3 safety invariants. Does not mutate v3.6-kirs.1 through v3.6-kirs.3.'
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($prUrl -join ''))) {
    throw 'PR creation failed'
}
$checks = gh pr checks $prUrl --repo $repo 2>&1
$checksExit = $LASTEXITCODE
if ($checksExit -ne 0 -and ($checks -join "`n") -notmatch '(?i)no checks') {
    throw "unable to read PR checks: $($checks -join "`n")"
}
if (($checks -join "`n") -notmatch '(?i)no checks') {
    gh pr checks $prUrl --repo $repo --watch
    if ($LASTEXITCODE -ne 0) { throw 'PR checks failed' }
} else {
    'NO_GITHUB_CHECKS_CONFIGURED'
}
```

Stop and require independent reviewer `Critical=0`, `Important=0`. Only after that gate passes:

```powershell
gh pr merge $prUrl --repo $repo --merge
if ($LASTEXITCODE -ne 0) { throw 'PR merge failed' }
git switch main
git pull --ff-only origin main
$releaseCommit = git rev-parse HEAD
if (git status --porcelain) { throw 'main not clean' }
git merge-base --is-ancestor $branchTip $releaseCommit
if ($LASTEXITCODE -ne 0) { throw 'merged main does not contain the reviewed Kirs.4 branch tip' }
```

- [ ] **Step 7: Create immutable tag and Release `v3.6-kirs.4`**

Do not move, delete, edit, or replace `v3.6-kirs.1`, `v3.6-kirs.2`, or `v3.6-kirs.3`.

```powershell
$existingTag = git ls-remote origin refs/tags/v3.6-kirs.4 2>$null
if ($LASTEXITCODE -ne 0) { throw 'failed to query remote tag state' }
if ($existingTag) { throw 'v3.6-kirs.4 already exists' }
git tag -a v3.6-kirs.4 $releaseCommit -m 'SmartZip 3.6 Kirs.4'
git push origin refs/tags/v3.6-kirs.4

$notes = @"
## SmartZip 3.6 Kirs.4 (24)

- 显式 outputState 结果契约：仅 usable 进入正常目标目录；quarantined / none / quarantine_failed 永不静默晋升
- 隔离失败时保留并报告临时目录（retainedOutputDir），阻断后续命名/覆盖/源处理
- 7-Zip 退出码 1 仅在同进程警告证据充分且无硬错误时记为 OK_WITH_WARNING；GUI 解压退出 1 不借用后续 7z t 警告文本冒充成功
- 加密 CRC/数据错误可提供密码重试资格，但不改判为 WRONG_PASSWORD；普通 CRC 不提供密码重试
- 批量/多选永不弹出密码对话框；未解决加密失败保持“密码可能错误或数据损坏”的诚实说明
- 设置文案对齐真实行为：完整测试、分卷同组一次说明、源文件移入回收站
- 保留 Kirs.1–Kirs.3 全部安全门：仅干净 OK 才处理源包；分卷永不自动处理；密码不落日志；生产无测试钩子

引擎：C:\Tool\7-Zip-Zstandard\7z.exe

SmartZip.exe SHA-256: $builtHash

升级时只替换 SmartZip.exe；请保留 SmartZip.ini 与 Contextmenu.exe。
Kirs.4 是新版本发布；不替换 v3.6-kirs.1 / v3.6-kirs.2 / v3.6-kirs.3 标签或 Release。
"@
gh release create v3.6-kirs.4 $builtExe --repo $repo `
  --title 'SmartZip 3.6 Kirs.4' --notes $notes --latest
```

Release notes suite line (exact after Task 9):

```text
Pester：静态 182、诊断 191、命令捕获 15、密码 83、生命周期 38、嵌套 30、诊断界面 52、真实集成 36，全部通过。
```

- [ ] **Step 8: Download and verify published/deployed/prior-release evidence**

```powershell
$downloadDir = Join-Path $env:TEMP "smartzip-kirs4-release-check-$stamp"
New-Item -ItemType Directory -Path $downloadDir | Out-Null
gh release download v3.6-kirs.4 --repo $repo --pattern 'SmartZip.exe' --dir $downloadDir
$downloaded = Join-Path $downloadDir 'SmartZip.exe'
$downloadedHash = (Get-FileHash $downloaded -Algorithm SHA256).Hash
if ($downloadedHash -ne $builtHash) { throw 'downloaded release hash mismatch' }
if ((Get-FileHash $deployExe -Algorithm SHA256).Hash -ne $builtHash) { throw 'deployed hash mismatch' }

$newRelease = gh release view v3.6-kirs.4 --repo $repo `
  --json tagName,name,isDraft,isPrerelease,targetCommitish,url,assets | ConvertFrom-Json
if ($newRelease.tagName -ne 'v3.6-kirs.4' -or $newRelease.isDraft -or $newRelease.isPrerelease) {
    throw 'release metadata mismatch'
}
if ((git ls-remote origin refs/tags/v3.6-kirs.1).Split()[0] -ne $oldTag1) {
    throw 'v3.6-kirs.1 tag changed'
}
if ((git ls-remote origin refs/tags/v3.6-kirs.2).Split()[0] -ne $oldTag2) {
    throw 'v3.6-kirs.2 tag changed'
}
if ((git ls-remote origin refs/tags/v3.6-kirs.3).Split()[0] -ne $oldTag3) {
    throw 'v3.6-kirs.3 tag changed'
}
$oldRelease1After = gh release view v3.6-kirs.1 --repo $repo --json tagName,targetCommitish,url,assets |
  ConvertFrom-Json | ConvertTo-Json -Depth 8 -Compress
$oldRelease2After = gh release view v3.6-kirs.2 --repo $repo --json tagName,targetCommitish,url,assets |
  ConvertFrom-Json | ConvertTo-Json -Depth 8 -Compress
$oldRelease3After = gh release view v3.6-kirs.3 --repo $repo --json tagName,targetCommitish,url,assets |
  ConvertFrom-Json | ConvertTo-Json -Depth 8 -Compress
if ($oldRelease1After -ne $oldRelease1Json) { throw 'v3.6-kirs.1 release changed' }
if ($oldRelease2After -ne $oldRelease2Json) { throw 'v3.6-kirs.2 release changed' }
if ($oldRelease3After -ne $oldRelease3Json) { throw 'v3.6-kirs.3 release changed' }
```

- [ ] **Step 9: Review gate**

Confirm FileVersion 3.6 / ProductVersion 24 / edition Kirs.4 / tag `v3.6-kirs.4` only; prior three releases immutable; backup exists; INI and Contextmenu hashes unchanged. `Critical=0`, `Important=0`.

---

## Execution Notes

- **Recommended execution:** `superpowers:subagent-driven-development` with a **fresh implementation agent per task**, then **separate spec-compliance and code-quality reviews** before the next task starts.
- Alternative: `superpowers:executing-plans` with batch checkpoints — still require RED→GREEN→commit→review per task.
- Do not skip isolation-failure coverage: it is the primary defect this release fixes (failed quarantine leaving `__7z*` promotable via `DirExist`).
- Do not “fix” exit-`1` by trusting a later `7z t` warning alone.
- Do not auto-convert generic `CRC Failed` into `WRONG_PASSWORD`.

### Final suite targets (after Task 9)

| Suite | PassedCount |
|---|---:|
| `tests/SmartZip.Static.Tests.ps1` | 182 |
| `tests/ArchiveDiagnostics.Tests.ps1` | 191 |
| `tests/RunCmdCapture.Tests.ps1` | 15 |
| `tests/PasswordPreflight.Tests.ps1` | 83 |
| `tests/ExtractionLifecycle.Tests.ps1` | 38 |
| `tests/NestingMigration.Tests.ps1` | 30 |
| `tests/DiagnosticUI.Tests.ps1` | 52 |
| `tests/Real7Zip.Integration.Tests.ps1` | 36 |

## Self-Review (plan author)

### Spec coverage

| Design requirement | Task |
|---|---|
| `ArchiveResult` fields `outputState`, `passwordRetryEligible`, `encryptionEvidence`, `retainedOutputDir` | Task 1 |
| Exit code 1 warning rules + hard-error precedence | Task 1 |
| Same-process warning evidence for extract exit 1 | Task 2 |
| `FinalizeExtraction` sole non-default `outputState` assigner; verified quarantine; quarantine_failed | Task 3 |
| Overridable `IsolatePartialOutput` | Task 3 |
| `zipx` returns every path; outer promotion only `usable` | Task 4 |
| Nested recycle clean OK only; volumes never auto-recycle | Task 4 (preserve) + NestingMigration gate |
| Encrypted CRC eligibility vs generic CRC | Tasks 1, 5, 6 |
| `ResolveArchivePassword` accepts eligible; one-resume budget; no pipeline dup in button | Tasks 4–6 |
| Batch never interactive password | Tasks 5–6 |
| Ambiguous diagnostic copy | Task 6 |
| Eligible encrypted-CRC batch summary says password check or possible damage | Task 6 |
| Settings accuracy without new keys / redesign | Task 7 |
| Integration exposes `outputState`; smoke no-hook | Task 8 |
| Kirs.4 metadata/docs; suite counts | Task 9 |
| Build/smoke/deploy/backup/rollback/publish `v3.6-kirs.4`; never mutate Kirs.1–3 | Task 10 |
| No size/ratio success heuristic | Global + Tasks 1–3 |
| Production no IntegrationTestHook | Global + Tasks 8–10 |
| Engine `C:\Tool\7-Zip-Zstandard\7z.exe` | Global + Tasks 8–10 |

### Placeholder scan

- Placeholder scan found no deferred implementation markers.
- Suite counts are concrete integers derived from the baseline plus the named new cases in this plan.
- Every code-changing task includes concrete code, exact commands, and expected RED/GREEN outcomes.

### Type/signature consistency

- `outputState` values: `none` | `usable` | `quarantined` | `quarantine_failed` (strings).
- `passwordRetryEligible` / `encryptionEvidence`: Booleans on `ArchiveResult`.
- `retainedOutputDir` / `partialOutputDir`: path strings.
- `IsolatePartialOutput(tempDir, partialPath) => String` (verified isolated path or empty string).
- `TempDirHasPromotableOutput(tempDir) => Boolean`.
- `FinalizeExtraction(path, result, tempDir, targetDir, mayDeleteSource) => ArchiveResult` remains the only post-extract state assigner.
- `zipx` returns `ArchiveResult`; outer gate compares `outputState` to `"usable"`.
- `ShowDiagnostic(result, isBatch := false, allowPasswordRetry := true) => ArchiveResult` (Kirs.3) remains unchanged in signature.
- `ResolveArchivePassword(path, probeResult) => ArchiveResult` entry widened for eligibility + batch.
- Identity: FileVersion `3.6`, ProductVersion/`buildVersion` `24`, edition `Kirs.4`, tag `v3.6-kirs.4`.
