# SmartZip Correctness Hotfix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore correct SmartZip behavior for single-entry nesting under default settings, mixed file/folder CreateZip path building, exact extension map lookup in `IsArchive`, and settings-page smart-unzip registry key casing—without architecture changes—validated first by Pester 3.4 static regressions then by manual runtime checks where AutoHotkey and 7-Zip exist.

**Architecture:** Four minimal edits in the single source file `SmartZip.ahk` (nesting control-flow gate, one local `path` init, `IsArchive` map query body, one settings call-site string). Static verification is pure source inspection via `tests/SmartZip.Static.Tests.ps1` (Pester 3.4.0). Runtime matrix rows T1–T13 remain manual because this environment has no AutoHotkey or 7-Zip executables.

**Tech Stack:** AutoHotkey v2 (`SmartZip.ahk`), Windows PowerShell, Pester 3.4.0 (classic `Should` pipe syntax only—no Pester 5 `-Be` forms), Git.

## Global Constraints

- Modify only `SmartZip.ahk` business logic in the four regions named below; create only `tests/SmartZip.Static.Tests.ps1` for automated checks.
- Do not split `SmartZip.ahk`, refactor GUI or 7-Zip call layers, change INI structure/defaults, CLI (`x`/`xc`/`o`/`a`), right-click menu display names, password/sort/log policy, or multi-volume formats.
- Do not change empty-extension behavior or `extExp` regex handling in `IsArchive` beyond removing the broken ordinary-ext path.
- Do not rename `nestingMuilt`, `openZip`/`addZip`/`unZipCP` checkbox call sites, `CheckCMD` profile `"unZip"`, or `ContextMenu` registry write paths.
- Do not introduce runtime dependencies, install steps, or config migration.
- Pester must use 3.4 classic syntax: `$x | Should Be $y`, `Should Match`, `Should Not Match`, `Should Exist`. Never `Should -Be`.
- Final automated gate on this machine: `Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -PassThru` with `FailedCount = 0`.
- Runtime scenarios (nested archives, 7-Zip compress, registry menu, GUI) cannot be auto-executed without AutoHotkey v2 and 7-Zip; they appear only as a manual checklist in Task 5.

---

## File Structure

| Path | Action | Responsibility |
| --- | --- | --- |
| `SmartZip.ahk` | Modify (four regions only) | Product fixes: Unzip nesting gate ~336–345; CreateZip mixed branch ~793–798; `IsArchive` ~1122–1141; settings checkbox ~1394 |
| `tests/SmartZip.Static.Tests.ps1` | Create | Pester 3.4 static regression: load `SmartZip.ahk` as text, assert structural invariants per defect |

No other source, test, INI, or menu files are in scope.

---

### Task 1: Unzip single-entry nesting gate

**Files:**
- Create: `tests/SmartZip.Static.Tests.ps1` (harness helpers + `Describe 'NestingGate'`)
- Modify: `SmartZip.ahk:336-345` (delete shared early-continue only)
- Test: `tests/SmartZip.Static.Tests.ps1`

**Interfaces:**
- Consumes: `this.nesting` (bool/int from INI `nesting`), `this.nestingMuilt` (bool/int from INI `nestingMuilt`), `isDir` (from `DirExist(souceFile)`), `outFile`, `ext`, nested function `UnZipNesting(path, ext)`
- Produces: control flow only—after single-entry move/recycle, file results nest when `this.nesting` is truthy; directory results nest when `this.nestingMuilt` is truthy; both off means neither branch runs. No new functions or return values.
- Spec matrix: static structure for T1–T4; runtime T1–T4 manual in Task 5

- [ ] **Step 1: Create `tests` directory and write failing NestingGate static suite**

Create directory `tests` if missing. Write the full file `tests/SmartZip.Static.Tests.ps1` with exactly the content below (helpers + NestingGate only for this task’s red/green cycle; later tasks append Describes).

