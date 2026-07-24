# SmartZip Kirs.4 Final Contract Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Kirs.4 warning classification and encrypted password-recovery outcomes preserve their exact evidence contracts.

**Architecture:** Keep the existing classifier and resolver boundaries. Tighten only the uppercase warning-heading match, then propagate already-proven encryption evidence through each `DATA_CORRUPT` result created inside one password-recovery session and return the last ambiguous result at batch/cancel boundaries.

**Tech Stack:** AutoHotkey v2.0.26, PowerShell 5.1, Pester 3.4.

## Global Constraints

- Base is `4ab6872`.
- Do not build, deploy, publish, push, or retry the known Grok `402`.
- Implement one review item at a time with a recorded RED before production changes.
- Preserve uppercase `WARNINGS:`, nonzero `Warnings:`, ordinary CRC, ordinary cancel, batch noninteraction, and password redaction.
- Remove generated fragments before commit.

---

### Task 1: Reject a zero warning counter

**Files:**
- Modify: `tests/ArchiveDiagnostics.Harness.ahk`
- Modify: `tests/ArchiveDiagnostics.Tests.ps1`
- Modify: `lib/ArchiveDiagnostics.ahk`

**Interfaces:**
- Consumes: `Classify7zResult(stage, exitCode, output, archivePath := "")`
- Produces: unchanged `ArchiveResult`; only warning evidence recognition changes.

- [ ] **Step 1: Add the executable regression**

After the existing exit-code-1 warning cases, add:

```ahk
r := Classify7zResult("test", 1, "Everything is Ok`nWarnings: 0`n")
AssertTrue(r.status != ArchiveStatus.OK && r.status != ArchiveStatus.OK_WITH_WARNING,
    "exit1_zero_warning_counter_not_success")
```

Add `exit1_zero_warning_counter_not_success` to the Pester wrapper's canonical harness-case list.

- [ ] **Step 2: Run RED**

Run:

```powershell
Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
```

Expected: exactly the new case fails because it receives `OK_WITH_WARNING`; record the actual Pester failed count.

- [ ] **Step 3: Make the heading check exact**

Change only the heading branch in `Classify7zResult`:

```ahk
if (trimmed ~= "i)^Warnings?:\s*[1-9]"
    || InStr(trimmed, "There are data after the end of archive")
    || InStr(trimmed, "WARNINGS:", true)) {
```

- [ ] **Step 4: Run GREEN**

Run the ArchiveDiagnostics suite again. Expected: all cases pass, including the existing `Warnings: 1` and uppercase `WARNINGS:` cases.

- [ ] **Step 5: Commit Task 1**

Stage the classifier, its tests, and the design/plan documents. Commit as:

```text
fix: reject zero 7-Zip warning counters
```

### Task 2: Preserve encrypted corruption across password recovery

**Files:**
- Modify: `tests/PasswordPreflight.Harness.ahk`
- Modify: `tests/PasswordPreflight.Tests.ps1`
- Modify: `SmartZip.ahk`

**Interfaces:**
- Consumes: `ResolveArchivePassword(path, probeResult) => ArchiveResult`
- Produces: the same signature; `DATA_CORRUPT` results may inherit session evidence and remain the terminal ambiguous result.

- [ ] **Step 1: Add executable recovery regressions**

Add real product-method harness scenarios with these assertions:

```text
resolve_batch_corrupt_keeps_status
resolve_batch_corrupt_keeps_encryption_evidence
resolve_batch_corrupt_keeps_retry_eligibility
resolve_batch_corrupt_never_opens_dialog
resolve_cancel_after_corrupt_keeps_status
resolve_cancel_after_corrupt_keeps_encryption_evidence
resolve_cancel_after_corrupt_keeps_retry_eligibility
resolve_cancel_after_corrupt_opens_dialog_once
resolve_typed_corrupt_keeps_status
resolve_typed_corrupt_keeps_encryption_evidence
resolve_typed_corrupt_keeps_retry_eligibility
resolve_plain_corrupt_never_opens_dialog
resolve_plain_cancel_stays_cancelled
resolve_ambiguous_log_hides_candidate
resolve_ambiguous_log_uses_redacted_placeholder
```

