# Active Task

## No-rule post-process walk measured — 2026-11-16

- Usable-output post-processing now uses `loop files "DR"` when `AfterUnzip("", true)`
  is false and keeps `loop files "RDF"` when it is true. `AfterUnzip` and the two
  placement loops are unchanged.
- Contract archive: 13,367 zero-byte files in `dir-000`..`dir-688`, plus `empty-dir`
  and `nested\empty-child`. All six recorded runs: 13,367 files, 690 directories,
  empty paths absent, `nested` present, inventory SHA-256
  `B203A4B872100E90AB5E573F7B61BC0E980F4B63E976B2073C40BC2B3ADF162F`.
- Baseline postprocess ms `1235 / 1281 / 1156` (median `1235`). Implemented
  `1000 / 1047 / 985` (median `1000`). An earlier baseline invocation was interrupted
  and is not included. Count-stress only; not a general extraction speedup.
  No commit, push, or installed EXE/INI replacement.
- Static suite 192/192 before the serial gate. Serial gate 851/851, zero
  failed/skipped/pending. Counts: 9, 192, 211, 22, 99, 39, 30, 53, 36, 1, 1, 141,
  10, 7. `git diff --check` exit 0.

## Sequential improvements completed and verified — 2026-11-06 (Codex)

- User authorized implementing the three reviewed items one at a time, then asked
  to continue. Main agent edits this existing worktree; read-only review was delegated.
  Plan: `docs/continuity/2026-11-06-improvements-plan.md` (bilingual). Prior source,
  test and documentation changes plus the pre-existing untracked password fragment
  are preserved. No commit, push or installed-app/INI replacement is authorized.
- Item 1: classify technical records and path announcements as data, retaining type,
  probe encryption and genuine diagnostics. TDD initially gave 195/205 (10 expected
  failures), then 204/208 (four announcement/real-listing failures), then 208/208.
  Independent review identified genuine `ERROR =` / `WARNING =` diagnostic fields;
  primary 7-Zip List.cpp/Rar5Handler.cpp source was checked. Three new regressions
  were RED 208/211 and GREEN 211/211 after preserving reserved diagnostic keys,
  including missing-volume count and its priority over encryption metadata.
- Item 2: `RunCmdCapture` requests a 1 MiB pipe, retries system default on failure,
  and returns exit -1 if both fail. Existing byte collection/UTF-8/15ms polling
  remain. Capture TDD was 17 passed / 3 failed (bulk read efficiency, fallback,
  total allocation failure), then 20/20 behavioral assertions, real exit 0.
- Item 3: unique TEMP stages for capture/password fragments and diagnostic/UI
  results; bounded process helper; independent exit-zero/fresh-result checks;
  constrained stage cleanup. Infrastructure TDD was 2/8 then 9/9 after adding a
  stale-result case. Focused suites: infrastructure 9, capture 22, password 99,
  diagnostics 211, UI 53 all green. Captured repository fragments were unchanged.
- Windows PowerShell 5.1 compatibility reruns: infrastructure 9/9, capture 22/22,
  password 99/99, and final diagnostics 211/211 (341 passed across focused runs,
  zero failed). Initial complete serial gate passed 848/848 before the review
  correction. The final 14-suite serial gate passed 851/851 after that correction,
  zero failed/skipped/pending. Counts in order: 9,192,211,22,99,39,30,53,36,1,1,141,10,7.
- Matched real-listing benchmark (4,096 files, 128 directories, 603,415 characters):
  baseline capture ms `2219 / 2140 / 2125`; implemented `47 / 47 / 47`, medians
  2140 and 47. Reads 139 versus 10 each run. All six output hashes were
  `71FA4B8F8056D4BB424D9B1AF466BBB41B6243396937017B3663750624DA9524`.
  `Measure-ImplementedCapture.ps1 -Repo <repo>` and CSV are under the previous
  review TEMP root. This is capture-only, not a whole-extraction speedup claim.
- Final hook-free build is staged below
  `%TEMP%\SmartZip-Implemented-20261106-22bf96cf1e0d451ca9369269c198fd73`:
  `SmartZip-final.exe`, Ahk2Exe exit 0, SHA-256
  `65FEF754AD5D63B634A1E9E2B5D1027F1E6CA6ACC99DBAAEA015F17C6BEE4590`.
  Earlier build in that root is superseded. Four production smoke scenarios passed:
  valid, crcPartial, splitMissing and encryptedHeader; zero leaked processes and
  redaction true. Compiled full extraction of `Headers Error.7z` containing
  `Data Error.txt` also passed, exactly one output with matching content hash and
  source preserved. The standalone filename test initially used UTF-8-BOM INI,
  unlike the project's UTF-16 smoke configuration; that invalid setup was excluded,
  and the UTF-16 rerun passed. No production change was made for that setup error.
- Review follow-up found no remaining high/medium issue in the reserved diagnostic
  key correction. Reviewers made no edits. Intended files changed this turn:
  `SmartZip.ahk`, `lib/ArchiveDiagnostics.ahk`, diagnostics/capture/password/UI test
  wrappers, `tests/RunCmdCapture.Harness.ahk`, `tests/TestHelper.ps1`, new
  `tests/TestInfrastructure.Tests.ps1`, test README and continuity docs/plan.
  Prior unrelated profiling/static/SFXV/INI edits remain preserved. In particular,
  `tests/RunCmdCapture.Fragment.ahk` has no diff; the pre-existing password fragment
  was not overwritten or removed.
- Exact verification commands: `Invoke-Pester -Script <suite> -Quiet -PassThru`
  serially over the 14 suites/counts in tests/README (851/851); Windows PowerShell
  5.1 focused runs of infrastructure/capture/password/diagnostics (9/22/99/211);
  `Measure-ImplementedCapture.ps1 -Repo <repo>` (six exact-hash runs);
  hook-free Ahk2Exe `/in <source-final> /out <SmartZip-final.exe> /base <AHK64>
  /silent` (exit 0); `Invoke-ProductionSmartZipSmoke.ps1` (4/4, Passed true,
  LeakedProcessCount 0, RedactionOk true); `ProductionSmokeUI.ahk` filename case
  (runner exit 0, driver ok, one exact-hash output, source preserved).
- Implementation is complete. Preserve this uncommitted branch/worktree for review;
  no commit, push, merge or installed EXE/INI deployment was performed. Final
  `git diff --check` passed (exit 0, line-ending warnings only); source/staging hashes
  matched and no owned validation processes remained. New files had no trailing whitespace.

## Optimization review with fresh evidence — 2026-11-06 (Codex)

- User request: inspect the project for worthwhile optimizations. This turn reviewed
  source/tests and ran isolated diagnostic experiments; production source, installed
  EXE/INI and user archives were unchanged. Existing eight tracked modifications and
  the untracked `tests/PasswordPreflight.Fragment.ahk` were preserved. Branch at start:
  `agent/diagnostic-ui-contract-repair`, ahead 4.
- Prioritized review: `docs/continuity/2026-11-06-optimization-review.md` (bilingual).
  First fix filename-triggered false diagnostics, then implement the experimentally
  supported pipe-buffer improvement, then strengthen test isolation/process gates.
- New confirmed bug: clean real 7z listings all exited 0, but harmless filenames
  `Wrong password.txt`, `Headers Error.txt`, `Data Error.txt` classified as password,
  header and data failures; a trailing-data phrase filename caused a false warning.
  `normal.txt` stayed OK. `Classify7zResult` treats `Path = ...` text as diagnostics.
  Header/data false positives can block extraction; the password case can recover
  through the existing successful empty-password test. Add regression cases first.