```powershell
#requires -Version 5.0
<#
.SYNOPSIS
  Static regression tests for SmartZip.ahk correctness hotfixes (no AutoHotkey runtime).

.NOTES
  Pester 3.4.0 only — classic Should syntax (pipe form).
  Run:
    Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -PassThru
#>

$ErrorActionPreference = 'Stop'

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$script:SmartZipPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\SmartZip.ahk'))

function Get-SmartZipSource {
    if (-not (Test-Path -LiteralPath $script:SmartZipPath)) {
        throw "SmartZip.ahk not found at: $script:SmartZipPath"
    }
    $raw = Get-Content -LiteralPath $script:SmartZipPath -Raw -Encoding UTF8
    if ($raw -notmatch '文件文件夹混合|多个文件') {
        $raw = Get-Content -LiteralPath $script:SmartZipPath -Raw
    }
    return $raw
}

function Get-SourceSlice {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$StartMarker,
        [Parameter(Mandatory = $true)][string]$EndMarker
    )
    $start = $Source.IndexOf($StartMarker)
    if ($start -lt 0) {
        return $null
    }
    $from = $start
    $end = $Source.IndexOf($EndMarker, $from + $StartMarker.Length)
    if ($end -lt 0) {
        return $Source.Substring($from)
    }
    return $Source.Substring($from, $end - $from)
}

function Test-Regex {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern
    )
    return [bool]([regex]::IsMatch($Text, $Pattern))
}

$script:SmartZipSource = Get-SmartZipSource
$script:UnzipBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    Unzip(loopPath" -EndMarker "`n    OpenZip()"
$script:CreateZipBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    CreateZip()" -EndMarker "`n    Gui()"
$script:IsArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    RunCmd("

Describe 'NestingGate' {

    It 'source file SmartZip.ahk exists next to tests folder' {
        $script:SmartZipPath | Should Exist
    }

    It 'Unzip method body can be extracted' {
        [string]::IsNullOrEmpty($script:UnzipBody) | Should Be $false
        $script:UnzipBody | Should Match 'UnZipNesting'
    }

    It 'does not share early-continue requiring both nesting AND nestingMuilt' {
        $hasSharedGate = Test-Regex -Text $script:UnzipBody -Pattern `
            'if\s*!this\.nesting\s*\|\|\s*!this\.nestingMuilt\s*\r?\n\s*continue'
        $hasSharedGate | Should Be $false
    }

    It 'does not gate single-entry nesting with OR of inverted nesting flags' {
        $hasOrGate = Test-Regex -Text $script:UnzipBody -Pattern `
            'if\s*!this\.nesting\s*\|\|\s*!this\.nestingMuilt'
        $hasOrGate | Should Be $false
    }

    It 'file branch still calls UnZipNesting only when this.nesting is true' {
        $ok = Test-Regex -Text $script:UnzipBody -Pattern `
            '(?s)if\s*!isDir\s*\{[^}]*if\s*this\.nesting\s+UnZipNesting\s*\('
        $ok | Should Be $true
    }

    It 'directory branch still loops UnZipNesting only when this.nestingMuilt is true' {
        $ok = Test-Regex -Text $script:UnzipBody -Pattern `
            '(?s)\}?\s*else if\s*this\.nestingMuilt\s+loop files[^\r\n]*\r?\n\s*UnZipNesting\s*\('
        $ok | Should Be $true
    }

    It 'multi-file branch still has nestingMuilt loop for UnZipNesting' {
        $ok = Test-Regex -Text $script:UnzipBody -Pattern `
            '(?s);多个文件.*?if\s*this\.nestingMuilt\s+loop files.*?UnZipNesting\s*\('
        $ok | Should Be $true
    }
}
```

- [ ] **Step 2: Run NestingGate tests to verify red on current source**

Run from repository root:

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -TestName '*NestingGate*' -PassThru
```

Expected:
- Total tests in NestingGate: 7
- Failed: at least 2 (`does not share early-continue...`, `does not gate single-entry nesting with OR...`)
- Failure shape (Pester 3.4): `Expected: {False}` / `But was:  {True}` because shared gate `if !this.nesting || !this.nestingMuilt` / `continue` is still present near line 336
- Passing smoke: source exists, Unzip body extracted, file/dir/multi-file nesting branch shapes still match

- [ ] **Step 3: Apply minimal AHK v2 fix in `Unzip` single-entry block**

In `SmartZip.ahk`, locate the single-entry block after `this.RecycleItem(tmpDir, A_LineNumber, true)` (currently ~324–345). **Delete only** the shared gate:

```ahk
                if !this.nesting || !this.nestingMuilt
                    continue
```

Leave the per-type body unchanged so the block becomes:

