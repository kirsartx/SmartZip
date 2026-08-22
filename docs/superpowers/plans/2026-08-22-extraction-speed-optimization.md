# SmartZip 解压速度优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`-`) syntax for tracking.

**Goal:** 在不改变 SmartZip 现有安全流水线、用户交互和结果语义的前提下，复用同一次调用链内已经完成的测试和探测结果，减少加密包与嵌套包的重复 7-Zip 子进程。

**Architecture:** `TestArchive` 的成功结果增加仅供内部使用的 `testVerified` 标记，`zipx` 在 `forceTest` 阶段优先消费同路径的已验证结果并保留原始 `TestArchive` 回退。嵌套流程将刚完成的 `ProbeArchive` 结果显式传入 `Unzip`/`zipx`；不做跨运行缓存，路径不匹配时回退到原探测。

**Tech Stack:** AutoHotkey v2, PowerShell 5.1, Pester 3.4, 7-Zip Zstandard 26.02 ZS, Ahk2Exe。

## Global Constraints

- 保留 `probe -> optional test -> isolated extract -> finalize` 的安全流水线语义。
- 不减少解压后的最终 `7z t`，不改变完整性、密码、分卷、隔离输出、源包回收和嵌套规则。
- 保持 `7zG.exe` GUI 路径、进度显示、隐藏规则、命令参数和配置项不变。
- 不引入跨运行缓存、并行解压、7-Zip 参数调优或生产测试钩子。
- `testVerified` 只存在于内存结果对象，不进入诊断日志、脱敏复制内容或集成结果 JSON。
- 只修改当前专用分支中的用户项目文件，保留既有变更。
- 每个生产改动都必须先有能正确失败的测试，并在绿灯后再重构。

---

### Task 1: Establish a clean baseline

**Files:**
- Read: `C:\Users\Kirs\Documents\smartzip优化\tests\README.md`
- Read: `C:\Users\Kirs\Documents\smartzip优化\docs\continuity\ACTIVE_TASK.md`
- Read: `C:\Users\Kirs\Documents\smartzip优化\docs\continuity\DECISIONS.md`

**Interfaces:**
- Consumes: current `SmartZip.ahk`, current Pester/AutoHotkey toolchain.
- Produces: recorded baseline for the focused suites before any test or production edit.

- [ ] **Step 1: Verify the worktree and required tool paths**

Run:

```powershell
git status --short
git diff --check
Test-Path -LiteralPath 'C:\Tool\7-Zip-Zstandard\7z.exe'
```

Expected: `git status --short` is empty, `git diff --check` exits 0, and the 7-Zip probe returns `True`.

- [ ] **Step 2: Run the focused baseline suites**

Run:

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=184
  'PasswordPreflight.Tests.ps1'=98
  'NestingMigration.Tests.ps1'=30
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
```

Expected: `184/184`, `98/98`, and `30/30`, all with zero failures. If a baseline suite fails, stop and report the pre-existing failure before editing.

- [ ] **Step 3: Commit the clean baseline only if the repository requires a checkpoint**

Do not create a content commit for this task; the existing design commit `7707af5` is the baseline checkpoint.

### Task 2: Add red tests for both result handoffs

**Files:**
- Modify: `C:\Users\Kirs\Documents\smartzip优化\tests\SmartZip.Static.Tests.ps1` in the existing `TestArchive uses RunCmdCapture...` and `Unzip zipx entry calls ProbeArchive...` cases.
- Modify: `C:\Users\Kirs\Documents\smartzip优化\tests\NestingMigration.Tests.ps1` in the existing `NestingProductHost`, `RunNestedOrder`, and `nested_requires_probe_stage_before_extract` case.

**Interfaces:**
- Consumes: existing source-slice variables `$script:TestArchiveBody`, `$script:UnzipBody`, and the existing nested host call-order spy.
- Produces: failing assertions that require the approved internal handoff contracts without changing Pester case counts.

- [ ] **Step 1: Add the password-result contract assertions**

Inside the existing `It 'TestArchive uses RunCmdCapture Classify7zResult stage test and -p'` block, append:

```powershell
        (Test-Regex -Text $b -Pattern 'result\.testVerified\s*:=\s*true') | Should Be $true
