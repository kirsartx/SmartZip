# SmartZip → Qoder 交接（2026-09-19）

## 任务与编辑权

用户要求：继续审查可改进点，形成规划与历史交接，然后由 Qoder 修改。保留现有解压行为、安全检查和用户未提交改动。Codex 本轮只审查、运行基线测试、写交接文档；交接后由 Qoder 单独编辑，不并行改同一工作树。

工作目录：`C:\Users\Kirs\Documents\smartzip优化`。
先按 AGENTS.md 阅读 ACTIVE_TASK、DECISIONS、README、tests/README 并检查 Git。用户已要求按推荐方案继续、不用重复询问；本交接授权实施下述规划，不授权发布、部署或清理现有改动。

执行规划：`docs/superpowers/plans/2026-09-19-sfxv-reliability-followup.md`。
此文件记录的是交接准备状态，不代表 Qoder 已完成或已收到任务；接收后请在 ACTIVE_TASK 记录执行状态。

## 从此前改动到当前状态

1. 解压可靠性：保留 probe → 密码解析 → test → 隔离目录解压及最终完整性检查 → finalize。失败、取消、警告不能误删源文件；分卷源文件不能自动删除。诊断输出脱敏。
2. 重用已验证结果：提交 `6cd7eca` 重用密码测试结果，`901ceca` 重用嵌套预探测，`a11fbe5` 加固交接失败回退。仅同一同步流程、匹配原始归档路径和正确阶段可复用，不能跨任务全局缓存。
3. 目录扫描：候选文件名门控跳过不可能分卷的同级目录扫描；空目录检查发现首个文件即停止，保留自定义扩展名规则。
4. SFXV 支持：提交 `0f75a63` 支持 `.exe + .001.sfxv + ...`；选择任一成员归一到首卷，检查缺卷，跳过 EXE stub 合并内嵌 7z 数据到临时文件，源文件只读。没有执行用户归档 EXE。7-Zip 26.02 ZS 的 7z stdin 实验返回 Not implemented，已移除该路线。
5. 最新本地优化：同一解压任务及密码重试只合并一次；嵌套预探测与实际解压共享输入、不同嵌套路径恢复外层所有者；普通格式跳过 SFXV 扫描；增加可用空间、短读短写、偏移检查和 prepare 耗时。此批改动尚未提交或推送，但已在此前部署到本机。

## 三种版本不可混淆

- Git 分支：`agent/diagnostic-ui-contract-repair`；HEAD `0f75a63`。origin：`https://github.com/kirsartx/SmartZip.git`。不要向 upstream 推送。
- 本地未提交实现：README.md、SmartZip.ahk、docs/continuity/ACTIVE_TASK.md、docs/continuity/DECISIONS.md、ini.md、lib/ArchiveDiagnostics.ahk、tests/README.md、tests/Sfxv.Integration.Tests.ps1，共 8 个原有修改文件。本轮另外新增规划和此交接文件；不要覆盖、还原这些改动。
- 上轮已部署：`C:\Tool\SmartZip\SmartZip.exe`，历史记录 SHA256 `06F7966340274672777239281B8B8EA7BE5F103BB99CC7B2A5432282DFF616A7`；备份 `SmartZip.exe.bak-sfxv-reuse-20260917-151230`，INI 未变。本轮未重新校验安装文件，不能把 Qoder 源码修改说成已经部署。

## 审查发现与边界

- 高优先级：SfxvInput 的构造/合并失败调用 Close 后 closed=true，而 SfxvInputMatches 拒绝 closed 输入，后续 Acquire 可能再次准备同一失败归档。需用回归测试验证并修复任务内失败结果复用。
- 高优先级：Close 先置 closed，删除失败被吞掉，下一次 Close 直接返回；临时文件暂时被占用时可能残留。应区分生命周期关闭和清理完成，并有界重试。
- 高优先级：集成测试仅在 results.txt 存在时动态注册行为断言，缺失或截断可能漏掉检查。先加强测试完整性再改实现。
- 后续候选而非本轮实施：首个六字节 7z magic 可能是假签名，应研究完整起始头验证及截断归档兼容；timing 日志轮转；同步合并进度/取消 UI；可重复的大归档性能基准。不要同时扩展这些项目。

