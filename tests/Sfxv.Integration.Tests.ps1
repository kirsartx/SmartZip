$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TestHelper.ps1')
$repo = Split-Path $PSScriptRoot -Parent
$engine = 'C:\Tool\7-Zip-Zstandard\7z.exe'
$root = Join-Path $env:TEMP ('SmartZip-SfxvIntegration-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root | Out-Null
# Harmless data-only MZ prefix. None of these fixture EXEs is ever executed.
$payload = New-Object byte[] 12000
[Random]::new(193).NextBytes($payload)
[IO.File]::WriteAllBytes((Join-Path $root 'payload.bin'), $payload)
$secret = [guid]::NewGuid().ToString('N')
$env:SMARTZIP_SFXV_PASSWORD = $secret
foreach ($kind in @('plain','encrypted','warning')) {
    $dir = Join-Path $root $kind
    New-Item -ItemType Directory $dir | Out-Null
    $archive = Join-Path $dir 'source.7z'
    $args7z = @('a','-t7z','-mx=0',$archive,(Join-Path $root 'payload.bin'))
    if ($kind -eq 'encrypted') { $args7z += @('-mhe=on',('-p' + $secret)) }
    & $engine @args7z *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Fixture generation failed' }
    $stub = New-Object byte[] 128
    $stub[0] = 77; $stub[1] = 90
    [byte[]]$bytes = $stub + [IO.File]::ReadAllBytes($archive)
    if ($kind -eq 'warning') { $bytes += [byte[]](1..100) }
    for ($offset = 0; $offset -lt $bytes.Length; $offset += 4096) {
        $index = [int]($offset / 4096)
        $name = if ($index -eq 0) { 'game.exe' } else { 'game.{0:000}.sfxv' -f $index }
        $length = [Math]::Min(4096, $bytes.Length - $offset)
        $piece = New-Object byte[] $length
        [Array]::Copy($bytes, $offset, $piece, 0, $length)
        [IO.File]::WriteAllBytes((Join-Path $dir $name), $piece)
    }
}
$before = @{}
Get-ChildItem $root -Recurse -File | Where-Object { $_.Extension -in @('.exe','.sfxv') } | ForEach-Object {
    $before[$_.FullName] = (Get-FileHash $_.FullName).Hash
}
$source = Get-Content (Join-Path $repo 'SmartZip.ahk') -Raw -Encoding UTF8
function Slice($start, $end) {
    $a = $source.IndexOf("`n    $start(")
    $b = $source.IndexOf("`n    $end(", $a + 1)
    if ($a -lt 0 -or $b -lt 0) { throw 'Missing production method slice' }
    $source.Substring($a, $b - $a)
}
$methods = (Slice 'ProbeArchive' 'BuildPasswordCandidates') + (Slice 'ExtractArchiveToTemp' 'FinalizeExtraction')
$capture = (Slice 'RunCmdCapture' 'RunCmd').Replace('RunCmdCapture(CmdLine', 'CaptureReal(CmdLine')
$program = @'
#Requires AutoHotkey v2.0
#Include __LIB__
class Host {
    7z := '"C:\Tool\7-Zip-Zstandard\7z.exe"'
    cmdLog := false
    guiShow := false
    hideRunSize := 999
    excludeArgs := ""
    codePage := ""
    timingLog := true
    commands := []
    RunCmdCapture(cmd, encoding := "UTF-8") {
        this.commands.Push(cmd)
        return this.CaptureReal(cmd, encoding)
    }
    IsArchive(ext) => ext = "exe"
    Run7z(hide, action, path, args, rest*) {
        this.commands.Push(action ' "' path args)
        this.exitCode := RunWait(this.7z ' ' action ' "' path args, , "Hide")
    }
__METHODS__
__CAPTURE__
}
Check(value, label) {
    FileAppend(label "=" (value ? "PASS" : "FAIL") "`n", A_Args[2], "UTF-8")
}
root := A_Args[1]
h := Host()
for kind in ["plain", "encrypted", "warning"] {
    first := root "\" kind "\game.exe"
    selected := root "\" kind "\game.002.sfxv"
    password := kind = "encrypted" ? EnvGet("SMARTZIP_SFXV_PASSWORD") : ""
    h.commands := []
    probe := h.ProbeArchive(selected)
    Check(probe.archivePath = first, kind "_probe_identity")
    Check(kind = "encrypted" ? (probe.status = ArchiveStatus.NEED_PASSWORD || probe.status = ArchiveStatus.WRONG_PASSWORD)
        : (probe.status = ArchiveStatus.OK || probe.status = ArchiveStatus.OK_WITH_WARNING), kind "_probe")
    tested := h.TestArchive(selected, password)
    Check(tested.status = (kind = "warning" ? ArchiveStatus.OK_WITH_WARNING : ArchiveStatus.OK), kind "_test")
    Check(tested.archivePath = first, kind "_test_identity")
    extracted := h.ExtractArchiveToTemp(selected, password, root "\" kind "\output")
    Check(extracted.status = (kind = "warning" ? ArchiveStatus.OK_WITH_WARNING : ArchiveStatus.OK), kind "_extract")
    Check(extracted.archivePath = first, kind "_extract_identity")
    Check(FileExist(root "\" kind "\output\payload.bin"), kind "_payload")
    routed := h.commands.Length = 4
    for cmd in h.commands
        routed := routed && InStr(cmd, "archive.7z") && !InStr(cmd, "game.exe") && !InStr(cmd, ".sfxv")
    Check(routed, kind "_routes_list_test_extract_finaltest")
    Check(!InStr(extracted.output, "archive.7z.001"), kind "_diagnostic_identity")
}
; Adapter failures must return a result, never fall back to launching input.
bad := root "\missing\game.002.sfxv"
DirCreate(root "\missing")
FileAppend("data", bad)
r := h.ProbeArchive(bad)
Check(r.status = ArchiveStatus.MISSING_VOLUME, "missing_first")
; A failed second hardlink must clean the first one too.
scope := SfxvInput(root "\plain\game.exe")
Check(scope.status = "" && FileExist(scope.commandPath) && FileGetSize(scope.commandPath) = 12130, "adapter_merge")
scope.Close()
scope.Close()
Check(scope.closed, "adapter_cleanup_idempotent")
; Default-off timing does not create a log; enabled timing contains fixed labels only.
Check(FileExist(A_ScriptDir "\SmartZip-timing.log"), "timing_enabled")
ExitApp(0)
'@
$program = $program.Replace('__LIB__',(Join-Path $repo 'lib/ArchiveDiagnostics.ahk')).Replace('__METHODS__',$methods).Replace('__CAPTURE__',$capture)
$scriptPath = Join-Path $root 'integration.ahk'
$resultPath = Join-Path $root 'results.txt'
[IO.File]::WriteAllText($scriptPath,$program,[Text.UTF8Encoding]::new($true))
$p = Start-Process (Resolve-AhkExe) -ArgumentList @('/ErrorStdOut',('"'+$scriptPath+'"'),('"'+$root+'"'),('"'+$resultPath+'"')) -PassThru -NoNewWindow
if (-not $p.WaitForExit(10000)) { $p.Kill(); throw 'SFXV integration timeout' }
Describe 'SFXV real 7-Zip production methods' {
    It 'runs source-extracted methods successfully' { $p.ExitCode | Should Be 0 }
    if (Test-Path $resultPath) {
        foreach ($line in (Get-Content $resultPath)) {
            $parts = $line -split '='
            It $parts[0] { $parts[1] | Should Be 'PASS' }
        }
    }
    It 'preserves every original volume byte' {
        foreach ($entry in $before.GetEnumerator()) { (Get-FileHash $entry.Key).Hash | Should Be $entry.Value }
    }
    It 'cleans all temporary alias directories' {
        @(Get-ChildItem $root -Directory -Recurse -Filter '__smartzip_sfxv_*').Count | Should Be 0
    }
    It 'extracts original payload bytes' {
        foreach ($kind in @('plain','encrypted','warning')) {
            (Get-FileHash (Join-Path $root "$kind\output\payload.bin")).Hash | Should Be (Get-FileHash (Join-Path $root 'payload.bin')).Hash
        }
    }
    It 'writes only operation and duration in timing logs' {
        $lines = Get-Content (Join-Path $root 'SmartZip-timing.log')
        foreach ($line in $lines) { $line | Should Match '^(probe|test|extract) duration_ms=\d+$' }
    }
}
$env:SMARTZIP_SFXV_PASSWORD = $null