```

Inside the existing `It 'Unzip zipx entry calls ProbeArchive and ResolveArchivePassword'` block, append:

```powershell
        (Test-Regex -Text $u -Pattern 'testVerified') | Should Be $true
        (Test-Regex -Text $u -Pattern 'tr\s*:=\s*resolved') | Should Be $true
        (Test-Regex -Text $u -Pattern 'TestArchive\s*\(\s*path\s*,\s*resolved\.passwordUsed\s*\)') | Should Be $true
```

These assertions require a marker, a reuse branch, and the original fallback call.

- [ ] **Step 2: Make the nested host observe the optional pre-probe argument**

In `NestingProductHost`, replace the existing `Unzip(path)` spy with:

```ahk
    lastPreProbe := ""

    Unzip(path, preProbe := "") {
        this.callOrder.Push("unzip")
        this.lastPreProbe := preProbe
    }
```

In `Reset()`, add:

```ahk
        this.lastPreProbe := ""
```

At the start of `RunNestedOrder`, add `host.lastPreProbe := ""`. After `orderOk := RunNestedOrder(...)` and before the `orderBad` call, capture:

```ahk
okPreProbe := host.lastPreProbe
```

Extend the existing final assertion to require the exact path that was probed:

```ahk
AssertTrue(okOrder && badOrder && IsObject(okPreProbe)
    && okPreProbe.archivePath = nestZip, "nested_requires_probe_stage_before_extract")
```

- [ ] **Step 3: Run the red tests**

Run:

```powershell
Invoke-Pester -Script '.\tests\SmartZip.Static.Tests.ps1' -PassThru
Invoke-Pester -Script '.\tests\NestingMigration.Tests.ps1' -PassThru
```

Expected: both runs fail because production `SmartZip.ahk` has no `testVerified` reuse branch and `UnZipNesting` still calls `Unzip(path)` without the probe object. The failures must be assertion failures, not parser or harness errors.

- [ ] **Step 4: Commit the red tests**

Run:

```powershell
git add -- 'tests/SmartZip.Static.Tests.ps1' 'tests/NestingMigration.Tests.ps1'
git diff --cached --check
git commit -m "test: define extraction result handoff contracts"
```

Expected: commit succeeds and the staged diff has no whitespace errors.

### Task 3: Implement password test-result reuse

**Files:**
- Modify: `C:\Users\Kirs\Documents\smartzip优化\SmartZip.ahk` in `TestArchive` and the `forceTest` block inside the local `zipx` function.

**Interfaces:**
- Consumes: `ArchiveResult.archivePath`, `ArchiveResult.passwordUsed`, existing `forceTest` expression.
- Produces: an `ArchiveResult` with `testVerified := true` only for successful `TestArchive` calls, and a `tr` value in `zipx` that reuses only a matching successful result.

- [ ] **Step 1: Mark successful test results without storing a new password field**

Replace the current single-line success assignment in `TestArchive`:

```ahk
        if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.OK_WITH_WARNING)
            result.passwordUsed := password
```

with:

```ahk
        if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.OK_WITH_WARNING) {
            result.passwordUsed := password
            result.testVerified := true
        }
```

Do not add `testVerified` to `ArchiveResult.__New` because an untested result must not look reusable by default.

- [ ] **Step 2: Reuse the result only after the existing force-test decision**

Replace the first line inside the existing `if (forceTest)` block:

```ahk
                    tr := this.TestArchive(path, resolved.passwordUsed)
```

with:

```ahk
                    tr := ""
                    if (resolved.HasOwnProp("testVerified") && resolved.testVerified
                        && resolved.archivePath != ""
                        && StrLower(resolved.archivePath) = StrLower(path))
                        tr := resolved
                    else
                        tr := this.TestArchive(path, resolved.passwordUsed)
