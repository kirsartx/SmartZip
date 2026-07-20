# SmartZip 3.6 Kirs.1 About Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the legacy feedback/donation surface, display the maintained Kirs.1 identity, deploy the rebuilt executable, and refresh the existing `v3.6-kirs.1` Release.

**Architecture:** Keep `MainVersion` numeric for Ahk2Exe compatibility and add a display-only `edition` constant. Treat the About page as a static presentation surface: current project/dependency links remain, while the donation handler and embedded image assets are removed completely. Build and smoke-test outside the repository, deploy only the EXE, then deliberately move the already-public tag and replace its Release asset as approved.

**Tech Stack:** AutoHotkey v2, Pester 3.4-compatible PowerShell tests, Ahk2Exe, 7-Zip Zstandard, Git, GitHub CLI.

## Global Constraints

- Display exactly `SmartZip 3.6 Kirs.1 (21)`.
- Keep `MainVersion := "3.6"` and Ahk2Exe `FileVersion 3.6`.
- Set `edition := "Kirs.1"`, `buildVersion := 21`, Ahk2Exe `ProductVersion 21`, and `buileTime := "2026/7/20 12:56:47"`.
- Keep only current GitHub, latest Release, 7-Zip Zstandard, and AutoHotkey links on the About page.
- Remove “建议反馈”, “论坛反馈”, “支持作者”, `Donate()`, donation `FileInstall` calls, and both tracked donation images.
- Do not change compression, extraction, exclusion, PID/WMI, ErrorMode, password, context-menu, INI-default, or hide-size behavior.
- Build with the already verified portable AutoHotkey v2.0.26 and Ahk2Exe toolchain.
- Deploy only `C:\Tool\SmartZip\SmartZip.exe`; preserve `SmartZip.ini` and `Contextmenu.exe`.
- Update the existing public `v3.6-kirs.1` tag/Release/asset; do not create `v3.6-kirs.2`.

---

## File Structure

- Modify `SmartZip.ahk`: metadata, About controls/links, removal of `Donate()`.
- Modify `tests/SmartZip.Static.Tests.ps1`: Kirs.1 metadata and About cleanup regression tests.
- Delete `donate/wexin.png`: obsolete embedded WeChat donation image.
- Delete `donate/alipay.jpg`: obsolete embedded Alipay donation image.
- Create ignored `.superpowers/sdd/kirs1-about-implementation-report.md`: RED/GREEN and scope evidence.
- Create ignored `.superpowers/sdd/kirs1-about-deploy-report.md`: build, smoke, deployment, tag, and Release evidence.

---

### Task 1: Refresh About Identity and Remove Donation Surface

**Files:**
- Modify: `SmartZip.ahk:1-14`
- Modify: `SmartZip.ahk:1538-1552`
- Modify: `SmartZip.ahk:1862-1888`
- Modify: `tests/SmartZip.Static.Tests.ps1:234-268`
- Delete: `donate/wexin.png`
- Delete: `donate/alipay.jpg`

**Interfaces:**
- Consumes: existing `MainVersion`, `buildVersion`, `buileTime`, Settings tab 6, and the Pester source loader.
- Produces: `edition := "Kirs.1"` and an About page containing only maintained project/dependency links.

- [ ] **Step 1: Add failing metadata and About cleanup tests**

Replace the existing `VersionBanner` Describe and add `AboutSection` immediately after it:

```powershell
Describe 'VersionBanner' {

    It 'MainVersion remains numeric 3.6' {
        $script:SmartZipSource | Should Match 'MainVersion\s*:=\s*"3\.6"'
    }

    It 'edition is Kirs.1' {
        $script:SmartZipSource | Should Match 'edition\s*:=\s*"Kirs\.1"'
    }

    It 'buildVersion is 21' {
        $script:SmartZipSource | Should Match 'buildVersion\s*:=\s*21\b'
    }

    It 'buileTime matches the Kirs.1 build timestamp' {
        $script:SmartZipSource |
            Should Match 'buileTime\s*:=\s*"2026/7/20 12:56:47"'
    }

    It 'Ahk2Exe file version remains 3.6' {
        $script:SmartZipSource |
            Should Match ';@Ahk2Exe-SetFileVersion\s+3\.6\b'
    }

    It 'Ahk2Exe product version is 21' {
        $script:SmartZipSource |
            Should Match ';@Ahk2Exe-SetProductVersion\s+21\b'
    }
}

Describe 'AboutSection' {

    It 'shows SmartZip 3.6 Kirs.1 build 21' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            'app\s+" "\s+MainVersion\s+" "\s+edition\s+" \("\s+buildVersion\s+"\)"'
        $ok | Should Be $true
    }

    It 'links to the maintained repository and latest Release' {
        $script:SmartZipSource |
            Should Match 'https://github\.com/kirsartx/SmartZip'
        $script:SmartZipSource |
            Should Match 'https://github\.com/kirsartx/SmartZip/releases/latest'
    }

    It 'links to the tested 7-Zip Zstandard project' {
        $script:SmartZipSource |
            Should Match 'https://github\.com/mcmilk/7-Zip-zstd'
        $script:SmartZipSource |
            Should Match '已测试 7-Zip 26\.02 ZS v1\.5\.7 R1'
    }

    It 'keeps the AutoHotkey project link' {
        $script:SmartZipSource |
            Should Match 'https://www\.autohotkey\.com/'
    }

    It 'removes legacy feedback and support copy' {
        $script:SmartZipSource | Should Not Match '建议反馈'
        $script:SmartZipSource | Should Not Match '论坛反馈'
        $script:SmartZipSource | Should Not Match '支持作者'
    }

    It 'removes legacy feedback endpoints' {
        $script:SmartZipSource |
            Should Not Match 'github\.com/vvyoko/SmartZip/issues/new'
        $script:SmartZipSource |
            Should Not Match 'meta\.appinn\.net/t/topic/33555'
    }

    It 'removes Donate and embedded donation files' {
        $script:SmartZipSource | Should Not Match '(?m)^\s+Donate\(\)\s*$'
        $script:SmartZipSource | Should Not Match 'FileInstall\("donate\\'
        $script:SmartZipSource | Should Not Match 'donate\\(wexin\.png|alipay\.jpg)'
    }

    It 'removes tracked donation image assets' {
        (Join-Path $PSScriptRoot '..\donate\wexin.png') | Should Not Exist
        (Join-Path $PSScriptRoot '..\donate\alipay.jpg') | Should Not Exist
    }
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```powershell
$result = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName @('VersionBanner', 'AboutSection') -PassThru
"Passed=$($result.PassedCount) Failed=$($result.FailedCount)"
if ($result.FailedCount -eq 0) { exit 1 }
```

Expected: `VersionBanner` fails for missing `edition`, build 21, new timestamp, and product version 21; `AboutSection` fails for the old title, links, copy, handler, and existing resource files.

- [ ] **Step 3: Implement the minimal metadata and About page**

At the top of `SmartZip.ahk`, use:

```ahk
;@Ahk2Exe-SetFileVersion 3.6
;@Ahk2Exe-SetProductVersion 21
;@Ahk2Exe-ExeName SmartZip.exe
buildVersion := 21
MainVersion := "3.6"
edition := "Kirs.1"
;Msgbox FormatTime(A_Now, "yyyy/M/d H:m:s")
buileTime := "2026/7/20 12:56:47"
```

Replace the About content in Settings tab 6 with:

```ahk
    Tab.UseTab(6)
    set.AddText()
    set.AddText("", app " " MainVersion " " edition " (" buildVersion ")")
    lineGeneration
    set.AddText("", "修改时间 " buileTime)
    set.AddText()
    set.AddText(, "相关链接")
    set.AddLink(, '<a id="GitHub" href="https://github.com/kirsartx/SmartZip">GitHub</a>')
    set.AddLink("yp", '<a id="Release" href="https://github.com/kirsartx/SmartZip/releases/latest">Release</a>')
    set.AddLink("yp", '<a id="7-Zip-Zstandard" href="https://github.com/mcmilk/7-Zip-zstd">7-Zip Zstandard</a>').ToolTip := "已测试 7-Zip 26.02 ZS v1.5.7 R1"
    set.AddLink("yp", '<a id="AutoHotkey" href="https://www.autohotkey.com/">AutoHotkey</a>')
