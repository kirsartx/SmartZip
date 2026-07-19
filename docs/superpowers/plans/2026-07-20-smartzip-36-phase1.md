# SmartZip 3.6 Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留四项正确性热修的前提下，定点迁移 SmartZip 3.6 的版本标识、全文件夹压缩排除规则、GUI ErrorMode、近似 IO 速度和安全的精确 PID 控制。

**Architecture:** 继续使用现有单文件 `SmartZip.ahk` 架构，只修改明确的函数区域。`Init` 成为排除参数的唯一构建点；`Run7z` 维护任务级精确 PID/query；`Gui` 用显式 ErrorMode 和 IO 子状态管理错误提示、采样和强制结束。

**Tech Stack:** AutoHotkey v2、7-Zip GUI/CLI、Windows WMI、PowerShell 5+、Pester 3.4。

## Global Constraints

- 基线包含 nesting、混合 `path := ""`、`IsArchive Has(ext)`、设置页 `"UnZip"` 四项热修，任何任务不得回退。
- 版本必须为 `MainVersion := "3.6"`、`buildVersion := 20`、`buileTime := "2023/1/30 17:46:22"`。
- `excludeArgs` 仅在 `Init` 构建；只由 `Unzip` 和 `CreateZip` 全文件夹分支消费。
- ErrorMode 仅在连续 GUI 文本解析失败次数严格大于 10 时进入。
- IO timer 仅在 ErrorMode 且精确 PID/query 有效时启动。
- WMI 失败必须软降级，不得改变压缩或解压主流程的结果。
- 禁止用 `ProcessExist("7zG.exe")` 或其他仅按映像名的方式赋值 PID。
- WQL 零匹配或多匹配都视为不精确，禁用 IO 和强杀。
- 正常解析恢复后必须保留 current 的 `速度2` 文本更新。
- 不迁移 hide 单位、hide 条件、盘符命名、密码分类、设置排序和其他未说明差异。
- 当前环境缺 AutoHotkey v2 或 7-Zip 时，只能报告静态验证结果。

---

## File Structure

| 文件 | 职责 | 本计划动作 |
| --- | --- | --- |
| `SmartZip.ahk` | 产品源码、GUI、7-Zip 调用和 WMI 绑定 | 定点修改 |
| `tests/SmartZip.Static.Tests.ps1` | 无 AHK 运行时的结构回归门禁 | 追加四组测试，保留现有 24 项 |
| `docs/superpowers/specs/2026-07-20-smartzip-36-phase1-design.md` | 已批准的行为规格 | 只读 |
| `.superpowers/analysis/SmartZip-3.6-recovered.ahk` | 3.6 对照稿 | 只读，不提交 |

### Task 1: Version Metadata

**Files:**
- Modify: `tests/SmartZip.Static.Tests.ps1`
- Modify: `SmartZip.ahk:7-13`

**Interfaces:**
- Consumes: `$script:SmartZipSource` from the existing test harness.
- Produces: `MainVersion="3.6"`, `buildVersion=20`, `buileTime="2023/1/30 17:46:22"` and matching Ahk2Exe metadata.

- [ ] **Step 1: Append the failing version tests**

Append exactly:

```powershell
Describe 'VersionBanner' {

    It 'MainVersion is 3.6' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'MainVersion\s*:=\s*"3\.6"'
        $ok | Should Be $true
    }

    It 'buildVersion is 20' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'buildVersion\s*:=\s*20\b'
        $ok | Should Be $true
    }

    It 'buileTime matches the recovered 3.6 timestamp' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'buileTime\s*:=\s*"2023/1/30 17:46:22"'
        $ok | Should Be $true
    }

    It 'Ahk2Exe file version is 3.6' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            ';@Ahk2Exe-SetFileVersion\s+3\.6\b'
        $ok | Should Be $true
    }

    It 'Ahk2Exe product version is 20' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            ';@Ahk2Exe-SetProductVersion\s+20\b'
        $ok | Should Be $true
    }
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```powershell
Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -TestName 'VersionBanner' -PassThru
```

Expected: `TotalCount=5`, `FailedCount=5`; failures show the old 3.4/17/18/2022 values.

- [ ] **Step 3: Apply the minimal version implementation**

Replace the existing metadata block with:

```ahk
;@Ahk2Exe-SetFileVersion 3.6
;@Ahk2Exe-SetProductVersion 20
;@Ahk2Exe-ExeName SmartZip.exe
buildVersion := 20
MainVersion := "3.6"
;Msgbox FormatTime(A_Now, "yyyy/M/d H:m:s")
buileTime := "2023/1/30 17:46:22"
```

- [ ] **Step 4: Run focused and full tests**

Run:

```powershell
$focused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -TestName 'VersionBanner' -PassThru
$full = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($focused.FailedCount -or $full.FailedCount) { exit 1 }
```

Expected: focused `5/5` pass; full suite `29/29` pass.

- [ ] **Step 5: Commit Task 1**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
git commit -m "feat: update SmartZip version metadata to 3.6"
```

