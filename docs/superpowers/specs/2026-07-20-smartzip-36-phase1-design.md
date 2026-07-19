# SmartZip 3.6 第一阶段迁移设计

日期：2026-07-20  
基线：`main` @ `938e927`  
对照：`.superpowers/analysis/SmartZip-3.6-recovered.ahk`

## 背景

当前 `main` 基于 SmartZip 3.4，并已经合入四项正确性热修：

1. `Unzip` 的 `nesting` 与 `nestingMuilt` 分开控制。
2. `CreateZip` 混合输入分支先初始化 `path := ""`。
3. `IsArchive` 的普通扩展名仅使用 `this.ext.Has(ext)` 精确匹配。
4. 设置页通过 `IsContextMenuVisible("UnZip")` 读取智能解压菜单状态。

官方 3.6 发布包只有编译产物。恢复出的脚本包含三项值得迁移的能力，也包含上述旧问题和若干未说明差异。本阶段因此以当前热修基线为准，只定点回移官方明确列出的三项功能及其必要支撑，不用恢复稿整体覆盖。

## 目标

### 版本标识

- `MainVersion := "3.6"`
- `buildVersion := 20`
- `buileTime := "2023/1/30 17:46:22"`
- 同步已有 Ahk2Exe 注释：
  - `SetFileVersion 3.6`
  - `SetProductVersion 20`

### 排除规则

- 在 `SmartZip.Init` 中统一构建 `this.excludeArgs`。
- `Unzip` 删除重复构建，继续消费该参数。
- `CreateZip` 仅在全部输入均为文件夹的分支追加该参数。
- 单文件、混合输入和 `OpenZip` 聚合压缩路径保持原行为。

### GUI 错误模式

- 7-Zip GUI 文本连续解析失败超过 10 次后进入 ErrorMode。
- ErrorMode 显示错误说明，并把暂停按钮改为“强制结束”。
- 仅在 ErrorMode 且精确绑定当前 `7zG.exe` 进程时，启用近似 IO 速度采样。
- 文本恢复后退出 ErrorMode，停止 IO timer，并继续使用正常 GUI 文本更新速度。

### 安全目标

- WMI 仅用于可选观测和精确进程绑定，失败必须软降级。
- 禁止用 `ProcessExist("7zG.exe")` 任意选择进程后执行强杀。
- `Close`、`Escape` 和解析恢复路径必须停止 IO timer。
- 四项已合入热修不得回退。

## 非目标

本阶段不迁移以下 recovered 差异：

- `hideRunSize` 的 KB/MB 单位变化。
- `CreateZip` 的 hide 条件变化。
- 混合压缩的盘符命名回退。
- 密码分类、动态排序和设置页排序变化。
- 其他未说明文案、控件顺序和 SendTo 差异。
- recovered 中的 nesting、扩展名子串、混合 `path` 和设置键名旧问题。
- INI 结构、命令行入口、菜单名称或运行时依赖变化。
- 系统级 7zG 单例锁和孤儿进程自动清理。

## 采用方案

采用“当前源码定点回移”：

1. `SmartZip.ahk` @ `938e927` 是唯一产品基线。
2. recovered 只用于核对功能意图和必要字段。
3. 安全行为以本规格为准，不逐字复制 recovered。
4. 实现差异限制在版本、排除规则、GUI ErrorMode、WMI/PID 支撑及相应测试。

拒绝以下方案：

| 方案 | 原因 |
| --- | --- |
| recovered 整文件覆盖 | 会回退四项热修，并带入未说明差异 |
| 照搬 PID 名称兜底 | 多个 7zG 并存时可能误杀 |
| 照搬成功路径的速度槽跳过 | 会破坏当前正常速度显示 |
| 同时迁移 hide、单位和命名差异 | 扩大回归面，超出官方三项说明 |
| 增加兼容开关和双轨代码 | 本阶段没有双轨需求，测试组合过多 |

## 组件级设计

### 1. 版本常量

