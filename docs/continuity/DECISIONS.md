# Cross-Model Decisions

## Conversation Boundary

Codex and EchoBird are separate conversation providers. Every provider switch starts a new conversation; models must rebuild context from repository files rather than continuing an old provider session.

## Source of Truth

Git history, the current worktree, and docs/continuity/ are authoritative. Model summaries are disposable convenience text.

## EchoBird Boundary

The installed EchoBird application contains its Responses-to-Chat translation and session storage in a compiled executable. This project does not patch that executable. An EchoBird conversation therefore receives the repository handoff prompt rather than a resumed Codex session.

## Mutation Safety

Only one model edits the worktree at a time. Existing uncommitted changes are user-owned until explicitly confirmed otherwise.

## DiagnosticUI Contract

The `DiagnosticUIHost` test double mirrors production `IsArchive` semantics: `SplitPath` extension values have no leading dot, exact configured extensions are held in `ext`, and regex extensions are held in `extExp`. The UI harness covers both generic non-archive paths and known archive extensions; production `SmartZip.ahk` remains the source of the diagnostic behavior.

## Extraction Speed Result Handoffs

- Reuse a successful `TestArchive` result only within the same synchronous extraction pipeline. Reuse requires the result to be test-verified and its own non-empty `archivePath` to match the current normalized archive path case-insensitively; every mismatch or unverified result follows the existing `TestArchive` path.
- Reuse a nested archive probe only as the immediate precomputed probe passed from `UnZipNesting` to the following `Unzip`. After volume normalization, reuse requires own `status`, own `stage = "probe"`, and a non-empty path-matching `archivePath`; a missing, empty, invalid, or path-mismatched probe follows the existing `ProbeArchive` path.
- Preserve the final post-extract `7z t` and all existing password, volume, isolation, source-recycle, nesting, status, error, and result behavior.
- Do not add a cross-run cache, concurrency, 7-Zip parameter tuning, GUI or CLI changes, or production hooks for this optimization.
- Do not record secrets, passwords, session IDs, or raw logs in continuity records.

## Directory Scan Optimization (2026-09-16)

- Use one conservative filename predicate for the existing RAR, rNN and numeric
  volume patterns before gathering sibling names or constructing volume indexes.
  The predicate is not volume evidence; DetectVolumeGroup still determines the group.
- Custom archive extension/regex checks run before the nested candidate rejection.
- Empty-directory detection stops on its first child; source handling and final
  integrity verification are unchanged. No directory cache is introduced.

## SFXV Compatibility (2026-09-17)

- Reuse a merged input only inside its synchronous task and matching original
  or normalized first-volume path. Borrowers do not delete it. Nested scopes
  restore the outer owner and task finally blocks release owned files.
- Ordinary archive filenames bypass the SFXV-specific directory scan. Before
  merging, query free bytes; copying validates byte counts and converts I/O
  failures to IO_ERROR. The full post-extraction integrity test is retained.
- Task preparation timing uses the fixed prepare label; no cross-run cache.
- Treat `.exe` plus `.001.sfxv`, `.002.sfxv`, and later pieces as a distinct
  byte-split self-extracting format. Do not reinterpret it as an ordinary
  `.7z.001` set or rename the source pieces.
- The tested 7-Zip Zstandard engine does not accept a 7z archive from stdin,
  so the production-compatible path is a sequential temporary merge after
  removing the first executable's SFX stub. The source files remain untouched;
  cleanup is best-effort and idempotent.
- SFXV operations preserve the first executable as `archivePath` for result
  identity, status reporting, and source-protection rules. Missing pieces fail
  before materialization. The temporary merge needs free space approximately
  equal to the archive payload.
- Operation timing is opt-in through `timingLog=0` and writes only fixed
  operation names plus duration values; no paths, passwords, or raw output are
  recorded.

## SFXV Reliability Follow-up (2026-09-19)

- An `SfxvInput` carries three independent states: `taskActive` (its owning task
  still accepts borrows), `closed` (a successful temporary file is no longer
  borrowable) and `cleanupComplete` (the `archive.7z` and directory this instance
  owns are gone). Borrowing requires a matching path plus `taskActive`; a
  successful input additionally requires `!closed`. This replaces reading
  `closed` as if it also meant "cleanup finished".
- A preparation that already failed stays terminal for the whole task and is
  reused without another directory scan, space query or merge, even after the
  original cause clears; only a new task re-attempts it. A failed input's
  `commandPath` never reaches 7-Zip because every caller branches on the
  non-empty status first. This refines the 2026-09-17 rule: cleanup is no longer
  merely "best-effort and idempotent".
- `Close()` stops borrowing before it touches the filesystem and never throws, so
  a failed cleanup cannot change the extraction result or mask the original
  error. It deletes only the file the instance owns, then removes the directory
  non-recursively, so a file the task did not create is preserved. Repeat calls
  are skipped only once cleanup has completed.
- `SfxvTaskScope.Close()` restores the previous owner before retrying cleanup, so
  a failed retry cannot leave the host pointing at a dead input. Cleanup is
  attempted at most three times with 50 ms in between, which adds no more than
  about 100 ms to task teardown, and a retry never re-merges. A leftover keeps
  its path and is reported through `Loging` with `RedactDiagnostic` at level 1
  when the host logs at all. Zero residue is not guaranteed while another
  process still holds the merge.
- Harness integrity: results are validated against a hand-authored expected label
  set that is never derived from the produced file, and per-label tests register
  from that set unconditionally, so a missing, duplicated, unknown, truncated or
  failing line cannot silently reduce the number of tests.