```

Delete the complete nested `Donate()` function from `SmartZip.ahk`. Delete both image files with the repository-aware patch operation:

```text
donate/wexin.png
donate/alipay.jpg
```

- [ ] **Step 4: Run focused and full GREEN**

Run:

```powershell
$focused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName @('VersionBanner', 'AboutSection') -PassThru
if ($focused.FailedCount -ne 0) { exit 1 }

$full = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"Passed=$($full.PassedCount) Failed=$($full.FailedCount) Total=$($full.TotalCount)"
if ($full.PassedCount -ne 69 -or $full.FailedCount -ne 0) { exit 1 }
```

Expected: focused tests all pass; full suite prints `Passed=69 Failed=0 Total=69`.

- [ ] **Step 5: Run scope and whitespace checks**

Run:

```powershell
git diff --check
git diff --stat
git diff -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 donate
rg -n '建议反馈|论坛反馈|支持作者|Donate\(|donate\\|vvyoko/SmartZip/issues/new|meta\.appinn\.net' `
    SmartZip.ahk tests
```

Expected: no whitespace errors; only the four scoped paths change; `rg` returns no product-source legacy matches.

- [ ] **Step 6: Write evidence and commit**

Write the RED/GREEN counts, exact diff scope, and self-review to ignored:

```text
.superpowers/sdd/kirs1-about-implementation-report.md
```

Then commit:

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 `
    donate/wexin.png donate/alipay.jpg
git commit -m "feat: refresh Kirs.1 about page"
```

Expected: one focused commit containing metadata/About/test/resource changes only.

---

### Task 2: Review, Build, Smoke-Test, and Deploy

**Files:**
- Verify: `SmartZip.ahk`
- Verify: `tests/SmartZip.Static.Tests.ps1`
- Build: a fresh `SmartZip.exe` under `%TEMP%`
- Deploy: `C:\Tool\SmartZip\SmartZip.exe`
- Preserve: `C:\Tool\SmartZip\SmartZip.ini`
- Preserve: `C:\Tool\SmartZip\Contextmenu.exe`

**Interfaces:**
- Consumes: Task 1 commit and verified portable AHK toolchain.
- Produces: a reviewed, TEMP-smoked EXE deployed byte-for-byte to `C:\Tool\SmartZip`.

- [ ] **Step 1: Run an independent read-only review**

Review Task 1 against the design spec and its commit range. Require:

```text
Critical=0
Important=0
```

Review specifically:

- `MainVersion` remains numeric.
- `edition` is display-only.
- the About page contains only approved links;
- the Donate function/assets have no remaining references;
- no compression, extraction, PID/WMI, ErrorMode, INI, or context-menu changes.

Fix every Critical/Important finding in one follow-up commit, rerun 69 tests, and re-review.

- [ ] **Step 2: Verify source, tests, and toolchain**

Run:

```powershell
$result = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($result.PassedCount -ne 69 -or $result.FailedCount -ne 0) { exit 1 }

$ahkBase = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'
$ahkCompiler = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe'

if ((Get-FileHash $ahkBase -Algorithm SHA256).Hash -ne
    'A2A54B8ABC476D7671D4DE0771BB54BF5F2373D79FF6871D0BA6A62C3B88AE00') { exit 1 }
if ((Get-FileHash $ahkCompiler -Algorithm SHA256).Hash -ne
    'E54A599B19BAA5C1688849BBAE7A9CF049EEFCCD4F704C67941B40DA13A625B2') { exit 1 }

git status --porcelain
```