- Fresh performance experiment: 4,096-file / 128-directory synthetic 7z, output
  603,415 characters. Three interleaved capture runs per variant. Median ms:
  default pipe 2,171; 64 KiB 203; 1 MiB 47; default pipe + 1ms polling 2,031;
  direct process capture 47. Output hashes matched for every run. Independent
  ~2 MiB emitter medians were 2,625 / 422 / 203 / 2,609 ms (direct 191 ms), with
  exact split-UTF-8 output. These are capture-only numbers, not extraction speedups.
- Commands/results: `Invoke-Pester -Script '.\tests\SmartZip.Static.Tests.ps1'
  -Quiet -PassThru` => 192 passed, 0 failed/skipped/pending;
  `Invoke-Pester -Script '.\tests\ArchiveDiagnostics.Tests.ps1' -Quiet -PassThru`
  => 193 passed, 0 failed/skipped/pending. TEMP-staged existing capture harness
  passed 15/15 and exit 0 for both original and 1 MiB pipe variants. No complete
  817-test run, compile, production smoke or large real archive extraction this turn.
- Reproduction artifacts remain below
  `%TEMP%\SmartZip-review-20261106-0d3cf0ad0a954ca49ae63b8fa5580f6b`.
  Commands are `Measure-Capture.ps1 -Repo <repo>`; same plus
  `-ArchivePath <root>\listing-stress.7z` for real listing; and
  `Check-FilenameClassification.ps1 -Repo <repo>` / `Check-CaptureContracts.ps1
  -Repo <repo>`. The initial temporary wrapper naming error was corrected before
  measurement; no failed launch is included in reported timings.
- Test-infrastructure read-only review confirmed unbounded legacy launchers, shared
  generated fragments/log paths and a UI harness exit check that accepts nonzero
  exit when a result file exists. README has stale 655/656 and six-suite 596 prose
  counts; current sums are 657/658 and 605. Full 817 arithmetic remains consistent.
- Files intentionally changed this turn: this handoff and the new review report
  only. `git diff --check` passed (exit 0; existing LF-to-CRLF warnings only), and
  the review's process scan found no remaining owned AHK/SmartZip/7z process.
  Retain the existing source/tests worktree for follow-up. No commit, push or deployment.

## Probe substage profiling implemented and verified — 2026-10-06 (Codex)

- Goal: split the slow `probe` diagnostic timing without changing archive
  commands, order, classification, or results. User approved the approach and
  requested routine choices follow the recommendation.
- Added `probe_list_capture` around initial `RunCmdCapture`, `probe_list_classify`
  around `Classify7zResult`, and conditional `probe_fallback_test` around fallback
  `7z t` capture/classification. Aggregate `probe` timing remains on acquisition
  failure and normal/finally paths. Existing `WriteOperationTiming` keeps all
  labels gated by `timingLog`; logs contain only a fixed label and milliseconds.
- Bilingual design: `docs/superpowers/specs/2026-10-06-probe-substage-profiling-design.md`.
  Plan: `docs/superpowers/plans/2026-10-06-probe-substage-profiling.md` (ignored).
  Stable contract recorded in `DECISIONS.md`.
- TDD: before implementation static tests were `190 passed / 2 failed`, exactly
  the two new missing-boundary assertions. Afterwards static passed `192/192` and
  SFXV integration `141/141`.
- Full serial 13-suite gate passed `817/817`, zero failed/skipped/pending. Counts:
  static 192, diagnostics 193, capture 16, password 98, lifecycle 39, nesting 30,
  UI 53, real 7-Zip 36, directory 1, SFXV recognition 1, SFXV integration 141,
  result contract 10, GUI extraction 7. `git diff --check` exited 0 (only Git's
  existing LF-to-CRLF working-copy warnings).
- Hook-free build exited 0; SHA-256
  `750F4FE55E67FD2EEEAD4D7738544F79D54FA6CC2827B92C2F094247F91B5E6F`.
  Production smoke passed `valid`, `crcPartial`, `splitMissing`, and
  `encryptedHeader`; zero leaked processes and redaction passed. Artifacts were
  isolated below `%TEMP%`; installed executable, INI, and user archives untouched.
- Exact verification: focused static 192/192; focused SFXV integration 141/141;
  documented serial gate 817/817; diff check exit 0; hook-free Ahk2Exe exit 0;
  production smoke `Passed=True`, four scenarios, `LeakedProcessCount=0`,
  `RedactionOk=True`. An initial fixture invocation omitted the required
  process-scoped test password and stopped before fixture generation; retry with
  an ephemeral test-only value succeeded.
- Tests/README.md reflects static 192, total 817, and the new probe labels. No
  speedup claim: rerun the same matched stress archive and inspect capture versus
  classify before considering parser changes. Existing prior fast-path/profile
  edits remain preserved. Do not commit, push, deploy, or clean unrelated TEMP
  roots without request.
- Branch remains `agent/diagnostic-ui-contract-repair`. Alongside preceding
  uncommitted edits, this follow-up changes `SmartZip.ahk`, static tests, SFXV
  timing-label validation, test instructions, and continuity records.

## Follow-up probe measurements — 2026-10-11 (Codex)

- Continued the recommended same-archive profiling. Input archive was the existing
  `%TEMP%\SmartZip-fastpath-benchmark-eb5cf2cf18a1472e92c3ac3af826aee2\count-stress.7z`,
  SHA-256 `DC6F1A9E95B06086CFA66C7F260BE24FEF05D10A4880AFD867ACCBDC6EE231F6`.
  It had previously been verified as 13,367 files / 689 directories. This follow-up
  invoked `ProbeArchive` only, so it did not write a new extracted output inventory.
- A temporary AHK harness extracted the production `ProbeArchive` and
  `RunCmdCapture` methods, ran the same `7z l -slt` probe three times, and returned
  `status=OK exit=0` each time. Results (ms):
  - run 1: aggregate probe 2,078; list capture 1,781; classify 297;
  - run 2: aggregate 4,016; capture 3,438; classify 578;
  - run 3: aggregate 3,110; capture 2,688; classify 422.
  Medians: probe 3,110 ms; capture 2,688 ms; classification 422 ms. The conditional
  fallback was not taken. Median capture was about 86% of probe time, so a classifier
  rewrite is not supported by this evidence.
- A second throwaway instrumentation run split the `RunCmdCapture` pipe-drain loop
  from `StrGet` conversion: pipe read/wait was 3,890 / 3,547 / 3,063 ms; conversion
  reported 0 ms at `A_TickCount` resolution; classification was 610 / 594 / 578 ms.
  This suggests the pipe pump/process-output path, not text decoding, is dominant.
  It does not yet distinguish time waiting for 7-Zip from the number/cost of pipe
  reads. Earlier direct-list measurements were 64 / 52 / 53 ms on this same stress
  archive, but are not an app-to-app controlled comparison.
- An application-level benchmark launch stayed in a SmartZip window without writing
  timing logs. It was stopped after confirming the process belonged to this test.
  Subsequent direct ProbeArchive harness runs succeeded. Two attempts at deeper
  temporary harness instrumentation also timed out because the diagnostic timer
  insertions were malformed; their AHK test processes were stopped, with no repo
  source change. Do not treat those attempts as product failures or timing data.
- Temporary roots created for these diagnostics remain under `%TEMP%`; no repository
  artifacts were added. Worktree code remains unchanged from the verified profiling
  implementation; `git status --short --branch` should be checked before any further
  edit. `git diff --check` is the next verification after this handoff update.
