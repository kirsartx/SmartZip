# Active Task

## Purpose

Maintain a portable handoff state so Codex and EchoBird can continue SmartZip work in separate new conversations.

## Current Git State

- Branch: main
- Latest committed handoff protocol: 0d314a8 docs: add cross-model handoff protocol
- The previously pending `tests/RunCmdCapture.Fragment.ahk` CRLF-to-LF-only change was discarded after review; no functional code difference existed.

## Completed

- Inspected the current SmartZip worktree and its test documentation.
- Recorded the cross-model handoff design in docs/superpowers/specs/2026-07-27-model-handoff-design.md.
- Created the project-level handoff files: AGENTS.md, docs/continuity/ACTIVE_TASK.md,
  docs/continuity/DECISIONS.md, and docs/continuity/RESUME_PROMPT.md.
- Confirmed that the pending fragment change is formatting-only.
- After the documentation handoff implementation, ran the full Pester gate. The first six suites passed 559 assertions total: SmartZip.Static (184), ArchiveDiagnostics (193), RunCmdCapture (15), PasswordPreflight (98), ExtractionLifecycle (39), and NestingMigration (30).
- Added a contract-faithful `DiagnosticUIHost.IsArchive` seam and optional reason `archivePath` input; production `SmartZip.ahk` remains unchanged.
- Added a known-extension `NOT_ARCHIVE` regression case. The focused DiagnosticUI suite now passes 53/53.
- Completed the full eight-suite contract gate: 184/184, 193/193, 15/15, 98/98, 39/39, 30/30, 53/53, and 36/36; `git diff --check` passed and the 7-Zip probe reported 7-Zip 26.02 ZS.

## Remaining

- Manual external acceptance is still pending: in a brand-new logged-in EchoBird conversation, paste `docs/continuity/RESUME_PROMPT.md` and verify its first response identifies the formatting-only test fragment and proposes `git status --short` plus `git diff --check` before editing. This has not yet run and requires user/account interaction.

## Changed Files

- `docs/superpowers/specs/2026-07-27-model-handoff-design.md`
- `docs/superpowers/plans/2026-07-27-model-handoff.md`
- `AGENTS.md`
- `docs/continuity/ACTIVE_TASK.md`
- `docs/continuity/DECISIONS.md`
- `docs/continuity/RESUME_PROMPT.md`
- `tests/DiagnosticUI.Tests.ps1`
- `tests/README.md`

## Commands Run

- `git status --short`: clean after discarding the LF-only fragment change.
- `git diff --check`: exit 0; no errors.
- Full Pester gate: SmartZip.Static, ArchiveDiagnostics, RunCmdCapture, PasswordPreflight, ExtractionLifecycle, and NestingMigration passed (559 assertions total). `DiagnosticUI.Tests.ps1` then failed reproducibly (51 passed / 1 failed) in `reason_NOT_ARCHIVE`; Real7Zip was not reached.
- RED focused run after adding the regression case: 51 passed / 2 failed, both `NOT_ARCHIVE` reason assertions, confirming the missing test-host seam.
- GREEN focused run after the test-host fix: 53 passed / 0 failed in 10.25 seconds.
- Full contract gate: SmartZip.Static 184/184, ArchiveDiagnostics 193/193, RunCmdCapture 15/15, PasswordPreflight 98/98, ExtractionLifecycle 39/39, NestingMigration 30/30, DiagnosticUI 53/53, and Real7Zip.Integration 36/36; all failures 0.
- 7-Zip probe: `7-Zip 26.02 ZS v1.5.7 R1 (x64)`.

## Next Verification Command

~~~powershell
git status --short
git diff --check
~~~
