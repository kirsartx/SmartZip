# AfterUnzip No-Op Fast Path Design / AfterUnzip 无操作快速路径设计

Date / 日期: 2026-10-06
Status / 状态: Candidate direction approved; written design awaiting user review / 方向已获认可；书面设计待用户审阅

## Goal / 目标

Reduce extraction post-processing time for configurations that do not rename or
delete files, without changing extracted contents, directory cleanup, status
reporting, source retention, or any configured-rule behavior.

在未配置文件重命名或删除规则时，减少解压后的处理耗时；同时不改变解压内容、目录清理、状态报告、源文件保留行为或任何已配置规则的行为。

## Evidence / 测量依据

The opt-in profiling work measured a median `postprocess` duration of 1,219 ms
(about 7.5% of median wall time) across three matched runs on a controlled
13,367-zero-byte-file / 689-directory stress archive. Every run produced the
expected file and directory counts. This is a file-count stress proxy, not a
large-payload throughput claim. In the no-rule case, most per-file calls to
`AfterUnzip` perform no applicable work; directory calls still matter because
they remove empty folders.

通过可选性能计时，对一个受控压力包进行了三次匹配测试。该包包含 13,367 个零字节文件和 689 个目录，`postprocess` 中位耗时为 1,219 ms（约占总耗时中位数的 7.5%）。每次运行的文件数和目录数均符合预期。这只是针对文件数量的压力测试，不代表大体积数据的吞吐量。在无规则配置时，大多数针对单个文件的 `AfterUnzip` 调用没有实际工作；目录调用仍有意义，因为它负责删除空目录。

## Proposed behavior / 建议行为

- Determine whether any file rename/delete rule is configured: `renameExt`,
  `renameName`, `renameExp`, and `deleteExp` must all be empty for the fast path.
- When all four are empty, do not call `AfterUnzip` for regular files. Continue
  calling it for directories, preserving existing empty-directory cleanup.
- When any rule is present, retain the existing traversal and call
  `AfterUnzip` for every entry, preserving current rule behavior and ordering.
- Keep the current timing boundary around the complete post-processing phase.
- Do not change extraction, verification, path construction, source deletion,
  nested extraction, UI, logging, or settings semantics.

- 判断是否配置了任何文件重命名或删除规则：只有 `renameExt`、`renameName`、`renameExp` 和 `deleteExp` 全部为空时，才启用快速路径。
- 四类规则都为空时，普通文件不再调用 `AfterUnzip`；目录仍调用该函数，以保留现有的空目录清理行为。
- 只要存在任一规则，就沿用现有遍历方式，并对每个条目调用 `AfterUnzip`，保持当前规则行为及处理顺序。
- 保留覆盖整个后处理阶段的现有计时边界。
- 不改变解压、校验、路径构造、源文件删除、嵌套解压、界面、日志或设置语义。

## Design and compatibility constraints / 设计与兼容性约束

The fast-path predicate must be computed once per extraction from the same
loaded rule data used by `AfterUnzip`, rather than repeatedly inspecting config
for each entry. Empty means no active entries, not merely a missing section or
an empty string in one rule family. A rule in any family disables the shortcut,
including rules that may match only directories. Directory entries continue
through the existing function even in the no-rule case.

快速路径条件必须在每次解压时基于 `AfterUnzip` 使用的同一份已加载规则数据计算一次，而不是为每个条目重复读取配置。“为空”表示没有生效的规则项，不只是配置节缺失或某一类规则的字符串为空。任何一类规则存在时都必须禁用快速路径，包括可能只匹配目录的规则。即使没有规则，目录条目也仍须经过现有函数处理。

The implementation should make the file-versus-directory decision from the
enumerator's existing entry attributes, without an additional filesystem
stat. It must preserve traversal order and the exact current branch for any
non-empty ruleset. If these conditions cannot be met cleanly with the existing
walk, stop and revise the design rather than broadening the optimization.

实现应使用枚举器已有的条目属性判断文件或目录，不额外调用文件系统查询（stat）。必须保持遍历顺序，并在规则集非空时完整保留当前处理分支。如果现有遍历结构无法干净地满足这些约束，应暂停并修订设计，而不是扩大优化范围。

## Alternatives considered / 已考虑的方案

1. **Skip no-op regular-file calls (recommended):** small localized change;
   retains the current rule engine and directory cleanup.
2. **Replace post-processing with a consolidated metadata traversal:** could
   remove more overhead, but increases mutation/order and compatibility risk;
   defer until profiling demonstrates a need.
3. **Stop after profiling:** zero behavior risk but leaves measured no-op work.

1. **跳过普通文件上的无操作调用（推荐）：** 改动范围小，沿用现有规则引擎和目录清理逻辑。
2. **用统一的元数据遍历重写后处理：** 可能减少更多开销，但会增加文件变更顺序和兼容性风险；在性能测量证明确有必要前暂缓。
3. **完成性能测量后停止：** 不引入行为风险，但保留了已测得的无效工作。

The user approved option 1 as the direction. This document still requires review
before implementation.

用户已认可方案 1 的方向；实施前仍需审阅并确认本文档。

## Validation plan / 验证计划

Add regression tests before implementation, proving:

- With all rule families empty, regular files bypass `AfterUnzip` while
  directories still reach it.
- Empty directories are still removed, and non-empty directories remain.
- Each individual rule family disables the shortcut and continues to affect
  matching files and directories as before: extension rename, name rename,
  regex rename, and regex delete.
- Nested extraction and existing ordering/behavior remain unchanged.

实现前先添加回归测试，证明：

- 所有规则类型都为空时，普通文件跳过 `AfterUnzip`，目录仍会进入该函数。
- 空目录仍会被删除，非空目录仍会保留。
- 每一类规则单独存在时都会禁用快速路径，并继续按原有行为作用于匹配的文件和目录：扩展名重命名、名称重命名、正则重命名、正则删除。
- 嵌套解压以及现有处理顺序和行为均保持不变。

Then run the documented full serial test gate (currently 813 assertions),
production smoke, and the same three-run count-stress benchmark. Compare exact
output tree contents and counts as well as post-process timing. A speedup is not
accepted if output behavior differs. Report timing distributions, not only the
best run. No production installation or publication is included in this scope.

随后运行文档规定的完整串行测试门禁（当前共 813 项断言）、生产版本冒烟测试，以及相同的三次文件数量压力基准。比较精确的输出目录内容、文件/目录数量和后处理耗时。若输出行为有任何差异，即使速度提升也不算通过。报告耗时分布，而非只报告最快一次。本范围不包含安装生产版本或发布。

## Risks and boundaries / 风险与边界

- If directory classification is wrong, empty-folder cleanup can regress.
- If the predicate overlooks one rule family, configured mutations may be
  skipped; independent tests for all four families guard against this.
- The benchmark uses zero-byte files and does not establish throughput gains
  for large files or different storage devices.
- The existing profiling changes are currently uncommitted; they must remain
  separate from implementation review and must not be accidentally included in
  the design-document commit.

- 如果目录判断错误，空目录清理可能退化。
- 如果快速路径条件漏掉任何一类规则，已配置的文件变更可能被跳过；对四类规则分别测试可防止此问题。
- 基准使用零字节文件，不能据此推断大文件或不同存储设备上的吞吐提升。
- 现有性能埋点改动尚未提交，必须与实现审查保持分离，不得误纳入设计文档提交。
