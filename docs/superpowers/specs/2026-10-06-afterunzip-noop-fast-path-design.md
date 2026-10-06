# AfterUnzip No-Op Fast Path Design

Date: 2026-10-06
Status: Candidate direction approved; written design awaiting user review

## Goal

Reduce extraction post-processing time for configurations that do not rename or
delete files, without changing extracted contents, directory cleanup, status
reporting, source retention, or any configured-rule behavior.

## Evidence

The opt-in profiling work measured a median `postprocess` duration of 1,219 ms
(about 7.5% of median wall time) across three matched runs on a controlled
13,367-zero-byte-file / 689-directory stress archive. Every run produced the
expected file and directory counts. This is a file-count stress proxy, not a
large-payload throughput claim. In the no-rule case, most per-file calls to
`AfterUnzip` perform no applicable work; directory calls still matter because
they remove empty folders.

## Proposed behavior

- Determine whether any file rename/delete rule is configured: `renameExt`,
  `renameName`, `renameExp`, and `deleteExp` must all be empty for the fast path.
- When all four are empty, do not call `AfterUnzip` for regular files. Continue
  calling it for directories, preserving existing empty-directory cleanup.
- When any rule is present, retain the existing traversal and call
  `AfterUnzip` for every entry, preserving current rule behavior and ordering.
- Keep the current timing boundary around the complete post-processing phase.
- Do not change extraction, verification, path construction, source deletion,
  nested extraction, UI, logging, or settings semantics.

## Design and compatibility constraints

The fast-path predicate must be computed once per extraction from the same
loaded rule data used by `AfterUnzip`, rather than repeatedly inspecting config
for each entry. Empty means no active entries, not merely a missing section or
an empty string in one rule family. A rule in any family disables the shortcut,
including rules that may match only directories. Directory entries continue
through the existing function even in the no-rule case.

The implementation should make the file-versus-directory decision from the
enumerator's existing entry attributes, without an additional filesystem
stat. It must preserve traversal order and the exact current branch for any
non-empty ruleset. If these conditions cannot be met cleanly with the existing
walk, stop and revise the design rather than broadening the optimization.

## Alternatives considered

1. **Skip no-op regular-file calls (recommended):** small localized change;
   retains the current rule engine and directory cleanup.
2. **Replace post-processing with a consolidated metadata traversal:** could
   remove more overhead, but increases mutation/order and compatibility risk;
   defer until profiling demonstrates a need.
3. **Stop after profiling:** zero behavior risk but leaves measured no-op work.

The user approved option 1 as the direction. This document still requires review
before implementation.

## Validation plan

Add regression tests before implementation, proving:

- With all rule families empty, regular files bypass `AfterUnzip` while
  directories still reach it.
- Empty directories are still removed, and non-empty directories remain.
- Each individual rule family disables the shortcut and continues to affect
  matching files and directories as before: extension rename, name rename,
  regex rename, and regex delete.
- Nested extraction and existing ordering/behavior remain unchanged.

Then run the documented full serial test gate (currently 813 assertions),
production smoke, and the same three-run count-stress benchmark. Compare exact
output tree contents and counts as well as post-process timing. A speedup is not
accepted if output behavior differs. Report timing distributions, not only the
best run. No production installation or publication is included in this scope.

## Risks and boundaries

- If directory classification is wrong, empty-folder cleanup can regress.
- If the predicate overlooks one rule family, configured mutations may be
  skipped; independent tests for all four families guard against this.
- The benchmark uses zero-byte files and does not establish throughput gains
  for large files or different storage devices.
- The existing profiling changes are currently uncommitted; they must remain
  separate from implementation review and must not be accidentally included in
  the design-document commit.