### Task 2: Centralize and Limit `excludeArgs`

**Files:**
- Modify: `tests/SmartZip.Static.Tests.ps1`
- Modify: `SmartZip.ahk:53-97`
- Modify: `SmartZip.ahk:205-245`
- Modify: `SmartZip.ahk:773-795`

**Interfaces:**
- Consumes: `ini.ReadLoop(section, target)` and the existing `this.excludeArgs` command fragment.
- Produces: one initialized `this.excludeArgs` string available to `Unzip` and the all-folder `CreateZip` path.

- [ ] **Step 1: Add reusable source slices**

Place these assignments after the existing `$script:SmartZipSource` assignment and before the Describes:

```powershell
$script:InitBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    Init(argsArr)" -EndMarker "`n    Exec("
$script:OpenZipBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    OpenZip()" -EndMarker "`n    CreateZip()"
$script:GuiBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    Gui()" -EndMarker "`n    Run7z("
$script:Run7zBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    Run7z(" -EndMarker "`n    RecycleItem("
```

- [ ] **Step 2: Append the failing exclude tests**

```powershell
Describe 'ExcludeArgsBuildAndConsume' {

    It 'Init method body can be extracted' {
        [string]::IsNullOrEmpty($script:InitBody) | Should Be $false
    }

    It 'Init reads both exclude lists' {
        $script:InitBody | Should Match 'ReadLoop\(\s*"excludeExt"'
        $script:InitBody | Should Match 'ReadLoop\(\s*"excludeName"'
    }

    It 'Init builds extension and name switches' {
        $script:InitBody | Should Match "this\.excludeArgs\s*\.=\s*'\s*-x!\*\.'\s*i"
        $script:InitBody | Should Match "this\.excludeArgs\s*\.=\s*'\s*-x!\*'\s*i\s*'\*'"
    }

    It 'Init appends recursion only when excludeArgs is non-empty' {
        $ok = Test-Regex -Text $script:InitBody -Pattern `
            '(?s)if\s+this\.excludeArgs\s+this\.excludeArgs\s*\.=\s*"\s*-r"'
        $ok | Should Be $true
    }

    It 'Unzip no longer builds excludeArgs locally' {
        $script:UnzipBody | Should Not Match 'ReadLoop\(\s*"excludeExt"'
        $script:UnzipBody | Should Not Match 'ReadLoop\(\s*"excludeName"'
        $script:UnzipBody | Should Not Match 'this\.excludeArgs\s*:='
    }

    It 'Unzip still consumes excludeArgs on both extraction paths' {
        $matches = [regex]::Matches(
            $script:UnzipBody,
            '(?m)this\.Run7z\([^\r\n]*''x''[^\r\n]*this\.excludeArgs'
        )
        ($matches.Count -ge 2) | Should Be $true
    }

    It 'CreateZip all-folder branch appends excludeArgs' {
        $m = [regex]::Match(
            $script:CreateZipBody,
            '(?s)if\s+count\s*=\s*this\.arr\.Length(.*?)(?:else if\s+this\.arr\.Length\s*=\s*1)'
        )
        $m.Success | Should Be $true
        $m.Groups[1].Value | Should Match "args\s*'\s*""'\s*i\s*'\\\*""'\s*this\.excludeArgs"
    }

    It 'CreateZip single and mixed branches do not append excludeArgs' {
        $singleAndMixed = [regex]::Match(
            $script:CreateZipBody,
            '(?s)else if\s+this\.arr\.Length\s*=\s*1(.*?)(?:IsHide\()'
        )
        $singleAndMixed.Success | Should Be $true
        $singleAndMixed.Groups[1].Value | Should Not Match 'this\.excludeArgs'
    }

    It 'OpenZip aggregate compression does not consume excludeArgs' {
        $script:OpenZipBody | Should Not Match 'this\.excludeArgs'
    }
}
```

- [ ] **Step 3: Run the focused test and confirm RED**

```powershell
Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -TestName 'ExcludeArgsBuildAndConsume' -PassThru
```

Expected: extraction and slice tests may pass, but Init construction, Unzip local-build removal, and all-folder consumption fail.

- [ ] **Step 4: Move the complete builder into `Init`**

After the existing `ini.ReadLoop("extExp", this.extExp)` add:

```ahk
        excludeExt := []
        ini.ReadLoop("excludeExt", excludeExt)
        excludeName := []
        ini.ReadLoop("excludeName", excludeName)
        this.excludeArgs := ""
        for i in excludeExt
            this.excludeArgs .= ' -x!*.' i
        for i in excludeName
            this.excludeArgs .= ' -x!*' i '*'
        if this.excludeArgs
            this.excludeArgs .= " -r"
```

Delete the current `Unzip` block from `excludeExt := []` through `this.excludeArgs .= " -r"`. Do not change the two later `Run7z(... this.excludeArgs ...)` calls.

- [ ] **Step 5: Add `excludeArgs` only to the all-folder compression call**

Replace only the all-folder call with:

```ahk
                this.Run7z(hideBool, 'a', zipName, args ' "' i '\*"' this.excludeArgs, hideBool || count > 1, , A_LineNumber)
```

Do not change the single-file or mixed calls.

- [ ] **Step 6: Run focused and full tests**

```powershell
$focused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -TestName 'ExcludeArgsBuildAndConsume' -PassThru
$full = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($focused.FailedCount -or $full.FailedCount) { exit 1 }
```

Expected: focused `9/9` pass; full `38/38` pass.

- [ ] **Step 7: Commit Task 2**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
git commit -m "feat: apply exclusions to folder batch compression"
```

### Task 3: Safe WMI Query and Exact PID Binding

**Files:**
- Modify: `tests/SmartZip.Static.Tests.ps1`
- Modify: `SmartZip.ahk:80-82`
- Modify: `SmartZip.ahk:1031-1075`

**Interfaces:**
- Consumes: the current `Run7z` `path`, WMI `Win32_Process`, and `this.pid`.
- Produces: `this.query: String`, `this.exactPid: Boolean`, and an exact `this.pid` or an empty PID.
- Provides to Task 4: ErrorMode may sample or kill only when `this.exactPid && this.query`.

- [ ] **Step 1: Append the failing PID/WMI safety tests**

```powershell
Describe 'PidAndWmiSafety' {

    It 'Run7z body can be extracted' {
        [string]::IsNullOrEmpty($script:Run7zBody) | Should Be $false
    }

    It 'Run7z resets pid query and exactPid for every task' {
        $ok = Test-Regex -Text $script:Run7zBody -Pattern `
            '(?s)this\.pid\s*:=\s*""\s*this\.query\s*:=\s*""\s*this\.exactPid\s*:=\s*false'
        $ok | Should Be $true
    }

    It 'WinGetPID stores a 7zG CommandLine query' {
        $script:Run7zBody | Should Match 'this\.query\s*:='
        $script:Run7zBody | Should Match 'Win32_Process'
        $script:Run7zBody | Should Match 'CommandLine\s+like'
    }

    It 'product source forbids a 7zG image-name PID fallback' {
        $bad = Test-Regex -Text $script:SmartZipSource -Pattern `
            'ProcessExist\(\s*["'']7zG\.exe["'']\s*\)'
        $bad | Should Be $false
    }

    It 'WinGetPID requires exactly one WMI match' {
        $script:Run7zBody | Should Match 'matches\.Length\s*!=\s*1'
        $script:Run7zBody | Should Match 'this\.exactPid\s*:=\s*true'
    }

    It 'WinGetPID has a soft failure path' {
        $script:Run7zBody | Should Match 'try'
        $script:Run7zBody | Should Match 'this\.exactPid\s*:=\s*false'
    }

    It 'path escaping covers recovered special characters' {
        $script:Run7zBody | Should Match 'EscapeCharacter'
        foreach ($char in @('\[', '\]', '\^')) {
            $script:Run7zBody | Should Match $char
        }
    }

    It 'CMDPID code is not moved into the GUI PID binding' {
        $script:Run7zBody | Should Not Match 'CMDPID'
    }
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -TestName 'PidAndWmiSafety' -PassThru
```

Expected: the existing no-name-fallback guard passes; query/exactPid/unique-match/escape tests fail.

- [ ] **Step 3: Initialize exact PID fields in `Init`**

Replace:

```ahk
        this.pid := this.log := this.testLog := ''
```

with:

```ahk
        this.pid := this.query := ""
        this.exactPid := false
        this.log := this.testLog := ""
```

- [ ] **Step 4: Reset all task-level PID state at `Run7z` entry**

Replace the first assignment in `Run7z` with:

```ahk
        this.pid := ""
        this.query := ""
        this.exactPid := false
```

- [ ] **Step 5: Replace `WinGetPID` with unique-match soft degradation**

Replace the nested `WinGetPID()` and `GetSize()` block with:

```ahk
        WinGetPID()
        {
            DetectHiddenWindows(1)
            static winmgmts := ""

            try
            {
                if !winmgmts
                    winmgmts := ComObjGet("winmgmts:")

                WinWait("ahk_exe 7zG.exe", , 3)
                this.query := 'Select * from Win32_Process where Name="7zG.exe" and CommandLine like "%' EscapeCharacter(path) '%"'
                matches := []
                for proc in winmgmts.ExecQuery(this.query)
                    matches.Push(proc)

                if matches.Length != 1
                    return ClearExactPid()

                this.pid := matches[1].ProcessID
                if !this.pid
                    return ClearExactPid()
                this.exactPid := true

                if this.to = "x" && this.excludeArgs
                {
                    while (!GetSize())
                    {
                        if A_TickCount - this.now > 1000
                            break
                    }
                    if RegExMatch(GetSize(), "(.+) MB$", &size)
                        this.currentSize := size[1] * 1024 * 1024
                }
                SetTimer(WinGetPID, 0)
            }
            catch
                ClearExactPid()

            ClearExactPid()
            {
                this.pid := ""
                this.query := ""
                this.exactPid := false
            }

            EscapeCharacter(str)
            {
                str := StrReplace(str, "\", "\\")
                for char in ["[", "]", "^"]
                    str := StrReplace(str, char, "_")
                return str
            }

            GetSize()
            {
                size := ""
                try
                    size := ControlGetText("Static15", "ahk_pid " this.pid)
                return size
            }
        }
```

Do not add any `ProcessExist("7zG.exe")` fallback.

- [ ] **Step 6: Run focused and full tests**

```powershell
$focused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -TestName 'PidAndWmiSafety' -PassThru
$full = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($focused.FailedCount -or $full.FailedCount) { exit 1 }
```

Expected: focused `8/8` pass; full `46/46` pass.

- [ ] **Step 7: Commit Task 3**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
git commit -m "fix: bind GUI controls to an exact 7zG process"
```

### Task 4: GUI ErrorMode, IO Sampling, and Timer Lifecycle

**Files:**
- Modify: `tests/SmartZip.Static.Tests.ps1`
- Modify: `SmartZip.ahk:825-1028`

**Interfaces:**
- Consumes: `this.pid`, `this.query`, and `this.exactPid` from Task 3.
- Produces: `g.errorMode`, `g.ioRunning`, `g.io`, `GetWriteIO()`, and guarded force-end behavior.

- [ ] **Step 1: Append the failing ErrorMode tests**

```powershell
Describe 'ErrorModeStateMachine' {

    It 'Gui method body can be extracted' {
        [string]::IsNullOrEmpty($script:GuiBody) | Should Be $false
    }

    It 'Gui initializes explicit error and IO state' {
        $script:GuiBody | Should Match 'g\.errorMode\s*:=\s*false'
        $script:GuiBody | Should Match 'g\.ioRunning\s*:=\s*false'
        $script:GuiBody | Should Match 'g\.io\s*:=\s*0'
    }

    It 'ShellMessage enters ErrorMode only after more than ten failures' {
        $script:GuiBody | Should Match 'static\s+times'
        $script:GuiBody | Should Match 'times\+\+'
        $script:GuiBody | Should Match 'times\s*>\s*10\b'
    }

    It 'ErrorMode uses the 3.6 force-end text' {
        $script:GuiBody | Should Match '界面出现错误'
        $script:GuiBody | Should Match '强制结束'
    }

    It 'IO timer starts at one second behind exact PID and query gates' {
        $script:GuiBody | Should Match 'this\.exactPid\s*&&\s*this\.query'
        $script:GuiBody | Should Match 'SetTimer\(\s*GetWriteIO\s*,\s*1000\s*\)'
    }

    It 'normal parse recovery stops IO and clears ErrorMode' {
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)SetTimer\(\s*GetWriteIO\s*,\s*0\s*\).*?g\.ioRunning\s*:=\s*false.*?g\.errorMode\s*:=\s*false'
        $ok | Should Be $true
    }

    It 'normal GUI speed text update remains present' {
        $script:GuiBody | Should Match 'IsChanged\(\s*速度2\s*,'
    }

    It 'Close stops the IO timer before destroying the GUI' {
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)Close\(\*\).*?SetTimer\(\s*GetWriteIO\s*,\s*0\s*\).*?g\.Destroy\(\)'
        $ok | Should Be $true
    }

    It 'force end requires ErrorMode and exact PID' {
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)ButtonPause\(.*?g\.errorMode\s*&&\s*this\.exactPid.*?ProcessClose\(\s*this\.pid\s*\)'
        $ok | Should Be $true
    }

    It 'show-hide is disabled during ErrorMode or IO sampling' {
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)ButtonShowHide\(.*?if\s+g\.errorMode\s*\|\|\s*g\.ioRunning\s+return'
        $ok | Should Be $true
    }
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -TestName 'ErrorModeStateMachine' -PassThru
```

Expected: method extraction and existing `速度2` test pass; state, threshold, timer, message and guarded button tests fail.

- [ ] **Step 3: Initialize GUI state**

Immediately after `g := Gui("+LastFound")` add:

```ahk
        g.io := 0
        g.ioRunning := false
        g.errorMode := false