- Recommended next step: use a small throwaway harness to compare the existing
  `CreatePipe` default buffer with a larger suggested buffer and record pipe-read
  call counts/wait time on the same archive. Do not change production `RunCmdCapture`
  until that isolated experiment demonstrates repeatable improvement and the UTF-8
  split-byte / exit-code / cancellation regression contracts remain protected.

## No-op post-processing fast path implemented; verification recorded — 2026-10-06 (Codex)

- Goal: improve SmartZip smoothness without changing extraction outcome, placement,
  source-retention, password, or settings behavior. User approved the umbrella design
  and profiling implementation plan; no asynchronous UI redesign is in scope.
- Added opt-in timings while preserving `prepare`, `probe`, `test`, and `extract`:
  `7z_extract`, `source_test`, `output_verify` (only when run), and `postprocess`.
  The setting stays off by default; lines contain only fixed labels and durations.
- RED/GREEN: SFXV integration was 137/141 with exactly the three missing timing
  labels failing; static suite was 184/188 with the four new boundaries failing.
  After implementation focused suites passed 141/141 and 188/188.
- Full serial gate: 813/813 passed, zero failed/skipped/pending/inconclusive;
  `git diff --check` exited 0. Hook-free production compile exited 0; SHA-256
  `1545C172517496F3A66A3DF569C37494D2DB626C4637981D081F0F2D72B60C2B`. Production
  smoke passed `valid`, `crcPartial`, `splitMissing`, `encryptedHeader`, with zero
  leaked processes and redaction passing. Installed `C:\Tool\SmartZip` was untouched.
- Three matched runs on a controlled 13,367-zero-byte-file / 689-directory archive:
  wall time 16,340 / 15,990 / 16,507 ms (median 16,340); `probe` 5,422 / 5,265 /
  6,375 ms (median 5,422); `7z_extract` 7,406 / 7,235 / 6,656 ms (median 7,235);
  `postprocess` 1,219 / 1,250 / 1,219 ms (median 1,219, 7.5% of wall time);
  source `test` median 31 ms, follow-up `source_test` median 32 ms. Each output had
  exactly 13,367 files and 689 directories. This is a count-stress proxy, not a
  10 GB throughput claim.
- User approved the bilingual design at
  `docs/superpowers/specs/2026-10-06-afterunzip-noop-fast-path-design.md`. Implemented
  the no-op fast path: cache whether any of the three rename maps or `deleteExp` has
  entries, query once for each usable extraction, and skip regular-file callbacks
  only when all are empty. Directory entries still use `AfterUnzip`, preserving
  empty-folder cleanup; configured rules retain the original per-entry traversal.
- Changed tracked files: `SmartZip.ahk`, `tests/Sfxv.Integration.Tests.ps1`,
  `tests/SmartZip.Static.Tests.ps1`, `tests/README.md`, `ini.md`, this file. The
  implementation plan is at `docs/superpowers/plans/2026-10-06-extraction-performance-profiling.md`
  (ignored by repository rules). Test-generated `PasswordPreflight.Fragment.ahk`
  and both temporary profiling roots were removed after all processes exited.
- Commands/results for this optimization: TDD red run with exactly the two new
  tests failing (188 passed / 2 failed), then static Pester 190/190. Full documented
  13-suite serial gate: 815/815, zero failed/skipped/pending/inconclusive. Hook-free
  production compile exit 0; smoke scenarios valid, crcPartial, splitMissing and
  encryptedHeader passed (4/4), leaked processes 0, redaction true. Three matched
  SmartZip runs on a 13,367-zero-byte-file / 689-directory archive produced exact
  counts in each run and the same output inventory SHA-256
  `72A6F583333EC7DB40354EF59C29509751724D8538990566F8158ED924E7DBD9`:
  wall ms `14788 / 15242 / 13581` (median `14788`); postprocess ms
  `766 / 766 / 735` (median `766`). Against the prior matched baseline medians
  (wall `16340`, postprocess `1219`), this is about 9.5% lower wall time and 37.2%
  lower postprocess time. These are single-machine count-stress results, not a
  general throughput guarantee. A preliminary invocation without a pre-created
  output directory failed its inventory check and is excluded. Rerun
  `git diff --check` after this continuity update.
  The initial full-gate wrapper also used unsupported `-Show None` under the
  installed Pester 3.4; rerunning without that option completed the 815/815 gate.
  Current branch is `agent/diagnostic-ui-contract-repair`; no commit, push, or
  deployment was made in this optimization turn. Existing profiling changes remain
  in the working tree.
- The test-generated `tests/PasswordPreflight.Fragment.ahk` was removed. Three
  generated validation roots remain under `%TEMP%` because the local shell safety
  policy rejected recursive cleanup: `SmartZip-fastpath-validation-359299a205c343bc9ee95b9e77dd0f87`,
  `SmartZip-fastpath-validation-85e967cef1614d91b46bc0b7f4ce9711`, and
  `SmartZip-fastpath-benchmark-eb5cf2cf18a1472e92c3ac3af826aee2`.
- Remaining: review the final diff; do not push or deploy unless requested.

## Real SFXV warning fix verified; GitHub publication in progress — 2026-10-06 (Codex)

- User asked to fix the failed real-sample verification. Preserved Qoder's pre-existing
  uncommitted changes and worked in the same branch. Production changes address: eight
  legitimate zero-byte files without 7-Zip CRC; BOM bytes skipped by AHK text-mode file
  open before RawRead; UTF-8 codepoints split across pipe reads; output-root/ancestor
  reparse points; case-folded destination collisions; and GUI test false leak detection.
- Added regression cases first. The expanded SFXV suite was red `135 passed / 2 failed`
  for BOM and case-folded enumerator collision (the aggregate harness assertion is the
  second failure); after the fixes it passed 137/137. RunCmdCapture was red 14/16 on the
  split UTF-8 emitter; after collecting raw bytes and decoding once at EOF it passed
  16/16. `GuiExtraction.Tests.ps1` passed 7/7 with a held-live unrelated 7z sentinel,
  proving owned-process leak checks don't flag unrelated jobs.
- Final hook-free build: `F:\SmartZip-Validation-20260921\final-app\SmartZip.exe`,
  SHA-256 `EEDDB9D7D66FD1ADD3C9BEDA0A7E17137902F350820326E2EAB03D251D84D775E`, Ahk2Exe
  exit 0. Production smoke passed all four scenarios (valid, crcPartial, splitMissing,
  encryptedHeader), `LeakedProcessCount=0`, `RedactionOk=True`.
