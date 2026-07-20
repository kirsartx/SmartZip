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
    -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    IsNestedArchiveCandidate("
if ([string]::IsNullOrEmpty($script:IsArchiveBody)) {
    $script:IsArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    ProbeArchive("
}
if ([string]::IsNullOrEmpty($script:IsArchiveBody)) {
    $script:IsArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    RunCmdCapture("
}
if ([string]::IsNullOrEmpty($script:IsArchiveBody)) {
    $script:IsArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    RunCmd("
}
$script:InitBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    Init(argsArr)" -EndMarker "`n    Exec("
$script:OpenZipBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    OpenZip()" -EndMarker "`n    CreateZip()"
$script:GuiBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    Gui()" -EndMarker "`n    Run7z("
$script:Run7zBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    Run7z(" -EndMarker "`n    RecycleItem("

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

Describe 'CreateZipPathInit' {

    It 'CreateZip method body can be extracted (excludes OpenZip)' {
        [string]::IsNullOrEmpty($script:CreateZipBody) | Should Be $false
        $script:CreateZipBody | Should Match 'CreateZip\s*\('
        $script:CreateZipBody | Should Not Match 'OpenZip\s*\('
    }

    It 'mixed file/folder branch still concatenates quoted paths with path .=' {
        $ok = Test-Regex -Text $script:CreateZipBody -Pattern `
            "(?s);文件文件夹混合\s*\{.*?path\s*\.=\s*'\s*""'\s*i\s*'""\s*'"
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

Describe 'IsArchiveExt' {

    It 'IsArchive method body can be extracted' {
        [string]::IsNullOrEmpty($script:IsArchiveBody) | Should Be $false
        $script:IsArchiveBody | Should Match 'IsArchive\s*\(\s*ext\s*\)'
    }

    It 'returns false when extension is empty' {
        $ok = Test-Regex -Text $script:IsArchiveBody -Pattern `
            '(?s)if\s*!ext\s+return\s+false'
        $ok | Should Be $true
        $bad = Test-Regex -Text $script:IsArchiveBody -Pattern `
            '(?s)if\s*!ext\s+return\s+true'
        $bad | Should Be $false
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
        # After Task 5, extract moves into ExtractArchiveToTemp (single Run7z path).
        $extractBody = Get-SourceSlice -Source $script:SmartZipSource `
            -StartMarker "`n    ExtractArchiveToTemp(" -EndMarker "`n    FinalizeExtraction("
        if ([string]::IsNullOrEmpty($extractBody)) {
            $extractBody = ''
        }
        $script:ExtractArchiveToTempBody = $extractBody
        $ok = Test-Regex -Text $script:ExtractArchiveToTempBody -Pattern `
            'Run7z\s*\([^\r\n]*[''"]x[''"][^\r\n]*this\.excludeArgs|Run7z\s*\([^\)]*this\.excludeArgs'
        $ok | Should Be $true
        $ok2 = Test-Regex -Text $script:UnzipBody -Pattern 'ExtractArchiveToTemp\s*\('
        $ok2 | Should Be $true
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
        # Source order: non-unique clear → literal CommandLine/path rejection → PID truthiness clear → exactPid true
        $ok = Test-Regex -Text $script:Run7zBody -Pattern `
            '(?s)matches\.Length\s*!=\s*1.*?ClearExactPid\(\).*?InStr\s*\([^)]*path[^)]*\).*?ClearExactPid\(\).*!this\.pid.*?ClearExactPid\(\).*this\.exactPid\s*:=\s*true'
        $ok | Should Be $true
    }

    It 'WinGetPID has a soft failure path' {
        $script:Run7zBody | Should Match 'try'
        $script:Run7zBody | Should Match 'this\.exactPid\s*:=\s*false'
        # catch must reset sticky winmgmts then clear exact bind state
        $ok = Test-Regex -Text $script:Run7zBody -Pattern `
            '(?s)catch\b.*?winmgmts\s*:=\s*""\s*.*?(?:ClearExactPid\(\)|this\.pid\s*:=\s*"".*?this\.exactPid\s*:=\s*false)'
        $ok | Should Be $true
    }

    It 'path escaping covers recovered special characters' {
        $script:Run7zBody | Should Match 'EscapeCharacter'
        # Character-by-character WQL LIKE builder for literal [ ] % _
        $script:Run7zBody | Should Match 'Loop\s+Parse'
        foreach ($token in @('\[\[\]', '\[\]\]', '\[%\]', '\[_\]')) {
            $script:Run7zBody | Should Match $token
        }
        # Authorization uses case-insensitive literal InStr on original unescaped path
        $ok = Test-Regex -Text $script:Run7zBody -Pattern `
            '(?s)InStr\s*\(\s*\w+\s*,\s*path\b'
        $ok | Should Be $true
    }

    It 'CMDPID code is not moved into the GUI PID binding' {
        $script:Run7zBody | Should Not Match 'CMDPID'
    }
}

Describe 'ErrorModeStateMachine' {

    It 'Gui method body can be extracted' {
        [string]::IsNullOrEmpty($script:GuiBody) | Should Be $false
    }

    It 'Gui initializes explicit error and IO state' {
        # Must be constructor-adjacent init, not recovery/Close clears alone.
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)g\s*:=\s*Gui\(\s*"\+LastFound"\s*\).*?g\.io\s*:=\s*0.*?g\.ioRunning\s*:=\s*false.*?g\.errorMode\s*:=\s*false.*?RegisterShellHookWindow'
        $ok | Should Be $true
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
        # GetWriteIO body: entry gate, PID filter, unique-match rejection (source order).
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)GetWriteIO\s*\(\s*\).*?if\s*!g\.errorMode\s*\|\|\s*!this\.exactPid\s*\|\|\s*!this\.query.*?proc\.ProcessID\s*=\s*this\.pid.*?matches\.Length\s*!=\s*1'
        $ok | Should Be $true
    }

    It 'normal parse recovery stops IO and clears ErrorMode' {
        # ShellMessage recovery branch only — not satisfiable by Close(*) cleanup alone.
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)if\s+g\.errorMode\s*\|\|\s*g\.ioRunning.*?SetTimer\(\s*GetWriteIO\s*,\s*0\s*\).*?g\.ioRunning\s*:=\s*false.*?g\.errorMode\s*:=\s*false.*?g\.io\s*:=\s*0.*?times\s*:=\s*0'
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
        # Full product gate: errorMode && exactPid && pid && ProcessExist(pid).
        # Close uses a captured local pid after bind invalidation (not this.pid).
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)ButtonPause\(.*?g\.errorMode\s*&&\s*this\.exactPid\s*&&\s*this\.pid\s*&&\s*ProcessExist\(\s*this\.pid\s*\).*?ProcessClose\(\s*pid\s*\)'
        $ok | Should Be $true
    }

    It 'force end invalidates exact PID bind before ProcessClose' {
        # Capture authorized PID, clear bind, then close only the captured value.
        # A second click must not reuse a stale exactPid authorization.
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)ButtonPause\(.*?g\.errorMode\s*&&\s*this\.exactPid\s*&&\s*this\.pid\s*&&\s*ProcessExist\(\s*this\.pid\s*\).*?SetTimer\(\s*GetWriteIO\s*,\s*0\s*\).*?g\.ioRunning\s*:=\s*false.*?pid\s*:=\s*this\.pid.*?this\.pid\s*:=\s*"".*?this\.query\s*:=\s*"".*?this\.exactPid\s*:=\s*false.*?ProcessClose\(\s*pid\s*\)'
        $ok | Should Be $true
    }

    It 'target-window loss clears ErrorMode and stops IO sampling' {
        # ShellMessage !WinExist path must disarm timer/state when ErrorMode or IO is armed
        # so sequential Run7z items cannot inherit a prior fault mode.
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)if\s+!WinExist\(\s*sub\(\)\s*\)\s*\{\s*if\s+g\.errorMode\s*\|\|\s*g\.ioRunning\s*\{\s*SetTimer\(\s*GetWriteIO\s*,\s*0\s*\).*?g\.ioRunning\s*:=\s*false.*?g\.errorMode\s*:=\s*false.*?g\.io\s*:=\s*0'
        $ok | Should Be $true
    }

    It 'ShellMessage keeps non-error throttle/wParam fast return separate from window-loss clear' {
        # Throttle and wParam!=6 remain a minimal early return; window-loss is a distinct check.
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)ShellMessage\s*\(.*?if\s+A_TickCount\s*-\s*timeSave\s*<\s*50\s*\|\|\s*wParam\s*!=\s*6\s+return.*?if\s+!WinExist\(\s*sub\(\)\s*\)'
        $ok | Should Be $true
    }

    It 'show-hide is disabled during ErrorMode or IO sampling' {
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)ButtonShowHide\(.*?if\s+g\.errorMode\s*\|\|\s*g\.ioRunning\s+return'
        $ok | Should Be $true
    }

    It 'Close ProcessClose is gated by exactPid and pid' {
        # Close(*) kill path must require exactPid + pid + ProcessExist before ProcessClose(this.pid).
        $ok = Test-Regex -Text $script:GuiBody -Pattern `
            '(?s)Close\(\*\).*?if\s+this\.exactPid\s*&&\s*this\.pid\s*&&\s*ProcessExist\(\s*this\.pid\s*\).*?ProcessClose\(\s*this\.pid\s*\)'
        $ok | Should Be $true
    }
}

$script:RunCmdBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    RunCmd(CmdLine" -EndMarker "`n    CheckCMD("
$script:RunCmdCaptureBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    RunCmdCapture(" -EndMarker "`n    RunCmd(CmdLine"

Describe 'RunCmdCaptureSafety' {

    It 'RunCmdCapture method exists before RunCmd' {
        [string]::IsNullOrEmpty($script:RunCmdCaptureBody) | Should Be $false
        $script:RunCmdCaptureBody | Should Match 'RunCmdCapture\s*\('
    }

    It 'RunCmdCapture default codePage is UTF-8' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'RunCmdCapture\s*\(\s*CmdLine\s*,\s*Codepage\s*:=\s*"UTF-8"\s*\)'
        if (-not $ok) {
            $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
                'RunCmdCapture\s*\(\s*\w+\s*,\s*\w+\s*:=\s*"UTF-8"\s*\)'
        }
        $ok | Should Be $true
    }

    It 'RunCmdCapture returns exitCode output and cancelled properties' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'exitCode'
        $ok2 = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'output'
        $ok3 = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'cancelled'
        ($ok -and $ok2 -and $ok3) | Should Be $true
    }

    It 'RunCmdCapture obtains a real exit code via GetExitCodeProcess' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'GetExitCodeProcess'
        $ok | Should Be $true
    }

    It 'RunCmdCapture wires both hStdOutput and hStdError to the pipe' {
        $okOut = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'hStdOutput|hPipeW'
        $okErr = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'hStdError|hPipeW'
        # Require two NumPut calls that assign the write pipe (stdout + stderr)
        $puts = [regex]::Matches($script:RunCmdCaptureBody, 'NumPut\(\s*"Ptr"\s*,\s*hPipeW')
        ($puts.Count -ge 2) | Should Be $true
    }

    It 'RunCmdCapture does not ProcessClose on keyword matchers' {
        $hasClose = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'ProcessClose\s*\('
        $hasClose | Should Be $false
    }

    It 'RunCmdCapture does not invoke CheckCMD maps during capture' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'CheckCMD\s*\('
        $ok | Should Be $false
    }

    It 'RunCmdCapture marks cancelled when exitCode is 255' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'cancelled\s*:=\s*.*255|255.*cancelled'
        $ok | Should Be $true
    }

    It 'legacy RunCmd method body still exists for compatibility' {
        [string]::IsNullOrEmpty($script:RunCmdBody) | Should Be $false
        $script:RunCmdBody | Should Match 'CreateProcess'
    }

    It 'legacy CheckCMD still early-closes only on its own path' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            '(?s)CheckCMD\(.*?LogAndReturn.*?ProcessClose\(\s*this\.CMDPID\s*\)'
        $ok | Should Be $true
    }

    It 'Run7z still launches 7zG for non-CLI GUI extract' {
        $ok = Test-Regex -Text $script:Run7zBody -Pattern `
            'this\.7zG'
        $ok | Should Be $true
        $ok2 = Test-Regex -Text $script:Run7zBody -Pattern `
            'is7z\s*\?\s*this\.7z\s*:\s*this\.7zG'
        $ok2 | Should Be $true
    }

    It 'Run7z still resets exactPid bind state per task' {
        $ok = Test-Regex -Text $script:Run7zBody -Pattern `
            'this\.exactPid\s*:=\s*false'
        $ok | Should Be $true
    }

    It 'product source still forbids 7zG image-name PID fallback' {
        $bad = Test-Regex -Text $script:SmartZipSource -Pattern `
            'ProcessExist\(\s*["'']7zG\.exe["'']\s*\)'
        $bad | Should Be $false
    }
}

$script:ProbeArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ProbeArchive(" -EndMarker "`n    TestArchive("
$script:TestArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    TestArchive(" -EndMarker "`n    BuildPasswordCandidates("
$script:BuildPasswordCandidatesBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    BuildPasswordCandidates(" -EndMarker "`n    ResolveArchivePassword("
$script:ResolveArchivePasswordBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ResolveArchivePassword(" -EndMarker "`n    ShowPasswordDialog("
$script:ShowPasswordDialogBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ShowPasswordDialog(" -EndMarker "`n    RememberPassword("
$script:RememberPasswordBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    RememberPassword(" -EndMarker "`n    FormatPassword("
$script:FormatPasswordBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    FormatPassword(" -EndMarker "`n    RunCmdCapture("

Describe 'PasswordPreflightSafety' {

    It 'includes ArchiveDiagnostics library before class SmartZip' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            '(?m)^#Include\s+lib\\ArchiveDiagnostics\.ahk\s*$'
        $ok | Should Be $true
        $inc = $script:SmartZipSource.IndexOf('#Include lib\ArchiveDiagnostics.ahk')
        $cls = $script:SmartZipSource.IndexOf('class SmartZip')
        ($inc -ge 0 -and $cls -gt $inc) | Should Be $true
    }

    It 'ProbeArchive method exists before TestArchive' {
        [string]::IsNullOrEmpty($script:ProbeArchiveBody) | Should Be $false
        $script:ProbeArchiveBody | Should Match 'ProbeArchive\s*\('
    }

    It 'TestArchive method exists with default empty password' {
        [string]::IsNullOrEmpty($script:TestArchiveBody) | Should Be $false
        $ok = Test-Regex -Text $script:TestArchiveBody -Pattern `
            'TestArchive\s*\(\s*\w+\s*,\s*\w+\s*:=\s*""\s*\)'
        $ok | Should Be $true
    }

    It 'BuildPasswordCandidates and ResolveArchivePassword methods exist' {
        [string]::IsNullOrEmpty($script:BuildPasswordCandidatesBody) | Should Be $false
        [string]::IsNullOrEmpty($script:ResolveArchivePasswordBody) | Should Be $false
    }

    It 'ShowPasswordDialog has exact buttons 本次使用 使用并保存 取消' {
        $b = $script:ShowPasswordDialogBody
        [string]::IsNullOrEmpty($b) | Should Be $false
        ($b -match '本次使用') | Should Be $true
        ($b -match '使用并保存') | Should Be $true
        ($b -match '取消') | Should Be $true
    }

    It 'ShowPasswordDialog masks password Edit with Password style' {
        $ok = Test-Regex -Text $script:ShowPasswordDialogBody -Pattern `
            'AddEdit\([^\)]*Password'
        $ok | Should Be $true
    }

    It 'ProbeArchive uses RunCmdCapture and Classify7zResult with stage probe' {
        $b = $script:ProbeArchiveBody
        (Test-Regex -Text $b -Pattern 'RunCmdCapture\s*\(') | Should Be $true
        (Test-Regex -Text $b -Pattern 'Classify7zResult\s*\(\s*"probe"') | Should Be $true
        (Test-Regex -Text $b -Pattern 'l\s+-slt') | Should Be $true
        (Test-Regex -Text $b -Pattern '-bso1') | Should Be $true
        (Test-Regex -Text $b -Pattern '-bse1') | Should Be $true
        (Test-Regex -Text $b -Pattern '-bsp0') | Should Be $true
        (Test-Regex -Text $b -Pattern '-sccUTF-8') | Should Be $true
    }

    It 'TestArchive uses RunCmdCapture Classify7zResult stage test and -p' {
        $b = $script:TestArchiveBody
        (Test-Regex -Text $b -Pattern 'RunCmdCapture\s*\(') | Should Be $true
        (Test-Regex -Text $b -Pattern 'Classify7zResult\s*\(\s*"test"') | Should Be $true
        (Test-Regex -Text $b -Pattern '(?m)\bt\b.*-bso1|-bso1.*\bt\b| '' t ') | Should Be $true
        (Test-Regex -Text $b -Pattern '-p"') | Should Be $true
        (Test-Regex -Text $b -Pattern 'passwordUsed') | Should Be $true
    }

    It 'cmdLog paths redact diagnostics and never concatenate raw password into log' {
        $combined = $script:ProbeArchiveBody + $script:TestArchiveBody + $script:ResolveArchivePasswordBody + $script:RememberPasswordBody
        (Test-Regex -Text $combined -Pattern 'RedactDiagnostic\s*\(') | Should Be $true
        # Forbid obvious secret leakage patterns in new preflight methods
        $bad = Test-Regex -Text $combined -Pattern 'Loging\([^\)]*-p"''\s*\w+'
        $bad | Should Be $false
        $bad2 = Test-Regex -Text $combined -Pattern 'testLog\s*\.=\s*[^\n]*password[^\n]*"'
        $bad2 | Should Be $false
    }

    It 'ResolveArchivePassword short-circuits non-password statuses without TestArchive loop' {
        $b = $script:ResolveArchivePasswordBody
        # Must mention NEED_PASSWORD and WRONG_PASSWORD as the only entry to iteration
        (Test-Regex -Text $b -Pattern 'NEED_PASSWORD') | Should Be $true
        (Test-Regex -Text $b -Pattern 'WRONG_PASSWORD') | Should Be $true
        (Test-Regex -Text $b -Pattern 'BuildPasswordCandidates\s*\(') | Should Be $true
        (Test-Regex -Text $b -Pattern 'ShowPasswordDialog\s*\(') | Should Be $true
        (Test-Regex -Text $b -Pattern 'CANCELLED') | Should Be $true
    }

    It 'BuildPasswordCandidates orders non-empty candidates and Resolve tests empty once' {
        $b = $script:BuildPasswordCandidatesBody
        $r = $script:ResolveArchivePasswordBody
        (Test-Regex -Text $b -Pattern 'lastPass') | Should Be $true
        (Test-Regex -Text $b -Pattern 'FormatPassword\s*\(\s*this\.GetClipboardText\s*\(\s*\)\s*\)') | Should Be $true
        (Test-Regex -Text $b -Pattern 'dynamicPassArr|password') | Should Be $true
        (Test-Regex -Text $b -Pattern 'addDir2Pass') | Should Be $true
        # Empty is excluded from candidates and tested only by ResolveArchivePassword.
        (Test-Regex -Text $b -Pattern 'Push\(\s*""\s*\)|add\(\s*""\s*\)|candidates\.Push\(\s*""\s*\)') | Should Be $false
        (Test-Regex -Text $r -Pattern 'TestArchive\s*\(\s*path\s*,\s*""\s*\)') | Should Be $true
    }

    It 'RememberPassword updates lastPass and dynamic maps without logging the secret' {
        $b = $script:RememberPasswordBody
        [string]::IsNullOrEmpty($b) | Should Be $false
        (Test-Regex -Text $b -Pattern 'lastPass') | Should Be $true
        (Test-Regex -Text $b -Pattern 'passwordMap|dynamicPassArr') | Should Be $true
        (Test-Regex -Text $b -Pattern 'Loging\s*\([^\)]*password') | Should Be $false
    }

    It 'Unzip zipx entry calls ProbeArchive and ResolveArchivePassword' {
        $u = $script:UnzipBody
        (Test-Regex -Text $u -Pattern 'ProbeArchive\s*\(') | Should Be $true
        (Test-Regex -Text $u -Pattern 'ResolveArchivePassword\s*\(') | Should Be $true
        # Legacy early-kill encrypted probe callback must no longer be the primary entry
        (Test-Regex -Text $u -Pattern 'CheckEncrypted') | Should Be $false
    }

    It 'RunCmdCapture still precedes RunCmd after password methods' {
        $src = $script:SmartZipSource
        $p = $src.IndexOf("`n    ProbeArchive(")
        $c = $src.IndexOf("`n    RunCmdCapture(")
        $r = $src.IndexOf("`n    RunCmd(CmdLine")
        ($p -ge 0 -and $c -gt $p -and $r -gt $c) | Should Be $true
    }
}

$script:ExtractArchiveToTempBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ExtractArchiveToTemp(" -EndMarker "`n    FinalizeExtraction("
$script:FinalizeExtractionBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    FinalizeExtraction(" -EndMarker "`n    WriteDiagnostic("
$script:WriteDiagnosticBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    WriteDiagnostic(" -EndMarker "`n    ShowDiagnostic("
if ([string]::IsNullOrEmpty($script:WriteDiagnosticBody)) {
    $script:WriteDiagnosticBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    WriteDiagnostic(" -EndMarker "`n    RunCmdCapture("
}
$script:ShowDiagnosticBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ShowDiagnostic(" -EndMarker "`n    RunCmdCapture("

Describe 'ExtractionLifecycleSafety' {

    It 'ExtractArchiveToTemp FinalizeExtraction WriteDiagnostic methods exist in order' {
        [string]::IsNullOrEmpty($script:ExtractArchiveToTempBody) | Should Be $false
        [string]::IsNullOrEmpty($script:FinalizeExtractionBody) | Should Be $false
        [string]::IsNullOrEmpty($script:WriteDiagnosticBody) | Should Be $false
        $e = $script:SmartZipSource.IndexOf('ExtractArchiveToTemp(')
        $f = $script:SmartZipSource.IndexOf('FinalizeExtraction(')
        $w = $script:SmartZipSource.IndexOf('WriteDiagnostic(')
        ($e -ge 0 -and $f -gt $e -and $w -gt $f) | Should Be $true
    }

    It 'ExtractArchiveToTemp uses Run7z extract and Classify7zResult stage extract' {
        $script:ExtractArchiveToTempBody | Should Match 'Run7z\s*\('
        $script:ExtractArchiveToTempBody | Should Match "['`"]x['`"]"
        $ok = Test-Regex -Text $script:ExtractArchiveToTempBody -Pattern `
            'Classify7zResult\s*\(\s*["'']extract["'']'
        $ok | Should Be $true
    }

    It 'ExtractArchiveToTemp reclassifies non-zero extract via console test capture' {
        $ok = Test-Regex -Text $script:ExtractArchiveToTempBody -Pattern `
            'RunCmdCapture\s*\('
        $ok | Should Be $true
        $script:ExtractArchiveToTempBody | Should Match '\bt\b'
        $script:ExtractArchiveToTempBody | Should Match '255'
    }

    It 'no IsSuccess size or successPercent authorization remains' {
        $script:UnzipBody | Should Not Match 'IsSuccess\s*\('
        $script:SmartZipSource | Should Not Match '(?s)IsSuccess\s*\(\s*\)\s*\{[^}]*succesSpercent'
        $script:ExtractArchiveToTempBody | Should Not Match 'succesSpercent|successPercent|GetFolder\s*\(\s*tmpDir\s*\)\s*\.Size|folderSize\s*/\s*this\.currentSize'
        $script:FinalizeExtractionBody | Should Not Match 'succesSpercent|successPercent|folderSize\s*/\s*this\.currentSize'
    }

    It 'FinalizeExtraction encodes partial dir name 解压不完整 and diagnostic file' {
        $script:FinalizeExtractionBody | Should Match '解压不完整'
        $script:FinalizeExtractionBody | Should Match 'yyyyMMdd-HHmmss'
        $script:FinalizeExtractionBody | Should Match 'PathDupl\s*\('
        $script:FinalizeExtractionBody | Should Match 'DirMove\s*\('
        $ok = Test-Regex -Text $script:FinalizeExtractionBody -Pattern 'WriteDiagnostic\s*\('
        $ok | Should Be $true
        $script:WriteDiagnosticBody | Should Match 'SmartZip-诊断\.txt'
        $script:WriteDiagnosticBody | Should Match 'RedactDiagnostic\s*\('
    }

    It 'FinalizeExtraction preserves source on warning and never permanently deletes a source path' {
        $script:FinalizeExtractionBody | Should Match 'OK_WITH_WARNING'
        $script:FinalizeExtractionBody | Should Match 'mayDeleteSource'
        $script:FinalizeExtractionBody | Should Match 'RecycleItem\s*\('
        # No source archive path may force permanent delete (delete:=true).
        $ok = Test-Regex -Text $script:FinalizeExtractionBody -Pattern `
            'RecycleItem\s*\(\s*path\s*,\s*[^,]+,\s*true\s*\)'
        $ok | Should Be $false
        $script:FinalizeExtractionBody | Should Match 'FileRecycle|delete\s*:=\s*false|RecycleItem\s*\(\s*path\s*,'
        # Permanent cleanup remains allowed only for the SmartZip-created tempDir.
        $script:FinalizeExtractionBody | Should Match 'RecycleItem\s*\(\s*tempDir\s*,[^\n]*true'
    }

    It 'zipx calls ExtractArchiveToTemp and FinalizeExtraction' {
        $ok = Test-Regex -Text $script:UnzipBody -Pattern 'ExtractArchiveToTemp\s*\('
        $ok2 = Test-Regex -Text $script:UnzipBody -Pattern 'FinalizeExtraction\s*\('
        $ok3 = Test-Regex -Text $script:UnzipBody -Pattern 'TestArchive\s*\('
        $ok4 = Test-Regex -Text $script:UnzipBody -Pattern 'forceTest\s*:=\s*this\.test\s*\|\|\s*mayHandleSource\s*\|\|\s*nestedMayRecycle'
        $ok5 = Test-Regex -Text $script:UnzipBody -Pattern '!\s*volume\.isVolume'
        ($ok -and $ok2 -and $ok3 -and $ok4 -and $ok5) | Should Be $true
        $script:UnzipBody | Should Match 'nestedMayRecycle\s*&&\s*extractResult\.isCleanSuccess'
        $script:UnzipBody | Should Not Match 'RecycleItem\s*\(\s*path\s*,[^\n]*true'
    }

    It 'Run7z still launches 7zG and exactPid reset unchanged' {
        $script:Run7zBody | Should Match '7zG'
        $script:Run7zBody | Should Match 'exactPid'
        $script:Run7zBody | Should Match 'this\.query\s*:='
    }

    It 'WriteDiagnostic never logs raw password material' {
        $script:WriteDiagnosticBody | Should Not Match 'passwordUsed'
        $script:WriteDiagnosticBody | Should Match 'RedactDiagnostic'
        $script:WriteDiagnosticBody | Should Match '7-Zip|sevenZipVersion'
        $script:WriteDiagnosticBody | Should Match '4096'
    }

    It 'volume and cancel paths do not authorize source handling in FinalizeExtraction' {
        # mayDeleteSource must gate any path RecycleItem; CANCELLED must not force delete
        $script:FinalizeExtractionBody | Should Match 'mayDeleteSource'
        $script:FinalizeExtractionBody | Should Not Match 'RecycleItem\s*\(\s*path\s*,[^\n]*CANCELLED'
    }

    It 'partial diagnostic name and PathDupl used' {
        $script:FinalizeExtractionBody | Should Match 'PathDupl\s*\('
        $script:FinalizeExtractionBody | Should Match 'DirMove|MoveItem'
    }

    It 'successPercent assignment may still load but must not gate extract success' {
        # Field may remain until Task 6 deprecates UI; must not appear in extract/finalize decision
        $script:ExtractArchiveToTempBody | Should Not Match 'successPercent|succesSpercent'
        $script:FinalizeExtractionBody | Should Not Match 'successPercent|succesSpercent'
    }
}

$script:IsNestedArchiveCandidateBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    IsNestedArchiveCandidate(" -EndMarker "`n    ProbeArchive("
if ([string]::IsNullOrEmpty($script:IsNestedArchiveCandidateBody)) {
    $script:IsNestedArchiveCandidateBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    IsNestedArchiveCandidate(" -EndMarker "`n    RunCmdCapture("
}
$script:UnZipNestingBody = ""
if ($script:UnzipBody -match '(?s)(UnZipNesting\s*\([^\)]*\)\s*\{.*?\n        \})') {
    $script:UnZipNestingBody = $matches[1]
}
$script:IniCreateBody = ""
if ($script:SmartZipSource -match '(?s)(IniCreate\s*\(\s*\)\s*\{.*\n\})') {
    $script:IniCreateBody = $matches[1]
}
$script:MigrateDeprecatedExtExpBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`nMigrateDeprecatedExtExp()" -EndMarker "`nIniCreate()"
$script:SettingsGuiRegion = ""
# Settings live in Set() / settings GUI block; use whole source for control assertions
$script:SettingsGuiRegion = $script:SmartZipSource

Describe 'NestingProbeAndMigrationSafety' {

    It 'IsNestedArchiveCandidate method exists after IsArchive' {
        [string]::IsNullOrEmpty($script:IsNestedArchiveCandidateBody) | Should Be $false
        $a = $script:SmartZipSource.IndexOf("`n    IsArchive(ext)")
        $c = $script:SmartZipSource.IndexOf("`n    IsNestedArchiveCandidate(")
        ($a -ge 0 -and $c -gt $a) | Should Be $true
    }

    It 'IsArchive empty extension returns false not true' {
        $script:IsArchiveBody | Should Match '(?s)if\s*!ext\s+return\s+false'
        $script:IsArchiveBody | Should Not Match '(?s)if\s*!ext\s+return\s+true'
    }

    It 'IsArchive still uses exact ext map and extExp regex only as hints' {
        $script:IsArchiveBody | Should Match 'this\.ext\.Has\(\s*ext\s*\)'
        $script:IsArchiveBody | Should Match 'this\.extExp'
        $script:IsArchiveBody | Should Match 'ext\s*~='
    }

    It 'IsNestedArchiveCandidate uses IsArchive and DetectVolumeGroup' {
        $b = $script:IsNestedArchiveCandidateBody
        $b | Should Match 'IsArchive\s*\('
        $b | Should Match 'DetectVolumeGroup\s*\('
    }

    It 'UnZipNesting gates on candidate then ProbeArchive before nested Unzip' {
        $b = $script:UnZipNestingBody
        [string]::IsNullOrEmpty($b) | Should Be $false
        ($b -match 'IsNestedArchiveCandidate\s*\(|IsArchive\s*\(') | Should Be $true
        $b | Should Match 'ProbeArchive\s*\('
        $b | Should Match 'Unzip\s*\('
        # ProbeArchive must appear before nested Unzip call in the function body
        $p = $b.IndexOf('ProbeArchive')
        $u = $b.LastIndexOf('Unzip(')
        ($p -ge 0 -and $u -gt $p) | Should Be $true
    }

    It 'UnZipNesting does not legacy-delete on time size or bare exitCode success' {
        $b = $script:UnZipNestingBody
        $b | Should Not Match 'FileGetTime\s*\(\s*path\s*\)\s*,\s*sizeSave\s*:=\s*FileGetSize'
        $b | Should Not Match 'FileGetTime\s*\(\s*path\s*\)\s*=\s*timeSave'
        $b | Should Not Match '(?s)if\s*!this\.exitCode\s*&&\s*part\s*='
    }

    It 'UnZipNesting volume path never RecycleItem deletes volumes' {
        $b = $script:UnZipNestingBody
        # Must consult DetectVolumeGroup or explicit volume guard; must not RecycleItem volume members
        ($b -match 'DetectVolumeGroup\s*\(|isVolume|part\s*=') | Should Be $true
        # No unconditional RecycleItem(path) after nested unzip without OK/isCleanSuccess gate in this helper
        $bad = Test-Regex -Text $b -Pattern 'RecycleItem\s*\(\s*path\s*,\s*A_LineNumber\s*\)\s*$'
        # UnZipNesting itself performs no source RecycleItem (Task 5 zipx owns clean-OK recycle).
        $b | Should Not Match 'RecycleItem\s*\(\s*path'
    }

    It 'zipx forces TestArchive before top-level or nested source handling even if test is 0' {
        $u = $script:UnzipBody
        $u | Should Match 'TestArchive\s*\('
        $u | Should Match 'this\.test'
        $u | Should Match 'delSource|delWhenHasPass'
        $u | Should Match 'nestedMayRecycle'
        # must not skip test solely because test flag is false when delete is enabled
        ($u -match 'forceTest|this\.test\s*\|\||mayHandleSource|mayDel') | Should Be $true
    }

    It 'Unzip no longer assigns succesSpercent from ini.successPercent' {
        $script:UnzipBody | Should Not Match 'succesSpercent\s*:=\s*ini\.successPercent'
        $script:UnzipBody | Should Not Match 'this\.succesSpercent\s*:=\s*ini\.successPercent'
    }

    It 'successPercent key remains in ini map and new-install default still written' {
        $script:SmartZipSource | Should Match 'successPercent\s*:'
        $script:IniCreateBody | Should Match 'setWrite\s*\(\s*"successPercent"'
    }

    It 'settings UI removes 判断解压成功百分比 control but keeps test checkbox' {
        $script:SettingsGuiRegion | Should Not Match '判断解压成功百分比'
        $script:SettingsGuiRegion | Should Not Match 'GuiUpDownEdit\s*\(\s*"successPercent"'
        $script:SettingsGuiRegion | Should Match 'GuiCheckBox\s*\(\s*"test"'
    }

    It 'migration removes only exact extExp values zi 7 z and preserves digit regex default' {
        $b = $script:IniCreateBody
        $m = $script:MigrateDeprecatedExtExpBody
        [string]::IsNullOrEmpty($b) | Should Be $false
        [string]::IsNullOrEmpty($m) | Should Be $false
        # Must still seed ^\d+$ for new installs
        $b | Should Match '\\\^\\d\+\$|"\^\\d\+\$"'
        # Must not seed broad zi/7/z as new defaults
        $b | Should Not Match 'Write\s*\(\s*"zi"\s*,\s*2\s*,\s*"extExp"\s*\)'
        $b | Should Not Match 'Write\s*\(\s*"7"\s*,\s*3\s*,\s*"extExp"\s*\)'
        $b | Should Not Match 'Write\s*\(\s*"z"\s*,\s*4\s*,\s*"extExp"\s*\)'
        # IniCreate invokes the script-level migration; its body filters exact tokens.
        $b | Should Match 'MigrateDeprecatedExtExp\s*\('
        $m | Should Match 'var\s*==\s*"zi"'
        $m | Should Match 'var\s*==\s*"7"'
        $m | Should Match 'var\s*==\s*"z"'
    }

    It 'migration does not rewrite unrelated INI sections wholesale' {
        $b = $script:MigrateDeprecatedExtExpBody
        # Forbid wiping entire password/ext sections blindly; migration should target extExp indices only
        $b | Should Not Match 'IniDelete\s*\(\s*this\.path\s*,\s*"password"\s*\)'
        $b | Should Not Match 'FileDelete\s*\(\s*ini\.path\s*\)'
        $b | Should Match 'extExp'
    }

    It 'nested clean OK source recycle remains only in zipx lifecycle and is never permanent' {
        $u = $script:UnzipBody
        $u | Should Match 'loopPath'
        $u | Should Match 'isCleanSuccess|ArchiveStatus\.OK'
        # Warning must not authorize nested handling; source paths never use delete:=true.
        $u | Should Match 'OK_WITH_WARNING'
        $u | Should Match 'nestedMayRecycle\s*:=\s*false'
        $u | Should Not Match 'RecycleItem\s*\(\s*path\s*,[^\n]*true'
    }
}

$script:DiagnosticButtonsBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    DiagnosticButtons(" -EndMarker "`n    FormatDiagnosticCopy("
if ([string]::IsNullOrEmpty($script:DiagnosticButtonsBody)) {
    $script:DiagnosticButtonsBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    DiagnosticButtons(" -EndMarker "`n    RunCmdCapture("
}
$script:RotateDiagnosticLogBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    RotateDiagnosticLogIfNeeded(" -EndMarker "`n    RunCmdCapture("
$script:AppendRotatingDiagnosticLogBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    AppendRotatingDiagnosticLog(" -EndMarker "`n    RotateDiagnosticLogIfNeeded("
if ([string]::IsNullOrEmpty($script:AppendRotatingDiagnosticLogBody)) {
    $script:AppendRotatingDiagnosticLogBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    AppendRotatingDiagnosticLog(" -EndMarker "`n    RunCmdCapture("
}

Describe 'DiagnosticUISafety' {

    It 'WriteDiagnostic precedes ShowDiagnostic which precedes RunCmdCapture' {
        $w = $script:SmartZipSource.IndexOf("`n    WriteDiagnostic(")
        $s = $script:SmartZipSource.IndexOf("`n    ShowDiagnostic(")
        $r = $script:SmartZipSource.IndexOf("`n    RunCmdCapture(")
        ($w -ge 0 -and $s -gt $w -and $r -gt $s) | Should Be $true
        [string]::IsNullOrEmpty($script:WriteDiagnosticBody) | Should Be $false
        [string]::IsNullOrEmpty($script:ShowDiagnosticBody) | Should Be $false
    }

    It 'ShowDiagnostic and WriteDiagnostic public signatures unchanged' {
        $script:SmartZipSource | Should Match '(?m)^    ShowDiagnostic\(result,\s*isBatch\s*:=\s*false\)'
        $script:SmartZipSource | Should Match '(?m)^    WriteDiagnostic\(result\)'
        $script:SmartZipSource | Should Not Match '(?m)^    ShowDiagnostic\([^)]*isBatch\s*:=\s*true'
        $script:SmartZipSource | Should Not Match '(?m)^    WriteDiagnostic\(result\s*,'
    }

    It 'failure and warning Chinese diagnostic titles exist' {
        $script:SmartZipSource | Should Match 'SmartZip 解压警告'
        $script:SmartZipSource | Should Match 'SmartZip 未完成解压'
        $script:SmartZipSource | Should Match '(?m)^    DiagnosticTitle\s*\('
        $script:SmartZipSource | Should Match 'OK_WITH_WARNING'
    }

    It 'all six diagnostic button labels exist' {
        foreach ($label in @(
                '打开部分文件目录',
                '重新输入密码',
                '定位首卷',
                '使用 7-Zip 打开',
                '复制脱敏诊断信息',
                '关闭'
            )) {
            ($script:SmartZipSource.Contains($label)) | Should Be $true
        }
    }

    It 'partial directory action requires non-empty existing partialOutputDir' {
        $btn = $script:DiagnosticButtonsBody
        if ([string]::IsNullOrEmpty($btn)) { $btn = $script:SmartZipSource }
        $btn | Should Match 'partialOutputDir'
        $btn | Should Match '打开部分文件目录'
        $ok = Test-Regex -Text $btn -Pattern 'DirExist\s*\(\s*result\.partialOutputDir|partialOutputDir\s*!=\s*""'
        $ok | Should Be $true
    }

    It 'password retry limited to NEED_PASSWORD and WRONG_PASSWORD' {
        $btn = $script:DiagnosticButtonsBody
        if ([string]::IsNullOrEmpty($btn)) { $btn = $script:SmartZipSource }
        $btn | Should Match 'NEED_PASSWORD'
        $btn | Should Match 'WRONG_PASSWORD'
        $btn | Should Match '重新输入密码'
        $ok = Test-Regex -Text $btn -Pattern `
            '(?s)(NEED_PASSWORD|WRONG_PASSWORD).{0,240}重新输入密码|重新输入密码.{0,240}(NEED_PASSWORD|WRONG_PASSWORD)'
        $ok | Should Be $true
    }

    It 'locate first volume limited to MISSING_VOLUME' {
        $btn = $script:DiagnosticButtonsBody
        if ([string]::IsNullOrEmpty($btn)) { $btn = $script:SmartZipSource }
        $btn | Should Match 'MISSING_VOLUME'
        $btn | Should Match '定位首卷'
        $ok = Test-Regex -Text $btn -Pattern `
            '(?s)MISSING_VOLUME.{0,240}定位首卷|定位首卷.{0,240}MISSING_VOLUME'
        $ok | Should Be $true
    }

    It 'batch mode uses this.muilt reset and one outer ShowBatchDiagnosticSummary' {
        $u = $script:UnzipBody
        $u | Should Match 'this\.muilt'
        $okReset = Test-Regex -Text $u -Pattern `
            '(?s)isBatch\s*:=\s*this\.muilt.{0,400}batchDiagnostic|(!loopPath\s*&&\s*(this\.muilt|isBatch)).{0,400}batchDiagnostic'
        $okReset | Should Be $true
        $okSum = Test-Regex -Text $u -Pattern `
            '(?s)(!loopPath\s*&&\s*(isBatch|this\.muilt)).{0,200}ShowBatchDiagnosticSummary\s*\('
        $okSum | Should Be $true
        $defs = [regex]::Matches($script:SmartZipSource, '(?m)^    ShowBatchDiagnosticSummary\s*\(')
        $defs.Count | Should Be 1
    }

    It 'batch buckets are success warning failure skipped' {
        $script:SmartZipSource | Should Match 'success:\s*\[\]'
        $script:SmartZipSource | Should Match 'warning:\s*\[\]'
        $script:SmartZipSource | Should Match 'failure:\s*\[\]'
        $script:SmartZipSource | Should Match 'skipped:\s*\[\]'
        $script:SmartZipSource | Should Match '(?m)^    RecordBatchDiagnostic\s*\('
        $script:SmartZipSource | Should Match 'batchBucket'
    }

    It 'OK and CANCELLED create neither popup nor rotating log entry' {
        $show = $script:ShowDiagnosticBody
        if ([string]::IsNullOrEmpty($show)) { $show = '' }
        $show | Should Match 'CANCELLED'
        $okSilent = Test-Regex -Text $show -Pattern `
            '(?s)(OK|CANCELLED).{0,400}return|return.{0,120}(OK|CANCELLED)'
        $okSilent | Should Be $true
        $wd = $script:WriteDiagnosticBody
        $wd | Should Match 'OK_WITH_WARNING|AppendRotatingDiagnosticLog'
        $wd | Should Match 'CANCELLED'
    }

    It 'warning and failure paths call WriteDiagnostic' {
        $script:SmartZipSource | Should Match 'WriteDiagnostic\s*\(\s*result\s*\)'
        $show = $script:ShowDiagnosticBody
        $u = $script:UnzipBody
        $ok = (Test-Regex -Text $show -Pattern 'WriteDiagnostic\s*\(') -or
            (Test-Regex -Text $u -Pattern 'WriteDiagnostic\s*\(')
        $ok | Should Be $true
        $wd = $script:WriteDiagnosticBody
        $wd | Should Match 'AppendRotatingDiagnosticLog\s*\('
    }

    It 'rotating log names are SmartZip-diagnostics.log .1 and .2' {
        $script:SmartZipSource | Should Match 'SmartZip-diagnostics\.log'
        (Test-Regex -Text $script:SmartZipSource -Pattern 'logPath\s*"\.1') | Should Be $true
        (Test-Regex -Text $script:SmartZipSource -Pattern 'logPath\s*"\.2') | Should Be $true
    }

    It 'rotation threshold is 1048576 and log writer uses UTF-8' {
        $script:SmartZipSource | Should Match '1048576'
        $rot = $script:RotateDiagnosticLogBody
        if ([string]::IsNullOrEmpty($rot)) { $rot = $script:SmartZipSource }
        $rot | Should Match 'FileGetSize\s*\(\s*logPath\s*\)\s*<\s*1048576'
        $app = $script:AppendRotatingDiagnosticLogBody
        if ([string]::IsNullOrEmpty($app)) { $app = $script:SmartZipSource }
        $app | Should Match 'FileAppend\s*\([^,]+,\s*logPath\s*,\s*"UTF-8"\s*\)'
        $script:WriteDiagnosticBody | Should Match 'FileAppend\s*\([^,]+,\s*diagPath\s*,\s*"UTF-8"\s*\)'
    }

    It 'copy redacts with false full path; local log permits full paths' {
        $script:SmartZipSource | Should Match 'RedactDiagnostic\s*\([^,]+,\s*false\s*\)'
        $okLog = Test-Regex -Text $script:WriteDiagnosticBody -Pattern `
            'RedactDiagnostic\s*\(\s*[^,\)]+\s*\)|RedactDiagnostic\s*\([^,]+,\s*true\s*\)'
        $okLog | Should Be $true
        $script:SmartZipSource | Should Match '(?m)^    FormatDiagnosticCopy\s*\('
    }

    It 'passwordUsed and clipboard contents absent from diagnostic composition' {
        # Composition methods only — exclude button action sinks that may write clipboard.
        $markers = @(
            @{ Start = "`n    WriteDiagnostic("; End = "`n    DiagnosticTitle(" },
            @{ Start = "`n    DiagnosticReason("; End = "`n    DiagnosticRecommendation(" },
            @{ Start = "`n    DiagnosticRecommendation("; End = "`n    DiagnosticButtons(" },
            @{ Start = "`n    FormatDiagnosticCopy("; End = "`n    FormatDiagnosticLogEntry(" },
            @{ Start = "`n    FormatDiagnosticLogEntry("; End = "`n    RecordBatchDiagnostic(" }
        )
        foreach ($m in $markers) {
            $slice = Get-SourceSlice -Source $script:SmartZipSource -StartMarker $m.Start -EndMarker $m.End
            if ([string]::IsNullOrEmpty($slice)) { continue }
            $slice | Should Not Match 'passwordUsed'
            $slice | Should Not Match 'A_Clipboard'
        }
        $script:WriteDiagnosticBody | Should Not Match 'passwordUsed'
    }

    It 'every legacy cmdLog testLog append is wrapped in RedactDiagnostic' {
        $combined = $script:SmartZipSource
        (Test-Regex -Text $combined -Pattern 'RedactDiagnostic\s*\(') | Should Be $true
        $rawCmdArgs = Test-Regex -Text $combined -Pattern `
            "testLog\s*\.=\s*'``n#####``n'\s*cmdArgs|testLog\s*\.=\s*``n#####``n'\s*cmdArgs"
        # Bare cmdArgs concatenation without RedactDiagnostic is forbidden
        $rawBare = Test-Regex -Text $combined -Pattern `
            "testLog\s*\.=\s*'``n#####``n'\s*cmdArgs\s*'``n'"
        $rawBare | Should Be $false
        $hasRedactCmdArgs = Test-Regex -Text $combined -Pattern 'RedactDiagnostic\s*\(\s*cmdArgs\s*\)'
        $hasRedactCmdArgs | Should Be $true
        $hasRedactLine = Test-Regex -Text $combined -Pattern 'RedactDiagnostic\s*\(\s*line\s*\)'
        $hasRedactLine | Should Be $true
    }
}