更新文件头的 Ahk2Exe 版本注释以及 `MainVersion`、`buildVersion`、`buileTime`。设置页继续使用现有表达式显示版本，不改变布局。

### 2. `SmartZip.Init`

把 current `Unzip` 中的排除规则构建迁到 `Init`：

1. 读取 `excludeExt` 和 `excludeName`。
2. 初始化 `this.excludeArgs := ""`。
3. 扩展名生成 ` -x!*.ext`。
4. 名称生成 ` -x!*name*`。
5. 仅在参数非空时追加 ` -r`。

同时初始化 WMI/PID 所需的任务级字段：

- `this.pid := ""`
- `this.query := ""`
- `this.exactPid := false`，或语义等价的精确绑定标志。

`hideRunSize` 保持 current 的 MB 语义。

### 3. `SmartZip.Unzip`

- 删除 `excludeExt`、`excludeName` 的本地读取和拼接。
- 保留现有两条解压 `Run7z` 路径对 `this.excludeArgs` 的消费。
- nesting 分开关逻辑不改。

### 4. `SmartZip.CreateZip`

在 `count = this.arr.Length` 的全文件夹分支中，把命令参数从：

```ahk
args ' "' i '\*"'
```

扩展为：

```ahk
args ' "' i '\*"' this.excludeArgs
```

以下路径不得追加 `this.excludeArgs`：

- 单文件压缩。
- 文件和文件夹混合压缩。
- `OpenZip` 聚合压缩。

现有 hide 条件、输出命名和混合分支的 `path := ""` 保持不变。

### 5. `SmartZip.Run7z` 与 `WinGetPID`

每次 `Run7z` 启动前清空 `pid`、`query` 和精确绑定状态，防止队列中的下一个任务继承旧状态。

`WinGetPID` 的契约：

1. 根据本次命令路径构建并保存 WQL：

   ```text
   Select * from Win32_Process
   where Name="7zG.exe"
   and CommandLine like "%<escaped path>%"
   ```

2. 路径转义至少覆盖 recovered 的反斜杠、`[`、`]`、`^` 情况。
3. `ComObjGet`、`ExecQuery` 和进程属性读取使用异常保护。
4. 仅在查询得到唯一、有效且与本次命令关联的进程时设置：
   - `this.pid`
   - `this.exactPid := true`
5. 查询失败、无结果或多结果时：
   - `this.pid := ""`
   - `this.exactPid := false`
   - 禁用 IO 采样和强杀能力。
6. 禁止用进程名称兜底赋值 `this.pid`。

`CMDPID` 仍只表示 `CreateProcess` 启动的 CLI `7z.exe`，不得与 GUI `7zG.exe` 的 PID 混用。

### 6. `SmartZip.Gui`

新增 GUI 任务状态：

- `g.io := 0`
- `g.ioRunning := false`
- `g.errorMode := false`

#### `ShellMessage`

使用连续失败计数 `times`：

- 解析结果为空时执行 `times++`。
- `times <= 10` 时只计数并返回。
- `times > 10` 时：
  - 设置 3.6 错误提示。
  - 暂停按钮文案变为“强制结束”。
  - 设置 `g.errorMode := true`。
  - 仅当 `this.exactPid && this.query` 时启动 `GetWriteIO` 的 1000ms timer。
  - 进入后把 `times` 清零；ErrorMode 的存续由显式状态表示。

一旦正常解析恢复：

1. 停止 `GetWriteIO` timer。
2. 清空 `g.ioRunning`、`g.errorMode`、`g.io` 和 `times`。
3. 继续 current 的正常字段更新。
4. 保留对 `速度2` 的 `IsChanged` 更新。
5. 禁止复制 recovered 中通过单独 `index++` 跳过速度槽的行为。

#### `GetWriteIO`

执行顺序：