## 验证证据

- 历史上一轮全量：717 passed / 0 failed，包括原八套 648、目录扫描 1、SFXV 识别 1、SFXV 集成 67。历史生产编译 exit 0。
- 本轮重新执行：`Invoke-Pester -Script './tests/Sfxv.Integration.Tests.ps1' -PassThru -Quiet | Select-Object TotalCount,PassedCount,FailedCount,SkippedCount` → Total 67 / Passed 67 / Failed 0 / Skipped 0，命令 exit 0。
- 本轮没有重新执行全量、编译或大文件性能测试。具体文档检查见 ACTIVE_TASK。
- 用户提供约 10.16 GB SFXV 样本；没有速度百分比实测。减少重复合并属于 I/O 减量推断，不是已测加速结果。不要读取/记录旁边说明文件中的密码，不执行样本 EXE。

## Qoder 完成后回交

按规划先红后绿，报告各项实际命令、测试数量、失败原因和修复，不只报旧的 717。运行 tests/README 的完整门禁及新增套件、git diff --check。检查测试生成片段，只清理由本次创建且确认归属的产物。更新 ACTIVE_TASK 和稳定决策；保留未提交 diff 供复审，不 commit/push、不覆盖安装 EXE、不修改 INI、不动源归档。

## Qoder 交付结果（2026-09-19）

状态：规划三项全部完成，逐项先红后绿；逐条命令与实际数字见
`docs/continuity/ACTIVE_TASK.md` 顶部 “Qoder implementation — 2026-09-19”，稳定契约见
`docs/continuity/DECISIONS.md` 的 “SFXV Reliability Follow-up (2026-09-19)”。

对上文两处记录的更正：

- 第 37 行的 67/67 在本机当时不可复现：该 `.ps1` 是唯一含中文又无 BOM 的测试文件，
  PowerShell 5.1 按 ANSI 解码使切片锚 `;解压嵌套` 失配，实测只注册 1 个测试且失败。
  补 BOM（仅 +3 字节，其余逐字节相同）后 67/67 成立，才作为本轮真实基线。
- `Start-Process -PassThru` 在本机不回填 `ExitCode`，使三套共同的“退出码必须为 0”
  崩溃门禁变成与空值比较；已统一到 `tests/TestHelper.ps1` 的 `Invoke-AhkRunner`。
  因此历史 717 只能视为旧环境记录，不能作为本轮基线或对照。

本轮最终结果：12 套 744 passed / 0 failed / 0 skipped（逐套显式校验 Failed 与 Skipped），
`git diff --check` exit 0；当轮未编译未部署（部署发生在随后一轮，见下一节）。

## Qoder 完整回归 + 生产编译 + 本机部署（2026-09-20）

用户随后授权「完整回归 → 独立 TEMP 生产编译 → 无 hook 生产冒烟 → 通过后才更新本机安装版」，
替代上一轮的不部署限制。五个阶段全部通过，安装版已更新。

- 回归：12 套 744/744，0 failed、0 skipped、0 pending，逐套按预期数量硬校验（184/193/15/98/
  39/30/53/36/1/1/84/10）。
- 编译：`%TEMP%\smartzip-prod-build-20260920-023700` 只放 `SmartZip.ahk`、
  `lib\ArchiveDiagnostics.ahk`、`ico.ico`（无 `tests` 目录）；编译前断言暂存源码与仓库
  `SmartZip.ahk` 逐字节相同、零 `IntegrationTestHook`、零 `#Include *i tests`、
  ArchiveDiagnostics include 恰好一次；Ahk2Exe exit 0；同一源码两次编译哈希一致，可复现。
- 冒烟：对刚构建的 exe 跑 `Invoke-ProductionSmartZipSmoke.ps1`（无 hook、仅观察文件/日志/UI），
  `Passed=True`、`LeakedProcessCount=0`、`RedactionOk=True`，四场景 valid / crcPartial /
  splitMissing / encryptedHeader 全过，crcPartial 恰好 1 个隔离 partial 目录、其余 0，无超时，
  过程内 fixture 密码未出现在 manifest 或报告里。
  第一次失败是我自己的接线错误（把生成器返回对象经 `Out-String` 当 JSON 用），不是产品问题；
  改用生成器返回的 `ManifestPath` 后通过。
