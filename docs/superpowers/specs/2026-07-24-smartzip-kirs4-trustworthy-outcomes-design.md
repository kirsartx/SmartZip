# SmartZip 3.6 Kirs.4 Trustworthy Outcomes Design

## Status

Approved under the standing instruction to choose the recommended option. This specification records the balanced Kirs.4 design selected after a Grok multi-agent audit of output promotion, 7-Zip result classification, encrypted-archive recovery, and settings accuracy.

## Goal

Make SmartZip's final state match the real extraction outcome. Failed or uncertain output must never appear as a normal successful extraction, 7-Zip warning exit code `1` must be handled accurately, encrypted CRC failures may offer a safe password retry without mislabeling ordinary corruption, and settings text must describe the behavior that is actually implemented.

## Release Boundary

- Create a new `v3.6-kirs.4` release; do not mutate Kirs.1 through Kirs.3 tags, releases, or artifacts.
- Keep `FileVersion` at `3.6`.
- Set `ProductVersion` and `buildVersion` to `24`.
- Set `edition` to `Kirs.4`.
- Preserve all existing volume, source-recycle, password-redaction, full-test, and batch-suppression invariants.
- Continue to use the locally installed `C:\Tool\7-Zip-Zstandard\7z.exe` for integration verification.

## Selected Approach

Use an explicit extraction-outcome contract rather than a minimal directory-existence patch or a full 7-Zip execution-layer rewrite.

- A minimal patch would be smaller but would retain hidden coupling between temporary-directory existence and success.
- Replacing the GUI extraction runner with a fully captured console pipeline would provide more output detail but has a substantially larger behavior and UI regression surface.
- The selected approach makes outcome state explicit while retaining the existing extraction and diagnostic architecture.

## Outcome Contract and Data Flow

`ArchiveResult` gains these fields with construction defaults:

- `outputState := "none"`
- `passwordRetryEligible := false`
- `encryptionEvidence := false`
- `retainedOutputDir := ""`

`zipx` must return an `ArchiveResult` for every attempted archive, including volume de-duplication skips, early failure, cancellation, missing-volume, and password-recovery paths. The outer `Unzip` loop, including nested `Unzip(loopPath)`, must capture that return value. The result carries an explicit `outputState`:

- `usable`: extraction output may be promoted to the normal destination.
- `quarantined`: failed or incomplete output was successfully moved to the incomplete-output directory.
- `none`: no output exists to preserve or publish.
- `quarantine_failed`: incomplete output could not be isolated and remains at a reported temporary location.

Paths that never start extraction retain the construction default `none`. `FinalizeExtraction` is the only component that may assign a non-default state after an extraction attempt. The outer `Unzip` loop must use `outputState`, not `DirExist(tmpDir)`, as its sole promotion authority:

- Only `usable` output enters the existing destination naming, overwrite, and move pipeline.
- `quarantined`, `none`, and `quarantine_failed` output never enters a normal destination.
- `usable` means clean or warning output remains in `tempDir` for the outer move pipeline; it does not mean the output has already been published.
- Quarantine succeeds only when the intended incomplete-output directory exists and `tempDir` no longer contains promotable output. Only then set `outputState := "quarantined"` and `partialOutputDir` to the verified path.
- If isolation cannot be verified after both move attempts, set `outputState := "quarantine_failed"`, leave `partialOutputDir` empty unless a real partial directory exists, set `retainedOutputDir` to the actual retained location, and report that location. No subsequent destination naming, overwrite, move, source operation, or nested recycle may occur.
- Partial isolation must go through an overridable `IsolatePartialOutput`-style method so the product lifecycle harness can deterministically force and verify a move failure.
- Nested extraction uses the same contract. Nested archives may be recycled only after a clean `OK` result and never because output merely exists.

Clean `OK` and `OK_WITH_WARNING` results may produce `usable` output. Only clean `OK` (`status = OK`, extraction exit code `0`, and all required stages successful) may authorize configured source handling; warnings always preserve the source. `outputState` controls promotion and isolation, while `isCleanSuccess` independently controls source and nested-archive recycling; the two signals are not interchangeable.

## 7-Zip Result Classification

The result classifier must treat process exit codes and diagnostic evidence from the same operation together. Recognized warning evidence is limited to the existing detectors: a nonzero `Warnings:` count, `WARNINGS:`, or `There are data after the end of archive`.

Exit code `1` may become `OK_WITH_WARNING` only when:

- recognized warning evidence is present; and
- no password, missing-volume, unsupported-method, truncation, header, data, not-archive, disk, permission, cancellation, I/O, non-warning `errorLines`, or other hard-error evidence is present.

Exit code `0` with recognized warning evidence remains `OK_WITH_WARNING`. Exit code `1` without sufficient warning evidence, or with any hard-error evidence, remains a failure. Existing diagnostic priority for cancellation and specific actionable failures is preserved.

All hard-error and I/O evidence must be evaluated before an exit-code-`1` warning-success branch. Exit code `1` never becomes clean `OK` and never authorizes source handling.

`ExtractArchiveToTemp` currently combines the GUI extraction exit code with output from a later `7z t` operation. Those are different operations, so a GUI extraction exit code `1` must not become `OK_WITH_WARNING` solely because the later source test contains warning text. Without direct extraction diagnostics, that extraction result remains a failure and its output is isolated. Exit-code-`1` warning success is permitted only when the warning evidence belongs to the process whose exit code is being classified.

This change must not use file size, `successPercent`, or extracted-size ratios as evidence of success.

## Encrypted CRC and Password Recovery

