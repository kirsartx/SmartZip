#requires -Version 5.0
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:HarnessPath = Join-Path $PSScriptRoot 'NestingMigration.Harness.ahk'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'

function Get-SmartZipSourceText([string]$SmartZipPath) {
    $raw = Get-Content -LiteralPath $SmartZipPath -Raw -Encoding UTF8
    if ($raw -notmatch 'IsArchive|UnZipNesting|class SmartZip') {
        $raw = Get-Content -LiteralPath $SmartZipPath -Raw
    }
    return $raw
}

function Get-SourceSlice {
    param(
        [string]$Source,
        [string]$StartMarker,
        [string]$EndMarker
    )
    $start = $Source.IndexOf($StartMarker)
    if ($start -lt 0) { return $null }
    $end = $Source.IndexOf($EndMarker, $start + $StartMarker.Length)
    if ($end -lt 0) { return $Source.Substring($start) }
    return $Source.Substring($start, $end - $start)
}

function Assert-ExactlyOneOccurrence([string]$Text, [string]$Name, [string]$Pattern) {
    $matches = [regex]::Matches($Text, $Pattern)
    if ($matches.Count -ne 1) {
        throw "expected exactly one $Name occurrence, found $($matches.Count)"
    }
}

function New-NestingMigrationProductHost {
    param(
        [Parameter(Mandatory = $true)][string]$SmartZipPath,
        [Parameter(Mandatory = $true)][string]$OutputRoot
    )
    if (-not (Test-Path -LiteralPath $SmartZipPath)) {
        throw "SmartZip.ahk not found: $SmartZipPath"
    }
    $src = Get-SmartZipSourceText $SmartZipPath

    $isArchiveSlice = Get-SourceSlice -Source $src -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    IsNestedArchiveCandidate("
    if ([string]::IsNullOrEmpty($isArchiveSlice)) {
        throw 'product IsArchive method slice missing (before IsNestedArchiveCandidate)'
    }
    $nestedCandidateSlice = Get-SourceSlice -Source $src -StartMarker "`n    IsNestedArchiveCandidate(" -EndMarker "`n    ProbeArchive("
    if ([string]::IsNullOrEmpty($nestedCandidateSlice)) {
        throw 'product IsNestedArchiveCandidate method slice missing'
    }
    Assert-ExactlyOneOccurrence $isArchiveSlice 'IsArchive def' '(?m)^    IsArchive\s*\('
    Assert-ExactlyOneOccurrence $nestedCandidateSlice 'IsNestedArchiveCandidate def' '(?m)^    IsNestedArchiveCandidate\s*\('

    $migrateSlice = Get-SourceSlice -Source $src -StartMarker "`nMigrateDeprecatedExtExp()" -EndMarker "`nIniCreate()"
    if ([string]::IsNullOrEmpty($migrateSlice)) {
        throw 'product MigrateDeprecatedExtExp slice missing'
    }
    Assert-ExactlyOneOccurrence $migrateSlice 'MigrateDeprecatedExtExp def' '(?m)^MigrateDeprecatedExtExp\s*\('

    $unzipBody = Get-SourceSlice -Source $src -StartMarker "`n    Unzip(loopPath" -EndMarker "`n    OpenZip()"
    if ([string]::IsNullOrEmpty($unzipBody)) {
        throw 'product Unzip body missing'
    }
    $unZipNestingBody = $null
    $mNest = [regex]::Match($unzipBody, '(?s)(UnZipNesting\s*\(\s*path\s*,\s*ext\s*\)\s*\{.*?\n        \})')
    if (-not $mNest.Success) {
        throw 'product UnZipNesting helper missing from Unzip body'
    }
    $unZipNestingBody = $mNest.Groups[1].Value
    Assert-ExactlyOneOccurrence $unzipBody 'UnZipNesting def' 'UnZipNesting\s*\(\s*path\s*,\s*ext\s*\)\s*\{'
    if ($unZipNestingBody -notmatch 'ProbeArchive\s*\(') {
        throw 'product UnZipNesting must call ProbeArchive'
    }
    if ($unZipNestingBody -notmatch 'IsNestedArchiveCandidate\s*\(') {
        throw 'product UnZipNesting must call IsNestedArchiveCandidate'
    }

    $zipxForce = $null
    $mForce = [regex]::Match($unzipBody, '(?s)(; test=0 still forces[^\r\n]*\r?\n.*?if \(nestedMayRecycle && extractResult\.isCleanSuccess && !volume\.isVolume && FileExist\(path\)\)\s*\r?\n\s*this\.RecycleItem\(path, A_LineNumber, false\))')
    if (-not $mForce.Success) {
        $mForce = [regex]::Match($unzipBody, '(?s)(mayHandleSource\s*:=\s*\(!loopPath\).*?if \(nestedMayRecycle && extractResult\.isCleanSuccess && !volume\.isVolume && FileExist\(path\)\)\s*\r?\n\s*this\.RecycleItem\(path, A_LineNumber, false\))')
    }
    if (-not $mForce.Success) {
        throw 'product zipx mayHandleSource..nestedMayRecycle block missing'
    }
    $zipxForce = $mForce.Groups[1].Value
    Assert-ExactlyOneOccurrence $zipxForce 'forceTest' 'forceTest\s*:='
    # initial assignment plus OK_WITH_WARNING disable assignment
    $nmr = [regex]::Matches($zipxForce, 'nestedMayRecycle\s*:=')
    if ($nmr.Count -lt 1) { throw 'expected nestedMayRecycle assignment in zipx force block' }

    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    }
    $libDir = Join-Path $OutputRoot 'lib'
    $workDir = Join-Path $OutputRoot 'work'
    New-Item -ItemType Directory -Path $libDir, $workDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk') `
        -Destination (Join-Path $libDir 'ArchiveDiagnostics.ahk') -Force

    $outAhk = Join-Path $OutputRoot 'NestingMigration.Product.ahk'
    $isArchiveMethod = $isArchiveSlice.TrimStart("`r", "`n")
    $nestedCandidateMethod = $nestedCandidateSlice.TrimStart("`r", "`n")
    $migrateFn = $migrateSlice.TrimStart("`r", "`n")

    # Convert nested helper into a class method (same body, 4-space class indent).
    $nestMethod = $unZipNestingBody -replace '(?m)^        ', '    '
    $nestMethod = $nestMethod -replace 'UnZipNesting\s*\(', 'UnZipNesting('

    $header = @'
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib\ArchiveDiagnostics.ahk

outPath := A_Args.Length >= 1 ? A_Args[1] : A_Temp "\NestingMigration.product.out.txt"
passCount := 0
failCount := 0
lines := []

AssertEq(actual, expected, name) {
    global passCount, failCount, lines
    a := String(actual), e := String(expected)
    if (a = e) {
        passCount++
        lines.Push("PASS " name)
    } else {
        failCount++
        lines.Push("FAIL " name " expected=[" e "] actual=[" a "]")
    }
}
AssertTrue(cond, name) => AssertEq(cond ? "1" : "0", "1", name)
AssertFalse(cond, name) => AssertEq(cond ? "1" : "0", "0", name)

; Minimal ini double for product MigrateDeprecatedExtExp (real IniRead/Write against temp path)
class ini
{
    static path := ""
    static Init(path) => this.path := path
    static Read(Key, default := "", section := "") => IniRead(this.path, section, key, default)
    static Write(value := "", Key := "", section := "") {
        static sectionSave := section
        if section
            sectionSave := section
        IniWrite(value, this.path, sectionSave, key)
    }
    static Delete(section, key) {
        IniDelete(this.path, section, key)
    }
}

'@

    $classOpen = @'

class NestingProductHost {
    ext := Map()
    extExp := []
    exitCode := -1
    callOrder := []
    scriptedProbeStatus := ArchiveStatus.OK
    siblingOverride := unset
    recycled := []
    test := 0
    delSource := 0
    delWhenHasPass := 0

    Reset() {
        this.callOrder := []
        this.recycled := []
        this.exitCode := -1
        this.scriptedProbeStatus := ArchiveStatus.OK
        this.siblingOverride := unset
    }

    ProbeArchive(path) {
        this.callOrder.Push("probe")
        return ArchiveResult(this.scriptedProbeStatus, "probe", 0, path)
    }

    Unzip(path) {
        this.callOrder.Push("unzip")
    }

    Loging(params*) {
    }

    RecycleItem(souce, lineNum, delete := false) {
        this.recycled.Push({ path: souce, delete: delete })
    }

    ; product IsArchive / IsNestedArchiveCandidate injected below
'@

    $classMid = @'

    ; product UnZipNesting as method
'@

    $classClose = @'
}

; product MigrateDeprecatedExtExp (script-level)
'@

    $footer = @'

RunMigrateCase(rules) {
    iniPath := A_ScriptDir "\work\migrate.ini"
    try FileDelete(iniPath)
    try DirCreate(A_ScriptDir "\work")
    FileAppend("", iniPath, "UTF-8")
    ini.Init(iniPath)
    for i, r in rules
        ini.Write(r, i, "extExp")
    MigrateDeprecatedExtExp()
    out := []
    loop {
        if !(var := ini.Read(A_Index, , "extExp"))
            break
        out.Push(var)
    }
    return out
}

ProductForceTest(testFlag, mayHandleSource, nestedMayRecycle := false) {
    ; Exact product expression: forceTest := this.test || mayHandleSource || nestedMayRecycle
    return (testFlag ? true : false) || (mayHandleSource ? true : false) || (nestedMayRecycle ? true : false)
}

ProductNestedSourceAction(status, isNested, isVolumeMember) {
    ; Product: nestedMayRecycle := loopPath && !volume.isVolume && (resolved.status = ArchiveStatus.OK)
    ; then recycle only when nestedMayRecycle && extractResult.isCleanSuccess && !volume.isVolume
    nestedMayRecycle := isNested && !isVolumeMember && (status = ArchiveStatus.OK)
    isCleanSuccess := (status = ArchiveStatus.OK)
    if (nestedMayRecycle && isCleanSuccess && !isVolumeMember)
        return "recycle_nested"
    return "none"
}

RunNestedOrder(host, path, ext, status) {
    host.scriptedProbeStatus := status
    host.callOrder := []
    if host.IsNestedArchiveCandidate(path, ext)
        host.callOrder.Push("candidate")
    host.UnZipNesting(path, ext)
    return host.callOrder
}

host := NestingProductHost()

; --- same 29 named cases as oracle, driven by product slices ---
extMap := Map("zip", true, "7z", true, "rar", true, "001", true)
extExp := ["^\d+$", "zi", "7", "z", "ZI", "custom$"]
host.ext := extMap.Clone()
host.extExp := extExp.Clone()

AssertFalse(host.IsArchive(""), "empty_ext_not_archive")
emptyPath := A_ScriptDir "\work\file"
try DirCreate(A_ScriptDir "\work")
if !FileExist(emptyPath)
    FileAppend("x", emptyPath, "UTF-8")
host.ext := Map()
host.extExp := []
AssertFalse(host.IsNestedArchiveCandidate(emptyPath, ""), "empty_ext_not_candidate")

host.ext := extMap.Clone()
host.extExp := extExp.Clone()
AssertTrue(host.IsArchive("zip"), "exact_zip_is_candidate")
AssertTrue(host.IsArchive("7Z"), "exact_7z_casefold_candidate")
AssertTrue(host.IsArchive("123"), "digit_regex_candidate")
host.extExp := ["custom$"]
AssertTrue(host.IsArchive("mycustom"), "custom_regex_candidate")
AssertFalse(host.IsArchive("nope"), "custom_regex_non_match")

volDir := A_ScriptDir "\work\vol"
try DirCreate(volDir)
v1 := volDir "\pack.7z.001"
v2 := volDir "\pack.7z.002"
if !FileExist(v1)
    FileAppend("v1", v1, "UTF-8")
if !FileExist(v2)
    FileAppend("v2", v2, "UTF-8")
host.ext := Map()
host.extExp := []
AssertTrue(host.IsNestedArchiveCandidate(v1, "001"), "volume_pattern_candidate")
sibs := ["pack.7z.001", "pack.7z.002"]
g := DetectVolumeGroup(v1, sibs)
AssertTrue(g.isVolume, "volume_detect_is_volume")
AssertTrue(g.selectedIsFirst, "volume_detect_first")

migrated := RunMigrateCase(["^\d+$", "zi", "7", "z", "ZI", "custom$"])
AssertEq(migrated.Length, 3, "migrate_count_three_kept")
AssertEq(migrated[1], "^\d+$", "migrate_keeps_digit_regex")
AssertTrue(migrated[2] == "ZI" && migrated[3] == "custom$", "migrate_keeps_other_custom")
for r in migrated {
    AssertFalse(r == "zi", "migrate_no_zi")
    AssertFalse(r == "7", "migrate_no_7")
    AssertFalse(r == "z", "migrate_no_z")
}

onlyCustom := RunMigrateCase(["foo", "zi", "bar", "7", "z", "baz"])
AssertEq(onlyCustom.Length, 3, "migrate_preserves_three_customs")
AssertEq(onlyCustom[1], "foo", "migrate_order_foo")
AssertEq(onlyCustom[2], "bar", "migrate_order_bar")
AssertEq(onlyCustom[3], "baz", "migrate_order_baz")

AssertEq(ProductNestedSourceAction(ArchiveStatus.OK, true, false), "recycle_nested", "nested_ok_recycles")
AssertEq(ProductNestedSourceAction(ArchiveStatus.OK_WITH_WARNING, true, false), "none", "nested_warn_preserves")
AssertEq(ProductNestedSourceAction(ArchiveStatus.DATA_CORRUPT, true, false), "none", "nested_fail_preserves")
AssertEq(ProductNestedSourceAction(ArchiveStatus.OK, true, true), "none", "nested_volume_never_deletes")
AssertEq(ProductNestedSourceAction(ArchiveStatus.OK, false, false), "none", "top_level_not_nested_delete_here")

AssertTrue(ProductForceTest(1, false), "test1_always_forces_test")
AssertTrue(ProductForceTest(0, true), "test0_forces_test_before_source_handle")
AssertTrue(ProductForceTest(0, false, true) && !ProductForceTest(0, false, false), "test0_nested_forces_and_nohandle_skips")

host.Reset()
host.ext := Map("zip", true)
host.extExp := []
nestZip := A_ScriptDir "\work\inner.zip"
if !FileExist(nestZip)
    FileAppend("z", nestZip, "UTF-8")
orderOk := RunNestedOrder(host, nestZip, "zip", ArchiveStatus.OK)
orderBad := RunNestedOrder(host, nestZip, "zip", ArchiveStatus.NOT_ARCHIVE)
okOrder := (orderOk.Length = 3 && orderOk[1] = "candidate" && orderOk[2] = "probe" && orderOk[3] = "unzip")
badOrder := (orderBad.Length = 2 && orderBad[1] = "candidate" && orderBad[2] = "probe")
AssertTrue(okOrder && badOrder, "nested_requires_probe_stage_before_extract")

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
'@

    $full = $header + $classOpen + "`n" + $isArchiveMethod + "`n" + $nestedCandidateMethod + "`n" +
        $classMid + "`n" + $nestMethod + "`n" + $classClose + "`n" + $migrateFn + "`n" + $footer

    # Product IsNestedArchiveCandidate lists siblings from disk — OK for our temp files.
    # Product UnZipNesting may call DetectVolumeGroup on path — ensure volume first-member semantics.
    [System.IO.File]::WriteAllText($outAhk, $full, [System.Text.UTF8Encoding]::new($true))
    return $outAhk
}