- 备份与哈希：
  - 旧安装版 `06F7966340274672777239281B8B8EA7BE5F103BB99CC7B2A5432282DFF616A7`
    （1435648 字节，2026-09-17 15:08:51），与本文记录一致后才继续。
  - 唯一时间戳备份（先建、先核对哈希，再写入）：
    `C:\Tool\SmartZip\SmartZip.exe.bak-sfxv-reliability-20260920-023829`
    —— 注意它的 `LastWriteTime` 仍是 2026-09-17（复制保留原时间戳），`CreationTime` 才是
    2026-09-20 02:38:29，别按修改时间判断新旧。
  - 新安装版 = 通过冒烟的构建哈希
    `7D933A46B706D088026A18DD0084EC967F62E29FB3BC60DA479B9285D9CAC413`（1436160 字节）。
  - `SmartZip.ini` 前后一致：`DDCC1A739F63700699E040095ECE3CEE39F3B4DCC9C5B18C67EE4824E7EE96A4`，
    mtime 2026-09-16 14:49:40；安装目录内只有 `SmartZip.exe` 被写。`Contextmenu.exe` 未动。
- 部署后复验：把已安装字节复制到 TEMP 再跑同一四场景冒烟（该脚本刻意拒绝
  `C:\Tool\SmartZip` 下的路径），同样 4/4 通过，且跑完后 exe 与 INI 哈希均未变。
- 恢复方法：先退出正在运行的 SmartZip 托盘进程，再
  `Copy-Item 'C:\Tool\SmartZip\SmartZip.exe.bak-sfxv-reliability-20260920-023829' 'C:\Tool\SmartZip\SmartZip.exe' -Force`
  并确认结果为 `06F7966…16A7`。
- 部署时没有正在解压的进程（`SmartZip`/`Contextmenu`/7z 均无），目标文件可独占打开，因此
  无需、也没有终止任何用户任务。
- 仍未测：没有大归档基准，所以这台机器上依旧没有速度数字可引用；本次部署的可信度来自契约测试
  加四场景无 hook 冒烟，而不是计时。
- 提交状态未变：索引仍然 0 暂存，未 commit、未 push；`git status --short` 仍是 11 改 + 3 新增
  （生成的两个测试片段已复原/删除）。构建源码与门禁通过时一致，故重新编译仍应得到上述哈希；
  若源码再有改动，先重跑门禁与冒烟，再谈部署。

给 Codex 的提交建议：**本轮没有 `git add`，索引仍是干净的**，`git status --short` 共 14 项
（11 个已跟踪修改 + 3 个未跟踪新增）。其中 8 个修改文件是 Codex 上一轮留下的，本轮又更新了
`lib/ArchiveDiagnostics.ahk`、`tests/Sfxv.Integration.Tests.ps1`、`tests/README.md`、
`docs/continuity/ACTIVE_TASK.md`、`docs/continuity/DECISIONS.md`，另外新改
`tests/TestHelper.ps1`、`tests/Sfxv.Tests.ps1`、`tests/DirectoryScanOptimization.Tests.ps1`，
并新增 `tests/SfxvResultHelper.ps1`、`tests/Sfxv.ResultContract.Tests.ps1`。这些应一起提交——
只暂存本轮文件会让下一次 `git commit` 静默漏掉 `SmartZip.ahk`、`README.md`、`ini.md`。
按规划三项拆 3 个提交：

1. `test: fail closed on missing SFXV harness results`
   （SfxvResultHelper.ps1、Sfxv.ResultContract.Tests.ps1、Sfxv.Integration.Tests.ps1 的注册与
   BOM、TestHelper.ps1 的 Invoke-AhkRunner、Sfxv.Tests.ps1、DirectoryScanOptimization.Tests.ps1、tests/README.md）
2. `fix: reuse a failed SFXV preparation inside its task`
   （lib/ArchiveDiagnostics.ahk 的 taskActive 与匹配规则、对应集成断言）
3. `fix: separate SFXV close from cleanup and retry it with a bound`
   （lib/ArchiveDiagnostics.ahk 的 Close/cleanupComplete 与有界重试、对应集成断言）

