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