- Every `.ps1` containing non-ASCII literals is saved as UTF-8 with BOM, and AHK
  runners are launched through `[Diagnostics.Process]`, because Windows
  PowerShell 5.1 decodes a BOM-less file with the ANSI codepage and can leave
  `Start-Process -PassThru` `ExitCode` empty.
- No production test hook was added. The new coverage uses the existing
  `AvailableBytes` seam, source slicing, and exclusive handles on TEMP fixtures.

## 7zG versus console exit codes and the extract verdict (2026-09-20, measured; fix not applied)

Facts established by measurement on 7-Zip 26.02 ZS with a self-built Copy + 7zAES SFXV
fixture carrying 1529 trailing bytes (nothing of the user's archive was touched):

| archive | `7z.exe x` | `7zG.exe x` | written | SHA-256 matched |
|---|---|---|---|---|
| clean, no tail | 0 | 0, and it exits with no lingering dialog | 6/6 | 6/6 |
| + 1529 trailing bytes | 0 plus warning text | **2** | 6/6 | **6/6, complete** |
| one data byte flipped | 2, `CRC Failed in encrypted file` | **2** | 6 | **5/6, real damage** |

- Which executable runs is **size-dependent**: `Run7z`'s first parameter selects the binary
  (`is7z ? 7z.exe : 7zG.exe`) and `ExtractArchiveToTemp` passes it `hideBool`, derived from
  `FileGetSize(path) / 1024 / 1024 < hideRunSize`. So `hideRunSize` silently switches both the
  user interface and the exit-code contract, and every existing fixture is small enough to take
  only the console branch. The `Sfxv` suite's `Host.Run7z` likewise always uses console
  `7z.exe`, so the GUI branch has no coverage at all.
- A 7zG exit code is not a usable verdict oracle for extraction. `2` covers both a
  fully-written run carrying a trailing-data warning and a run with real corruption.
  `Classify7zResult` grants warning-success only at exit 0 and exit 1, so a GUI warned run falls
  through to `UNKNOWN_ERROR`, and `FinalizeExtraction` then quarantines complete output into
  `<name>_解压不完整_<stamp>`. `mayDeleteSource` stays false, so this is a false failure and a
  mislabelled folder, not data loss.
- An `extract` result must not carry another process's stdout. Currently `extractExit` from the
  GUI is paired with `cap.output` from a separate console `7z t`, which is why a report can say
  `stage=extract exitCode=2` above `Testing archive … Everything is Ok`. The same text also
  feeds the hard-error detail branches, so an extract can be characterised by a run that never
  extracted anything.
- The follow-up `7z t` proves source content only; it cannot prove what reached disk.
  Output completeness must be judged on the output side.
- Rejected framing: "closing the warning window produces 2". Clicking the Close button
  (`BM_CLICK` id=2), `WM_COMMAND`, `WM_CLOSE`, `WM_SYSCOMMAND SC_CLOSE`, Esc and Enter all
  returned 2 with all files intact. The code belongs to the warned completion state; the dialog
  only decides when the process exits, and a warned 7zG never exits by itself.
- Safety invariants any fix must keep: an indeterminate outcome stays
  `isCleanSuccess=false` and `mayDeleteSource=false`, and exit 2 must never be blanket-mapped
  to success.
- Known trap: simply deleting the `t`-text attachment is unsafe. Measured with empty extract
  text, exit 0 classifies as `OK` with `isCleanSuccess=1` and `mayDeleteSource=1`, which would
  newly permit recycling the source of a warned run. The extract stage needs its own verdict
  source, not less text.

Proposed minimal fix, **deliberately not implemented this turn**:

1. Treat GUI exit 2 as indeterminate and resolve it from the post-extract console `t` **and** an
   output-side inventory: every non-directory entry from `7z l -slt` present with a matching
   size (hash small outputs). All present plus clean-or-warning `t` gives `OK_WITH_WARNING`;
   anything else gives a partial or `DATA_CORRUPT` result.
2. Keep per-process provenance on the result (`extractText` versus `verifyText`) and have
   `WriteDiagnostic` label which process each block came from.
3. Decide at product level whether extraction should stop depending on 7zG's codes at all
   (console `7z.exe x` plus SmartZip's own progress window), or record formally that the two
   branches have different contracts. This is the user's call, not an agent's.

Required regression coverage alongside such a fix: `Classify7zResult` cases for
`(2, warning-only text)` and `(2, empty text)`; an assertion that an extract result cannot
carry `t` output; a `Host.Run7z` that mirrors production's binary choice so the GUI branch is
finally exercised; one trailing-data fixture crossing the `hideRunSize` boundary that must
produce the same status on both sides; and file count plus hash checks for completeness instead
of trusting `t`.

Still unproven, and not to be assumed by whoever continues: the real mid-run 7zG cancel exit
code (pausing ~100 ms into a 1.34 GB run did not stop the write, so no genuine mid-run abort
was observed) and therefore whether `extractExit = 255` to `CANCELLED` is reachable through the
GUI at all; other 7zG warning classes; and whether the user's own tail is the same kind of
trailing data beyond its matching `Tail Size=1529`.

Test-harness constraints learned the hard way: dismiss 7zG with `PostMessage`, because
`SendMessageW(BM_CLICK)` blocks the caller indefinitely on that dialog; a warned 7zG never
exits without dismissal, so any such test needs an explicit dismiss step plus a bounded wait;
and it must own only its own PIDs. Raw logs remain in
`%TEMP%\szx-taildiag-20260920-030128`.