Generic `CRC Failed` or `Data Error` remains `DATA_CORRUPT` and must not automatically be called a wrong password or offer a password retry.

Encryption evidence is limited to a case-insensitive `in encrypted file` diagnostic phrase or an earlier successful probe/list observation of `Encrypted = +` for the same archive. Existing explicit wrong-password phrases keep their current higher-priority `WRONG_PASSWORD` classification.

When status is `DATA_CORRUPT` and encryption evidence exists, set `passwordRetryEligible := true` without changing the status. Recovery behavior is separated from the final status:

- A single-archive diagnostic may offer “重新输入密码” when password retry is otherwise allowed.
- `ResolveArchivePassword`, or an equivalent shared helper, must accept `passwordRetryEligible` results and actually test candidate or entered passwords rather than short-circuiting on `DATA_CORRUPT`.
- A successful retry returning `OK` or `OK_WITH_WARNING` resumes the one existing test, extract, finalize, and source-handling pipeline under the existing one-resume budget. It must not duplicate or bypass the forced full-test gate.
- If retry is cancelled or still fails, the result remains `DATA_CORRUPT` and explains that the password may be wrong or the encrypted data may be damaged. The source is preserved and partial output follows the normal isolation contract.
- Batch extraction never opens preflight `ShowPasswordDialog`, diagnostic password-retry UI, or encrypted-CRC retry UI. Noninteractive stored-password candidates may still be tried; unresolved items are recorded and summarized as requiring a password check or possibly being damaged.

This avoids both false certainty and pointless password prompts for ordinary CRC corruption.

## User Experience and Settings Accuracy

Update settings wording without introducing new persistent keys or redesigning the settings page:

- Replace the generic “启用测试中的功能” copy with wording that describes the actual full archive-test behavior.
- Replace the ineffective `partSkip` checkbox with a noninteractive explanation that members of the same volume group are always processed once. Preserve the existing INI key for backward compatibility, but do not present it as an effective runtime switch.
- Change source “删除” wording to “移入回收站”.
- Explain that source recycling occurs only after a completely clean result and never for volume members.
- Keep nested-archive recycling described separately from top-level source recycling.

## Error Handling

- Clean success: publish usable output and apply existing source-recycle policy.
- Success with warning: publish usable output, show a warning summary, and preserve the source.
- Wrong password: allow the existing single-archive synchronous retry flow.
- Encrypted CRC/data failure: offer password retry; if unresolved, preserve the source and incomplete output with an ambiguity-aware diagnostic.
- Ordinary CRC/data failure: treat as corruption without password retry.
- Disk-full, access-denied, destination-busy, and other I/O failures: do not publish normally; quarantine incomplete output where possible.
- Quarantine failure: preserve the temporary location, report it explicitly, and block all promotion and source handling.
- User cancellation with partial output: quarantine it under the same verified isolation contract. If the temporary directory is empty, remove only that empty state. Always preserve the source archive.

Batch mode must not open password dialogs.

## Safety Invariants

- Source archives may be recycled only after clean `OK` completion of every required stage.
- `OK_WITH_WARNING`, corrupt, missing-volume, password failure, cancellation, and every other failure preserve the source.
- Volume members are never automatically recycled.
- With normal testing disabled, source handling and nested recycling still require the forced full test.
- Password values never appear in commands copied to diagnostics, logs, diagnostic files, or batch summaries.
- Partial output is either isolated and discoverable or left in a clearly reported temporary location; it is never silently promoted.
- Production source and executable contain no integration test hook.
- Batch and multi-select flows contain no interactive password prompt.

## Tests and Verification

Write failing regression tests before implementation for:

- a failed quarantine move never publishing temporary content to a normal destination;
- each `outputState` and the outer promotion gate;
- exit code `1` with pure warning evidence versus exit code `1` with hard-error evidence;
- GUI extraction exit code `1` not borrowing warning evidence from a separate follow-up test;
- generic CRC/data corruption versus encrypted evidence that permits a password retry;
- unresolved encrypted retry retaining an honest ambiguous diagnostic;
- encrypted retry button, resolver entry, one-budget resume, and batch noninteraction;
- warning, failure, cancellation, and volume results preserving source archives;
- settings labels matching runtime behavior and the ineffective volume toggle being removed;
- Kirs.4 metadata and documentation.

Use the existing harness boundaries: diagnostics tests own classifier and encryption-evidence cases; extraction lifecycle tests own `outputState`, promotion, and forced isolation failure; diagnostic UI tests own buttons, ambiguity copy, and batch behavior; static tests own the outer gate, settings, and metadata; integration results expose `outputState`.

Run all existing unit, static, headless GUI, product, and real-7-Zip integration suites and update the documented suite counts. Add or strengthen a no-test-hook production smoke test. Exercise normal, wrong-password, damaged, volume, and nested fixtures with `C:\Tool\7-Zip-Zstandard\7z.exe`.

Build the production executable from a clean staging tree, verify the production smoke test, back up the current `C:\Tool\SmartZip\SmartZip.exe`, deploy the candidate locally, and verify metadata and SHA-256. After local verification, commit, push, merge through the existing repository workflow, and publish `v3.6-kirs.4`.

## Non-Goals

- No file-size or extracted-ratio success heuristic.
- No permanent deletion or expansion of automatic source handling.
- No settings redesign or INI key rename.
- No batch wizard or list-view UI.
- No online archive repair.
- No compression or `CreateZip` behavior changes.
- No context-menu redesign.
- No mutation of earlier releases or tags.
