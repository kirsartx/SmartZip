# Active Task

## Purpose

Maintain a portable handoff state so Codex and EchoBird can continue SmartZip work in separate new conversations.

## Current Git State

- Branch: main
- Latest committed handoff protocol: 0d314a8 docs: add cross-model handoff protocol
- Existing user worktree change: tests/RunCmdCapture.Fragment.ahk
- Change classification: CRLF-to-LF conversion only; no functional code difference from HEAD has been observed.

## Completed

- Inspected the current SmartZip worktree and its test documentation.
- Recorded the cross-model handoff design in docs/superpowers/specs/2026-07-27-model-handoff-design.md.
- Created the project-level handoff files: AGENTS.md, docs/continuity/ACTIVE_TASK.md,
  docs/continuity/DECISIONS.md, and docs/continuity/RESUME_PROMPT.md.
- Confirmed that the pending fragment change is formatting-only.
- After the documentation handoff implementation, ran the full Pester gate. The first six suites passed 559 assertions total: SmartZip.Static (184), ArchiveDiagnostics (193), RunCmdCapture (15), PasswordPreflight (98), ExtractionLifecycle (39), and NestingMigration (30).

## Remaining

- Decide whether the pending LF-only test-fragment change should be reverted or committed as an intentional formatting change. Do not make that decision without user direction.
- Investigate and fix the DiagnosticUI test-double/product-contract mismatch before claiming a full green baseline. `DiagnosticUI.Tests.ps1` reproducibly fails with 51 passed / 1 failed in `reason_NOT_ARCHIVE` at `tests\DiagnosticUI.Tests.ps1:819`: expected `文件不是可识别的压缩包。`, but received an empty reason. The final Real7Zip suite was not reached because the gate stops at this failure. Evidence indicates that `SmartZip.ahk`'s `DiagnosticReason` and `DiagnosticRecommendation` call `this.IsArchive(...)` for NOT_ARCHIVE, while the `DiagnosticUIHost` test double in `tests\DiagnosticUI.Tests.ps1` has no `IsArchive` method and uses a `.7z` fixture path, so its harness returns no reason. Do not change production code or tests until that mismatch is investigated and a contract decision is made.
- Manual external acceptance is still pending: in a brand-new logged-in EchoBird conversation, paste `docs/continuity/RESUME_PROMPT.md` and verify its first response identifies the formatting-only test fragment and proposes `git status --short` plus `git diff --check` before editing. This has not yet run and requires user/account interaction.

## Changed Files

- `docs/superpowers/specs/2026-07-27-model-handoff-design.md`
- `docs/superpowers/plans/2026-07-27-model-handoff.md`
- `AGENTS.md`
- `docs/continuity/ACTIVE_TASK.md`
- `docs/continuity/DECISIONS.md`
- `docs/continuity/RESUME_PROMPT.md`

## Commands Run

- `git status --short`: `M tests/RunCmdCapture.Fragment.ahk`
- `git diff --check`: exit 0; no errors.
- Full Pester gate: SmartZip.Static, ArchiveDiagnostics, RunCmdCapture, PasswordPreflight, ExtractionLifecycle, and NestingMigration passed (559 assertions total). `DiagnosticUI.Tests.ps1` then failed reproducibly (51 passed / 1 failed) in `reason_NOT_ARCHIVE`; Real7Zip was not reached.

## Next Verification Command

~~~powershell
git status --short
git diff --check
~~~
