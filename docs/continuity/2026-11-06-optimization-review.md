# Optimization review / 优化审查 — 2026-11-06

Follow-up status / 后续状态: user authorized implementation. All three items are
implemented; final validation and current evidence are recorded at the top of
`ACTIVE_TASK.md`. The findings below describe the pre-fix review. / 用户已授权实施，三项均已实现；最新验证见 ACTIVE_TASK 顶部，下文保留修复前的审查证据。

Scope / 范围: review and isolated experiments only. Production source, installed
application, user archives and configuration were not changed. Existing worktree
changes were preserved. / 本轮仅审查并运行隔离实验，未修改生产源码、安装版、用户归档或配置；保留原有未提交改动。

## 1. Filename false diagnostics / 文件名导致错误诊断

`lib/ArchiveDiagnostics.ahk:79,109,113` matches error phrases against every listing
line, including `Path = ...` values. Real, clean 7z archives containing one harmless
file reproduced the following results. Every `7z l -slt` invocation exited zero.

分类器把列表中的 `Path = ...` 文件名也交给错误关键词匹配。用真实正常归档复现如下；所有 7-Zip 列表命令退出码均为 0。

| File / 文件名 | Expected / 应为 | Actual probe classification / 实际分类 |
|---|---|---|
| `normal.txt` | `OK` | `OK` |
| `Wrong password.txt` | `OK` | `WRONG_PASSWORD` |
| `Headers Error.txt` | `OK` | `HEADER_CORRUPT` |
| `Data Error.txt` | `OK` | `DATA_CORRUPT` |
| `There are data after the end of archive.txt` | `OK` | `OK_WITH_WARNING` |

Header/data false failures can stop valid extraction. The password false positive
enters password resolution and may recover through a successful empty-password
test; it does not prove a password dialog always appears. The warning false positive
can produce an unnecessary warning and prevent clean-success source handling.

伪报包头/数据损坏可阻止正常解压；伪报密码错误会进入密码解析，空密码测试成功时可恢复，不能据此断言一定弹密码框。伪警告也会影响提示及仅限干净成功时执行的源文件处理。

Recommendation / 建议: add real-listing filename regression cases first, then keep
metadata values out of diagnostic phrase matching. Preserve actual diagnostics,
status priority, `Type` and `Encrypted = +` evidence. / 先增加真实列表回归，再区分列表元数据与诊断消息；保留真正的错误、状态优先级、类型及加密证据。

## 2. Pipe capture throughput / 管道捕获速度

`SmartZip.ahk:2236` requests the default pipe buffer. A temporary source-extracted
capture harness compared buffer sizes and polling timeouts. It did not edit the
production implementation. / 临时测试壳从源码提取捕获函数，对比管道缓冲和轮询等待时间，未改生产实现。

Real 7-Zip fixture / 真实 7-Zip 夹具: 4,096 zero-length files, 128 directories,
`7z l -slt -bso1 -bse1 -bsp0 -sccUTF-8 -p""`; 603,415 output characters. Three
interleaved rounds per condition, same command and archive; SHA-256 of every captured
output matched the direct-process output.

| Variant / 方案 | Capture median / 捕获中位耗时 | Median reads / 读取次数中位数 | Median waits / 等待次数中位数 |
|---|---:|---:|---:|
| Current default buffer, 15 ms wait / 当前默认 | 2,171 ms | 139 | 132 |
| 64 KiB pipe buffer, 15 ms wait | 203 ms | 19 | 11 |
| 1 MiB pipe buffer, 15 ms wait | 47 ms | 11 | 2 |
| Default buffer, 1 ms wait | 2,031 ms | 139 | 130 |
| Direct .NET process capture / 直接进程捕获 | 47 ms | — | — |

