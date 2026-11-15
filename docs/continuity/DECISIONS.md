# Cross-Model Decisions

## No-rule post-process enumeration (2026-11-16)

- With all four rule families empty, post-processing enumerates directories only
  (`loop files "DR"`) and still calls `AfterUnzip` for each directory. Any rule
  family keeps the full `loop files "RDF"` walk. Empty-directory removal stays
  inside `AfterUnzip` and stays pre-order.

## Reviewed sequential improvements (2026-11-06)

- Treat technical `Key = Value` records and `Listing/Testing/Extracting archive:`
  path announcements as data, not diagnostic phrases. Continue extracting archive
  type and probe `Encrypted = +` evidence, and retain actual message priority.
  Reserved Error/Errors/Error Type and Warning/Warnings properties are diagnostics,
  even with the same equals-sign formatting; do not filter them out.
- Request a 1 MiB buffer only for `RunCmdCapture`; retry system-default pipe size
  if the larger allocation fails, and return exit -1 if neither pipe can be made.
  Keep byte-exact collection, decode-once UTF-8 and the 15 ms wait loop.
- Capture/password fragments are generated in unique TEMP stages, never in the
  checkout. A fresh result file and exit 0 are independent requirements. Test stages
  may be recursively removed only after validating their parent and generated name.
- Synthetic test INI files use the same UTF-16 encoding as the production smoke
  writer. A standalone UTF-8-BOM fixture caused a startup failure and was excluded;
  the matching UTF-16 fixture passed without a production-source change.
- Keep this implementation in the existing branch with its prior changes preserved;
  no commit, push or installed EXE/INI replacement is part of this request.

## Output proof edge cases (2026-10-06)

- 7z may omit CRC for zero-length regular files. Accept only when size parses as an
  integer zero and a regular, non-reparse file exists with exactly zero bytes; all
  nonempty files still require a matching CRC.
- CRC covers raw bytes including UTF-8/UTF-16 BOMs. Seek to offset zero after AHK
  `FileOpen`, which may auto-skip BOMs even when the caller later uses `RawRead`.
- Decode captured command output only after reading all raw pipe bytes; UTF-8 characters
  may be split across pipe reads.
- Reject case/separator-colliding archive listing entries and case-folded written-file
  keys. Check every output path component for reparse points before reading file contents.
- These checks assume a stable output tree; they are not atomic against concurrent
  hostile filesystem changes. The test account cannot enable case-sensitive NTFS folders.

## Real-sample release gate (2026-09-20)

- Synthetic regression success is insufficient to publish the GUI-exit-2 fix: the real
  SFXV sample still fails because eight legitimate zero-byte files have no listed CRC.
  Publication stays blocked until real-sample output verification succeeds safely.
- Any empty-file accommodation must prove existence, regular-file identity and exact
  zero length; it must not relax checksum requirements for nonempty files. Reparse and
  destination-path collision findings must be resolved before claiming output integrity.

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

## Probe Substage Timing (2026-10-06)

- Preserve aggregate `probe` timing and add fixed labels `probe_list_capture`
  (initial listing process output capture), `probe_list_classify` (classification
  of that output), and conditional `probe_fallback_test` (fallback `7z t` capture
  plus classification).
- Use the existing `timingLog` gate and fixed-label/integer-duration format. Do not
  log paths, archive names, commands, output, or passwords.
- Instrumentation must not change command arguments/order, classification, status,
  or fallback conditions. Consider classifier optimization only after split timings
  identify the dominant cost and a matched benchmark confirms improvement.

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

## 7zG versus console exit codes and the extract verdict (2026-09-20, measured and implemented)

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

Implemented decision (2026-09-20 follow-up):

- `ExtractionVerdict(extractExit, verifyStatus, outputVerified, usedGui)` in
  `lib/ArchiveDiagnostics.ahk` is now the only place an extract status is chosen from an
  ambiguous code. A user break stays `CANCELLED`; any hard result from the source test is
  returned as-is; exit `0` keeps the source test's status (so a source warning still downgrades
  the outcome instead of looking clean). Promotion is pinned to the single measured
  ambiguity - the **GUI** front-end returning **2** with the output proved - and everything
  else stays `UNKNOWN_ERROR`: an earlier draft let any code other than 0/1/255 be promoted,
  which a review rejected, because a console `2` means real failure and `3`/`4`/`7`/`8`/`-1`
  mean usage, memory, lock, disk-full or an unassigned launch failure. A promoted result is
  never `OK`, so `isCleanSuccess` and `mayDeleteSource` stay false and the source is never
  recycled. `usedGui` is `!hideBool`, the same comparison that picked the executable, so the
  verdict is told which contract the code came from instead of guessing.
- Proof of integrity is per item, over **all** items: `VerifyExtractedOutput` reads
  `7z l -slt` and compares every non-directory entry with the file actually written, by size
  and by CRC-32 computed with `ntdll!RtlComputeCrc32` while streaming. An earlier proposal to
  check only counts and sizes and hash small files was rejected: it cannot show that a large
  file's content arrived, and the source test proves nothing about the output. The rejection is
  now tested directly - damaging one output byte while the source stays intact makes the check
  report `mismatched=1` and blocks promotion.