The batch scenario begins with `NEED_PASSWORD` plus `encryptionEvidence`, scripts both empty and candidate tests as generic `DATA_CORRUPT`, and includes a secret-valued candidate. The cancel scenario begins with the same evidence, scripts empty testing as `DATA_CORRUPT`, has no candidate, and cancels the dialog. The control scenarios use plain corrupt and plain password-cancel inputs.

- [ ] **Step 2: Run RED**

Run:

```powershell
Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
```

Expected: the new evidence/eligibility/terminal-status assertions fail while dialog-suppression and redaction controls may already pass. Record the exact failing count.

- [ ] **Step 3: Add the minimum session state**

At resolver entry, derive:

```ahk
recoveryEncryptionEvidence := (probeResult.HasOwnProp("encryptionEvidence")
        && probeResult.encryptionEvidence)
    || (probeResult.HasOwnProp("passwordRetryEligible")
        && probeResult.passwordRetryEligible)
lastEligibleCorrupt := ""
```

After each empty, candidate, and typed-password test, when its status is `DATA_CORRUPT` and `recoveryEncryptionEvidence` is true, set:

```ahk
result.encryptionEvidence := true
result.passwordRetryEligible := true
lastEligibleCorrupt := result
```

Before batch returns `last`, return `lastEligibleCorrupt` when it is an object. Before a cancel synthesizes `CANCELLED`, return `lastEligibleCorrupt` when it is an object; retain the existing initial eligible-corrupt fallback.

- [ ] **Step 4: Run GREEN**

Run PasswordPreflight. Expected: all old and new cases pass and the logged secret candidate is absent.

- [ ] **Step 5: Commit Task 2**

Stage only `SmartZip.ahk` and the password harness/wrapper. Commit as:

```text
fix: retain encrypted corruption during password recovery
```

### Task 3: Counts, focused verification, and final review

**Files:**
- Modify: `tests/README.md`
- Modify if an existing exact release-test count exists: `README.md`
- Create ignored report: `.superpowers/sdd/final-contract-fix-report.md`

**Interfaces:**
- Consumes: Pester `PassedCount`, `FailedCount`, and `TotalCount`.
- Produces: accurate suite-count documentation and a review report against base `4ab6872`.

- [ ] **Step 1: Run all requested focused suites**

Run ArchiveDiagnostics, PasswordPreflight, DiagnosticUI, SmartZip.Static, ExtractionLifecycle, and NestingMigration independently with `-PassThru`. Capture their actual counts; do not infer totals from stale documentation.

- [ ] **Step 2: Update count documentation**

Update the ordered suite map and prose totals in `tests/README.md` to the observed counts. Update `README.md` only if it contains a release-test number that is now stale.

- [ ] **Step 3: Clean and inspect**

Remove generated `tests/PasswordPreflight.Fragment.ahk`, run `git diff --check`, inspect `git status --short`, and review `git diff 4ab6872 --` for scope, secrets, and accidental build/release files.

- [ ] **Step 4: Write the final report**

Document root-cause evidence, RED and GREEN counts, focused suite counts, changed files, redaction checks, generated-file cleanup, commits, and final review findings in `.superpowers/sdd/final-contract-fix-report.md`.

- [ ] **Step 5: Final verification and commit**

Freshly rerun the requested focused suites after the documentation update, then commit the documentation/report state that is tracked. Do not push.

## Self-Review

- Spec coverage maps Task 1 to the warning-token defect, Task 2 to all recovery-session `DATA_CORRUPT` boundaries and control behaviors, and Task 3 to counts/review/cleanup.
- No behavior is inferred from static regex alone; both changes use executable AutoHotkey harnesses.
- No new public method or result type is introduced.
- `ResolveArchivePassword(path, probeResult) => ArchiveResult` and `Classify7zResult(...) => ArchiveResult` remain type-consistent.
