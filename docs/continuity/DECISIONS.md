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
