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
