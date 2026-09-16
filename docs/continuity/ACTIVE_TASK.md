# Active Task

## Current Handoff — 2026-09-17

- Goal: continue extraction-speed work without changing existing outcomes, and
  support HaoZip-style SFXV sets consisting of one `.exe` plus numbered
  `.NNN.sfxv` pieces.
- Completed: SFXV members are recognized from any selected piece; the first
  executable and every numbered piece are checked in order; missing pieces
  return `MISSING_VOLUME`. When complete, the executable's embedded 7z
  signature is located, the self-extractor stub is skipped, and the remaining
  bytes are merged into a temporary regular `.7z` file for 7-Zip. Original
  pieces are never modified or deleted, temporary files are cleaned
  idempotently, and result identity remains the original first `.exe` path.
  The earlier stdin feeder experiment was removed after the tested 7-Zip
  engine reported 7z stdin input as unsupported.
- Instrumentation: opt-in `timingLog=0` records only `probe`, `test`, and
  `extract` durations; it is disabled by default.
- Changed files: `SmartZip.ahk`, `lib/ArchiveDiagnostics.ahk`, `README.md`, `ini.md`,
  `tests/Sfxv.Tests.ps1`, `tests/Sfxv.Integration.Tests.ps1`, `tests/README.md`,
  this file, and `docs/continuity/DECISIONS.md`. Existing directory-scan
  changes remain in the same working tree.
- Verification: full documented gate plus directory-scan and SFXV suites
  passed `686/686`, 0 failed. This includes the original `648/648`, directory
  scan `1/1`, SFXV recognition `1/1`, and SFXV real 7-Zip integration `36/36`.
  `git diff --check` exited 0. The SFXV integration uses data-only fixtures
  and never executes an archive EXE.
+- Deployment: final source compiled successfully with the staged AutoHotkey
+  toolchain and installed as `C:\Tool\SmartZip\SmartZip.exe`. The deployed SHA-256 is
  `C9EF0553D7FB4013B6233C60C6E0C6D20D0C2F139326573112061B43273FBEA3`; it
  matches the final temporary build. Existing executables were backed up as
  `C:\Tool\SmartZip\SmartZip.exe.bak-codex-20260917-033601` and
  `C:\Tool\SmartZip\SmartZip.exe.bak-codex-pre-final-20260917-033629`.
- Remaining: no implementation work is pending for this SFXV adaptation.
- Next verification: rerun the exact gate in `tests/README.md` if source
  changes continue; otherwise inspect `git diff --stat` and the final status.

## Current Handoff — 2026-09-16

- Goal: preserve extraction behavior while reducing directory scan overhead.
- Completed: AfterUnzip stops its non-empty scan at the first child; a shared
  conservative filename gate avoids sibling enumeration and volume-index building
  for impossible volume names. Custom nested extension rules remain first.
- Baseline HEAD: de80a38. Changes are in the working tree for review.
- Changed files: SmartZip.ahk, lib/ArchiveDiagnostics.ahk,
  tests/DirectoryScanOptimization.Tests.ps1, tests/README.md, this file,
  docs/continuity/DECISIONS.md, and
  docs/superpowers/specs/2026-09-16-directory-scan-design.md.
- Verification: Invoke-Pester -Script './tests/DirectoryScanOptimization.Tests.ps1'
  -PassThru passed 1/1, executing 120 comparisons against de80a38.
- The existing gate's first seven suites passed 184, 193, 15, 98, 39, 30, 53
  respectively (612/612). Integration initially blocked at Ahk2Exe: its /base
  argument contained an unquoted Program Files path. Stopped only the owned test
  runner/compiler and staged the installed toolchain in the supported TEMP
  ahk_tools directories. No repository toolchain configuration changed.
- Invoke-Pester -Script './tests/Real7Zip.Integration.Tests.ps1' -PassThru then
  passed 36/36 in 93.8 seconds, exit 0. Total verified: 649/649 including the new
  regression. These are test durations, not measured extraction speed gains.
- git diff --check: exit 0. Generated RunCmdCapture fragment formatting was
  restored and the generated PasswordPreflight fragment removed.
- Remaining: no implementation work; optional matched performance benchmark.
- Next verification: the eight-suite command below, followed by the additional
  DirectoryScanOptimization test documented in tests/README.md.

## Previous Optimization Handoff (Historical)

## Purpose

Maintain a portable handoff state so Codex and EchoBird can continue SmartZip work in separate new conversations.

## Current Task

Optimize extraction speed without behavior changes by reusing already-successful archive validation results only inside the synchronous extraction pipeline that produced them.

## Current Git State

- Branch: `agent/diagnostic-ui-contract-repair`.
- Final optimization verification HEAD: `a11fbe5` (`test: harden extraction handoff fallbacks`).
- Final optimization-gate `git status --short`: exit 0 with empty output (clean).

## Completed

- `6cd7eca` (`perf: reuse validated password test results`) marks successful `TestArchive` results and reuses them in the same synchronous extraction pipeline only when the non-empty result `archivePath` matches the current normalized path case-insensitively; otherwise the original test path runs.
- `901ceca` (`perf: reuse nested archive probe results`) passes the probe computed by `UnZipNesting` only into the immediately following `Unzip` call and reuses it after volume normalization only for the same non-empty archive path; otherwise the original probe path runs.
- `38ed0c1` (`test: align static matchers with extraction handoffs`) updates only the stale static-test matchers for the new `zipx` signature and call shape. This corrected the initial static result of 182 passed / 2 failed to 184/184 without changing production behavior.
- `a11fbe5` (`test: harden extraction handoff fallbacks`) requires a valid probe-shaped object before nested probe reuse, adds executable same-path/mismatch/invalid fallback call-count coverage for both handoffs, and records all affected test/harness files.
- The approved optimization is complete. It preserves the final post-extract `7z t` and all existing password, volume, isolation, source-recycle, nesting, status, error, and result behavior.

