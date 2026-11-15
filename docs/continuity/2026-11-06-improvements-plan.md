# SmartZip sequential improvements / 逐项改进实施计划

> **For agentic workers:** Use superpowers:executing-plans, task by task, with TDD and verification checkpoints. User approved the reviewed recommendations in order; routine choices proceed without further confirmation. Only the main agent edits this existing worktree.

**Goal / 目标:** Fix filename false diagnostics, improve capture throughput, then isolate and bound test processes. / 修复文件名误报、提高捕获吞吐，再处理测试进程隔离与超时。

**Architecture / 设计:** Classify technical `Key = Value` records as data while retaining `Type`, probe encryption and reserved Error/Warning diagnostic properties; actual diagnostic lines still use the existing status ladder. Request a 1 MiB capture pipe with a default-size retry on allocation failure, preserving byte collection, decoding and polling. Stage legacy harnesses and generated fragments per run under TEMP and share a bounded, strict result runner. / 技术字段按数据处理，保留 Error/Warning 诊断字段；管道请求 1 MiB，失败时回退默认；测试每次独立临时目录，并严格检查退出码与结果。

**Tech stack:** AutoHotkey v2; Windows PowerShell 5.1+; Pester 3.4; real 7-Zip Zstandard.

## Global constraints / 全局约束

- Preserve existing user changes, archive commands, source handling, final integrity checks and password recovery. / 保留既有改动、命令、源文件处理、最终校验和密码恢复。
- Keep the installed app and INI unchanged; no commit/push/deployment. / 不改安装版及 INI；不提交、推送或部署。
- Use synthetic fixtures; no secrets or raw user logs in project files. / 使用合成夹具，不记录秘密或用户原始日志。

## Task 1: Metadata classification / 元数据分类

Files: `lib/ArchiveDiagnostics.ahk`, `tests/ArchiveDiagnostics.Tests.ps1`.

- [x] Add filename/metadata tests plus genuine errors and encryption evidence. Add real `7z l/t` coverage using `Headers Error.7z` containing `Data Error.txt`.
- [x] Run `Invoke-Pester -Script '.\tests\ArchiveDiagnostics.Tests.ps1' -Quiet -PassThru`; confirm new false-positive cases fail.
- [x] After existing `Type` parsing, recognize `^[A-Za-z][A-Za-z0-9 ]* = ` records. For probe `Encrypted = +`, retain NEED_PASSWORD/encryptionEvidence, then skip diagnostic phrase matching for the record.
- [x] Rerun focused diagnostics and real fixture reproduction; true diagnostics after records must still win.

## Task 2: Pipe throughput / 管道吞吐

Files: `SmartZip.ahk`, `tests/RunCmdCapture.Harness.ahk`, `tests/RunCmdCapture.Tests.ps1`.

- [x] Add large-output exactness and bounded pipe-read-count regression using a fast deterministic child emitter, together with existing split UTF-8 and exit-code checks.
- [x] Run the focused capture suite; confirm current pipe buffer fails the targeted throughput contract without a timing-only assertion.
- [x] Request `1024 * 1024` bytes in `CreatePipe`; if it fails retry size 0, and return exit -1 when both fail. Keep the existing read buffer/decoder and 15 ms polling.
- [x] Run capture regressions and repeat the three-round real 7z listing benchmark from the review. Verify exact output hashes.

## Task 3: Test infrastructure / 测试基础设施

Files: `tests/TestHelper.ps1`, legacy capture/preflight/diagnostic/UI wrappers, new `tests/TestInfrastructure.Tests.ps1`, `tests/README.md`.

- [x] Add executable process tests: exit 7 remains 7; strict case rejects exit 7 even if output exists; missing results fail; a sleeping child times out within a bound; staging gives unique paths and preserves input fragments.
- [x] Introduce `New-AhkTestStage`, `Remove-AhkTestStage`, and `Invoke-AhkResultRunner` around `Invoke-AhkRunner`; allow `WorkingDirectory` and optional captured stdout/stderr without changing existing callers' integer exit result.
- [x] Stage capture/preflight harness and generated fragment in unique TEMP roots, parse results before cleanup, and preserve repository fragments. Use bounded runner for UI/diagnostics and independently require exit 0 plus result presence.
- [x] Run infrastructure, capture, password, diagnostic and UI focused suites. Correct stale README counts using fresh actual totals.

## Final gate / 最终验证

- [x] Run all documented suites serially plus new infrastructure tests with exact passed/failed/skipped/pending checks.
- [x] Build hook-free production EXE in TEMP; run four production smoke scenarios and filename regression against production behavior where available.
- [x] Review final diff, `git diff --check`, and update ACTIVE_TASK/DECISIONS with exact results and remaining work.