```ahk
                outFile := this.MoveItem(souceFile, A_WorkingDir "\" name, isDir, A_LineNumber)

                this.RecycleItem(tmpDir, A_LineNumber, true)

                if !isDir
                {
                    if this.nesting
                        UnZipNesting(outFile, ext)
                } else if this.nestingMuilt
                    loop files outFile "\*.*", "F"
                        UnZipNesting(A_LoopFileFullPath, A_LoopFileExt)

            } else	;多个文件
```

Do not edit the multi-file branch (`} else { ... if this.nestingMuilt ...}` ~347–354). Do not rename `nestingMuilt`. Do not change INI defaults (`nesting=1`, `nestingMuilt=0`).

- [ ] **Step 4: Run NestingGate tests to verify green**

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -TestName '*NestingGate*' -PassThru
```

Expected: all NestingGate Its pass; `FailedCount = 0` for this filter.

- [ ] **Step 5: Commit Task 1**

```powershell
git add tests/SmartZip.Static.Tests.ps1 SmartZip.ahk
git commit -m "fix: allow default single-entry nesting without nestingMuilt" `
  -m "Remove the shared early-continue that required both nesting flags. File nesting follows nesting only; directory nesting follows nestingMuilt. Add Pester 3.4 static NestingGate regressions."
```

---

### Task 2: CreateZip mixed path initialization

**Files:**
- Modify: `SmartZip.ahk:793-798` (mixed file/folder branch inside `CreateZip`)
- Modify: `tests/SmartZip.Static.Tests.ps1` (append `Describe 'CreateZipPathInit'`)
- Test: `tests/SmartZip.Static.Tests.ps1`

**Interfaces:**
- Consumes: `this.arr` (array of input paths), local `args`/`ext` from `ini.add`, `this.AUO(...)`, `this.Run7z(...)`
- Produces: local string `path` of space-separated quoted inputs for the mixed branch only, passed as `args path` to `Run7z`
- Spec matrix: static structure for T5; T6/T7 branch-shape non-regression; runtime T5–T7 manual in Task 5

- [ ] **Step 1: Append failing CreateZipPathInit Describe to the test file**

Append the following complete block to the end of `tests/SmartZip.Static.Tests.ps1` (do not remove NestingGate). Helpers `$script:CreateZipBody` and `Test-Regex` already exist from Task 1.