The independent ~2 MiB emitter experiment gave medians 2,625 / 422 / 203 / 2,609 ms
for those four AHK variants, with direct-process median 191 ms. The emitter ends in
one UTF-8 character emitted byte by byte. All 24 AHK captures across both experiments
had exact expected hashes. / 独立约 2 MiB 输出实验也得到相同方向，尾部中文字符逐字节写入；两组共 24 次捕获哈希均一致。

Recommendation / 建议: prioritize a bounded larger-pipe-buffer change over reducing
polling time or rewriting the classifier for speed. Check pipe creation failure and
run the complete integration/production smoke gate before shipping. These numbers
measure output capture, not complete extraction; no end-to-end speedup is claimed.

建议优先验证并实现较大的管道缓冲；同时覆盖创建失败，发布前跑完整集成及生产冒烟。上述数字仅代表输出捕获，不能作为整个解压流程的提速比例。

## 3. Test process isolation / 测试进程隔离

- `tests/RunCmdCapture.Tests.ps1:67` and `tests/PasswordPreflight.Tests.ps1:499`
  use unbounded `Start-Process -Wait`. A hung harness can block the serial gate.
  / 缺少超时，测试进程卡住会阻塞整套门禁。
- `tests/DiagnosticUI.Tests.ps1:784` accepts a nonzero process exit when an output
  file exists. / 只要输出文件存在，就可能放过非零退出码。
- Capture/preflight wrappers write shared fragment files in the checkout and use
  fixed TEMP stdout/stderr paths. Parallel runs can collide and ordinary runs dirty
  the tree. / 共享片段和固定日志路径可能互相覆盖，并污染工作区。

Recommendation / 建议: stage each harness, fragment and logs in one unique TEMP
directory; use a bounded process runner with independent exit-zero and result-file
checks. / 每次运行使用独立临时目录，统一限时启动器，分别检查退出码和结果完整性。

## 4. Documentation consistency / 文档一致性

`tests/README.md:54` still says 655/656 while the current eight-suite manifest sums
to 657 (658 with directory regression). Line 44's six-suite 596 is not the current
605. Full total 817 is arithmetically consistent. / 部分局部测试总数已过时；完整 817 总数仍一致。建议统一测试清单，历史结果明确标注日期。

## Verification and evidence / 验证与证据

- `Invoke-Pester -Script '.\tests\SmartZip.Static.Tests.ps1' -Quiet -PassThru`:
  192 passed, zero failed/skipped/pending.
- `Invoke-Pester -Script '.\tests\ArchiveDiagnostics.Tests.ps1' -Quiet -PassThru`:
  193 passed, zero failed/skipped/pending. Existing tests do not catch the filename bug.
- Existing capture behavioral harness staged in TEMP: original and 1 MiB variant
  each exited 0, 15 passed / 0 failed. Includes complete stdout/stderr, exit-code
  preservation, exit-255 mapping and split UTF-8; no interactive cancellation claim.
- This review did not rerun the complete 817-test gate, compile, production smoke
  or the user's large SFXV extraction. / 本轮未重跑完整门禁、编译、生产冒烟或用户大归档。

Reproducible temporary scripts / 可复现实验脚本:
`%TEMP%\SmartZip-review-20261106-0d3cf0ad0a954ca49ae63b8fa5580f6b` contains
`Measure-Capture.ps1`, `Check-FilenameClassification.ps1`, `Check-CaptureContracts.ps1`,
`results.csv` and `archive-results.csv`. Pass the repository path via `-Repo`;
the real-listing benchmark additionally uses `-ArchivePath` pointing to that root's
`listing-stress.7z`. No secrets are used. The first temporary wrapper had an AHK
class/variable name collision; it was corrected before collecting any benchmark
results and is excluded. / 实验使用无秘密的合成数据；初次临时壳命名冲突已修正，无效运行未计入结果。

Suggested order / 建议顺序: filename correctness → pipe-buffer optimization →
test isolation and strict process gates → documentation counts. / 文件名误报 → 管道提速 → 测试隔离及严格进程门禁 → 文档总数。