```

- [ ] **Step 4: Replace `Close`, add show-hide guard, and add force-end gate**

Use this `Close` body:

```ahk
        Close(*)
        {
            SetTimer(GetWriteIO, 0)
            g.ioRunning := false
            g.errorMode := false
            g.io := 0
            if this.exactPid && this.pid && ProcessExist(this.pid)
                ProcessClose(this.pid), ProcessWaitClose(this.pid)
            if this.HasOwnProp("temp")
                this.RecycleItem(this.temp, A_LineNumber, true)
            if !this.setShow
                ExitApp(255)
            OnMessage(msgNum, ShellMessage, 0), g.Destroy()
        }
```

Add this as the first condition inside `ButtonShowHide`:

```ahk
            if g.errorMode || g.ioRunning
                return
```

Add this before the existing `DetectHiddenWindows(1)` in `ButtonPause`:

```ahk
            if g.errorMode && this.exactPid && this.pid && ProcessExist(this.pid)
            {
                SetTimer(GetWriteIO, 0)
                g.ioRunning := false
                ProcessClose(this.pid)
                return
            }
```

The existing `ControlClick("Button2")` pause path remains the fallback.

- [ ] **Step 5: Add failure transition and recovery to `ShellMessage`**

Change its static declaration to:

```ahk
            static timeSave := A_TickCount
            static times := 0