Expected: 69/0, both tool hashes match, clean tree.

- [ ] **Step 3: Compile a fresh executable**

Run:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$buildDir = Join-Path $env:TEMP "smartzip-kirs1-about-build-$stamp"
New-Item -ItemType Directory -Path $buildDir | Out-Null
$builtExe = Join-Path $buildDir 'SmartZip.exe'
$source = (Resolve-Path '.\SmartZip.ahk').Path

$process = Start-Process -FilePath $ahkCompiler `
    -ArgumentList @('/in',('"' + $source + '"'),
        '/out',('"' + $builtExe + '"'),
        '/base',('"' + $ahkBase + '"')) `
    -WorkingDirectory (Get-Location) -WindowStyle Hidden -Wait -PassThru

if ($process.ExitCode -ne 0 -or -not (Test-Path $builtExe)) { exit 1 }
Get-Item $builtExe | Select-Object FullName,Length,LastWriteTime
Get-FileHash $builtExe -Algorithm SHA256
```

Expected: exit 0 and a non-empty EXE with recorded SHA-256.

- [ ] **Step 4: Smoke-test the exact build with a TEMP INI**

Create a dedicated TEMP smoke directory, copy `$builtExe` and the deployed INI into its `bin` subdirectory, and change only the TEMP INI:

```powershell
$smokeRoot = Join-Path $env:TEMP "smartzip-kirs1-about-smoke-$stamp"
$smokeBin = Join-Path $smokeRoot 'bin'
$smokeWork = Join-Path $smokeRoot 'work'
New-Item -ItemType Directory -Path $smokeBin,$smokeWork | Out-Null
Copy-Item $builtExe (Join-Path $smokeBin 'SmartZip.exe')
Copy-Item 'C:\Tool\SmartZip\SmartZip.ini' (Join-Path $smokeBin 'SmartZip.ini')

$smokeIni = Join-Path $smokeBin 'SmartZip.ini'
$iniText = Get-Content $smokeIni -Raw
$iniText = $iniText -replace '(?m)^delSource=.*$', 'delSource=0'
$iniText = $iniText -replace '(?m)^targetDir=.*$', 'targetDir='
$iniText = $iniText -replace '(?m)^dynamicPassSort=.*$', 'dynamicPassSort=0'
$iniText = $iniText -replace '(?m)^test=.*$', 'test=0'
[System.IO.File]::WriteAllText($smokeIni, $iniText, [System.Text.Encoding]::Unicode)
```

Use `Start-Process -Wait -PassThru` without stdout/stderr redirection:

```powershell
$smokeExe = Join-Path $smokeBin 'SmartZip.exe'
$inputFile = Join-Path $smokeWork 'hello.txt'
[System.IO.File]::WriteAllText($inputFile, 'SmartZip Kirs.1 About smoke a')
$a = Start-Process $smokeExe -ArgumentList @('a',('"' + $inputFile + '"')) `
    -WorkingDirectory $smokeBin -Wait -PassThru
if ($a.ExitCode -ne 0 -or -not (Test-Path (Join-Path $smokeWork 'hello.zip'))) { exit 1 }

$payload = Join-Path $smokeWork 'payload.txt'
[System.IO.File]::WriteAllText($payload, 'SmartZip Kirs.1 About smoke x')
& 'C:\Tool\7-Zip-Zstandard\7z.exe' a -tzip (Join-Path $smokeWork 'payload.zip') $payload
Remove-Item -LiteralPath $payload
$x = Start-Process $smokeExe -ArgumentList @('x',('"' + (Join-Path $smokeWork 'payload.zip') + '"')) `
    -WorkingDirectory $smokeBin -Wait -PassThru
