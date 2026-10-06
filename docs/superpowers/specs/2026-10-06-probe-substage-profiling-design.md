# Probe Substage Profiling Design / Probe 子阶段性能计时设计

Date / 日期: 2026-10-06
Status / 状态: Measurement direction approved; written design awaiting user review / 测量方向已认可；书面设计待用户审阅

## Goal / 目标

Identify which SmartZip-side work dominates the `probe` duration—pipe capture,
classification, or a fallback test—without changing archive decisions,
7-Zip arguments, extraction results, or user-visible behavior. Use the evidence
to decide whether a later classifier optimization is justified.

在不改变归档判断、7-Zip 参数、解压结果或用户可见行为的前提下，确定 `probe` 耗时主要来自 SmartZip 的哪一段：管道捕获、结果分类，还是备用测试。依据测量结果再判断后续是否值得优化分类器。

## Evidence / 测量依据

On the controlled 13,367-zero-byte-file / 689-directory archive, three SmartZip
runs measured `probe` at 5,235 / 5,500 / 4,203 ms (median 5,235 ms). Running the
same archive's `7z l -slt` command directly took 64 / 52 / 53 ms and returned
2,031,082 characters each time. This strongly suggests the delay lies in
SmartZip's capture/classification path, but does not yet distinguish those two
costs. `Classify7zResult` currently splits all output lines and runs multiple
string/regex checks per line, making it a concrete profiling target, not yet a
proven cause.

在包含 13,367 个零字节文件和 689 个目录的受控归档上，SmartZip 三次 `probe` 耗时为 5,235 / 5,500 / 4,203 ms（中位数 5,235 ms）。直接运行同一归档的 `7z l -slt` 命令耗时为 64 / 52 / 53 ms，每次返回 2,031,082 个字符。这强烈暗示耗时在 SmartZip 的输出捕获/分类路径，但目前还不能区分两者。`Classify7zResult` 当前会拆分全部输出行，并对每行执行多项字符串/正则检查，因此它是明确的测量对象，但尚未证明就是根因。

## Proposed instrumentation / 建议计时

- Keep the existing aggregate `probe duration_ms` unchanged.
- Add fixed-label opt-in timings for the initial list-process capture and its
  `Classify7zResult` call, using labels `probe_list_capture` and
  `probe_list_classify`.
- When the existing known-extension fallback `7z t` runs, record its capture
  and classification together as `probe_fallback_test`; omit this line when the
  fallback is not executed.
- Keep all new timings behind the existing `timingLog` setting. Emit only the
  fixed operation label and integer elapsed milliseconds—no path, filename,
  command, archive contents, or password.
- Preserve the current command strings, call order, result object, status
  priority, fallback conditions, and the aggregate `probe` timing boundary.

- 保持现有汇总计时 `probe duration_ms` 不变。
- 为初始列表进程的输出捕获及其 `Classify7zResult` 调用分别增加固定标签的可选计时：`probe_list_capture` 和 `probe_list_classify`。
- 当现有的已知扩展名备用 `7z t` 分支运行时，以 `probe_fallback_test` 记录该进程的捕获与分类总耗时；未执行备用分支时不写此行。
- 所有新增计时都受现有 `timingLog` 设置控制。日志仅包含固定操作标签和整数毫秒，不含路径、文件名、命令、归档内容或密码。
- 保持当前命令字符串、调用顺序、结果对象、状态优先级、备用分支条件以及汇总 `probe` 的计时边界不变。

## Alternatives / 备选方案

1. **Instrument the `ProbeArchive` sub-stages (recommended):** directly separates
   the measured SmartZip work while retaining the current behavior and aggregate
   metric.
2. **Instrument `RunCmdCapture` globally:** could reveal capture cost across the
   application, but mixes probe with unrelated tests and commands and expands
   scope beyond the measured hotspot.
3. **Change `7z l` output or optimize classification immediately:** may reduce
   work, but the current measurements do not prove which stage is dominant;
   changing output parsing risks encryption, warning, and error classification.

1. **为 `ProbeArchive` 子阶段计时（推荐）：** 直接拆分已测得的 SmartZip 耗时，同时保留现有行为和汇总指标。
2. **全局为 `RunCmdCapture` 计时：** 可以了解全应用的捕获耗时，但会混入 probe 之外的测试和命令，使范围超出已测热点。
3. **立即修改 `7z l` 输出或优化分类器：** 可能减少开销，但现有测量尚未证明哪一阶段占主导；改变输出解析可能影响加密、警告和错误分类。

## Validation / 验证

- Add static tests for the two initial-list timing boundaries, conditional
  fallback timing, preservation of the aggregate boundary, and the logging-off
  contract. Keep assertions on fixed labels and absence of path/content data.
- Run the focused static and SFXV timing suites, then the documented complete
  serial test gate with exact suite counts.
- Build a hook-free production executable and run the four production smoke
  scenarios. Confirm there are no leaked processes and redaction still passes.
- Repeat the same controlled archive three times. Verify the file/directory
  counts and output inventory remain identical, then report the substage timing
  distributions and the original aggregate `probe` distribution.
- Do not change `Classify7zResult`, the 7-Zip command, or archive outcomes in
  this profiling-only change. Any subsequent behavior optimization gets its
  own design and approval.

- 为两个初始列表计时边界、条件性备用计时、汇总边界保留和关闭日志时不输出的约定添加静态测试。断言只检查固定标签，并确认不泄露路径或内容信息。
- 运行静态测试和 SFXV 计时测试，再运行文档规定的完整串行测试门禁，并核对每个套件的精确数量。
- 编译不含测试钩子的生产版本并运行四个生产冒烟场景；确认没有遗留进程且脱敏检查通过。
- 对同一受控归档重复运行三次，验证文件/目录数和输出清单一致，再报告各子阶段及原有汇总 `probe` 的耗时分布。
- 本次仅增加计时，不修改 `Classify7zResult`、7-Zip 命令或归档判断结果。之后如需改变行为，另行设计并取得确认。

## Boundaries / 范围边界

- This change is profiling-only; no speedup is claimed from adding timers.
- Timing remains opt-in and uses fixed labels only.
- Existing uncommitted extraction-performance work must be preserved and kept
  out of the design-only commit.

- 本次只增加性能计时；不能把计时本身宣称为速度提升。
- 计时默认关闭，且只写固定标签。
- 必须保留现有未提交的解压性能改动，并确保它们不进入本次纯文档提交。