```powershell
Describe 'CreateZipPathInit' {

    It 'CreateZip method body can be extracted (excludes OpenZip)' {
        [string]::IsNullOrEmpty($script:CreateZipBody) | Should Be $false
        $script:CreateZipBody | Should Match 'CreateZip\s*\('
        $script:CreateZipBody | Should Not Match 'OpenZip\s*\('
    }

    It 'mixed file/folder branch still concatenates quoted paths with path .=' {
        $ok = Test-Regex -Text $script:CreateZipBody -Pattern `
            "(?s);文件文件夹混合\s*\{.*?path\s*\.=\s*'\s*""\s*i\s*""\s*'"
        $ok | Should Be $true
    }

    It 'mixed branch initializes path := "" before path .=' {
        $ok = Test-Regex -Text $script:CreateZipBody -Pattern `
            '(?s);文件文件夹混合\s*\{\s*path\s*:=\s*""\s*for\s+i\s+in\s+this\.arr\s+path\s*\.='
        $ok | Should Be $true
    }

    It 'path empty-init appears before first path .= inside mixed branch body' {
        $m = [regex]::Match(
            $script:CreateZipBody,
            '(?s);文件文件夹混合\s*\{(.*?)this\.Run7z'
        )
        $m.Success | Should Be $true
        $mixed = $m.Groups[1].Value

        $init = [regex]::Match($mixed, 'path\s*:=\s*""')
        $concat = [regex]::Match($mixed, 'path\s*\.=')

        $init.Success | Should Be $true
        $concat.Success | Should Be $true
        ($init.Index -lt $concat.Index) | Should Be $true
    }
}
```

- [ ] **Step 2: Run CreateZipPathInit tests to verify red**

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -TestName '*CreateZipPathInit*' -PassThru
```

Expected:
- Failed: at least 2 Its requiring `path := ""` before mixed `path .=` (current mixed branch has `for` + `path .=` with no init ~795–796)
- Failure shape: `Expected: {True}` / `But was:  {False}` for missing `path := ""`
- Smoke Its (body extract, still has `path .=`) pass
- NestingGate remains green if re-run without `-TestName` filter later

- [ ] **Step 3: Apply minimal AHK v2 fix in CreateZip mixed branch**

In `SmartZip.ahk` `CreateZip()`, replace the mixed branch (~793–798) so `path` is initialized before concatenation. Mirror `OpenZip` ~754–756. Full fixed branch:

```ahk
        else	;文件文件夹混合
        {
            path := ""
            for i in this.arr
                path .= ' "' i '" '
            this.Run7z(hideBool, 'a', this.AUO(RegExReplace(A_WorkingDir, ".+\\"), ext), args path, hideBool, , A_LineNumber)
        }
```

Do not change the all-directories branch (~776–789), the single-file branch (~791–792), quote format, `AUO`, or `Run7z` argument order. Do not init `path` at the top of `CreateZip` for other branches. Do not edit `OpenZip`.

- [ ] **Step 4: Run CreateZipPathInit tests to verify green**

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -TestName '*CreateZipPathInit*' -PassThru
```

Expected: all CreateZipPathInit Its pass; `FailedCount = 0` for this filter.

- [ ] **Step 5: Commit Task 2**

```powershell
git add tests/SmartZip.Static.Tests.ps1 SmartZip.ahk
git commit -m "fix: initialize path before mixed CreateZip concatenation" `
  -m "AHK v2 rejects path .= on an unassigned local. Initialize path to empty string in the file/folder mixed branch only. Add static CreateZipPathInit tests."
```

---

### Task 3: IsArchive exact map lookup (C3 + C4)

**Files:**
- Modify: `SmartZip.ahk:1122-1141` (`IsArchive(ext)` body)
- Modify: `tests/SmartZip.Static.Tests.ps1` (append `Describe 'IsArchiveExt'`)
- Test: `tests/SmartZip.Static.Tests.ps1`

**Interfaces:**
- Consumes: parameter `ext` (string), `this.ext` (`Map` of lowercased ordinary extensions from `ini.ReadLoop("ext", this.ext, true)`), `this.extExp` (array of regex strings)
- Produces: `true` if empty ext, or exact `this.ext.Has(ext)`, or any `extExp` match; otherwise `false`
- Spec matrix: static structure for T8–T10; runtime T8–T10 manual in Task 5

- [ ] **Step 1: Append failing IsArchiveExt Describe to the test file**

Append this complete block to the end of `tests/SmartZip.Static.Tests.ps1`:

```powershell
Describe 'IsArchiveExt' {

    It 'IsArchive method body can be extracted' {
        [string]::IsNullOrEmpty($script:IsArchiveBody) | Should Be $false
        $script:IsArchiveBody | Should Match 'IsArchive\s*\(\s*ext\s*\)'
    }

    It 'returns true when extension is empty' {
        $ok = Test-Regex -Text $script:IsArchiveBody -Pattern `
            '(?s)if\s*!ext\s+return\s+true'
        $ok | Should Be $true
    }

    It 'uses this.ext.Has(ext) for exact map lookup' {
        $ok = Test-Regex -Text $script:IsArchiveBody -Pattern `
            'this\.ext\.Has\(\s*ext\s*\)'
        $ok | Should Be $true
    }

    It 'does not call this.ext.Has(zip) with undefined zip' {
        $bad = Test-Regex -Text $script:IsArchiveBody -Pattern `
            'this\.ext\.Has\(\s*zip\s*\)'
        $bad | Should Be $false
    }

    It 'does not substring-match map keys via InStr(i, ext) over this.ext' {
        $bad = Test-Regex -Text $script:IsArchiveBody -Pattern `
            '(?s)for\s+i\s*,\s*n\s+in\s+this\.ext\s+if\s+InStr\(\s*i\s*,\s*ext\s*\)'
        $bad | Should Be $false
    }

    It 'still loops this.extExp with regex match on ext' {
        $ok = Test-Regex -Text $script:IsArchiveBody -Pattern `
            '(?s)for\s+i\s+in\s+this\.extExp\s+if\s+ext\s*~='
        $ok | Should Be $true
    }

    It 'still lowercases ext before checks' {
        $ok = Test-Regex -Text $script:IsArchiveBody -Pattern `
            'ext\s*:=\s*StrLower\s*\(\s*ext\s*\)'
        $ok | Should Be $true
    }
}
```

- [ ] **Step 2: Run IsArchiveExt tests to verify red**

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -TestName '*IsArchiveExt*' -PassThru
```

Expected:
- Failed: 3 Its — missing `Has(ext)`, presence of `Has(zip)`, presence of `for i, n in this.ext` + `InStr(i, ext)` (~1129–1134)
- Passing: body extract, empty-ext true, `extExp` loop, `StrLower`
- Failure shapes: `Expected: {True}` when `Has(ext)` absent; `Expected: {False}` when bad patterns still present

- [ ] **Step 3: Apply minimal AHK v2 fix to `IsArchive`**

Replace the entire `IsArchive` method (`SmartZip.ahk` ~1122–1141) with:

```ahk
    IsArchive(ext)
    {
        ext := StrLower(ext)

        if !ext
            return true

        if this.ext.Has(ext)
            return true

        for i in this.extExp
            if ext ~= "i)" i
                return true

        return false
    }
```

Concrete changes vs current:
1. `this.ext.Has(zip)` → `this.ext.Has(ext)`
2. Delete the entire loop:
   ```ahk
        for i, n in this.ext
            if InStr(i, ext)
                return true
   ```
3. Keep `StrLower`, empty-ext `return true`, `extExp` loop, final `return false`

Do not change `ini.ReadLoop("ext", ...)` or INI extension defaults. Do not reintroduce substring matching.

- [ ] **Step 4: Run IsArchiveExt tests to verify green**

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -TestName '*IsArchiveExt*' -PassThru
```

Expected: all IsArchiveExt Its pass; `FailedCount = 0` for this filter.

- [ ] **Step 5: Commit Task 3**

```powershell
git add tests/SmartZip.Static.Tests.ps1 SmartZip.ahk
git commit -m "fix: use exact Map.Has(ext) in IsArchive" `
  -m "Replace undefined Has(zip) and InStr substring scanning with exact extension map lookup. Preserve empty-ext true and extExp regex rules. Add static IsArchiveExt regressions."
```

---

### Task 4: Settings IsContextMenuVisible UnZip key

**Files:**
- Modify: `SmartZip.ahk:1394` (smart-unzip settings checkbox only)
- Modify: `tests/SmartZip.Static.Tests.ps1` (append `Describe 'SettingsUnZipKey'`)
- Test: `tests/SmartZip.Static.Tests.ps1`

**Interfaces:**
- Consumes: nested function `IsContextMenuVisible(what)` which branches on `what = "UnZip" || what = "unZipCP"` to read `keyPathForFile "\" what`; `ContextMenu` registers smart unzip at `keyPathForFile "\UnZip"`
- Produces: initial `Checked` state for the 智能解压 checkbox (`o1`) only
- Spec matrix: static structure for T11–T12; runtime T11–T12 manual in Task 5

- [ ] **Step 1: Append failing SettingsUnZipKey Describe to the test file**

Append this complete block to the end of `tests/SmartZip.Static.Tests.ps1`:

```powershell
Describe 'SettingsUnZipKey' {

    It 'smart unzip checkbox uses IsContextMenuVisible("UnZip") capital U' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'IsContextMenuVisible\(\s*"UnZip"\s*\)'
        $ok | Should Be $true
    }

    It 'does not call IsContextMenuVisible("unZip") for smart unzip' {
        # Pattern ends at closing quote so "unZipCP" is not a false positive.
        $bad = Test-Regex -Text $script:SmartZipSource -Pattern `
            'IsContextMenuVisible\(\s*"unZip"\s*\)'
        $bad | Should Be $false
    }

    It 'leaves openZip checkbox key as openZip' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'IsContextMenuVisible\(\s*"openZip"\s*\)'
        $ok | Should Be $true
    }

    It 'leaves addZip checkbox key as addZip' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'IsContextMenuVisible\(\s*"addZip"\s*\)'
        $ok | Should Be $true
    }

    It 'leaves unZipCP checkbox key as unZipCP' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'IsContextMenuVisible\(\s*"unZipCP"\s*\)'
        $ok | Should Be $true
    }

    It 'IsContextMenuVisible still treats UnZip as file-shell key' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'if\s+what\s*=\s*"UnZip"\s*\|\|\s*what\s*=\s*"unZipCP"'
        $ok | Should Be $true
    }
}
```

- [ ] **Step 2: Run SettingsUnZipKey tests to verify red**

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -TestName '*SettingsUnZipKey*' -PassThru
```