function Export-NestingMigrationProductHarness {
    # Required implementation contract (no oracle fallback):
    # - Slice exact product IsArchive + IsNestedArchiveCandidate methods,
    #   exact UnZipNesting helper, script-level MigrateDeprecatedExtExp, and
    #   the zipx block from mayHandleSource through FinalizeExtraction.
    # - Throw unless each region occurs exactly once.
    # - Generate a TEMP host with INI/probe/volume/recycle spies and the same
    #   29 named keys; never copy IsArchiveExt, NestedSourceAction,
    #   ShouldForceTestArchive, or ShouldEnterNestedAfterProbe from the oracle.
    # - For nested_requires_probe_stage_before_extract, the product host spy
    #   must record call order ["candidate","probe","unzip"] for OK and
    #   ["candidate","probe"] for NOT_ARCHIVE, with no unzip call.
    $productHarness = New-NestingMigrationProductHost `
        -SmartZipPath (Join-Path $script:RepoRoot 'SmartZip.ahk') `
        -OutputRoot (Join-Path $env:TEMP ("SmartZip-Nesting-Product-{0}" -f ([guid]::NewGuid().ToString('N'))))
    if (-not (Test-Path -LiteralPath $productHarness)) { throw 'product nesting harness was not generated' }
    return $productHarness
}