```

Immediately after `arr := StrSplit(WinGetText(sub()), "`n")` add:

```ahk
                if !arr.Length
                {
                    times++
                    if times > 10
                    {
                        IsChanged(处理3, "界面出现错误,如速度有变动但仍在解压中,长时间未变动可点击强制结束防止卡住")
                        IsChanged(暂停, "强制结束", 1)
                        g.errorMode := true
                        if this.exactPid && this.query
                            SetTimer(GetWriteIO, 1000)
                        times := 0
                    }
                    return
                }

                if g.errorMode || g.ioRunning
                {
                    SetTimer(GetWriteIO, 0)
                    g.ioRunning := false
                    g.errorMode := false
                    g.io := 0
                }
                times := 0
```

Do not remove or replace:

```ahk
                , IsChanged(速度2, arr[index++ ])
```

- [ ] **Step 6: Add the guarded IO sampler inside `Gui`**

Place this local function before `ShellMessage`:

```ahk
        GetWriteIO()
        {
            if !g.errorMode || !this.exactPid || !this.query
                return

            try
            {
                winmgmts := ComObjGet("winmgmts:")
                matches := []
                for proc in winmgmts.ExecQuery(this.query)
                    if proc.ProcessID = this.pid
                        matches.Push(proc)
                if matches.Length != 1
                    return

                io := Round(matches[1].WriteTransferCount / 1024 / 1024)
                if g.io
                    速度2.Text := Round(io - g.io) " MB/s"
                g.io := io
                g.ioRunning := true
            }
        }