Expected:
- Failed: 2 Its — missing `IsContextMenuVisible("UnZip")`, still has `IsContextMenuVisible("unZip")` at ~1394
- Passing: openZip / addZip / unZipCP call sites; helper branch `what = "UnZip" || what = "unZipCP"`
- Failure shapes: `Expected: {True}` for required `"UnZip"`; `Expected: {False}` while `"unZip"` call remains

- [ ] **Step 3: Apply minimal AHK v2 fix at settings checkbox**

Change only line ~1394 in `SmartZip.ahk` from:

```ahk
    o1 := set.AddCheckbox("r1.5 Checked" IsContextMenuVisible("unZip"), ini.unZipName)
```

to:

```ahk
    o1 := set.AddCheckbox("r1.5 Checked" IsContextMenuVisible("UnZip"), ini.unZipName)
```

Do not change:
- `IsContextMenuVisible("openZip")` (~1393)
- `IsContextMenuVisible("addZip")` (~1395)
- `IsContextMenuVisible("unZipCP")` (~1396)
- body of `IsContextMenuVisible` (~1670–1676)
- `ContextMenu` registry paths for `UnZip` / `unZipCP` / `OpenZip` / `AddZip`
- `CheckCMD(what := "unZip", ...)` (~1181) — that string is a log-profile name, not a shell key

