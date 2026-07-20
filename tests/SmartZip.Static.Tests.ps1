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