```

All WMI failures are swallowed by the local `try`; no catch body is required because failure only skips the current timer tick.

- [ ] **Step 7: Run focused and full tests**

```powershell
$focused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -TestName 'ErrorModeStateMachine' -PassThru
$full = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($focused.FailedCount -or $full.FailedCount) { exit 1 }
```

Expected: focused `10/10` pass; full `56/56` pass.

- [ ] **Step 8: Review the Task 4 source diff before committing**

```powershell
git diff -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
rg -n 'ProcessExist\([\"'']7zG\.exe[\"'']\)|IsChanged\(速度2|times\s*>\s*10|SetTimer\(GetWriteIO' SmartZip.ahk
```

Expected:

- no literal 7zG name fallback;
- one normal `IsChanged(速度2, ...)` remains;
- threshold is `times > 10`;
- timer has a 1000ms start and explicit stop paths.

- [ ] **Step 9: Commit Task 4**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1
git commit -m "feat: add safe 3.6 GUI error recovery"
```

### Task 5: Final Regression and Scope Audit

**Files:**
- Verify: `SmartZip.ahk`
- Verify: `tests/SmartZip.Static.Tests.ps1`
- Verify: `docs/superpowers/specs/2026-07-20-smartzip-36-phase1-design.md`

**Interfaces:**
- Consumes: all Task 1–4 commits.
- Produces: an evidence-backed completion report; no product change unless a failed check sends work back to its owning task.