## Remaining

- None for this approved extraction-speed optimization.

## Changed Files

- `SmartZip.ahk`
- `tests/SmartZip.Static.Tests.ps1`
- `tests/PasswordPreflight.Tests.ps1`
- `tests/PasswordPreflight.Harness.ahk`
- `tests/NestingMigration.Tests.ps1`
- `docs/continuity/ACTIVE_TASK.md`
- `docs/continuity/DECISIONS.md`

## Final Verification Results

- Full eight-suite contract gate: 648/648, with 0 failures: SmartZip.Static 184/184, ArchiveDiagnostics 193/193, RunCmdCapture 15/15, PasswordPreflight 98/98, ExtractionLifecycle 39/39, NestingMigration 30/30, DiagnosticUI 53/53, and Real7Zip.Integration 36/36.
- Two measured Real7Zip integration runs: 36/36 at 101305 ms and 36/36 at 99524 ms.
- `git diff --check`: exit 0.
- 7-Zip probe: `7-Zip 26.02 ZS v1.5.7 R1 (x64)`.
- Final optimization verification HEAD: `a11fbe5`.
- Final optimization-gate `git status --short`: exit 0 with empty output (clean).
- Fresh final full gate after `a11fbe5`: Real7Zip.Integration 36/36 in 96.31 seconds; all eight suites passed 648/648.
- Tests not run: none; all eight suites in the documented full contract gate ran.
- No secrets, passwords, session IDs, or raw logs are recorded in this handoff.

## Next Verification Command (Exact Full Gate Family Used)

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=184
  'ArchiveDiagnostics.Tests.ps1'=193
  'RunCmdCapture.Tests.ps1'=15
  'PasswordPreflight.Tests.ps1'=98
  'ExtractionLifecycle.Tests.ps1'=39
  'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=53
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

## Historical Prior Handoff (Superseded as the Active Task)

### Prior Git State

- Branch: main
- Latest committed handoff protocol: 0d314a8 docs: add cross-model handoff protocol
- The previously pending `tests/RunCmdCapture.Fragment.ahk` CRLF-to-LF-only change was discarded after review; no functional code difference existed.

### Prior Completed Work

- Inspected the current SmartZip worktree and its test documentation.
- Recorded the cross-model handoff design in docs/superpowers/specs/2026-07-27-model-handoff-design.md.
- Created the project-level handoff files: AGENTS.md, docs/continuity/ACTIVE_TASK.md,
  docs/continuity/DECISIONS.md, and docs/continuity/RESUME_PROMPT.md.
- Confirmed that the pending fragment change is formatting-only.
- After the documentation handoff implementation, ran the full Pester gate. The first six suites passed 559 assertions total: SmartZip.Static (184), ArchiveDiagnostics (193), RunCmdCapture (15), PasswordPreflight (98), ExtractionLifecycle (39), and NestingMigration (30).
- Added a contract-faithful `DiagnosticUIHost.IsArchive` seam and optional reason `archivePath` input; production `SmartZip.ahk` remains unchanged.
- Added a known-extension `NOT_ARCHIVE` regression case. The focused DiagnosticUI suite now passes 53/53.
- Completed the full eight-suite contract gate: 184/184, 193/193, 15/15, 98/98, 39/39, 30/30, 53/53, and 36/36; `git diff --check` passed and the 7-Zip probe reported 7-Zip 26.02 ZS.

### Prior Remaining Work

- Manual external acceptance is still pending: in a brand-new logged-in EchoBird conversation, paste `docs/continuity/RESUME_PROMPT.md` and verify its first response identifies the formatting-only test fragment and proposes `git status --short` plus `git diff --check` before editing. This has not yet run and requires user/account interaction.

### Prior Changed Files

- `docs/superpowers/specs/2026-07-27-model-handoff-design.md`
- `docs/superpowers/plans/2026-07-27-model-handoff.md`
- `AGENTS.md`
- `docs/continuity/ACTIVE_TASK.md`
- `docs/continuity/DECISIONS.md`
- `docs/continuity/RESUME_PROMPT.md`
- `tests/DiagnosticUI.Tests.ps1`
- `tests/README.md`

### Prior Commands Run

- `git status --short`: clean after discarding the LF-only fragment change.
- `git diff --check`: exit 0; no errors.
- Full Pester gate: SmartZip.Static, ArchiveDiagnostics, RunCmdCapture, PasswordPreflight, ExtractionLifecycle, and NestingMigration passed (559 assertions total). `DiagnosticUI.Tests.ps1` then failed reproducibly (51 passed / 1 failed) in `reason_NOT_ARCHIVE`; Real7Zip was not reached.
- RED focused run after adding the regression case: 51 passed / 2 failed, both `NOT_ARCHIVE` reason assertions, confirming the missing test-host seam.
- GREEN focused run after the test-host fix: 53 passed / 0 failed in 10.25 seconds.
- Full contract gate: SmartZip.Static 184/184, ArchiveDiagnostics 193/193, RunCmdCapture 15/15, PasswordPreflight 98/98, ExtractionLifecycle 39/39, NestingMigration 30/30, DiagnosticUI 53/53, and Real7Zip.Integration 36/36; all failures 0.
- 7-Zip probe: `7-Zip 26.02 ZS v1.5.7 R1 (x64)`.

### Prior Next Verification Command

~~~powershell
git status --short
git diff --check
~~~