- The check is skipped, and the result stays conservative, whenever the expected file set is
  not knowable: `excludeArgs` or `codePage` set, listing empty or unparsable, an item listed
  without a checksum, a missing item, or more files in the output than the archive lists
  (which also covers `-aou` renames). It is not run at all when the exit code is already
  unambiguous, so a normal extraction pays nothing; an ambiguous one costs one read pass.
- Evidence stays per process. The extract result carries its own `exitCode` and its own
  `output`; the follow-up source test is recorded separately as `verifyExitCode` and
  `verifyOutput`, plus an `outputCheck=` line, and every diagnostic form labels that block as
  coming from the source test. Deleting the `t` text alone was rejected as unsafe for the
  reason measured above (exit `0` with empty text would have become `OK` and permitted source
  recycling), so the source test still constrains the verdict - it just no longer impersonates
  the extract run.
- The GUI experience, password retry, exclusion rules, split-volume source retention and
  failure isolation are unchanged, and the extraction binary is still chosen by `hideRunSize`.
  Whether extraction should stop depending on 7zG's codes at all remains the user's product
  decision; this change only stops treating that code as a success oracle.

Required regression coverage alongside such a fix: `Classify7zResult` and `ExtractionVerdict`
cases for `(2, warning-only text)`, `(2, empty text)`, `(255, verified output)` and
`(1, warning text)`; a provenance assertion that an extract result cannot carry `t` text;
oracle cases for complete, damaged, missing, unexpected and no-checksum outputs; and file count
plus hash checks for completeness instead of trusting `t`.

Hardening added after review of that first implementation (all of it red-then-green, labels
`oracle_*` / `verdict_*_not_promoted` in `Sfxv.Integration.Tests.ps1`):

- The listing is treated as another process's evidence: `report.listingExit` is now **checked**
  (only `0` is accepted, so a process that printed plausible rows and then failed still
  refuses), and the text is validated structurally before one entry is believed - the
  `----------` separator must exist to tell the archive header from its entries, the header
  must name the archive that was queried, and each entry must carry a size, attributes and
  - for files - a checksum, with no duplicate and no truncated final entry.
- `outputDir + item.path` is validated before use: absolute, UNC, device, alternate-stream and
  `..` shapes are refused, and the normalised target must lie inside the normalised output
  directory behind a `\` boundary, so a prefix like `D:\out2` cannot pass for `D:\out`.
  A reparse point aborts verification instead of reading a file the extraction never wrote,
  both where a listed item stands and during the walk of what was actually written.
  This closes a real defect found while writing the tests: the enumeration walk recursed
  through junctions, so a link out of the output directory could be certified as output.
- Expected and written files are compared **as sets in both directions**, not by count: a
  fixture with one deleted and one added file has matching counts, and only the set comparison
  refuses it. Nothing is silently skipped, because a skipped suspicious entry would leave a
  hole that still looks verified.
- Any CRC or read exception ends as a conservative failure with a reason (the reason now
  carries the line), so verification can never escape and bypass failure isolation.

Automated real-7zG coverage now exists: `tests/GuiExtraction.Tests.ps1` with
`tests/GuiDismissDriver.ahk`, seven assertions that launch the executables themselves with the
argument shape `Run7z` builds and read their own exit codes - clean exit 0, trailing data exit
2 with complete output, the same archive on the console build exit 0 with identical output (the
two sides of `hideRunSize`), corruption exit 2 with output that does not verify, an unwritable
output path, and a mid-run cancel that leaves output strictly partial. Ran 3/3 times green in
about 8 seconds each. An earlier `tests/ExtractGui.Tests.ps1` was deleted when it timed out;
deleting it and calling the branch covered was wrong, and this suite replaces it.

What the new suite had to learn about driving that dialog, none of it guessable from the
outside: `WinExist` returns only the top-most window and 7-Zip keeps its progress dialog open
underneath the box that follows, so the driver walks the top-level Z-order outward; `GetParent`
reports the **owner** for a dialog, so filtering on it discarded the very message box that had
to be clicked (which looked exactly like a hang); and `CallbackCreate` is avoided because this
build rejects every form of its callable argument with "Invalid base". On the cancel gesture
itself, measured on a *running* dialog: Escape, `WM_CLOSE` and a click on the default control
(id 2) leave the extraction untouched, the first owner-drawn button (id 444) only pauses it, and
the second (id 446) cancels - but only when the archive is not solid, because inside one solid
block 7-Zip can stop only at the end. The earlier hand measurement of a 1.34 GB job
interrupted at 3.2 % returning **2** therefore stays the only observation of a cancel on a
solid archive; the automated fixture uses `-ms=off` and asserts bytes on disk, never a
substituted exit code. A warned 7zG still never exits without acknowledgement.

Test-harness constraints learned the hard way: dismiss 7zG with `PostMessage`, because
`SendMessageW(BM_CLICK)` blocks the caller indefinitely on that dialog; a warned 7zG never
exits without dismissal, so any such test needs an explicit dismiss step plus a bounded wait;
and it must own only its own PIDs. Raw logs remain in
`%TEMP%\szx-taildiag-20260920-030128`.