if ($x.ExitCode -ne 0 -or -not (Test-Path $payload)) { exit 1 }
```

Expected: `a` and `x` exit 0 and expected artifacts exist.

- [ ] **Step 5: Back up and deploy only the tested EXE**

Run:

```powershell
$deployDir = 'C:\Tool\SmartZip'
$deployExe = Join-Path $deployDir 'SmartZip.exe'
$backupExe = Join-Path $deployDir "SmartZip.exe.bak-$stamp"
$iniHash = (Get-FileHash (Join-Path $deployDir 'SmartZip.ini') -Algorithm SHA256).Hash
$contextHash = (Get-FileHash (Join-Path $deployDir 'Contextmenu.exe') -Algorithm SHA256).Hash

$running = Get-Process SmartZip,Contextmenu,7z,7zG,7zFM -ErrorAction SilentlyContinue
if ($running) { exit 1 }

Copy-Item $deployExe $backupExe
Copy-Item $builtExe $deployExe -Force

$builtHash = (Get-FileHash $builtExe -Algorithm SHA256).Hash
$deployedHash = (Get-FileHash $deployExe -Algorithm SHA256).Hash
if ($builtHash -ne $deployedHash) {
    Copy-Item $backupExe $deployExe -Force
    exit 1
}
if ((Get-FileHash (Join-Path $deployDir 'SmartZip.ini') -Algorithm SHA256).Hash -ne $iniHash) { exit 1 }
if ((Get-FileHash (Join-Path $deployDir 'Contextmenu.exe') -Algorithm SHA256).Hash -ne $contextHash) { exit 1 }
```

Expected: backup exists; deployed EXE equals the TEMP-smoked build; INI and Contextmenu hashes remain unchanged.

- [ ] **Step 6: Record deployment evidence**

Write exact commands, test counts, build/deployed hashes, backup path, smoke results, preserved hashes, and rollback state to:

```text
.superpowers/sdd/kirs1-about-deploy-report.md
```

Expected verdict: `KIRS1_ABOUT_BUILD_DEPLOYED`.

---

### Task 3: Push Main and Refresh Existing v3.6-kirs.1 Release

**Files:**
- Publish: current `main`
- Move: remote tag `v3.6-kirs.1`
- Replace: Release asset `SmartZip.exe`
- Update: Release title and notes

**Interfaces:**
- Consumes: reviewed Task 1 commit and Task 2 tested/deployed EXE hash.
- Produces: remote `main`, tag, Release target, asset digest, and local deployment all aligned.

- [ ] **Step 1: Verify pre-publish state**

Run:

```powershell
gh auth status
$result = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($result.PassedCount -ne 69 -or $result.FailedCount -ne 0) { exit 1 }
if (git status --porcelain) { exit 1 }

$head = git rev-parse HEAD
$asset = 'C:\Tool\SmartZip\SmartZip.exe'
$assetHash = (Get-FileHash $asset -Algorithm SHA256).Hash
"HEAD=$head"
"ASSET_SHA256=$assetHash"
```

Expected: authenticated as `kirsartx`; 69/0; clean tree; exact head and asset hash recorded.

- [ ] **Step 2: Push main**

Run:

```powershell
git push origin main
$remoteMain = (git ls-remote origin refs/heads/main).Split()[0]
if ($remoteMain -ne $head) { exit 1 }
```

Expected: `origin/main` equals `$head`.

- [ ] **Step 3: Move the approved existing tag**

The user explicitly approved changing the already-public tag:

```powershell
git tag -f v3.6-kirs.1 $head
git push origin refs/tags/v3.6-kirs.1 --force
$remoteTag = (git ls-remote origin refs/tags/v3.6-kirs.1).Split()[0]
if ($remoteTag -ne $head) { exit 1 }
```

Expected: remote tag now equals final Kirs.1 About commit. Do not create any Kirs.2 tag.

- [ ] **Step 4: Update Release notes and replace the EXE asset**

Use this exact release copy:

```powershell
$notes = @'
## SmartZip 3.6 Kirs.1

