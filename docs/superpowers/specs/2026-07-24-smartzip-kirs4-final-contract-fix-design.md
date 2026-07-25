# SmartZip Kirs.4 Final Contract Fix Design

## Goal

Close two final-review gaps without changing the Kirs.4 extraction architecture:

1. exit code `1` plus `Warnings: 0` must remain a failure;
2. a password-recovery session with existing encryption evidence must preserve that evidence on every `DATA_CORRUPT` result it produces, including the result returned after batch exhaustion or an interactive cancel.

No build, deployment, release, or network work is in scope.

## Verified Defects

At base `4ab6872`, an executable AutoHotkey probe classifies:

```text
exit=1, output="Everything is Ok\nWarnings: 0\n"
=> OK_WITH_WARNING
```

`InStr("Warnings: 0", "WARNINGS:")` returns `1` because AutoHotkey's default comparison is case-insensitive, while the same call with `CaseSense := true` returns `0`. This bypasses the existing nonzero-counter regular expression.

The exported product password-recovery methods also reproduce:

```text
batch: NEED_PASSWORD + encryptionEvidence -> DATA_CORRUPT
=> DATA_CORRUPT, encryptionEvidence=false, passwordRetryEligible=false, dialogCalls=0

interactive cancel: NEED_PASSWORD + encryptionEvidence -> DATA_CORRUPT -> cancel
=> CANCELLED
```

`ResolveArchivePassword` currently replaces the initial result with raw `TestArchive` results. Those results do not know the earlier probe evidence. Batch returns the raw `last` result, while cancel checks only the initial `passwordRetryEligible` flag; an initial `NEED_PASSWORD` may carry encryption evidence while its retry-eligibility default remains false.

## Considered Approaches

### Selected: local token fix plus recovery-session evidence propagation

- Make only the `WARNINGS:` heading detector case-sensitive.
- Record whether the recovery session began with encryption evidence or retry eligibility.
- Whenever empty, saved-candidate, or typed-password testing returns `DATA_CORRUPT`, attach that session evidence and eligibility to the result.
- Retain the last such ambiguous corrupt result so batch exhaustion and cancel can return it.

This is the smallest change that fixes the evidence boundary at its source and preserves the existing return types and UI flow.

### Rejected: remove the `WARNINGS:` detector

This would fix `Warnings: 0` but break real uppercase heading output already covered by the harness.

### Rejected: infer ambiguity only at batch/cancel return sites

This would leave intermediate `DATA_CORRUPT` results internally inconsistent and would miss typed-password and future return paths. The invariant belongs where each recovery result enters the session.

## Behavioral Contract

### Warning classification

- `Warnings: 0` is not warning evidence.
- `Warnings: N`, where `N` begins with `1` through `9`, remains warning evidence.
- The exact uppercase heading token `WARNINGS:` remains warning evidence.
- Existing warning text `There are data after the end of archive` remains warning evidence.
- Exit code `1` still requires warning evidence and no hard-error evidence before it can become `OK_WITH_WARNING`.

### Password-recovery ambiguity

- Recovery-session encryption evidence is true when the initial result has `encryptionEvidence = true` or `passwordRetryEligible = true`.
- Every `DATA_CORRUPT` result produced by the session's empty-password, saved-candidate, or typed-password tests inherits `encryptionEvidence = true` and `passwordRetryEligible = true`.
- The session retains the most recent inherited `DATA_CORRUPT` result.
- Batch mode never opens a dialog. When candidates are exhausted after an inherited corrupt result, it returns that eligible `DATA_CORRUPT`.
- If the interactive user cancels after an inherited corrupt result, the resolver returns that result instead of synthesizing `CANCELLED`.
- An ordinary `DATA_CORRUPT` result without prior encryption evidence still bypasses password recovery.
- An ordinary password prompt followed by cancel still returns `CANCELLED`.
- Existing command logging continues through `RedactDiagnostic`; tests must prove candidate password material is absent.

## Test Strategy

Use executable AutoHotkey harnesses, not static source assertions:

- Add `ArchiveDiagnostics.Harness.ahk` assertions for exit `1` plus `Warnings: 0` and for an embedded uppercase token that is not a standalone heading. Existing assertions remain the protection for `Warnings: 1` and standalone uppercase `WARNINGS:`.
- Add password-harness assertions for batch exhaustion, interactive cancel, inherited flags, dialog count, ordinary CRC, ordinary cancel, and redacted candidate logging.
- Record each focused suite's failing count before implementation and passing count after implementation.
- Finish with the focused suites requested by review: ArchiveDiagnostics, PasswordPreflight, DiagnosticUI, SmartZip.Static, ExtractionLifecycle, and NestingMigration.
- Update `tests/README.md` from the actual resulting Pester counts.

## Scope and Safety

Only `lib/ArchiveDiagnostics.ahk`, `SmartZip.ahk`, the directly related harness/wrapper files, test-count documentation, this design/plan, and the requested ignored review report may change. Generated `PasswordPreflight.Fragment.ahk` must be removed before commit. No production hook, password value, build artifact, release mutation, push, or deployment is permitted.