- [ ] **Step 4: Run SettingsUnZipKey tests to verify green**

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -TestName '*SettingsUnZipKey*' -PassThru
```

Expected: all SettingsUnZipKey Its pass; `FailedCount = 0` for this filter.

- [ ] **Step 5: Commit Task 4**

```powershell
git add tests/SmartZip.Static.Tests.ps1 SmartZip.ahk
git commit -m "fix: read smart-unzip menu state with UnZip registry key" `
  -m "Settings checkbox called IsContextMenuVisible('unZip'), which misses the file-shell UnZip path and always appears unchecked. Align call with ContextMenu registration. Add static SettingsUnZipKey regressions."
```

---

### Task 5: Full static regression and integration checklist

**Files:**
- Verify only: `tests/SmartZip.Static.Tests.ps1`, `SmartZip.ahk` (no further product edits unless a regression is found)
- Test: full suite via `Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -PassThru`

**Interfaces:**
- Consumes: all Task 1–4 static invariants and the four product regions
- Produces: confirmation that automated gate is green; documented manual checklist for environments with AutoHotkey v2 + 7-Zip

- [ ] **Step 1: Run full Pester 3.4 static suite**

From repository root:

```powershell
Invoke-Pester -Script tests/SmartZip.Static.Tests.ps1 -PassThru
```

Expected:
- Describes present: `NestingGate`, `CreateZipPathInit`, `IsArchiveExt`, `SettingsUnZipKey`
- Approximate total: 24 Its (7 + 4 + 7 + 6)
- `FailedCount = 0`, `PassedCount` equals total
- No script load errors (UTF-8 Chinese comment anchors resolve)

- [ ] **Step 2: Run whitespace and tree hygiene checks**

```powershell
git diff --check
git status --short
```

Expected:
- `git diff --check`: no output (no trailing whitespace / conflict-marker errors in touched files)
- `git status --short`: only intentional paths dirty or clean after commits—typically empty working tree if Tasks 1–4 were committed; if any uncommitted fix remains, only `SmartZip.ahk` and/or `tests/SmartZip.Static.Tests.ps1` (plus this plan under `docs/superpowers/plans/` if tracked). No accidental edits to `Contextmenu.ahk`, INI, or unrelated assets.

- [ ] **Step 3: Confirm diff scope against design**

```powershell
git log --oneline -5
git diff HEAD~4..HEAD --stat
```

Expected product touch surface (across Task 1–4 commits):
- `SmartZip.ahk`: only nesting gate deletion, `path := ""` in CreateZip mixed branch, `IsArchive` map lookup, settings `"UnZip"` string
- `tests/SmartZip.Static.Tests.ps1`: created and extended
- No changes to INI defaults, CLI entry points, or menu registration write paths

- [ ] **Step 4: Manual integration checklist (requires AutoHotkey v2 + 7-Zip — not auto-runnable on this machine)**

**Environment note:** The current host has **no AutoHotkey executable and no 7-Zip executable**. Steps below cannot be automated here. Perform them on a Windows machine with AutoHotkey v2 and 7-Zip installed before calling the hotfix done for runtime acceptance.