- Repeated the full four-volume real-package extraction from SHA-256-verified isolated
  copies. After acknowledging 7zG's trailing-data warning, production returned
  `OK_WITH_WARNING`, extract exit 2, verify exit 0, `output-verified`, `checked=13367/13367`,
  689 directories, zero mismatched/missing/unexpected/no-CRC entries. Final output had
  13367 files totaling 10162118522 bytes (matches the archive's reported Size), all four
  original input hashes were rechecked unchanged. Installed EXE/INI are untouched.
- The environment denied `fsutil file setCaseSensitiveInfo` on an isolated test directory
  (access denied). Listing collisions are covered directly, and output enumeration rejects
  a pre-seeded normalized key; the actual case-sensitive-NTFS on-disk collision scenario
  could not be enabled in this Windows account. Component/reparse tests run with real
  junction fixtures. Reparse defense assumes the path tree does not change concurrently.
- The full serial 13-suite gate passed exactly `805/805`, with zero failed, skipped, pending,
  or inconclusive tests. Exact counts in order: 1, 137, 184, 193, 16, 98, 39, 30, 53, 36,
  10, 7, 1. The focused `Real7Zip.Integration.Tests.ps1` rerun also passed 36/36.
- The first full-gate attempt exposed a test harness defect: `Start-Process -ArgumentList`
  split the AutoHotkey base path at `C:\Program Files`. Quoting all compiler paths fixed the
  harness; the retry and full gate both compiled and passed. The fix is in
  `tests/Real7Zip.Integration.Tests.ps1`.
- `git diff --check` passed before the latest continuity edit; rerun after edits. Stage only
  intended sources/tests/docs, review staged diff and secret scan, commit, push to `origin`
  on the existing branch, and verify the remote ref. The old Kirs.9 installed build remains
  untouched; this request did not ask to deploy the EXE locally.
- Verification commands and exact outcomes: `Invoke-Pester -Script '.\tests\Real7Zip.Integration.Tests.ps1' -PassThru`
  => 36 passed, 0 failed/skipped/pending/inconclusive; serial 13-suite PowerShell gate
  documented in `tests/README.md` => 805 passed, 0 failed/skipped/pending/inconclusive;
  `git diff --check` => exit 0 (rerun after this edit).
- Test/build artifacts reside under `F:\SmartZip-Validation-20260920` and
  `F:\SmartZip-Validation-20260921`; no source archive or embedded program was run.
  Isolated test configuration and saved password clones stay outside the repository.

## Publication blocked by real sample validation — 2026-09-20 (Codex)

- User authorized independent tests and GitHub upload only after validation. No commit,
  push, production code edit or deployment was performed in this validation turn.
- Ran all 13 documented suites under Windows PowerShell 5.1: 785 non-GUI assertions
  passed; GUI first run 6/7 because its broad recent-process scan counted the concurrent
  real sample extraction. Serial GUI rerun passed 7/7, zero failed/skipped/pending.
  Thus all 792 assertions passed across runs, not in one uninterrupted green gate.
  Initial invocation under the default PowerShell rejected `-Show` before running tests.
- Tested the installed EXE (SHA-256 `6031E2B04C0739F7E7D80113D5DF03508BAB1962D7336B64003DC9C207DB27C5`)
  in an isolated app directory against SHA-256-verified copies of all four real SFXV
  members. Existing saved password candidates were used locally; no password note read,
  no archive/program inside the sample executed, no original archive/config changed.
  Source deletion, nested extraction and rename/delete/exclusion rules were disabled
  only in the isolated test INI. Original installed EXE and INI hashes stayed unchanged.
- Reproduced 7zG at 100%, 13367 files, 9691 MiB, trailing-data warning; clicked Close
  only after completion. Final production verdict was still `UNKNOWN_ERROR`, extract
  exit 2, source verification exit 0, with `listing file entry without a checksum`.
  Output was quarantined, not accepted as complete. This blocks publication.
- Root cause evidence: real `7z l -slt` exited 0 and listed 14056 items; exactly eight
  regular files have size 0, Attributes A and an empty CRC. Current validation rejects
  all checksum-less files, including these legitimate empty files. Do not blanket-accept
  missing CRC for nonempty files. Add regression coverage and prove exact zero length.
- Timing: prepare 5454 ms, successful source test 4687 ms, extract wrapper 59360 ms.
  The last includes waiting for manual UI acknowledgement and verification, so it is
  NOT a throughput benchmark. 7zG itself displayed 18 seconds; no baseline speed claim.
- Read-only review additionally identified output-root/ancestor reparse handling and
  case-colliding listing entries as important integrity gaps (static findings, not runtime
  reproduced). Root junctions can bypass current enumeration checks; ancestor links can
  be read before rejection; A.bin/a.bin collapse in lowercase expected-file sets.
  GUI leakage assertion also needs owned-process tracking instead of a ten-minute scan.
- Remaining: fix/retest empty files and review findings, rerun full gate and real sample,
  then review staged content for secrets and push to the user's existing GitHub remote.
  Do not publish this as a completed fix merely because synthetic tests pass.
- Test artifacts remain outside Git under `F:\SmartZip-Validation-20260920` for retest.
  Test process exited and its merged temporary archive was removed by normal teardown.
  Removed the isolated password-bearing INI after exit; installed INI was untouched.
  Test-generated password fragment was removed and capture-fragment encoding restored.
  Final `git diff --check` passed (exit 0; line-ending warnings only).
  Only continuity documents were intentionally edited; test-generated fragments are
  not part of the deliverable. No raw logs or passwords were added to project files.

## Review gaps closed, real-7zG coverage and local deployment — 2026-09-20 (Qoder)

- Closed all four items a review had rejected, each red-then-green: the listing process's own
  exit code is now required to be `0` before its text is used and the text is validated
  structurally; every listed path is proved to be a safe relative path resolving inside the
  output directory behind a directory boundary, with reparse points refused rather than read
  through; expected and written files are compared as sets in both directions; and promotion is
  narrowed to `usedGui && extractExit == 2 && outputVerified`, so a console `2` and codes
  `1/3/4/7/8/-1/99` stay failures even with verified output.
- Added `tests/GuiExtraction.Tests.ps1` with `tests/GuiDismissDriver.ahk`: seven assertions on
  the real `7zG.exe` / `7z.exe` contract, launching the executables with the argument shape
  `Run7z` builds and reading their own exit codes, including the two sides of `hideRunSize` and
  a genuine mid-run cancel that leaves output strictly partial. Ran 3/3 green. The
  `tests/ExtractGui.Tests.ps1` that was deleted in the previous pass is replaced by this suite;
  deleting a hanging test and claiming the branch was covered was wrong.
- Two real defects surfaced while writing those tests and are now fixed: `VerifyExtractedOutput`
  initialised `reason` to a non-empty value, which made every verification return early as
  “aborted”, and the enumeration walk followed junctions, which could certify files outside the
  output directory as extracted output.
- Gate 792/792 over 13 suites (0 failed, 0 skipped, 0 pending); `git diff --check` exit 0.
  Hook-free production build `6031E2B04C0739F7E7D80113D5DF03508BAB1962D7336B64003DC9C207DB27C5`
  (1445376 bytes, no hook marker present in the binary) passed the four-scenario smoke, and the
  installed copy now carries exactly that hash; the previous build
  `7D933A46B706D088026A18DD0084EC967F62E29FB3BC60DA479B9285D9CAC413` is backed up at
  `C:\Tool\SmartZip\SmartZip.exe.bak-gui-reliability-20260920-185150` and the INI was never
  modified (`DDCC1A739F63700699E040095ECE3CEE39F3B4DCC9C5B18C67EE4824E7EE96A4`).
  Restore command and full evidence: `QODER_HANDOFF.md`, section
  「四项复审缺口修复、真实 7zG 回归与本机部署」.
- Still open by choice, not by oversight: `-aou` renames and `excludeArgs` / `codePage` keep the
  verdict conservative instead of promoting; a solid archive can only be cancelled at the block
  end, so that one case still rests on the hand measurement rather than an automated one.

## Fix — extraction verdict and per-process evidence (2026-09-20)

- Implemented the diagnosed fix. Production source, library and tests were edited; no
  staging, no commit, no push, and **no deployment** this turn, so the installed
  `C:\Tool\SmartZip\SmartZip.exe` is still `7D933A46B706D088026A18DD0084EC967F62E29FB3BC60DA479B9285D9CAC413`
  and `SmartZip.ini` is still `DDCC1A739F63700699E040095ECE3CEE39F3B4DCC9C5B18C67EE4824E7EE96A4`.
  The user's archive, split members, extraction directory and password note were never opened;
  no archive EXE was executed and the 10 GB sample was not re-run.
- Design settled before code, on the evidence in DECISIONS: GUI `exit 2` covers a
  warned-complete run, a corrupt run and a cancelled run alike (measured 2, 2, 2), so no exit
  code can certify extraction. The verdict therefore comes from the written output, item by
  item, by size and CRC-32 from `7z l -slt`; a hard source-test result always wins; a promoted
  run is only `OK_WITH_WARNING`. A generic `2 -> success` mapping is not used anywhere.
- `lib/ArchiveDiagnostics.ahk`: added `ExtractionVerdict`, `VerifyExtractedOutput`,
  `ParseArchiveListing`, `Crc32OfFileHex` (streaming `ntdll!RtlComputeCrc32`) and
  `CountWrittenFiles`; `ArchiveResult` gained `verifyExitCode`, `verifyOutput`, `outputCheck`.
  `RtlComputeCrc32` over `c-clean\a.bin` reproduces 7-Zip's listed `CRC = 52F52622` and all six
  fixture files matched the listing, so the oracle is anchored to 7-Zip's own checksums.
- `SmartZip.ahk`: `ExtractArchiveToTemp` keeps the extract process's exit code as its own,
  classifies the follow-up console `t` as stage `verify`, records it in `verifyExitCode` /
  `verifyOutput`, leaves `result.output` empty for the extract stage, and takes its status from
  `ExtractionVerdict`. The output proof runs only for an ambiguous code and only when
  `excludeArgs` and `codePage` are empty. `WriteDiagnostic`, the GUI text and the rotating log
  now label the source-test block (`verify (source test) exitCode=` / `output:`, plus
  `outputCheck=`), so an exit code can never be read next to another run's `Everything is Ok`.
- Red first, then green, per behaviour:
  - Oracle tests: 6 labels in `Sfxv.Integration.Tests.ps1`. Teeth proven by mutation -
    forcing `verified := true` failed exactly `oracle_rejects_damaged_output`,
    `oracle_rejects_missing_output` and `oracle_rejects_unexpected_output` (4 failures
    including the aggregate), then the mutation was reverted (`grep -c MUTATION` = 0).
  - Verdict tests: 8 labels. With a stub reproducing today's behaviour (everything ambiguous
    becomes `UNKNOWN_ERROR`) the run gave `total=99 passed=92 failed=7`, failing precisely the
    six contracts that behaviour violates while `verdict_unverified_never_promoted` and
    `verdict_exit_one_stays_unknown` already passed. After the real implementation: 99/99.
  - Damage-detection proof that the source test cannot substitute for output evidence:
    corrupting one written byte while the archive stays intact yields `mismatched=1` and no
    promotion; a missing item yields `missing=1`; an extra renamed file yields `unexpected=1`.