本轮请复审、暂存与提交。交接文件本身保持未跟踪。

## 交给 Codex 复审：解压判定修复（2026-09-20，复审未通过，缺口在下一节修复）

- 已实现：`ExtractionVerdict` 成为解压状态的唯一裁决点;`VerifyExtractedOutput` 用
  `7z l -slt` 的每项 Size + CRC-32(`ntdll!RtlComputeCrc32` 流式)逐文件核对**实际写出**内容;
  后续源码 `t` 的退出码/文本改存 `verifyExitCode`/`verifyOutput`,诊断文本按进程标注,
  `result.output` 对 extract 阶段留空。模糊码升格**只会**得到 `OK_WITH_WARNING`,
  `isCleanSuccess`/`mayDeleteSource` 恒为 false;不存在任何 2→成功 的映射。
- 证据:`Sfxv.Integration.Tests.ps1` 99/99(先以“复现今日行为”的 stub 得到 92 通过/7 失败,
  再实现转绿);oracle 的判别力用变异验证(强制 `verified := true` 只让三条 reject 用例变红,
  随后已还原)。全量 12 套 759/759,0 failed/0 skipped/0 pending;`git diff --check` exit 0;
  独立 TEMP 生产编译无 hook(SHA256 `529E5F10B2551BDB0791023C3DA114C5B31D198B9EAFDA9E6FB6EE0513F600C3`,
  1440768 字节),无 hook 四场景冒烟全过(`Passed=True`、`LeakedProcessCount=0`、`RedactionOk=True`)。
- 当时未部署:安装版仍为上一轮 `7D933A46…`,INI 哈希未变。未 commit、未 push、索引 0 暂存。
  （该限制已被下一条记录取代:复审指出四项缺口,修复并重新验证后已在本机部署。）
- 请重点复审的取舍:① 成本只在歧义退出码路径上多一次输出读盘(10GB 归档即一遍全量读),
  正常成功路径不付出;② `excludeArgs`/`codePage` 非空时**故意不**升格(保持保守失败);
  ③ CRC-32 是 7-Zip 自身校验强度,不是密码学保证;④ 末字节已写完后的取消会被判为
  `OK_WITH_WARNING`,与“完成后再关窗”同结果。
- 当时仍缺的自动化(下一节已补齐):真实 7zG 分支的回归。临时套件把**干净**场景经真 7zG 跑通到
  `exit 0`+`OK`,但**带警告**对话框无论用外部窗口监视器还是 AHK 内 `SetTimer` 都无法稳定关闭,
  故该文件已删除而不是留下一个会超时的套件。删除它并声称该分支已覆盖是错的,本轮以
  `tests/GuiExtraction.Tests.ps1` 重建并跑绿。
- 另需注意:本轮两处自我回归(未加花括号的 `if`、`name (args)` 被 AHK v2 解析成方法调用)
  是被既有门禁(`crcPartial` 超时与 Static 失配)抓出来的,而非新测试;`SmartZip.Static` 的
  exit-1 匹配器已改为同时钉住“裁决委托”和“升格上限”,不是简单放宽。

不要因为“看起来可以更简”而回退的决定：

- 不要把预期标签集合改回从 `results.txt` 推导或条件注册；新增 `Check` 必须同步
  `$expectedLabels`，否则缺项又会变成少几个测试的假绿。
- 不要用 `closed` 兼任“清理已完成”，也不要把 `SfxvInputMatches` 放宽成允许所有 closed
  对象复用；三态契约记录在 DECISIONS。
- 不要把目录删除改回默认参数（当前靠 `DirDelete(dir, false)` 显式非递归；实测本机
  AutoHotkey 2.0.26 默认也不递归，但那属于版本默认值，不应依赖）。
- `scope_retry_attempted` / `scope_retry_bounded` 是本轮唯一受负载影响的计时断言；曾有一次
  合并标签在全量门禁里失败而单跑通过。要调整请先跑完整门禁，不要直接删断言。
- 未做大归档基准，不要写任何加速百分比；被其他进程占用时仍可能残留临时文件，
  不能声称零残留。
- 六字节 7z magic 的完整起始头验证、timing 日志轮转、同步合并进度/取消 UI 仍属未实现
  的后续候选，本轮有意未动。
