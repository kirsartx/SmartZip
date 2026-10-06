# Output verification repair

Scope approved by the user after the failed real-package validation. Preserve all
existing uncommitted work, GUI selection, source protection and final source test.
Only one editor works in this checkout; reviews are read-only. No premature push.

## Design

Use a narrow empty-file exception instead of bypassing output verification or
changing the extraction engine. A checksum-less entry is acceptable only with a
valid integer size of zero and an existing, regular, zero-length output file.
Nonempty files retain mandatory CRC. Check output root and ancestor components
before reading; reject destination names colliding under case-insensitive Windows
comparison. This is conservative for case-sensitive directories. No claim of
protection against concurrent hostile filesystem mutation is made.

## Execution checklist

- [x] Extend `tests/Sfxv.Integration.Tests.ps1` with real 7z empty-file fixtures,
  missing/nonempty/directory replacements, case-colliding entries, root junctions
  and ancestor junctions. Assert refusal before any file has been CRC-checked.
- [x] Run Windows PowerShell `Invoke-Pester -Script ./tests/Sfxv.Integration.Tests.ps1
  -PassThru`; record expected failures before modifying production.
- [x] In `lib/ArchiveDiagnostics.ahk`, validate integer sizes, permit absent CRC
  only for zero size, verify file identity/size before counting it, reject case
  collisions and check ancestor reparse points before opening file data.
- [x] Re-run focused suite and exact-count full gate from `tests/README.md`; final full run pending.
- [x] In `tests/GuiExtraction.Tests.ps1`, replace broad process scan with owned
  Process-object tracking; test an unrelated live process and an owned live one.
- [x] Build hook-free SmartZip in an isolated directory, run production smoke and
  repeat the four-volume real sample against preserved copies with source deletion
  disabled. Require complete output verification and `OK_WITH_WARNING`.
- [ ] Obtain read-only review, finish full regression, update continuity/results/counts,
  check staged diff and sensitive content, commit and push to the user's existing origin branch.

No new UI, parallel extraction, cache, compression tuning or archive execution.
