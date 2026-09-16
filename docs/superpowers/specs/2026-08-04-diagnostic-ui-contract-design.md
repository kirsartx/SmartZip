# DiagnosticUI Test Contract Repair Design

## Goal

Repair the `DiagnosticUI` test-double/product-contract mismatch introduced by the smarter `NOT_ARCHIVE` diagnostic, while leaving production behavior unchanged.

## Context

`SmartZip.ahk` now distinguishes a `NOT_ARCHIVE` result by checking whether the archive path has a configured archive extension. The `DiagnosticUIHost` test double was created before that behavior and does not provide `IsArchive`, while its reason fixture uses `pack.7z`. The harness therefore aborts the reason case before returning the expected text.

The current worktree also contains an existing user-owned LF-only change in `tests/RunCmdCapture.Fragment.ahk`; this design does not modify or decide that change.

## Chosen approach

Use a contract-faithful test host and cover both extension branches:

1. Add `ext` and `extExp` state plus an `IsArchive(ext)` method to `DiagnosticUIHost`, matching the production method's case-folding and configured-extension semantics.
2. Make the reason command accept an optional `archivePath` in its JSON input so each test can select the branch it is exercising.
3. Keep the existing generic `NOT_ARCHIVE` expectation using a non-archive path such as `plain.txt`.
4. Add a focused known-extension `NOT_ARCHIVE` case using `pack.7z`, expecting the newer damaged/incomplete-header reason and recommendation.
5. Update the documented `DiagnosticUI` and overall assertion counts if the additional case changes the suite total.

This keeps the production contract authoritative, makes the harness dependency explicit, and prevents either branch from becoming untested.

## Scope and interfaces

### Test host

`DiagnosticUIHost` will expose:

```ahk
ext := Map("7z", true, "zip", true, "rar", true)
extExp := []
IsArchive(ext) {
    ext := StrLower(ext)
    if !ext
        return false
    if this.ext.Has(ext)
        return true
    for i in this.extExp
        if ext ~= "i)" i
            return true
    return false
}
```

The concrete map values are only membership markers; the method must preserve the product's extension normalization and expression-list behavior.

### Reason command

`RunDiagnosticUICommand("reason", ...)` will read an optional `archivePath`, defaulting to a generic non-archive fixture for the table-driven mappings. The dedicated known-extension case will pass a `.7z` path explicitly.

### Test contract

- Generic `NOT_ARCHIVE`: `文件不是可识别的压缩包。` and `请确认文件类型或使用 7-Zip 打开检查。`
- Known archive extension: `压缩包文件头可能已损坏或不完整。` and `请重新下载或复制完整源文件，或用 7-Zip 打开检查。`

No production method, status enum, or user-facing string outside the already-established product behavior will change.

## Verification

1. Download the approved official AutoHotkey v2 portable toolchain to `%TEMP%\ahk_tools\ahk-v2` only if it is not already present.
2. Add the failing known-extension test first and run the focused `DiagnosticUI` suite to confirm the expected pre-fix failure.
3. Add the minimal host seam and path plumbing; rerun `DiagnosticUI.Tests.ps1` and confirm all cases pass.
4. Run `git diff --check`.
5. Run the exact eight-suite Pester gate from `tests/README.md`, followed by the documented 7-Zip probe.

## Non-goals

- No changes to `SmartZip.ahk`.
- No cleanup or reversal of `tests/RunCmdCapture.Fragment.ahk`.
- No system-wide AutoHotkey installation.
- No unrelated refactoring of the diagnostic harness.