```

Leave every subsequent `tr.status` branch unchanged. This preserves the logical test stage and the original fallback when a result is not reusable.

- [ ] **Step 3: Run the focused green tests for the password optimization**

Run:

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=184
  'PasswordPreflight.Tests.ps1'=98
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
```

Expected: `184/184` and `98/98`, zero failures. The static assertions prove both the marker and fallback are present; the password harness continues to prove candidate ordering, retries, and redaction.

- [ ] **Step 4: Commit the password optimization**

Run:

```powershell
git add -- 'SmartZip.ahk'
git diff --cached --check
git commit -m "perf: reuse validated password test results"
```

### Task 4: Implement nested probe-result handoff

**Files:**
- Modify: `C:\Users\Kirs\Documents\smartzip优化\SmartZip.ahk` in `Unzip`, the local `zipx`, and `UnZipNesting`.

**Interfaces:**
- Consumes: the `probe` object created immediately before the nested `Unzip` call.
- Produces: `Unzip(loopPath := "", preProbe := "")`, `zipx(path, preProbe := "")`, and a matching-path pre-probe branch with a safe `ProbeArchive` fallback.

- [ ] **Step 1: Add the optional pre-probe parameter to `Unzip` and pass it to `zipx`**

Change the method signature and the local call as follows:

```ahk
    Unzip(loopPath := "", preProbe := "")
```

```ahk
            zipResult := zipx(i, preProbe)
```

Top-level callers continue to use the default empty value.

- [ ] **Step 2: Add the matching-path fallback in `zipx`**

Change the local function signature:

```ahk
        zipx(path, preProbe := "")
```

Replace the direct probe assignment after volume normalization:

```ahk
            probe := this.ProbeArchive(path)
```

with:

```ahk
            if (IsObject(preProbe) && preProbe.HasOwnProp("archivePath")
                && preProbe.archivePath != ""
                && StrLower(preProbe.archivePath) = StrLower(path))
                probe := preProbe
            else
                probe := this.ProbeArchive(path)
```

The check remains after volume normalization so a path change cannot accidentally consume a result for a different archive.

- [ ] **Step 3: Pass the probe from `UnZipNesting`**

Replace the nested call:

```ahk
            this.Unzip(path)
```

with:

```ahk
            this.Unzip(path, probe)
```

Keep the existing `ProbeArchive` status switch and nested source-recycle comments unchanged.

- [ ] **Step 4: Run the focused green nested tests**

Run:

```powershell
$r = Invoke-Pester -Script '.\tests\NestingMigration.Tests.ps1' -PassThru
if ($r.FailedCount -ne 0 -or $r.PassedCount -ne 30) {
    throw "NestingMigration.Tests.ps1: expected 30/0, got $($r.PassedCount)/$($r.FailedCount)"
}
```

Expected: `30/30`, zero failures, including the new assertion that the exact probe object reaches nested `Unzip`.

- [ ] **Step 5: Commit the nested optimization**

Run:

```powershell
git add -- 'SmartZip.ahk' 'tests/NestingMigration.Tests.ps1'
git diff --cached --check
git commit -m "perf: reuse nested archive probe results"
```

### Task 5: Verify unchanged user-visible contracts

**Files:**
- Read: `C:\Users\Kirs\Documents\smartzip优化\tests\SmartZip.Static.Tests.ps1`
- Read: `C:\Users\Kirs\Documents\smartzip优化\tests\ExtractionLifecycle.Tests.ps1`
- Read: `C:\Users\Kirs\Documents\smartzip优化\tests\Real7Zip.Integration.Tests.ps1`

**Interfaces:**
- Consumes: optimized `SmartZip.ahk` and existing eight-suite contract gate.
- Produces: evidence that final extraction testing, output-state decisions, password recovery, volumes, nesting, and production hook boundaries remain unchanged.