1. 先检查 `g.errorMode`、`this.exactPid` 和 `this.query`。
2. 门闩通过后才设置 `g.ioRunning := true`。
3. 在异常保护中读取 `WriteTransferCount`。
4. 转换为 MB，并以相邻采样差值更新 `速度2.Text`。
5. 查询、属性或控件写入失败时，本次采样直接返回，不改变压缩/解压结果。

WMI 失败可以保留最后一次速度显示；不得因此中止任务或结束进程。

#### `ButtonPause`

- 仅当 `g.errorMode && this.exactPid && ProcessExist(this.pid)` 时，按钮具有强制结束语义，只结束 `this.pid`。
- 其他情况保持 current 的 `ControlClick("Button2")` 普通暂停行为。
- 精确 PID 不可用时，“强制结束”不得退化为按名称杀进程。

#### `ButtonShowHide`

ErrorMode 或 IO timer 运行期间直接返回，避免操作失效的 7zG GUI。

#### `Close` 与 `Escape`

清理顺序：

1. 停止 `GetWriteIO` timer。
2. 清空 GUI 的 IO 和 ErrorMode 状态。
3. 仅当 `this.exactPid` 且 `this.pid` 仍存在时结束该进程。
4. 保留现有临时目录回收、消息注销和 GUI 销毁流程。

精确绑定失败时允许目标 7zG 残留，优先避免误杀其他任务。

## 状态机

```text
Normal
  ├─ 单次解析成功 ───────────────► Normal
  └─ 连续解析失败 > 10 ─────────► ErrorMode

ErrorMode
  ├─ exactPid=true ─────────────► IO 子态，可强制结束 this.pid
  ├─ exactPid=false ────────────► 仅显示错误，禁 IO、禁强杀
  ├─ 解析恢复 ──────────────────► 停 timer、清状态、Normal
  └─ Close/Escape ──────────────► 停 timer、条件结束 pid、销毁 GUI
```

`exactPid` 与 GUI 状态正交：

| ErrorMode | exactPid | IO timer | `ProcessClose(this.pid)` | 普通暂停 |
| --- | --- | --- | --- | --- |
| 否 | 否/是 | 关 | 禁止 | 可用 |
| 是 | 否 | 关 | 禁止 | 尽力保留 |
| 是 | 是 | 可开 | 仅当前 PID | 由强制结束语义覆盖 |

## 数据流

### 排除参数

```text
INI excludeExt / excludeName
              │
              ▼
       Init 构建 excludeArgs
          ├────────► Unzip 的两条 Run7z(x) 路径
          └────────► CreateZip 全文件夹 Run7z(a) 路径
```

### PID 与速度

```text
Run7z(path)
  → 清 pid/query/exactPid
  → path 转义并生成 WQL
  → 唯一命中：保存 pid/query，exactPid=true
  → 失败或歧义：清 pid，exactPid=false
  → 仅 ErrorMode + exactPid：WMI IO 差分写入速度2
```

## 错误与降级

| 场景 | 应有行为 | 禁止行为 |
| --- | --- | --- |
| WMI 服务不可用 | 禁 IO、禁强杀，压缩/解压继续 | 未捕获异常退出 |
| WQL 无匹配 | 清空精确 PID 状态 | 按名称选择 7zG |
| WQL 多匹配 | 视为不精确并禁强杀 | 默认取第一个结果 |
| 连续失败不超过 10 次 | 只计数 | 提前进入 ErrorMode |
| ErrorMode 无精确 PID | 可显示错误；普通暂停尽力保留 | 空 PID 或名称强杀 |
| 正常解析恢复 | 停 timer，清状态，恢复文本速度 | 继续 WMI 写入或跳过速度槽 |
| `GetWriteIO` 单次失败 | 跳过该次采样 | 改变任务结果 |
| Close/Escape | 先停 timer，再条件结束精确 PID | timer 写已销毁控件 |
| 多个 7zG 并存 | 只允许绑定当前命令的唯一进程 | 结束其他 7zG |
| 排除配置为空 | `excludeArgs` 为空，不追加 `-r` | 生成无意义递归排除参数 |

