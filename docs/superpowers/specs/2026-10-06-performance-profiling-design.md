# SmartZip extraction smoothness and profiling design

Date: 2026-10-06
Status: approved design; implementation not started

## Goal

Improve perceived and measured extraction performance without changing archive
classification, extracted bytes, output placement, source-retention rules, password
handling, or existing settings. Measure first and optimize only a demonstrated
SmartZip-side hotspot. Do not promise a speedup when 7-Zip or storage dominates.

## Current evidence and gap

SmartZip already has an opt-in `timingLog` setting, disabled by default. With it
enabled, the application records fixed operation labels for `prepare`, `probe`,
`test`, and `extract`; SFXV preparation is recorded separately from operations that
borrow the same merged archive. Timing lines contain only an operation label and
elapsed milliseconds.

The current `extract` duration combines the 7-Zip extraction, the follow-up source
test, and (for ambiguous results) output verification. Output post-processing and
file placement are not separately timed. Consequently existing logs cannot tell
whether a long extraction task is spent in 7-Zip, SmartZip's integrity check, or
post-extraction filesystem work. No matched before/after large-archive benchmark is
documented, so the next optimization target is not yet evidenced.

## Proposed change

Keep the existing aggregate operation timings and their labels for compatibility.
When `timingLog` is enabled, add nested fixed-label timings for:

- `7z_extract`: time spent waiting for the selected 7-Zip extraction process;
- `source_test`: follow-up `7z t` used to classify the source archive;
- `output_verify`: output-side listing and integrity verification when invoked;
- `postprocess`: SmartZip's extracted-file enumeration, configured per-file
  processing, and final placement after a usable extraction result.

Each substage line uses the existing format `operation duration_ms=<integer>`.
Aggregate `extract` remains available and continues to include its existing whole
operation boundary. Timing stays opt-in and records no paths, archive names, file
names, password material, or command output. Normal runs with timing disabled do
not incur file writes or additional full-directory traversals solely for profiling.

## Measurement and optimization loop

1. Run the current test gate and capture a baseline on a fixed fixture; where safe
   and practical, also measure a representative large archive in an isolated output
   directory. Never execute an executable embedded in an archive. Keep archive,
   destination volume, SmartZip build, 7-Zip build, and settings constant across
   compared runs; record whether each run was warm or cold rather than trying to
   flush the operating-system file cache.
2. Repeat at least three times and compare per-stage and total medians. Use the
   profile to determine whether SmartZip-controlled filesystem work is material or
   whether 7-Zip/storage dominates.
3. If a SmartZip stage is materially expensive, propose the smallest targeted
   implementation change. A likely candidate is redundant recursive enumeration
   during output post-processing, but change it only if measurements support it and
   preserve `AfterUnzip` mutation semantics and nesting behavior. If evidence points
   elsewhere, revise the implementation proposal before touching that path.
4. Re-run the same workload and compare medians and output evidence. Keep the change
   only if it improves the identified stage without a meaningful whole-task
   regression; otherwise revert the optimization and report that the measured
   bottleneck is external or not safely reducible in scope.

## Compatibility and safety requirements

- Existing `timingLog=0` behavior remains the default; the UI/settings contract and
  extraction result/status contract do not change.
- Existing aggregate labels (`prepare`, `probe`, `test`, `extract`) remain present.
- New timing labels contain only fixed names and durations, matching the existing
  privacy boundary.
- Preserve output ordering/placement behavior, rename/delete rules, nested archive
  handling, volume preservation, source deletion eligibility, and failure isolation.
- Do not add asynchronous extraction or redesign GUI lifecycle in this work; that
  is a separate, higher-risk product change.
- A timing improvement alone cannot relax the output integrity verifier or promote
  an ambiguous extraction result.

## Verification

- Add or update focused tests to prove old aggregate timings remain, new substage
  labels are emitted only when enabled, and timing output contains no user data.
- Run the full regression gate from `tests/README.md` (currently 805 assertions),
  including real 7-Zip GUI/console exit-contract tests.
- For any filesystem optimization, compare file listing and per-file hashes (or the
  existing output verifier) before and after, and exercise configured post-processing,
  nested archives, and split-volume cases.
- Report measured before/after stage and total medians with workload and cache-state
  notes. If the baseline shows no material in-scope hotspot, make no speculative
  production optimization.

## Scope boundary

This work targets evidence-led reduction of SmartZip's own avoidable overhead and
better attribution of time spent; it does not change 7-Zip algorithms, compression
settings, disk behavior, or the UI into an asynchronous worker model.