本次刷新更新“关于”页并保持压缩/解压核心行为不变：

- 显示 SmartZip 3.6 Kirs.1 (21)
- GitHub 与 Release 链接改为 kirsartx/SmartZip
- 7-Zip 链接改为 7-Zip Zstandard，并标注已测试 26.02 ZS v1.5.7 R1
- 删除“建议反馈”“论坛反馈”“支持作者”及捐赠资源
- Pester：69 passed / 0 failed
- 临时目录 a / x 冒烟测试通过

附件 SmartZip.exe 为升级主程序。请保留现有 SmartZip.ini 与 Contextmenu.exe。

SHA-256:

ASSET_HASH

本 Release 的标签与附件已按用户要求刷新到最新 Kirs.1 源码。
'@.Replace('ASSET_HASH', $assetHash)

gh release edit v3.6-kirs.1 --repo kirsartx/SmartZip `
    --target $head --title 'SmartZip 3.6 Kirs.1' --notes $notes --latest

gh release delete-asset v3.6-kirs.1 SmartZip.exe `
    --repo kirsartx/SmartZip --yes
gh release upload v3.6-kirs.1 `
    "$asset#SmartZip.exe" --repo kirsartx/SmartZip
```

Expected: existing Release stays public/non-prerelease; old EXE asset is replaced.

- [ ] **Step 5: Verify tag, Release, asset, and deployment alignment**

Run:

```powershell
$release = gh release view v3.6-kirs.1 --repo kirsartx/SmartZip `
    --json tagName,name,isDraft,isPrerelease,targetCommitish,url,assets |
    ConvertFrom-Json
$release | ConvertTo-Json -Depth 8

if ($release.tagName -ne 'v3.6-kirs.1') { exit 1 }
if ($release.isDraft -or $release.isPrerelease) { exit 1 }
if ($release.targetCommitish -ne $head) { exit 1 }

$exeAsset = $release.assets | Where-Object { $_.name -eq 'SmartZip.exe' }
if (-not $exeAsset -or $exeAsset.state -ne 'uploaded') { exit 1 }
if ($exeAsset.digest -ne ('sha256:' + $assetHash.ToLowerInvariant())) { exit 1 }

$deployedHash = (Get-FileHash 'C:\Tool\SmartZip\SmartZip.exe' -Algorithm SHA256).Hash
if ($deployedHash -ne $assetHash) { exit 1 }
```

Expected: `main`, `v3.6-kirs.1`, Release target, asset digest, and deployed EXE all align.

- [ ] **Step 6: Final clean-state report**

Run:

```powershell
git status --short --branch
git log --oneline -5
gh release view v3.6-kirs.1 --repo kirsartx/SmartZip --json url
```

Expected: clean `main...origin/main`, final feature commit present, and the updated Release URL returned.

---

## Plan Self-Review

- **Spec coverage:** Task 1 covers every metadata, About, dead-code, and resource requirement. Task 2 covers review/build/smoke/deploy/preservation. Task 3 covers the explicitly approved destructive tag/asset refresh.
- **Placeholders:** All source strings, paths, test counts, hashes for the fixed toolchain, release copy, commands, and expected outcomes are concrete. Runtime-produced source/asset hashes are named variables and verified before use.
- **Type consistency:** `MainVersion`, `edition`, and `buileTime` are strings; `buildVersion` is numeric; `$head` and `$assetHash` are strings; Release JSON fields are checked using their actual names.
- **Scope:** No compression, extraction, WMI/PID, ErrorMode, password, INI-default, Contextmenu, or hide-size change is included.
- **Safety:** Tag force-update and asset replacement occur only after main push, full tests, clean state, exact asset hash capture, and explicit user authorization.