function Invoke-NestingMigrationHarness([string]$HarnessPath, [string]$Label) {
    $outFile = Join-Path $env:TEMP ("NestingMigration.{0}.{1}.out.txt" -f $Label,([guid]::NewGuid().ToString('N')))
    $runPath = $HarnessPath
    $harnessDir = [System.IO.Path]::GetDirectoryName($HarnessPath)
    $tempRoot = $env:TEMP
    $isUnderTemp = $harnessDir.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)
    $stagedRoot = $null
    if (-not $isUnderTemp) {
        $stagedRoot = Join-Path $tempRoot ("SmartZip-Nest-Run-{0}" -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null
        $leaf = [System.IO.Path]::GetFileName($HarnessPath)
        $runPath = Join-Path $stagedRoot $leaf
        Copy-Item -LiteralPath $HarnessPath -Destination $runPath -Force
        $libSrc = Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk'
        if (Test-Path -LiteralPath $libSrc) {
            $libDst = Join-Path $stagedRoot 'lib'
            New-Item -ItemType Directory -Path $libDst -Force | Out-Null
            Copy-Item -LiteralPath $libSrc -Destination (Join-Path $libDst 'ArchiveDiagnostics.ahk') -Force
        }
        if ($leaf -eq 'NestingMigration.Harness.ahk') {
            $text = Get-Content -LiteralPath $runPath -Raw -Encoding UTF8
            $text = $text.Replace('#Include %A_ScriptDir%\..\lib\ArchiveDiagnostics.ahk',
                '#Include %A_ScriptDir%\lib\ArchiveDiagnostics.ahk')
            [System.IO.File]::WriteAllText($runPath, $text, [System.Text.UTF8Encoding]::new($false))
        }
    }
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList @('/ErrorStdOut', $runPath, $outFile) `
        -Wait -PassThru -NoNewWindow -WorkingDirectory ([System.IO.Path]::GetDirectoryName($runPath))
    $map = @{}
    if (Test-Path -LiteralPath $outFile) {
        Get-Content -LiteralPath $outFile -Encoding UTF8 | ForEach-Object {
            if ($_ -match '^(PASS|FAIL)\s+(\S+)') { $map[$matches[2]] = $matches[1] }
            elseif ($_ -match '^SUMMARY\s+passed=(\d+)\s+failed=(\d+)') {
                $map['__summary_passed'] = $matches[1]
                $map['__summary_failed'] = $matches[2]
            }
        }
    }
    if ($stagedRoot -and (Test-Path -LiteralPath $stagedRoot)) {
        try { Remove-Item -LiteralPath $stagedRoot -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    return [pscustomobject]@{ ExitCode = $p.ExitCode; Map = $map }
}

Describe 'NestingMigrationBehavior' {
    BeforeAll {
        $script:OracleRun = Invoke-NestingMigrationHarness $script:HarnessPath 'oracle'
        $script:ProductHarnessPath = Export-NestingMigrationProductHarness
        $script:ProductRun = Invoke-NestingMigrationHarness $script:ProductHarnessPath 'product'
    }

    It 'oracle and product harnesses exit 0' {
        $script:OracleRun.ExitCode | Should Be 0
        $script:ProductRun.ExitCode | Should Be 0
    }

    $cases = @(
        'empty_ext_not_archive',
        'empty_ext_not_candidate',
        'exact_zip_is_candidate',
        'exact_7z_casefold_candidate',
        'digit_regex_candidate',
        'custom_regex_candidate',
        'custom_regex_non_match',
        'volume_pattern_candidate',
        'volume_detect_is_volume',
        'volume_detect_first',
        'migrate_count_three_kept',
        'migrate_keeps_digit_regex',
        'migrate_keeps_other_custom',
        'migrate_no_zi',
        'migrate_no_7',
        'migrate_no_z',
        'migrate_preserves_three_customs',
        'migrate_order_foo',
        'migrate_order_bar',
        'migrate_order_baz',
        'nested_ok_recycles',
        'nested_warn_preserves',
        'nested_fail_preserves',
        'nested_volume_never_deletes',
        'top_level_not_nested_delete_here',
        'test1_always_forces_test',
        'test0_forces_test_before_source_handle',
        'test0_nested_forces_and_nohandle_skips',
        'nested_requires_probe_stage_before_extract'
    )

    foreach ($name in $cases) {
        It "oracle and product behavior $name PASS" {
            $script:OracleRun.Map.ContainsKey($name) | Should Be $true
            $script:ProductRun.Map.ContainsKey($name) | Should Be $true
            $script:OracleRun.Map[$name] | Should Be 'PASS'
            $script:ProductRun.Map[$name] | Should Be 'PASS'
        }
    }
}