- 不要因为“看起来可以更简”而回退本轮新增的判定门槛:`listingExit` 必须判定、归档头与条目必须靠
  分隔线区分、条目路径必须验证并做边界包含判断、reparse point 必须拒绝而不是读穿、预期与实际必须
  按集合双向比较。把它们简化成“比数量 + 拼路径”会重新打开“认证目录外文件”和“缺一多一互相抵消”
  两个洞,而这两处正是本轮测试用来钉住的。
- 不要删除 `tests/GuiExtraction.Tests.ps1` 或其 marker 证据链来让门禁变绿:它对取消场景只断言
  盘上字节与进程自身退出码,任何“注入退出码”的替代都不构成该分支的覆盖。

## 四项复审缺口修复、真实 7zG 回归与本机部署（2026-09-20，Qoder）

- 缺口 1（`listingExit` 只记录不判定）:`VerifyExtractedOutput` 现在要求 `7z l -slt` 自身退出码
  为 0 才使用其文本,并在文本被采信前校验结构:分隔线必须存在（用它区分归档头与条目）、头部
  `Type` 非空、头部 `Path` 必须等于被查询的归档、每项必须有 Size 与 Attributes（文件还必须有
  CRC）、不得重复、末项不得被截断。先红后绿:`oracle_refuses_nonzero_listing_exit`、
  `oracle_refuses_unreadable_listing`、`oracle_refuses_listing_with_hard_error`、
  `oracle_refuses_header_without_archive_path`、`oracle_refuses_entry_missing_size` /
  `_checksum` / `_attributes`、`oracle_refuses_duplicate_entries`、
  `oracle_refuses_incomplete_final_entry`、`oracle_refuses_missing_separator`。
  写测试过程中这套用例抓到两处真实缺陷:`report.reason` 初值非空使每次核对都提前返回
  “aborted”;`CollectWrittenFiles` 会递归穿过 junction,从而把目录外的文件当作输出认证。
- 缺口 2（拼接前不校验路径）:条目路径必须是安全相对路径（盘符、UNC、设备、ADS、`..` 全拒）,
  目标先经 `GetFullPathNameW` 归一化,再要求落在输出目录的**目录边界之内**（`D:\out2` 不能
  冒充 `D:\out`）;命中 reparse point 一律拒绝,且不读取其后内容。预期集合与实际写出集合按
  **双向集合**比较而非比数量:`oracle_rejects_missing_and_extra_pair` 用“删一个 + 多一个”这种
  数量相等的夹具钉住它,可疑条目也绝不静默跳过。另有用例
  `oracle_refuses_absolute_item_path` / `_unc_` / `_device_` / `_parent_traversal` / `_stream_`、
  `oracle_refuses_reparse_entry`、`oracle_refuses_reparse_directory`。
- 缺口 3（升格过宽）:`ExtractionVerdict` 收窄为四参数,只有 `usedGui && extractExit == 2 &&`
  输出已证明 才升格;`verdict_console_two_not_promoted` 以及
  `verdict_{three,four,seven,eight,launch_failure,unknown_code}_not_promoted` 即使
  `outputVerified=true` 也仍是失败。`usedGui := !hideBool`,与挑选可执行文件的比较同源,
  `SmartZip.Static` 同时钉住这条来路与“不存在任何 2→成功 映射”。
- 缺口 4（真实 7zG 自动回归）:新增 `tests/GuiExtraction.Tests.ps1` 与
  `tests/GuiDismissDriver.ahk`,七条断言全部启动真 `7zG.exe` / `7z.exe`,参数与 `Run7z` 同款
  （`x "<arc>" -aou -o"<dir>"`）,退出码取自进程本身:干净=0 且无残留窗口;尾部数据=2 且输出
  哈希全部命中;同一归档在控制台侧=0 且输出一致（即 `hideRunSize` 两侧的可执行断言）;内容
  损坏=2 且输出不过校验;输出路径不可写=非 0 且不产出;中途取消=非 0 且盘上字节严格介于 0 与
  全量之间。连跑 3 次均 7/7 绿,每次约 8.5 秒;只操作本测试启动的 PID,超时只杀自己的子进程,
  夹具全部在 TEMP,失败路径也有清理。
