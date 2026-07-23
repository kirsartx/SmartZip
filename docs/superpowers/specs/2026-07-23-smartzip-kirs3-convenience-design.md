# SmartZip 3.6 Kirs.3 Convenience and Recovery Design

## Status

Approved under the standing instruction to choose the recommended option. This specification describes the balanced Kirs.3 package selected after a parallel Grok audit of recovery UX, volume handling, and maintenance safety.

## Goal

Make everyday extraction more predictable without weakening Kirs.2's safety guarantees: selecting any member of a complete split archive extracts the set once, a password retry from the diagnostic window can actually resume extraction, ordinary numeric filenames are not misreported as damaged volumes, and diagnostics remain useful without exposing passwords.

## Release Boundary

- Create a new `v3.6-kirs.3` release; do not mutate the Kirs.1 or Kirs.2 tags, releases, or artifacts.
- Keep `FileVersion` at `3.6`.
- Set `ProductVersion` and `buildVersion` to `23`.
- Set `edition` to `Kirs.3`.
- Preserve all Kirs.2 source-deletion, partial-output, password-redaction, and batch-suppression invariants.

## User Experience

### Selecting split archives

The outer extraction loop must no longer silently discard a selected non-first volume. Every selected path reaches `DetectVolumeGroup`.

- A complete recognized set redirects to its first member and is extracted once.
- Multiple selected members from the same set are de-duplicated through `processedVolumeFirst`.
- An incomplete recognized set reports `MISSING_VOLUME` and offers “定位首卷”.
- Split-archive members are never auto-deleted.
- The existing `partSkip` key remains for INI compatibility, but its documented behavior becomes “same group extracts once; selecting any member starts from the first”. It must not authorize an early `continue`.

### Password recovery

For a single archive, a password diagnostic remains open until the user closes it or a retry succeeds. “重新输入密码” must no longer discard the retry result.

`ShowDiagnostic(result, false)` becomes a synchronous recovery boundary:

1. It displays one diagnostic window and waits for that window to close.
2. `DiagnosticButtonAction` stores a successful password resolution on the GUI/recovery context and closes the window.
3. `ShowDiagnostic` returns the resolved `ArchiveResult`, or the original result when no retry succeeds.
4. `zipx` detects a returned successful result and resumes its existing test, extract, finalize, and source-handling pipeline. The retry path must not duplicate those steps.
5. A wrong password keeps the same window available and updates no source files. Cancel/close returns without extraction.

Batch mode stays noninteractive: it records the result and returns immediately, never opening one password dialog per item.

### Batch summary

Keep the existing tray-tip/message-box summary. When failures exist, append at most three failed archive basenames. If more fail, append an ellipsis/count marker. Do not add a list view or a new batch window. Paths and diagnostic contents remain redacted.

## Detection Rules for Numeric Extensions

Pattern D (`name.<digits>`) is recognized as a split archive only when at least one evidence rule holds:

- the stem ends in a known archive/compression extension, including at minimum `.7z`, `.zip`, `.rar`, `.tar`, or `.wim`; or
- a sibling with the same stem and numeric width exists at a different positive index; or
- the selected index is `1`, allowing a lone first-volume candidate.

Examples:

- `archive.7z.001` is a volume even when alone.
- `data.001` plus `data.002` is a volume set.
- lone `data.001` remains a first-volume candidate.
- lone `report.2024` is an ordinary file, not a volume.
- existing digit-width, case-insensitive matching, missing-member calculation, and 4096-span guard remain unchanged.

## Diagnostic and Build Safety

### Logging

`CheckCMD.LogAndReturn` must pass both command arguments and captured line text through `RedactDiagnostic` before calling `Loging`. No password-bearing argument may be written raw.

### Integration hook

Production `SmartZip.ahk` must not include `tests\IntegrationTestHook.ahk`, even optionally. `tests\Real7Zip.Integration.Tests.ps1` will stage a temporary copy of `SmartZip.ahk` and inject the optional include into that temporary source immediately after the production library include. Only the temporary source is compiled for integration tests. Production staging and smoke tests must continue to prove that test-hook names/content are absent.

## Architecture and Data Flow

The change stays within the existing monolithic AutoHotkey structure and diagnostics library:

- `lib\ArchiveDiagnostics.ahk` owns pure volume classification.
- `SmartZip.Unzip/zipx` owns orchestration, de-duplication, testing, extraction, finalization, and source handling.
- `ShowDiagnostic` and `DiagnosticButtonAction` exchange a small GUI recovery context containing the current result and an optional resolved result.
- PowerShell/Pester harnesses provide static, headless GUI, unit, and real-7-Zip integration coverage.

No new runtime dependency or persistent configuration key is introduced.

## Error Handling and Safety Invariants

- Source archives may be handled only after a clean `OK` result from all required stages.
- `OK_WITH_WARNING`, corrupt, missing-volume, password failure, cancellation, and all other failures preserve the source.
- Volume members are never automatically deleted or recycled.
- Partial output remains isolated and discoverable through diagnostics.
- Password values never appear in copied diagnostics, diagnostic files, runtime logs, or batch summaries.
- `successPercent` remains a deprecated compatibility key and must not become runtime authorization.
- Password retry must reuse the normal pipeline and cannot bypass the full-test requirement that protects source handling.

## Tests

Add failing tests first, then implementation, for:

- selection of first and non-first complete volume members, de-duplication, incomplete-set diagnostics, and no volume deletion;
- `report.2024` false-positive prevention plus preservation of `data.001/.002` and archive-extension cases;
- synchronous diagnostic return behavior, retry success, wrong retry/cancel behavior, and batch noninteraction;
- batch summary basename limit and ellipsis;
- `CheckCMD` log redaction;
- absence of the test hook from production source and successful temporary integration-hook injection;
- Kirs.3 metadata and documentation.

Run every existing test suite plus the real 7-Zip integration suite against `C:\Tool\7-Zip-Zstandard\7z.exe`. Compile the production executable from a clean staging tree, run production smoke tests, back up the currently deployed executable, deploy to `C:\Tool\SmartZip`, and verify file metadata and SHA-256.

## Non-Goals

- No batch list view or per-row diagnostic GUI.
- No settings-page redesign or INI key rename.
- No automatic archive download or repair.
- No compression-algorithm changes.
- No source-deletion policy expansion.
- No changes to Kirs.1 or Kirs.2 release history.