- Full gate, 12 suites, each asserting total/passed/failed/skipped/pending against the expected
  count: 184, 193, 15, 98, 39, 30, 53, 36, 1, 1, 99, 10 → **759 passed / 0 failed / 0 skipped
  / 0 pending**, `SUM_EXPECTED=759`, script exit 0. `git diff --check` exit 0.
- Production build in `%TEMP%\smartzip-prod-build-20260920-124426` (only `SmartZip.ahk`,
  `lib\ArchiveDiagnostics.ahk`, `ico.ico`; no `tests` directory), with staged-source
  byte-equality, zero hook references and exactly one ArchiveDiagnostics include asserted
  before compiling. Ahk2Exe exit 0, artifact 1440768 bytes,
  SHA-256 `529E5F10B2551BDB0791023C3DA114C5B31D198B9EAFDA9E6FB6EE0513F600C3`, and a byte scan
  of the EXE found no `IntegrationTestHook`. Not deployed.
- Hook-free production smoke on that exact artifact: `Passed=True`, `LeakedProcessCount=0`,
  `RedactionOk=True`, and all four scenarios passed - `valid`, `crcPartial` (exactly one
  isolated partial directory), `splitMissing`, `encryptedHeader` - with no timeouts. So the
  new verdict path did not disturb the quarantine or redaction behaviour.
- Two self-inflicted regressions were caught by the existing gate and are worth recording,
  because both were invisible to the SFXV suite: an unbraced `if (check != "")` after a
  line-continuation rewrite threw on every clean extraction (surfacing as 8
  `crcPartial ... timed out after 120s` failures plus a stalled SFXV run), and a bare
  `name (args)` in AHK v2 is a method call, not concatenation. Fixed with an explicit block
  and `.` concatenation. `SmartZip.Static`'s exit-1 matcher was aligned to its new home in
  `ExtractionVerdict` and now also asserts the promotion ceiling, so the safeguard is pinned
  rather than dropped.
- Not finished, stated plainly: automated coverage of the real 7zG branch. A temporary
  `tests/ExtractGui.Tests.ps1` drove the **clean** scenario through real 7zG end to end
  (`exit 0`, status `OK`, per-file provenance labels green), but the **warned** dialog could
  not be dismissed reliably from an external watcher or from an in-process `SetTimer`, so the
  file was deleted instead of being left as a timing-out suite. Mid-run cancel likewise stays
  manual-only evidence (interrupted at 3.2 % of a 1.34 GB job, `exit 2`). `hideRunSize`
  both-sides equivalence is asserted nowhere executable today; the rule is size-independent by
  construction, but that is reasoning, not a test.
- Residual limits of this fix: CRC-32 is the strength 7-Zip itself verifies with, not a
  cryptographic guarantee; a cancellation that lands after the final byte is written will
  verify complete and report `OK_WITH_WARNING`, which is the same outcome as closing a finished
  dialog; and the oracle is deliberately unavailable when `excludeArgs`/`codePage` are set, so
  those configurations keep the old conservative failure.

## Investigation — SFXV “extra data” reported as UNKNOWN_ERROR (2026-09-20, no code changed)

- Scope of this turn: reproduce and diagnose only. No production code edited, no build, no
  deploy, no staging, no commit/push. Installed `SmartZip.exe` is still
  `7D933A46B706D088026A18DD0084EC967F62E29FB3BC60DA479B9285D9CAC413` and the INI is untouched.
- User facts: extraction had finished and the “有额外数据” window was closed by hand; it was
  not a mid-run cancel. Redacted diagnostic: `status=UNKNOWN_ERROR stage=extract exitCode=2`
  with output that belongs to a `Testing archive: archive.7z` run, `Tail Size=1529`,
  `Method=Copy 7zAES`, `Everything is Ok`, `Archives with Warnings: 1`.