- [ ] **Step 1: Run the full static suite from a clean PowerShell**

```powershell
$result = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"Passed=$($result.PassedCount) Failed=$($result.FailedCount)"
if ($result.PassedCount -ne 56 -or $result.FailedCount -ne 0) { exit 1 }
```

Expected: `Passed=56 Failed=0`.

- [ ] **Step 2: Run whitespace and repository checks**

```powershell
git diff --check HEAD~4..HEAD
git status --short --branch
```

Expected: no whitespace errors; working tree clean.

- [ ] **Step 3: Prove the four hotfix guards remain**

```powershell
$result = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
$required = @('NestingGate','CreateZipPathInit','IsArchiveExt','SettingsUnZipKey')
foreach ($name in $required) {
    $group = $result.TestResult | Where-Object { $_.Describe -eq $name }
    if (-not $group -or ($group | Where-Object { -not $_.Passed })) { exit 1 }
}
```

Expected: all four Describe groups exist and every test passes.

- [ ] **Step 4: Audit forbidden scope changes**

```powershell
git diff 5489bc7..HEAD -- SmartZip.ahk
rg -n 'hideRunSize\s*:=.*1024|A_LoopFileSizeKB|ProcessExist\([\"'']7zG\.exe[\"'']\)' SmartZip.ahk
```