## 精确验收标准

### 版本

1. 版本常量为 3.6、20 和 `2023/1/30 17:46:22`。
2. Ahk2Exe 文件版本和产品版本同步。
3. 设置页不再显示旧的 3.4/18。

### 排除规则

4. `excludeArgs` 仅在 `Init` 构建。
5. `Unzip` 两条解压路径继续消费该参数。
6. `CreateZip` 全文件夹分支追加该参数。
7. 单文件、混合和 `OpenZip` 不追加该参数。
8. 空排除配置不追加 `-r`。

### ErrorMode

9. 进入条件是连续失败次数严格大于 10。
10. 错误提示和“强制结束”文案存在。
11. IO timer 只在 ErrorMode 且精确 PID 有效时启动。
12. 正常解析恢复和 Close/Escape 均停止 timer。
13. 正常路径继续更新 `速度2`，不存在 recovered 式速度槽跳过。

### 进程安全

14. 产品源码中不存在 `ProcessExist("7zG.exe")` 形式的 PID 兜底。
15. GUI 7zG 的 `ProcessClose` 仅针对受精确门闩保护的 `this.pid`。
16. WMI 调用失败可以软降级，不改变主任务结果。
17. 多匹配不被视为精确 PID。
18. `CMDPID` 语义不变。

### 回归与范围

19. 现有 24 项静态测试全部通过。
20. 四项热修结构保持。
21. diff 不包含非目标行为变化。
22. 无新配置、新依赖或用户迁移步骤。

### 环境说明

23. 如果环境仍缺 AutoHotkey v2 或 7-Zip，只能声明静态验证完成；不得声称 GUI 和真实压缩/解压场景已经运行。

## 自动化测试

测试文件：`tests/SmartZip.Static.Tests.ps1`。继续使用仓库现有 Pester 3.4 语法。

现有门禁：

| Describe | 数量 | 主题 |
| --- | ---: | --- |
| NestingGate | 7 | 嵌套开关 |
| CreateZipPathInit | 4 | 混合路径初始化 |
| IsArchiveExt | 7 | 扩展名精确匹配 |
| SettingsUnZipKey | 6 | UnZip 键名 |

新增以下静态测试组：

### `VersionBanner`

- `MainVersion` 为 3.6。
- `buildVersion` 为 20。
- `buileTime` 为 3.6 对照时间。
- Ahk2Exe 文件和产品版本同步。

### `ExcludeArgsBuildAndConsume`

- `Init` 含唯一构建块。
- `Unzip` 不再读取排除配置，但保留两处消费。
- `CreateZip` 仅全文件夹分支消费。
- 单文件和混合分支不消费。

### `ErrorModeStateMachine`

- 存在连续失败计数和 `times > 10` 门槛。
- 存在错误提示、“强制结束”和 1000ms IO timer。
- timer 启动受 ErrorMode 与精确 PID 门闩约束。
- 成功解析和 Close 均停止 timer。
- 正常速度更新仍存在，未被跳过。

### `PidAndWmiSafety`

- 每次任务清空 PID/query。
- WQL 关联 7zG CommandLine 与本次路径。
- 产品源码不存在按 `7zG.exe` 名称兜底 PID。
- `ProcessClose(this.pid)` 受精确绑定条件保护。
- WMI 和 IO 采样具有软降级结构。