| ID | Scenario | Setup / input | Expected |
| --- | --- | --- | --- |
| T1 | Default single-file nesting | `nesting=1`, `nestingMuilt=0`; outer archive contains exactly one nested archive file | Inner archive continues to auto-extract via `UnZipNesting` |
| T2 | Nesting off | `nesting=0`, `nestingMuilt=0` | Inner archive remains as a normal extracted file |
| T3 | Dir nesting off | `nesting=1`, `nestingMuilt=0`; single-entry result is a directory containing archives | Directory is **not** walked for further nesting |
| T4 | Dir nesting on | `nesting=1`, `nestingMuilt=1` | First-level files in that directory go through `UnZipNesting` as before |
| T5 | Mixed compress | Select one file + one directory, command `a` | No unassigned-variable error; one archive is produced |
| T6 | Single-file compress regression | One file, command `a` | Behavior and output naming unchanged |
| T7 | Multi-directory compress regression | Two directories, command `a` | Each directory produces its own archive |
| T8 | Exact extension hit | Configured `.zip` / `.7z` / `.rar` | `IsArchive` true; existing open/extract paths apply |
| T9 | Substring false positive gone | Unconfigured `.z` / `.ip` | Ordinary map path does **not** return true |
| T10 | Regex extension regression | Extension matching an `extExp` rule | Still returns true via regex loop |
| T11 | Smart unzip registered | Register `UnZip` menu, reopen settings | 智能解压 checkbox checked |
| T12 | Smart unzip unregistered | Delete `UnZip` menu, reopen settings | 智能解压 checkbox unchecked |
| T13 | Entry regression | Basic `x`, `xc`, `o`, `a` scenarios | No new exceptions; existing interaction preserved |

**Acceptance (from design):**
1. T1, T2, T5, T8, T9, T11, T12 all pass on a machine with AutoHotkey v2 + 7-Zip.
2. T3, T4, T6, T7, T10, T13 show no behavioral regression.
3. Diff limited to the four logic regions + static tests (and this plan if committed separately).
4. No new config keys, dependencies, or migration steps.
5. AutoHotkey v2 syntax check passes where `Ahk2Exe` / `AutoHotkey64.exe /ErrorStdOut` is available; executable scenarios completed only in that environment.

- [ ] **Step 5: Final verification commit only if anything remains uncommitted**

If Task 5 found no code changes:

```powershell
git status --short
```

Expected: clean tree for product/test files (or only docs). Do not invent a no-op commit.

If a last-minute static-test hardening was required:

```powershell
git add tests/SmartZip.Static.Tests.ps1 SmartZip.ahk
git commit -m "test: complete SmartZip static correctness hotfix suite" `
  -m "Ensure full Pester 3.4 regression covers nesting, CreateZip path init, IsArchive exact map, and UnZip settings key after all hotfixes."
```

---

## Spec coverage self-check (plan author)

| Spec item | Plan task |
| --- | --- |
| Unzip nesting gate; T1–T4 semantics | Task 1 (+ Task 5 manual T1–T4) |
| CreateZip mixed `path := ""`; T5–T7 | Task 2 (+ Task 5 manual) |
| IsArchive `Has(ext)`, drop InStr; T8–T10 | Task 3 (+ Task 5 manual) |
| Settings `"UnZip"`; T11–T12 | Task 4 (+ Task 5 manual) |
| Non-goals (no split/refactor/INI/CLI/openZip renames) | Global Constraints + each “Do not change” |
| Static tests file path | Tasks 1–5 use `tests/SmartZip.Static.Tests.ps1` |
| Final Pester + git hygiene | Task 5 Steps 1–3 |
| No AHK/7z on host | Task 5 Step 4 environment note |

## Placeholder and naming consistency self-check

- No TODO, TBD, “similar to Task N”, or “add appropriate handling” placeholders.
- Identifiers consistent across tasks: `nesting`, `nestingMuilt`, `UnZipNesting`, `CreateZip`, `IsArchive`, `this.ext`, `this.extExp`, `IsContextMenuVisible`, `"UnZip"` vs `"unZip"` vs `"unZipCP"`, `path := ""`, `path .=`.
- Pester Describe names: `NestingGate`, `CreateZipPathInit`, `IsArchiveExt`, `SettingsUnZipKey`.
- Function markers for slices: `Unzip(loopPath`, `OpenZip()`, `CreateZip()`, `Gui()`, `IsArchive(ext)`, `RunCmd(`.