- 取消手势的实测结论（外部不可猜）:对**正在运行**的进度框,Esc、`WM_CLOSE`、默认控件 id2 的
  点击都不会中断;第一个 owner-draw 按钮（id 444）只暂停;第二个（id 446）才取消,且只在
  **非 solid** 归档上有效（solid 块只能在块尾停止）,故取消夹具以 `-ms=off` 构建。窗口发现侧
  另有两处坑:`WinExist` 只返回最上层窗口（7zG 完成后进度框仍压在结果框上）,而 `GetParent`
  对对话框返回的是 owner——用它过滤会正好滤掉要点的那个消息框,表现即为“没人点击直到超时”;
  本机 AutoHotkey 2.0.26 的 `CallbackCreate` 对任何 callable 形式都报 “Invalid base”,因此驱动
  改用 `GetWindow` 沿 Z 序双向遍历。驱动把点到的控件 id 记进 marker,失败时会打印出来。
- 门禁:13 套 792/792,`failed=0 / skipped=0 / pending=0`（Sfxv.Integration 125、SmartZip.Static
  184、ArchiveDiagnostics 193、PasswordPreflight 98、DiagnosticUI 53、ExtractionLifecycle 39、
  Real7Zip 36、NestingMigration 30、RunCmdCapture 15、Sfxv.ResultContract 10、GuiExtraction 7、
  Sfxv 1、DirectoryScan 1）。`git diff --check` 退出 0,只有 LF/CRLF 提示。
- 编译与冒烟:独立 TEMP 暂存 `SmartZip.ahk` + `lib` + `ico.ico`,不含 `tests` 目录故无 hook;
  Ahk2Exe 退出 0,产物 SHA256
  `6031E2B04C0739F7E7D80113D5DF03508BAB1962D7336B64003DC9C207DB27C5`（1445376 字节）;以 UTF-16
  扫描产物字节,`SmartZipTest_ResultPath`、`SmartZipTest_SuppressGui`、`IntegrationTestHook`
  三个标记均不存在。对该构建跑无 hook 四场景冒烟:`Passed=True`、`LeakedProcessCount=0`、
  `RedactionOk=True`,四场景全过。
- 部署（本次已执行）:preflight 先确认 `C:\Tool` 下没有 SmartZip/7z/7zG 进程、安装 EXE 能被独占
  打开,才继续;备份为唯一时间戳路径
  `C:\Tool\SmartZip\SmartZip.exe.bak-gui-reliability-20260920-185150`,并核对备份哈希等于旧哈希;
  旧 `7D933A46B706D088026A18DD0084EC967F62E29FB3BC60DA479B9285D9CAC413` → 新
  `6031E2B04C0739F7E7D80113D5DF03508BAB1962D7336B64003DC9C207DB27C5`,与通过验证的构建一致;
  INI 全程为 `DDCC1A739F63700699E040095ECE3CEE39F3B4DCC9C5B18C67EE4824E7EE96A4` 未变。随后对
  **已安装字节的 TEMP 副本**再跑一次冒烟:四场景全过、0 泄漏进程、脱敏 OK,冒烟后安装目录的
  EXE 与 INI 哈希不变。未动用户归档、解压结果与密码说明,未执行用户归档 EXE,未重跑 10GB 样本。
- 回退方法:`Copy-Item 'C:\Tool\SmartZip\SmartZip.exe.bak-gui-reliability-20260920-185150' 'C:\Tool\SmartZip\SmartZip.exe' -Force`,
  然后核对安装版 SHA256 应为旧值 `7D933A46B706D088026A18DD0084EC967F62E29FB3BC60DA479B9285D9CAC413`;
  INI 从未被修改,无需恢复。
- 边界与未做:CRC-32 是 7-Zip 自身校验强度而非密码学保证;`excludeArgs` / `codePage` 非空时仍
  **不**升格（保守失败）;歧义退出码路径要多读一遍输出（10GB 归档即一遍全量读）,正常成功路径
  不付出;未做大归档基准,故不写任何加速百分比;solid 归档上的取消只能在块尾生效,该场景仍只有
  手工证据。后续 Codex 已完成真实样本验证与 805 项门禁，并修复了集成测试编译参数中的路径引号问题；该交接记录保留为历史背景。