- [ ] **Step 1: Run the complete contract gate in the documented order**

Run:

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=184
  'ArchiveDiagnostics.Tests.ps1'=193
  'RunCmdCapture.Tests.ps1'=15
  'PasswordPreflight.Tests.ps1'=98
  'ExtractionLifecycle.Tests.ps1'=39
  'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=53
  'Real7Zip.Integration.Tests.ps1'=36
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
& 'C:\Tool\7-Zip-Zstandard\7z.exe' i | Select-Object -First 5
```

Expected: `184/184`, `193/193`, `15/15`, `98/98`, `39/39`, `30/30`, `53/53`, and `36/36`; zero failures; clean diff check; 7-Zip reports `26.02 ZS`.

- [ ] **Step 2: Measure representative integration runtime without a hard threshold**

Run the same real integration suite twice and record the wall-clock values:

```powershell
1..2 | ForEach-Object {
    $elapsed = Measure-Command {
        $r = Invoke-Pester -Script '.\tests\Real7Zip.Integration.Tests.ps1' -PassThru
        if ($r.FailedCount -ne 0 -or $r.PassedCount -ne 36) {
            throw "Real7Zip.Integration.Tests.ps1: expected 36/0, got $($r.PassedCount)/$($r.FailedCount)"
        }
    }
    [pscustomobject]@{ Run = $_; TotalMilliseconds = [math]::Round($elapsed.TotalMilliseconds, 0) }
}
```

Expected: both runs remain `36/36`; report the measured values as evidence, without failing on a machine-dependent time target.

- [ ] **Step 3: Confirm no production test hook or new secret-bearing output exists**

Run:

```powershell
rg -n -S 'IntegrationTestHook|testVerified|passwordUsed' SmartZip.ahk tests/IntegrationTestHook.ahk
```

Expected: `SmartZip.ahk` contains `testVerified` only in internal result/reuse logic, contains no `IntegrationTestHook`, and no new diagnostic/JSON composition includes `testVerified` or `passwordUsed`.

### Task 6: Update continuity records and finish the branch

**Files:**
- Modify: `C:\Users\Kirs\Documents\smartzip优化\docs\continuity\ACTIVE_TASK.md`
- Modify: `C:\Users\Kirs\Documents\smartzip优化\docs\continuity\DECISIONS.md`
- Read: `C:\Users\Kirs\Documents\smartzip优化\tests\README.md`

**Interfaces:**
- Consumes: exact commit hashes, test outputs, measured runtime values, and final `git status --short` output from Tasks 1–5.
- Produces: a handoff record that identifies the two result-handoff optimizations, changed files, exact verification commands/results, and any remaining manual acceptance.

- [ ] **Step 1: Record the stable performance decisions**

Append a decision entry stating that successful `TestArchive` results are reused only within the same synchronous pipeline when `testVerified` and the normalized archive path match; nested `ProbeArchive` results are passed only to the immediately following nested `Unzip`; no cross-run cache or final post-extract test removal is allowed.

- [ ] **Step 2: Record the active task state**

Update `ACTIVE_TASK.md` with the optimization goal, completed red-green cycles, changed files, exact suite totals, 7-Zip probe result, benchmark values, and remaining work. Do not record passwords, API keys, session IDs, or unredacted logs.

- [ ] **Step 3: Verify and commit continuity documentation**

Run:

```powershell
git diff --check
git status --short
```

Expected: diff check exits 0 and `git status --short` is empty after committing the continuity update:

```powershell
git add -- 'docs/continuity/ACTIVE_TASK.md' 'docs/continuity/DECISIONS.md'
git diff --cached --check
git commit -m "docs: record extraction speed optimization handoff"
```

### Final handoff

After all tasks pass, report:

- The two internal handoffs implemented and why they preserve existing behavior.
- Exact focused and complete test totals.
- 7-Zip version probe and measured benchmark values.
- Changed files and commit hashes.
- Explicitly state whether any tests were not run.