- Fixture (self-built, TEMP only, never the user's archive): 6 files across nested dirs,
  `-mx=0 -mhe=on` (Copy + 7zAES), split as `game.exe` + `game.NNN.sfxv`, then merged the way
  `SfxvInput` merges (128-byte stub stripped) so the result is the real 7z stream plus
  **1529 trailing bytes**. Physical Size 4129185, tail delta verified exactly 1529.
- Measured on 7-Zip 26.02 ZS:

  | archive | `7z.exe x` (console) | `7zG.exe x` (GUI) | files written | SHA-256 matched |
  |---|---|---|---|---|
  | clean, no tail | exit 0 | exit 0, exits by itself, no lingering dialog | 6/6 | 6/6 |
  | +1529 tail | exit 0 + warning text | **exit 2** | 6/6 | **6/6 (complete)** |
  | 1 byte flipped | exit 2 + `CRC Failed in encrypted file` | **exit 2** | 6 | **5/6 (real damage)** |

- The dismissal mechanism is irrelevant: clicking the Close button (`BM_CLICK` id=2),
  `WM_COMMAND`, `WM_CLOSE`, `WM_SYSCOMMAND SC_CLOSE`, Esc and Enter all returned **exit 2**
  with 6/6 files intact. So “closing the warning window causes 2” is the wrong framing: 7zG's
  completion code for a warned run *is* 2; the dialog only controls when the process exits.
- Why it reaches the classifier at all: `Run7z`'s first parameter selects the binary
  (`is7z ? 7z.exe : 7zG.exe`, SmartZip.ahk:1156) and `ExtractArchiveToTemp` passes `hideBool`
  (= `FileGetSize(path)/1024/1024 < hideRunSize`, :1636). A 10.16 GB archive therefore extracts
  through **7zG**, while small archives — every fixture in the suite — go through console
  `7z.exe`, where the same warning yields exit 0. The defect is size-dependent by construction,
  which is why 744 green tests cannot see it. `tests/Sfxv.Integration.Tests.ps1`'s
  `Host.Run7z` always uses console 7z.exe, so it models only the small-archive branch.
- Classification measured against a hash-verified copy of the real library
  (`Classify7zResult`, inputs = the console text above):

  | exit | with the `t` text attached | with the GUI's own (empty) text |
  |---|---|---|
  | 0 | OK_WITH_WARNING, mayDeleteSource=0 | **OK, isCleanSuccess=1, mayDeleteSource=1** |
  | 1 | OK_WITH_WARNING | UNKNOWN_ERROR |
  | 2 | **UNKNOWN_ERROR** (matches the report) | UNKNOWN_ERROR |
  | 255 | CANCELLED | CANCELLED |

  The ladder only grants warning-success at exit 0 and exit 1, so 7zG's 2 falls through to
  `UNKNOWN_ERROR`. Consequence read from source: not OK/OK_WITH_WARNING →
  `FinalizeExtraction` (:1719) quarantines the complete output into
  `<name>_解压不完整_<stamp>` and writes the diagnostic; `mayDeleteSource=false`, so the source
  survives. The user-visible damage is a false failure plus a wrongly-labelled folder, not
  data loss.
- Reporting defect confirmed (Codex's read is right): `ExtractArchiveToTemp` stores the GUI
  code in `extractExit` (:1642) and then classifies with `cap.output` from a *different*
  console `7z t` process (:1651-1652, :1681), so a stage=extract/exitCode=2 result carries
  “Testing archive … Everything is Ok”. Static text of another process also feeds the
  hard-error detail paths, so an extract can be labelled from a run that never extracted.
- **Trap for whoever fixes it**: simply “stop attaching the `t` output” is unsafe. The exit-0
  row above shows an empty extract text turns a warned-but-complete run into `OK` with
  `mayDeleteSource=1`, i.e. it would newly allow source recycling. The extract stage needs a
  real verdict source, not merely less text.
- Not proven (deliberately not assumed): the genuine mid-run 7zG cancel code. Pausing the job
  ~100 ms into a 1.34 GB run did not stop it (the write completed), so no true mid-run abort
  was observed; whether `exitCode=255 → CANCELLED` (:1645) is reachable through 7zG at all is
  still unknown. Also untested: other 7zG warning classes, and whether the user's real tail is
  the same kind of trailing data (its `Tail Size=1529` matches the synthetic case).
- Suggested minimal fix, in priority order (not applied this turn):
  1. Give the extract stage its own oracle: for the GUI branch treat exit 2 as *indeterminate*
     and resolve it from (a) the post-extract console `t` **and** (b) an output-side inventory —
     every non-directory entry from `7z l -slt` present with matching size (hash small outputs
     only). All-present + clean-or-warning `t` → `OK_WITH_WARNING`; anything else →
     `DATA_CORRUPT`/partial. Never promote from `t` text alone, and never blanket-map 2→success
     (the corrupt row proves 2 also means real damage).
  2. Keep per-process provenance in the result (`extractText` vs `verifyText`) and have
     `WriteDiagnostic` label which process each block came from.
  3. Product decision for the user, not an agent's: `hideRunSize` silently switches both the
     UI *and* the exit-code contract. Either normalise on console `7z.exe x` with SmartZip's own
     progress window, or record in DECISIONS that the GUI branch's codes differ.
  4. Preserve `isCleanSuccess=false` / `mayDeleteSource=false` for every indeterminate outcome.
- Regression tests to add with such a fix: `Classify7zResult` cases for (2, warning-only) and
  (2, empty); a provenance assertion that an extract result cannot carry `t` text; a
  `Host.Run7z` that mirrors production's binary choice so the GUI branch is finally exercised;
  a trailing-data fixture crossing the `hideRunSize` boundary and expecting the *same* status on
  both sides; and file count + hash checks instead of trusting `t` for completeness.
- Evidence lives in `%TEMP%\szx-taildiag-20260920-030128` (`dismiss-*.log`, `controls-*.log`,
  `cancel-*.log`, `midrun-*.log`, `classify.txt`, `console-text-*.txt`). The multi-gigabyte
  fixtures and this session's 7zG test windows were removed afterwards.
- Harness note for the GUI test above: dismiss 7zG's dialog with **PostMessage**, not
  `SendMessageW(BM_CLICK)`. The synchronous send blocks the caller indefinitely on that dialog
  and hung two of my runs; a finished 7zG job also never exits on its own, so any test needs an
  explicit dismissal step plus a bounded wait, and must own only its own PIDs.

## Full regression, production build and local deployment — 2026-09-20

- User authorization for this turn replaced the earlier no-deploy limit: run the complete
  gate, build the production artifact in an isolated TEMP tree, run the hook-free production
  smoke, and only then update `C:\Tool\SmartZip\SmartZip.exe`. All five stages passed, so the
  install was updated. No new features, no source-archive changes, no user password read, no
  user archive EXE executed, no staging added, no commit, no push.
- Stage A — full gate, 12 suites, each asserting total/passed/failed/skipped/pending against
  the expected count: 184, 193, 15, 98, 39, 30, 53, 36, 1, 1, 84, 10 → **744 passed /
  0 failed / 0 skipped / 0 pending**, script exit 0.
- Stage B — production compile in `%TEMP%\smartzip-prod-build-20260920-023700` holding only
  `SmartZip.ahk`, `lib\ArchiveDiagnostics.ahk` and `ico.ico` (no `tests` directory).
  Pre-compile assertions: staged source byte-equal to repository `SmartZip.ahk`, zero
  `IntegrationTestHook` references, zero `#Include *i tests` injections, exactly one
  `#Include lib\ArchiveDiagnostics.ahk`. `Ahk2Exe /in ... /out ... /base AutoHotkey64.exe
  /silent` exit 0, output present. Built artifact 1436160 bytes,
  SHA-256 `7D933A46B706D088026A18DD0084EC967F62E29FB3BC60DA479B9285D9CAC413`; a byte scan of
  the compiled EXE found no `IntegrationTestHook` string. A prior run of the same source at
  `023542` produced the identical hash, so the compile is reproducible for this tree.
- Stage C — hook-free production smoke of that exact built file. The first attempt failed in
  my own wiring, not in the product: I piped the fixture generator's returned object through
  `Out-String` into the manifest path, which is formatted text rather than JSON, so
  `ConvertFrom-Json` rejected it. Corrected to use the generator's own `ManifestPath`; the
  suite then reported `Passed=True`, `LeakedProcessCount=0`, `RedactionOk=True` with all four
  scenarios passing (`valid`, `crcPartial`, `splitMissing`, `encryptedHeader`); `crcPartial`
  produced exactly one isolated partial directory, the others produced none, no scenario
  timed out, and the process-only fixture password appeared in neither manifest nor report.
- Stage D — deployment. Before any write: no `SmartZip`/`Contextmenu`/7z process was running
  and an exclusive open of the target succeeded, so nothing was interrupted or killed.
  Previous installed bytes `06F7966340274672777239281B8B8EA7BE5F103BB99CC7B2A5432282DFF616A7`
  (1435648 bytes, written 2026-09-17 15:08:51) matched the record. Backup created first and
  hash-verified before the install: `C:\Tool\SmartZip\SmartZip.exe.bak-sfxv-reliability-20260920-023829`
  (unique name asserted absent beforehand; its `LastWriteTime` still reads 2026-09-17 because
  the copy preserves it, `CreationTime` is 2026-09-20 02:38:29). `SmartZip.ini` SHA-256
  `DDCC1A739F63700699E040095ECE3CEE39F3B4DCC9C5B18C67EE4824E7EE96A4`, mtime 2026-09-16
  14:49:40, identical before and after. Only `SmartZip.exe` was replaced; installed SHA-256 now
  equals the smoke-tested build hash, and the install-directory listing confirms it was the
  only file with a fresh write time.
- Stage E — the deployed bytes were copied to TEMP (the smoke driver deliberately refuses any
  path under `C:\Tool\SmartZip`) and the same four-scenario hook-free smoke passed again on
  that copy: `Passed=True`, `LeakedProcessCount=0`, `RedactionOk=True`, 4/4 scenarios, with the
  installed EXE and INI re-hashed afterwards and unchanged. Rollback logic was armed but not
  needed.
- Restore method if ever required: exit the running SmartZip tray process first, then
  `Copy-Item 'C:\Tool\SmartZip\SmartZip.exe.bak-sfxv-reliability-20260920-023829' 'C:\Tool\SmartZip\SmartZip.exe' -Force`
  and confirm the result hashes to `06F7966…16A7`. The INI was never part of either artifact.
- Cleanup: the gate rewrites `tests/RunCmdCapture.Fragment.ahk` (tracked) and regenerates
  `tests/PasswordPreflight.Fragment.ahk` (untracked); both were confirmed clean at task start
  and were restored from the committed blob and removed again. Final `git status --short` is
  11 modified + 3 untracked, `git diff --cached` is empty (staging state preserved as found),
  `git diff --check` exits 0. Both compiled sources predate the 02:37 build:
  `SmartZip.ahk` 2026-09-17 15:01:18, `lib/ArchiveDiagnostics.ahk` 2026-09-19 09:12:58.
- Still not measured: no large-archive benchmark ran, so there is still no speed figure for
  this build. Deployment is verified by contract tests plus the four hook-free scenarios, not
  by timing.

## Qoder implementation — 2026-09-19 (SFXV reliability follow-up)

- Sole editor: Qoder, per the user's authorization of all three planned items and
  of this worktree (Codex stopped editing). Plan:
  `docs/superpowers/plans/2026-09-19-sfxv-reliability-followup.md`. Red was run
  before green for every item. Nothing was committed, pushed or deployed, and the
  eight pre-existing dirty files were preserved.
- Two blocking defects had to be fixed before any red/green evidence was possible,
  both in the harness rather than in extraction behaviour:
  1. `tests/Sfxv.Integration.Tests.ps1` was the only non-ASCII `.ps1` saved without
     a UTF-8 BOM, so Windows PowerShell 5.1 decoded it with the ANSI codepage and
     its own `'        ;解压嵌套'` slice anchor no longer matched. The suite
     therefore registered **1 test with 1 failure** (`Missing zipx pipeline`), not
     the 67 recorded in the handoff. Fixed by adding the BOM; `[IO.File]` byte
     comparison confirmed `payload-identical-except-BOM=True` (12148 to 12151 bytes).
  2. `Start-Process -PassThru` does not populate `ExitCode` in this environment, so
     `ExitCode | Should Be 0` compared against empty. Reproduced on an unrelated
     process: `cmd /c exit 7` gave `code=[]`, while `-Wait -PassThru` and
     `[Diagnostics.Process]::Start` both gave the true code. Three suites shared
     this dead crash gate: `Sfxv.Integration` (67/1 fail), `Sfxv.Tests` and
     `DirectoryScanOptimization` (each 1 fail). All three now use one
     `Invoke-AhkRunner` added to `tests/TestHelper.ps1`.
  - Baseline after both fixes, before any new assertion: 67 passed / 0 failed.
- Task 1 — harness results cannot be silently missing. Added
  `tests/SfxvResultHelper.ps1` (`Assert-SfxvResults`, `Get-SfxvResultMap`) and
  `tests/Sfxv.ResultContract.Tests.ps1` (10/10), covering the plan's six cases plus
  an empty expected set, a truncated line, a blank line and the status map. The
  integration suite now holds a hand-authored 76-label `$expectedLabels` set that is
  never derived from `results.txt`, registers per-label tests from that set, and
  registers the file-exists and label-completeness tests unconditionally.
  - Red evidence: with the old registration, commenting out one `Check` gave
    `TotalCount 66 / Passed 66 / Failed 0` — an assertion vanished while the suite
    stayed green. With the new registration the same mutation gives
    `TotalCount 69 / Failed 2`, naming `ordinary_formats_skip_sfxv_scan` twice.
  - A harness that cannot launch (broken `#Include`) gives `TotalCount 69 / Failed 67`
    and reports the real exit code `2`, instead of 6 tests and 1 failure.
  - `SMARTZIP_SFXV_PASSWORD` is restored through `try/finally` to the inherited
    value; verified with a preset sentinel (`after-suite=sentinel-original-value`).
    A timeout kills only the runner process the suite started.
- Task 2 — a failed preparation is reused inside its task. `SfxvInput` gained
  `taskActive`, set by `SfxvTaskScope` after construction and cleared before the
  previous owner is restored. `SfxvInputMatches` now requires the task to be active
  and requires `!closed` only of a successful input, so a terminal failure is reused
  while a cleaned success is not.
  - Red: 7 failures, including 2 leaked `__smartzip_sfxv_*` directories, i.e. the
    re-preparation really did redo full merges. Green at 76/76.
  - Failure is induced by holding an exclusive handle on a fixture volume and then
    releasing it, so a repeated preparation would succeed; no production hook.
- Task 3 — cleanup is separate from closing and can be retried. `Close()` sets
  `closed` first, deletes only the owned `archive.7z`, removes the directory with an
  explicit non-recursive `DirDelete(dir, false)`, then derives `cleanupComplete` from
  what still exists; a repeat call is skipped only once cleanup completed.
  `SfxvTaskScope.Close()` restores ownership before attempting cleanup at most three
  times with 50 ms in between, never re-merges, and reports a leftover through the
  existing `Loging`/`RedactDiagnostic` path inside a `try`.
  - Red: 4 failures (`cleanup_retry_done`, `empty_dir_removed_after_child_leaves`,
    the aggregate and the alias-directory scan showing 2 leftovers).
  - A `DirDelete(dir)` without the explicit flag was probed on this toolchain
    (AutoHotkey 2.0.26): it throws on a non-empty directory and left both the child
    file and the directory in place, so the unowned-file risk was latent, not live;
    the explicit `false` now pins the guarantee instead of relying on the default.
  - The single `scope_cleanup_bounded_retry` label failed once inside the full gate
    while passing standalone, so it was split into `scope_retry_attempted`
    (at least 80 ms of retries), `scope_retry_bounded` (under 3000 ms) and
    `scope_leftover_kept` (path retained, ownership released). Reducing `Loop 3` to
    `Loop 1` fails exactly `scope_retry_attempted`, which proves the retry count is
    really measured; the timing bounds are the only load-sensitive assertions added.
- Final verification, all commands run this turn:
  - Full gate with explicit `FailedCount`/`SkippedCount`/expected-count checks per
    suite: static 184, diagnostics 193, capture 15, password 98, lifecycle 39,
    nesting 30, UI 53, real integration 36, directory scan 1, Sfxv recognition 1,
    Sfxv integration 84, Sfxv result contract 10 — **744 passed / 0 failed / 0
    skipped**, script threw on the earlier failing run and exited 0 on this one.
  - The focused suite ran green three consecutive times at 84/84 while iterating.
  - `git diff --check`: exit 0 (only the pre-existing LF/CRLF working-copy warnings).
  - 7-Zip probe: `7-Zip 26.02 ZS v1.5.7 R1 (x64)`.
- Boundaries respected: no commit/push/deploy; `C:\Tool\SmartZip\SmartZip.exe` still
  hashes to `06F7966340274672777239281B8B8EA7BE5F103BB99CC7B2A5432282DFF616A7`
  (written 2026-09-17, matching the handoff) and `SmartZip.ini` is unchanged
  (2026-09-16); no archive EXE was executed and the user's sample and its password
  note were not opened; production still has no `IntegrationTestHook` reference and
  includes `lib\ArchiveDiagnostics.ahk` exactly once.
- Changed files: `lib/ArchiveDiagnostics.ahk`, `tests/Sfxv.Integration.Tests.ps1`,
  `tests/TestHelper.ps1`, `tests/Sfxv.Tests.ps1`,
  `tests/DirectoryScanOptimization.Tests.ps1`, `tests/README.md`,
  `docs/continuity/DECISIONS.md`, this file, plus new `tests/SfxvResultHelper.ps1`
  and `tests/Sfxv.ResultContract.Tests.ps1`.
- Cleanup: the gate regenerates `tests/RunCmdCapture.Fragment.ahk` (tracked, CRLF
  rewrite) and `tests/PasswordPreflight.Fragment.ahk` (untracked). Both were
  confirmed clean at task start and restored/removed after the last run; any future
  test run recreates them. The suites still leave their own
  `%TEMP%\SmartZip-SfxvIntegration-<guid>` roots behind; those were not swept, per
  the rule against recursively deleting other runs' temporary directories.
- Not done / remaining: no large-archive benchmark was run, so there is no measured
  speed figure — avoiding repeat merges is an I/O reduction, not a proven gain.
  Residual temporary files are still possible while another process holds the merge.
  Deferred candidates from the handoff stay untouched: validating more than the
  six-byte 7z signature, timing log rotation, progress/cancel during synchronous
  merge, and a repeatable performance benchmark.

## Qoder handoff preparation — 2026-09-19

- User requested further review, a plan/history handoff, and implementation by Qoder.
- Read `docs/continuity/QODER_HANDOFF.md` and
  `docs/superpowers/plans/2026-09-19-sfxv-reliability-followup.md` next.
- Scope: fail-closed test result validation, task-local failed preparation reuse,
  and bounded retryable cleanup. Existing extraction behavior must remain intact.
- Codex changed only handoff/planning documents this turn; existing eight dirty
  files were preserved. Qoder becomes sole editor after task delivery.
- Fresh baseline command: Invoke-Pester -Script './tests/Sfxv.Integration.Tests.ps1'
  -PassThru -Quiet | Select-Object TotalCount,PassedCount,FailedCount,SkippedCount.
  Exact result: TotalCount 67, PassedCount 67, FailedCount 0, SkippedCount 0; exit 0.
- Full suite/build/deployment were not rerun this turn. Prior results below are historical.
- Document verification: git diff --check exited 0 (LF/CRLF warnings only).
- The plan exists locally under docs/superpowers, which .gitignore excludes;
  preserve it for Qoder. No ignore rule or staging state was changed this turn.
- Next verification: Qoder follows the plan's red/green gates.
- Delivery status: documents prepared for dispatch; Qoder should record acceptance
  and implementation results here. No claim of delegated implementation completion.

## Current Task — SFXV task-scoped reuse

- Baseline: 0f75a63; worktree was clean before this authorized optimization.
- Completed: one owner per synchronous zipx task (including password retries).
  Probe/test/extract borrow its merged input. Nested pre-probe owns an outer
  scope so nested zipx can reuse it; different nested paths restore the previous
  owner. All normal, cancelled, and exceptional exits release task ownership.
- Ordinary RAR/numeric/ZIP names bypass SFXV sibling scanning. SFXV preparation
  checks available bytes before creating temporary output, catches header I/O
  errors, and verifies reads/writes and first-volume offsets during merging.
- Timing: task-level merge duration is recorded separately as prepare.
- Tests: Sfxv.Integration.Tests.ps1 initially failed three reuse assertions,
  later failed no-space/offset and preparation-timing regressions as expected.
  Latest focused run: 67 passed, 0 failed. Existing eight-suite gate passed
  648/648; DirectoryScanOptimization and Sfxv recognition each passed 1/1.
  Total: 717 passed, 0 failed. No large-user-archive benchmark was run.
- Changed files: SmartZip.ahk, lib/ArchiveDiagnostics.ahk,
  tests/Sfxv.Integration.Tests.ps1, tests/README.md, README.md, ini.md,
  docs/continuity/ACTIVE_TASK.md, docs/continuity/DECISIONS.md.
- Commands: Invoke-Pester -Script './tests/Sfxv.Integration.Tests.ps1'
  -PassThru -Quiet: 67/0; production-only TEMP compilation: exit 0.
- Gate command: foreach name in SmartZip.Static, ArchiveDiagnostics,
  RunCmdCapture, PasswordPreflight, ExtractionLifecycle, NestingMigration,
  DiagnosticUI, Real7Zip.Integration, DirectoryScanOptimization, Sfxv:
  Invoke-Pester -Script ('./tests/' + name + '.Tests.ps1') -PassThru -Quiet.
  Passed counts in order: 184, 193, 15, 98, 39, 30, 53, 36, 1, 1;
  failures all zero, command exit 0. git diff --check: exit 0.
- Generated RunCmdCapture fragment restored to its baseline; generated
  PasswordPreflight fragment removed. No user files were removed.
- Deployment: production-only TEMP build installed to C:\Tool\SmartZip\SmartZip.exe;
  SHA-256 06F7966340274672777239281B8B8EA7BE5F103BB99CC7B2A5432282DFF616A7
  matches the build. INI hash unchanged. Previous binary backed up to
  C:\Tool\SmartZip\SmartZip.exe.bak-sfxv-reuse-20260917-151230.
- Remaining: changes are uncommitted and not pushed. Implementation and local
  deployment complete; optional matched large-archive timing benchmark.
- Cancellation coverage is extraction cancellation; this change does not add
  a user-facing cancellation control during synchronous preparation.

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
- Deployment: final source compiled successfully with the staged AutoHotkey
  toolchain and installed as `C:\Tool\SmartZip\SmartZip.exe`. The deployed SHA-256 is
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