运行命令：

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -PassThru
```

门禁是全部测试 `FailedCount = 0`，并且原有 24 项不得删除或弱化。

## 手工测试矩阵

总前置：Windows、AutoHotkey v2，以及包含 `7z.exe`、`7zG.exe`、`7zFM.exe` 的 7-Zip 环境。

| 编号 | 场景 | 操作 | 预期结果 |
| --- | --- | --- | --- |
| T1 | 全文件夹排除 | 配置扩展名/名称排除，压缩两个文件夹 | 命令含排除项与 `-r`，包内无被排除项 |
| T2 | 单文件压缩 | 同一配置下压缩单文件 | 命令无排除段，压缩成功 |
| T3 | 混合压缩 | 压缩一个文件和一个文件夹 | 命令无排除段，无 `path` 未初始化异常 |
| T4 | 解压排除 | 解压包含被排除项的包 | 两条解压路径继续应用排除规则 |
| T5 | ErrorMode 门槛 | 让 GUI 文本连续不可解析超过 10 次 | 第 11 次后显示错误并进入 ErrorMode |
| T6 | 解析恢复 | ErrorMode 后恢复可解析文本 | timer 停止，状态和按钮恢复，速度继续更新 |
| T7 | WMI 不可用 | 禁用 WMI 或让查询失败 | 压缩/解压继续，无异常和误杀 |
| T8 | 精确 PID | 同时存在无关 7zG | 只绑定本次命令路径对应进程 |
| T9 | 多进程关闭 | 多个 7zG 并存时关闭或强制结束 | 不结束其他 7zG |
| T10 | timer 清理 | IO timer 运行时关闭或按 Esc | timer 停止，无销毁后回调异常 |
| T11 | 强制结束 | ErrorMode 且精确 PID 有效时点击按钮 | 仅结束 `this.pid` |
| T12 | nesting 回归 | `nesting=1`、`nestingMuilt=0` 解压单内层包 | 内层继续解压 |
| T13 | 路径和扩展名回归 | 混合压缩并测试 `.zip`、`.z` | 无路径异常；`.zip` 命中，`.z` 不误判 |
| T14 | 设置键回归 | 注册 `UnZip` 后打开设置 | 智能解压复选框选中 |
| T15 | 版本显示 | 打开设置版本区域 | 显示 SmartZip 3.6、build 20 和新时间 |
| T16 | 入口回归 | 分别执行 `x`、`xc`、`o`、`a` 最小场景 | 无新增崩溃，静态测试全绿 |

缺少运行时工具时，T1–T16 全部记录为“未执行：缺少运行时”，不以静态断言替代运行结果。

## 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| recovered 的名称 PID 兜底造成误杀 | 静态禁止该模式，并使用精确 PID 门闩 |
| timer 在 GUI 销毁后继续运行 | 恢复、Close 和 Escape 都显式停止 |
| WQL 路径产生零个或多个结果 | 两种情况都视为不精确，禁 IO 和强杀 |
| 队列继承上一任务 PID | 每次 `Run7z` 重置任务级状态 |
| IO 状态与 ErrorMode 混淆 | 使用显式 `g.errorMode` 和 `g.ioRunning` |
| 排除参数在多个入口重复构建 | `Init` 是唯一构建点 |
| 回移时碰坏热修 | 原有 24 项静态测试作为硬门禁 |
| 夹带 hide、单位或设置差异 | 通过非目标清单和最终 diff 审查拒绝 |
| 缺少运行时却误报完成 | 实施报告明确区分静态与动态验证 |

## 实施边界

允许修改：

- `SmartZip.ahk`：本规格列出的定点改动。
- `tests/SmartZip.Static.Tests.ps1`：追加静态测试，不删除或弱化原有 24 项。
- 本规格和后续实现计划：只记录本阶段决策。

禁止修改：

- `Contextmenu.ahk`、INI 默认策略和资源文件。
- 与三项功能无关的 GUI、设置、密码、命名和 hide 行为。
- recovered 整文件。
- 新依赖、安装步骤或配置迁移。

建议实施顺序：

1. 先追加会失败的版本和排除规则静态测试，再做对应实现。
2. 追加会失败的 ErrorMode/PID/WMI 静态测试，再做安全实现。
3. 运行全量 Pester。
4. 审查 diff，确认非目标没有夹带。
5. 具备运行时后执行 T1–T16。

## 完成定义

- 所有精确验收标准满足。
- Pester 全量通过，原有 24 项保留。
- 实现差异仅在允许范围。
- 运行时测试状态如实记录。
- 多个 7zG 并存时不存在按名称误杀路径。