Expected:

- the diff contains only version, exclude, PID/WMI and GUI ErrorMode changes;
- no `hideRunSize * 1024`;
- no `A_LoopFileSizeKB`;
- no literal 7zG image-name fallback;
- the mixed branch still contains `path := ""`;
- `IsArchive` still contains `this.ext.Has(ext)`;
- settings still contains `IsContextMenuVisible("UnZip")`.

- [ ] **Step 5: Check runtime tool availability and record an honest result**

```powershell
$ahk = Get-Command AutoHotkey64.exe,AutoHotkey.exe -ErrorAction SilentlyContinue
$seven = Get-Command 7z.exe,7zG.exe,7zFM.exe -ErrorAction SilentlyContinue
"AutoHotkeyFound=$([bool]$ahk) SevenZipTools=$($seven.Count)"
```

Expected in the current environment: AutoHotkey v2 and the complete 7-Zip tool set may be unavailable. If either prerequisite is missing, record T1–T16 as `未执行：缺少运行时` and make no runtime-success claim.

- [ ] **Step 6: If the runtime prerequisites exist, execute T1–T16**

Run this matrix:

| ID | Setup and action | Expected |
| --- | --- | --- |
| T1 | Configure `excludeExt=tmp` and `excludeName=skipme`; compress two folders | Command contains both exclude switches and `-r`; excluded entries are absent |
| T2 | Keep the same config; compress one file | Command has no exclude fragment; compression succeeds |
| T3 | Keep the same config; compress one file plus one folder | Command has no exclude fragment; no uninitialized `path` error |
| T4 | Extract an archive containing excluded entries | Both extraction paths still apply `excludeArgs` |
| T5 | Make 7zG GUI text unavailable for more than ten consecutive reads | The 11th failure enters ErrorMode and shows “强制结束” |
| T6 | Restore parseable 7zG text after T5 | Timer stops; state/button recover; normal speed text resumes |
| T7 | Disable WMI or force the query to fail | Compression/extraction continues; no exception or wrong process kill |
| T8 | Keep an unrelated 7zG open and start SmartZip | Only the current command-path process is bound |
| T9 | With multiple 7zG processes, close or force-end SmartZip | Unrelated 7zG processes remain alive |
| T10 | Close or press Esc while IO sampling runs | Timer stops and no callback touches the destroyed GUI |
| T11 | In ErrorMode with an exact PID, press “强制结束” | Only `this.pid` exits |
| T12 | Set `nesting=1`, `nestingMuilt=0`; extract one inner archive | Inner archive continues extracting |
| T13 | Run mixed compression and probe configured `.zip` plus unconfigured `.z` | No path error; `.zip` matches and `.z` does not |
| T14 | Register `UnZip` and open settings | Smart-unzip checkbox is selected |
| T15 | Open the settings version area | SmartZip 3.6, build 20 and the 2023/1/30 timestamp appear |
| T16 | Run minimal `x`, `xc`, `o`, and `a` scenarios | No new crash or entry-point regression |

Expected: every executed item passes. A failure returns to the owning task; do not weaken a static test to hide it.

- [ ] **Step 7: Confirm final commit history and clean tree**

```powershell
git log --oneline -6
git status --porcelain
```

Expected: four focused implementation commits after the plan commit; `git status --porcelain` has no output.

## Self-Review

- **Spec coverage:** Tasks 1–4 map to every IN requirement; Task 5 covers all static, scope and runtime-reporting gates.
- **Placeholders:** Every code-changing step contains exact AHK or Pester content; every command has an expected result.
- **Type consistency:** `this.query` is a string, `this.exactPid` a boolean, `this.pid` empty or numeric, and `g.errorMode`/`g.ioRunning` booleans in every task.
- **Task dependencies:** Task 2 owns the Init exclude builder; Task 3 adds PID fields without changing exclude behavior; Task 4 consumes Task 3’s exact PID contract.
- **TDD order:** Each product change follows a focused RED test and ends with focused plus full GREEN verification.
- **Scope:** No task modifies the OUT areas, `Contextmenu.ahk`, INI defaults, password behavior or hide-size units.
