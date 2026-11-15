$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TestHelper.ps1')
. (Join-Path $PSScriptRoot 'SfxvResultHelper.ps1')
$repo = Split-Path $PSScriptRoot -Parent
$engine = 'C:\Tool\7-Zip-Zstandard\7z.exe'
$root = Join-Path $env:TEMP ('SmartZip-SfxvIntegration-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root | Out-Null
# Harmless data-only MZ prefix. None of these fixture EXEs is ever executed.
$payload = New-Object byte[] 12000
[Random]::new(193).NextBytes($payload)
[IO.File]::WriteAllBytes((Join-Path $root 'payload.bin'), $payload)
$secret = [guid]::NewGuid().ToString('N')
$originalSfxvPassword = Get-Item Env:SMARTZIP_SFXV_PASSWORD -ErrorAction SilentlyContinue
$env:SMARTZIP_SFXV_PASSWORD = $secret
# The body below is deliberately left at its original indentation so the
# try/finally that restores the inherited password stays a two-hunk diff.
try {
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
# Reparse-point fixtures: a junction standing where a listed directory was extracted, and a
# second junction sitting unlisted beside files that do verify. They are built here so the
# AHK harness never shells out; the harness reports an unavailable fixture as a failure.
$junctionReady = $false
try {
    $rp = Join-Path $root 'rp'
    New-Item -ItemType Directory (Join-Path $rp 'src\sub') | Out-Null
    $inner = New-Object byte[] 512
    [Random]::new(7).NextBytes($inner)
    [IO.File]::WriteAllBytes((Join-Path $rp 'src\sub\inner.bin'), $inner)
    Push-Location (Join-Path $rp 'src')
    try {
        & $engine a -t7z -mx=0 (Join-Path $rp 'source.7z') 'sub' *> $null
        if ($LASTEXITCODE -ne 0) { throw 'reparse fixture archive failed' }
        & $engine x -y (Join-Path $rp 'source.7z') ('-o' + (Join-Path $rp 'out')) *> $null
        if ($LASTEXITCODE -ne 0) { throw 'reparse fixture extract failed' }
    } finally { Pop-Location }
    # The link target holds a byte-identical inner.bin, so only the reparse guard can keep a
    # naive implementation from reading the outside file and calling the output verified.
    New-Item -ItemType Directory (Join-Path $rp 'outside') | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $rp 'outside\inner.bin'), $inner)
    Remove-Item -LiteralPath (Join-Path $rp 'out\sub') -Recurse -Force
    New-Item -ItemType Junction -Path (Join-Path $rp 'out\sub') -Target (Join-Path $rp 'outside') | Out-Null
    New-Item -ItemType Directory (Join-Path $rp 'src2') | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $rp 'src2\payload2.bin'), $inner)
    Push-Location (Join-Path $rp 'src2')
    try {
        & $engine a -t7z -mx=0 (Join-Path $rp 'source2.7z') 'payload2.bin' *> $null
        if ($LASTEXITCODE -ne 0) { throw 'second reparse fixture archive failed' }
        & $engine x -y (Join-Path $rp 'source2.7z') ('-o' + (Join-Path $rp 'out2')) *> $null
        if ($LASTEXITCODE -ne 0) { throw 'second reparse fixture extract failed' }
    } finally { Pop-Location }
    New-Item -ItemType Directory (Join-Path $rp 'outside2') | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $rp 'outside2\other.bin'), $inner)
    New-Item -ItemType Junction -Path (Join-Path $rp 'out2\link') -Target (Join-Path $rp 'outside2') | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $rp 'rootLink') -Target (Join-Path $rp 'src2') | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $rp 'parentLink') -Target $rp | Out-Null
    $junctionReady = (Test-Path (Join-Path $rp 'out\sub\inner.bin')) -and (Test-Path (Join-Path $rp 'out2\link\other.bin'))
    Write-Host ('REPARSE FIXTURES READY=' + $junctionReady)
} catch {
    Write-Host ('REPARSE FIXTURES UNAVAILABLE: ' + $_.Exception.Message)
    $junctionReady = $false
}
$junctionLiteral = if ($junctionReady) { 'true' } else { 'false' }
$emptySrc = Join-Path $root 'empty-src'
New-Item -ItemType Directory $emptySrc | Out-Null
[IO.File]::WriteAllBytes((Join-Path $emptySrc 'empty.bin'), [byte[]]@())
& $engine a -t7z -mx=0 (Join-Path $root 'empty.7z') (Join-Path $emptySrc 'empty.bin') *> $null
if ($LASTEXITCODE -ne 0) { throw 'Empty fixture creation failed' }
& $engine x -y (Join-Path $root 'empty.7z') ('-o' + (Join-Path $root 'empty-out')) *> $null
if ($LASTEXITCODE -ne 0) { throw 'Empty fixture extraction failed' }
$bomSrc = Join-Path $root 'bom-src'
New-Item -ItemType Directory $bomSrc | Out-Null
[IO.File]::WriteAllBytes((Join-Path $bomSrc 'utf8.txt'), [byte[]](239,187,191,65,66,67))
[IO.File]::WriteAllBytes((Join-Path $bomSrc 'utf16.txt'), [byte[]](255,254,65,0,66,0))
& $engine a -t7z -mx=0 (Join-Path $root 'bom.7z') (Join-Path $bomSrc '*') *> $null
if ($LASTEXITCODE -ne 0) { throw 'BOM fixture creation failed' }
$source = Get-Content (Join-Path $repo 'SmartZip.ahk') -Raw -Encoding UTF8
function Slice($start, $end) {
    $a = $source.IndexOf("`n    $start(")
    $b = $source.IndexOf("`n    $end(", $a + 1)
    if ($a -lt 0 -or $b -lt 0) { throw 'Missing production method slice' }
    $source.Substring($a, $b - $a)
}
$methods = (Slice 'ProbeArchive' 'BuildPasswordCandidates') + (Slice 'ExtractArchiveToTemp' 'FinalizeExtraction')
$methods += (Slice 'ResolveArchivePassword' 'ShowPasswordDialog')
$a = $source.IndexOf('        zipx(path, preProbe := "")')
$b = $source.IndexOf('        ;解压嵌套', $a)
if ($a -lt 0 -or $b -lt 0) { throw 'Missing zipx pipeline' }
$pipeline = $source.Substring($a, $b - $a)
$methods += "`n    Pipeline(path, output) {`n        loopPath := false`n        isBatch := true`n        tmpDir := output`n        return zipx(path)`n$pipeline`n    }`n"
$capture = (Slice 'RunCmdCapture' 'RunCmd').Replace('RunCmdCapture(CmdLine', 'CaptureReal(CmdLine')
$library = Get-Content (Join-Path $repo 'lib/ArchiveDiagnostics.ahk') -Raw
$copyStart = $library.IndexOf("`nMergeSfxvPieces(")
$copyEnd = $library.IndexOf("`nFindSfx7zOffset(", $copyStart)
$shortCopy = $library.Substring($copyStart, $copyEnd - $copyStart).Replace('MergeSfxvPieces(', 'MergeWithShortWriter(').Replace('target := FileOpen(destination, "w")', 'target := ShortWriter(FileOpen(destination, "w"))')
$program = @'
#Requires AutoHotkey v2.0
#Include __LIB__
class ShortWriter {
    __New(file) {
        this.file := file
    }
    RawWrite(data, count) => this.file.RawWrite(data, count - 1)
    Close() => this.file.Close()
}
__SHORTCOPY__
class Host {
    7z := '"C:\Tool\7-Zip-Zstandard\7z.exe"'
    cmdLog := false
    guiShow := false
    hideRunSize := 999
    excludeArgs := ""
    codePage := ""
    timingLog := true
    commands := []
    logLevel := 0
    test := true
    delSource := false
    delWhenHasPass := false
    muilt := true
    cancelExtract := false
    throwCapture := false
    forceExtractExitCode := 0
    BuildPasswordCandidates(path) => ["deliberately-wrong", EnvGet("SMARTZIP_SFXV_PASSWORD")]
    ShowDiagnostic(result, rest*) => result
    FinalizeExtraction(path, result, rest*) => result
    RunCmdCapture(cmd, encoding := "UTF-8") {
        if this.throwCapture
            throw Error("Injected process-launch failure")
        this.commands.Push(cmd)
        return this.CaptureReal(cmd, encoding)
    }
    IsArchive(ext) => ext = "exe"
    Run7z(hide, action, path, args, rest*) {
        this.commands.Push(action ' "' path args)
        if this.cancelExtract {
            this.exitCode := 255
            return
        }
        actualExitCode := RunWait(this.7z ' ' action ' "' path args, , "Hide")
        this.exitCode := (action = 'x' && this.forceExtractExitCode != 0)
            ? this.forceExtractExitCode : actualExitCode
    }
__METHODS__
__CAPTURE__
}
Check(value, label) {
    FileAppend(label "=" (value ? "PASS" : "FAIL") "`n", A_Args[2], "UTF-8")
}
HasTimingLabel(lines, label) {
    for line in lines {
        if RegExMatch(Trim(line), "^" label " duration_ms=\d+$")
            return true
    }
    return false
}
MarkStep(m) {
    FileAppend(A_TickCount " " m "`n", A_Args[1] "\progress.txt", "UTF-8")
}
CountSfxvDirs(dir) {
    count := 0
    Loop files dir "\__smartzip_sfxv_*", "D"
        count++
    return count
}
LockExclusive(path) {
    return DllCall("CreateFileW", "Str", path, "UInt", 0x80000000, "UInt", 0,
        "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
}
VerdictCase(caseName, expect, exitCode, verifyStatus, outputVerified) {
    Check(ExtractionVerdict(exitCode, verifyStatus, outputVerified, true) = expect, caseName)
}
VerdictGuiCase(caseName, expect, exitCode, verifyStatus, outputVerified, usedGui) {
    Check(ExtractionVerdict(exitCode, verifyStatus, outputVerified, usedGui) = expect, caseName)
}
DropLine(text, pattern) {
    ; An empty result means the fixture did not match: the case then fails on its own
    ; instead of quietly verifying an unmutated listing.
    m := ""
    if !RegExMatch(text, pattern, &m)
        return ""
    return StrReplace(text, m[0], "", 1)
}
OracleCase(caseName, text, exitCode, expectVerified, expectReason) {
    lh := OracleHost()
    lh.text := text
    lh.code := exitCode
    r := VerifyExtractedOutput(lh, oracleArc, root "\oracle-good", "")
    Check(r.verified = expectVerified && r.listingExit = exitCode
        && (expectReason = "" || InStr(r.reason, expectReason)), caseName)
}
class OracleHost {
    7z := "C:\Tool\7-Zip-Zstandard\7z.exe"
    text := ""
    code := 0
    RunCmdCapture(cmd, encoding := "UTF-8") => ({ exitCode: this.code, output: this.text })
}
root := A_Args[1]
junctionReady := __JUNCTIONREADY__
h := Host()
for kind in ["plain", "encrypted", "warning"] {
    first := root "\" kind "\game.exe"
    selected := root "\" kind "\game.002.sfxv"
    password := kind = "encrypted" ? EnvGet("SMARTZIP_SFXV_PASSWORD") : ""
    h.commands := []
    MarkStep("scope " kind)
    kindScope := SfxvTaskScope(h, selected)
    sharedPath := h.sfxvTaskInput.commandPath
    MarkStep("probe " kind)
    probe := h.ProbeArchive(selected)
    MarkStep("probed " kind)
    Check(probe.archivePath = first, kind "_probe_identity")
    Check(kind = "encrypted" ? (probe.status = ArchiveStatus.NEED_PASSWORD || probe.status = ArchiveStatus.WRONG_PASSWORD)
        : (probe.status = ArchiveStatus.OK || probe.status = ArchiveStatus.OK_WITH_WARNING), kind "_probe")
    tested := h.TestArchive(selected, password)
    Check(tested.status = (kind = "warning" ? ArchiveStatus.OK_WITH_WARNING : ArchiveStatus.OK), kind "_test")
    Check(tested.archivePath = first, kind "_test_identity")
    if (kind = "warning") {
        h.forceExtractExitCode := 2
        h.hideRunSize := 0
    }
    extracted := h.ExtractArchiveToTemp(selected, password, root "\" kind "\output")
    h.forceExtractExitCode := 0
    h.hideRunSize := 999
    Check(extracted.status = (kind = "warning" ? ArchiveStatus.OK_WITH_WARNING : ArchiveStatus.OK), kind "_extract")
    Check(extracted.archivePath = first, kind "_extract_identity")
    Check(FileExist(root "\" kind "\output\payload.bin"), kind "_payload")
    routed := h.commands.Length = (kind = "warning" ? 5 : 4)
    for cmd in h.commands
        routed := routed && InStr(cmd, "archive.7z") && !InStr(cmd, "game.exe") && !InStr(cmd, ".sfxv")
    Check(routed, kind "_routes_list_test_extract_finaltest")
    reused := true
    for cmd in h.commands
        reused := reused && InStr(cmd, sharedPath)
    Check(reused && FileExist(sharedPath), kind "_reuses_one_merge")
    kindScope.Close()
    Check(!FileExist(sharedPath), kind "_task_cleanup")
    Check(!InStr(extracted.output, "archive.7z.001"), kind "_diagnostic_identity")
}
; Adapter failures must return a result, never fall back to launching input.
bad := root "\missing\game.002.sfxv"
DirCreate(root "\missing")
FileAppend("data", bad)
r := h.ProbeArchive(bad)
Check(r.status = ArchiveStatus.MISSING_VOLUME, "missing_first")
; Standalone calls retain their own cleanup ownership.
scope := SfxvInput(root "\plain\game.exe")
Check(scope.status = "" && FileExist(scope.commandPath) && FileGetSize(scope.commandPath) = 12130, "adapter_merge")
scope.Close()
scope.Close()
Check(scope.closed, "adapter_cleanup_idempotent")
for mode in ["plain", "encrypted", "cancel", "exception"] {
    runner := Host()
    runner.cancelExtract := mode = "cancel"
    runner.throwCapture := mode = "exception"
    kind := mode = "encrypted" ? "encrypted" : "plain"
    caught := false
    try result := runner.Pipeline(root "\" kind "\game.002.sfxv", root "\pipeline-" mode)
    catch
        caught := true
    if mode = "exception"
        Check(caught, "pipeline_exception_propagates")
    else {
        Check(result.status = (mode = "cancel" ? ArchiveStatus.CANCELLED : ArchiveStatus.OK), "pipeline_" mode)
        paths := Map()
        for cmd in runner.commands {
            if RegExMatch(cmd, '"([^"\r\n]*__smartzip_sfxv_[^"\r\n]*archive\.7z)"', &m)
                paths[m[1]] := true
        }
        Check(paths.Count = 1, "pipeline_" mode "_one_merge")
        for path in paths
            Check(!FileExist(path), "pipeline_" mode "_file_cleanup")
        if mode = "encrypted"
            Check(runner.commands.Length >= 6, "pipeline_password_retries_exercised")
    }
    Check(!runner.HasOwnProp("sfxvTaskInput"), "pipeline_" mode "_scope_cleanup")
}
; A read-locked first volume must produce IO_ERROR instead of a script error.
locked := root "\plain\game.exe"
handle := DllCall("CreateFileW", "Str", locked, "UInt", 0x80000000, "UInt", 0,
    "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
try {
    lockedInput := SfxvInput(locked)
    Check(lockedInput.status = ArchiveStatus.IO_ERROR, "locked_input_io_error")
} finally {
    DllCall("CloseHandle", "Ptr", handle)
}
failedPath := root "\failed-merge.7z"
Check(!MergeSfxvPieces([locked, root "\absent.sfxv"], 128, failedPath)
    && !FileExist(failedPath), "partial_merge_cleanup")
class NoSpaceInput extends SfxvInput {
    AvailableBytes(dir) => 0
}
noSpace := NoSpaceInput(locked)
Check(noSpace.status = ArchiveStatus.IO_ERROR && noSpace.directory = "", "no_space_before_creation")
noSpace.Close()
Check(!MergeSfxvPieces([locked], FileGetSize(locked) + 1, failedPath)
    && !FileExist(failedPath), "invalid_offset_rejected")
Check(!MergeWithShortWriter([locked], 128, failedPath)
    && !FileExist(failedPath), "short_write_cleanup")
owner := SfxvTaskScope(h, locked)
outerPath := h.sfxvTaskInput.commandPath
inner := SfxvTaskScope(h, locked)
inner.Close()
Check(FileExist(outerPath), "same_path_nested_borrow_keeps_owner")
other := SfxvTaskScope(h, root "\encrypted\game.exe")
otherPath := h.sfxvTaskInput.commandPath
other.Close()
Check(!FileExist(otherPath) && h.sfxvTaskInput.commandPath = outerPath
    && FileExist(outerPath), "different_path_restores_owner")
owner.Close()
owner.Close()
Check(!FileExist(outerPath) && !h.HasOwnProp("sfxvTaskInput"), "owner_cleanup_idempotent")
Check(!IsSfxvNameCandidate("archive.rar") && !IsSfxvNameCandidate("archive.7z.001")
    && !IsSfxvNameCandidate("archive.zip"), "ordinary_formats_skip_sfxv_scan")
; A preparation that failed is terminal for the task: borrowing it again must not
; re-scan, re-merge or hand a temporary path to 7-Zip, even after the cause clears.
reuseHost := Host()
reuseDir := root "\warning"
reuseTarget := reuseDir "\game.exe"
reuseBefore := CountSfxvDirs(reuseDir)
reuseLock := LockExclusive(reuseTarget)
reuseScope := SfxvTaskScope(reuseHost, reuseTarget)
reuseFirst := AcquireSfxvInput(reuseHost, reuseTarget)
DllCall("CloseHandle", "Ptr", reuseLock)
reuseSecond := AcquireSfxvInput(reuseHost, reuseTarget)
Check(reuseFirst.status = ArchiveStatus.IO_ERROR && reuseSecond.status = ArchiveStatus.IO_ERROR
    && reuseFirst.commandPath = reuseTarget && reuseSecond.commandPath = reuseTarget, "failed_prepare_reused")
Check(CountSfxvDirs(reuseDir) = reuseBefore, "failed_prepare_once")
reuseScope.Close()
nextScope := SfxvTaskScope(reuseHost, reuseTarget)
Check(reuseHost.sfxvTaskInput.status = "" && FileExist(reuseHost.sfxvTaskInput.commandPath)
    && CountSfxvDirs(reuseDir) = reuseBefore + 1, "next_task_retries")
nextScope.Close()
Check(CountSfxvDirs(reuseDir) = reuseBefore, "reused_failure_task_cleanup")
; A set that fails part-way through the merge is terminal for the task as well.
partialHost := Host()
partialPiece := reuseDir "\game.002.sfxv"
partialLock := LockExclusive(partialPiece)
partialScope := SfxvTaskScope(partialHost, partialPiece)
partialFirst := AcquireSfxvInput(partialHost, partialPiece)
DllCall("CloseHandle", "Ptr", partialLock)
partialSecond := AcquireSfxvInput(partialHost, partialPiece)
Check(partialFirst.status = ArchiveStatus.IO_ERROR && partialSecond.status = ArchiveStatus.IO_ERROR
    && CountSfxvDirs(reuseDir) = reuseBefore, "partial_merge_failure_reused")
partialScope.Close()
; An input whose successful temporary file has already been cleaned is not borrowable
; even while its task is still the active owner.
staleHost := Host()
staleInput := SfxvInput(reuseTarget)
staleCommand := staleInput.commandPath
staleInput.Close()
staleInput.taskActive := true
staleHost.sfxvTaskInput := staleInput
staleAcquired := AcquireSfxvInput(staleHost, reuseTarget)
Check(staleAcquired.commandPath != staleCommand && !FileExist(staleCommand)
    && FileExist(staleAcquired.commandPath), "closed_success_not_reused")
staleAcquired.Close()
staleHost.DeleteProp("sfxvTaskInput")
; A different path never borrows the active input.
otherHost := Host()
otherScope := SfxvTaskScope(otherHost, reuseTarget)
otherAcquired := AcquireSfxvInput(otherHost, root "\plain\game.exe")
Check(otherAcquired.status = "" && otherAcquired.commandPath != otherHost.sfxvTaskInput.commandPath,
    "different_path_not_reused")
otherAcquired.Close()
otherScope.Close()
; A temporary merge that another process still holds must be finished off by a
; later Close instead of being reported as cleaned.
lockInput := SfxvInput(reuseTarget)
lockArchive := lockInput.commandPath
lockDir := lockInput.directory
lockHandle := LockExclusive(lockArchive)
lockInput.Close()
Check(lockInput.closed, "locked_cleanup_closed")
Check(!lockInput.cleanupComplete && FileExist(lockArchive), "locked_cleanup_pending")
DllCall("CloseHandle", "Ptr", lockHandle)
lockInput.Close()
Check(lockInput.cleanupComplete && !FileExist(lockArchive) && !DirExist(lockDir), "cleanup_retry_done")
; The directory is removed only while it is empty, so files the task did not
; create are never deleted recursively.
childInput := SfxvInput(reuseTarget)
childDir := childInput.directory
childFile := childDir "\foreign.txt"
FileAppend("keep", childFile)
childInput.Close()
Check(FileExist(childFile) != "" && DirExist(childDir) && !childInput.cleanupComplete,
    "unowned_child_preserved")
FileDelete(childFile)
childInput.Close()
Check(!DirExist(childDir) && childInput.cleanupComplete, "empty_dir_removed_after_child_leaves")
; The task retries a still-locked temporary file a bounded number of times on the
; way out, releases ownership regardless, and keeps the leftover path for diagnosis.
retryHost := Host()
retryScope := SfxvTaskScope(retryHost, reuseTarget)
retryArchive := retryHost.sfxvTaskInput.commandPath
retryHandle := LockExclusive(retryArchive)
retryStarted := A_TickCount
retryScope.Close()
retryElapsed := A_TickCount - retryStarted
DllCall("CloseHandle", "Ptr", retryHandle)
Check(retryElapsed >= 80, "scope_retry_attempted")
Check(retryElapsed < 3000, "scope_retry_bounded")
Check(FileExist(retryArchive) && !retryHost.HasOwnProp("sfxvTaskInput"), "scope_leftover_kept")
retryScope.input.Close()
; The verdict for an ambiguous exit code has to come from what was actually written.
try {
oracleInput := SfxvInput(reuseTarget)
oracleArc := oracleInput.commandPath
DirCopy(root "\plain\output", root "\oracle-good", true)
og := VerifyExtractedOutput(h, oracleArc, root "\oracle-good", "")
Check(og.verified && og.listingExit = 0 && og.checked = 1 && og.files = 1
    && og.mismatched = 0 && og.missing = 0 && og.unexpected = 0, "oracle_accepts_complete_output")
; Simulate the key retained from an earlier case-variant enumeration entry.
; Uses the real enumerator without requiring privileged case-sensitive NTFS setup.
collisionFiles := Map("payload.bin", true)
collisionReport := {aborted: ""}
CollectWrittenFiles(root "\oracle-good", NormalizedFullPath(root "\oracle-good"), collisionFiles, collisionReport)
Check(InStr(collisionReport.aborted, "collision"), "oracle_enumerator_refuses_existing_key")
DirCopy(root "\plain\output", root "\oracle-damaged", true)
dmgPath := root "\oracle-damaged\payload.bin"
dmg := FileOpen(dmgPath, "r")
dmgBytes := Buffer(dmg.Length, 0)
dmg.RawRead(dmgBytes, dmg.Length)
dmg.Close()
NumPut("UChar", NumGet(dmgBytes, 0, "UChar") ^ 0xFF, dmgBytes, 0)
wr := FileOpen(dmgPath, "w")
wr.RawWrite(dmgBytes, dmgBytes.Size)
wr.Close()
ob := VerifyExtractedOutput(h, oracleArc, root "\oracle-damaged", "")
Check(!ob.verified && ob.mismatched = 1, "oracle_rejects_damaged_output")
DirCopy(root "\plain\output", root "\oracle-missing", true)
FileDelete(root "\oracle-missing\payload.bin")
om := VerifyExtractedOutput(h, oracleArc, root "\oracle-missing", "")
Check(!om.verified && om.missing = 1, "oracle_rejects_missing_output")
DirCopy(root "\plain\output", root "\oracle-extra", true)
FileAppend("x", root "\oracle-extra\stray.bin")
ox := VerifyExtractedOutput(h, oracleArc, root "\oracle-extra", "")
Check(!ox.verified && ox.unexpected = 1, "oracle_rejects_unexpected_output")
DirCopy(root "\plain\output", root "\oracle-swapped", true)
FileDelete(root "\oracle-swapped\payload.bin")
FileAppend("y", root "\oracle-swapped\renamed.bin")
os := VerifyExtractedOutput(h, oracleArc, root "\oracle-swapped", "")
Check(!os.verified && os.missing = 1 && os.unexpected = 1, "oracle_rejects_missing_and_extra_pair")
oa := VerifyExtractedOutput(h, oracleArc, root "\oracle-absent", "")
Check(!oa.verified && oa.reason != "", "oracle_rejects_absent_directory")
pl := ParseArchiveListing("Path = C:\dir\archive.7z`nType = 7z`n----------`nPath = a.bin`nSize = 10`nCRC = 1234abcd`n"
    . "Attributes = A`nPath = sub`nSize = 0`nCRC = `nAttributes = D`nPath = b.bin`nSize = 5`nCRC = 0000000F`n"
    . "Attributes = ....A`n")
Check(pl.Length = 3 && pl[1].path = "a.bin" && pl[1].checksum = "1234ABCD" && pl[1].size = 10 && !pl[1].isDir
    && pl[1].hasSize && pl[1].hasAttr && pl[2].isDir && pl[3].checksum = "0000000F" && pl[3].size = 5,
    "oracle_listing_parser")
Check(ValidateArchiveListing("Path = C:\dir\archive.7z`nType = 7z`nPath = a.bin`nSize = 1`nCRC = 0`n"
    . "Attributes = A`n", "C:\dir\archive.7z").reason = "listing has no item separator",
    "oracle_refuses_missing_separator")
; The verdict for an ambiguous exit code has to come from what was actually written.
VerdictCase("verdict_promotes_verified_warning_only", ArchiveStatus.OK_WITH_WARNING,
    2, ArchiveStatus.OK, true)
VerdictCase("verdict_verified_still_not_clean", ArchiveStatus.OK_WITH_WARNING,
    2, ArchiveStatus.OK_WITH_WARNING, true)
VerdictCase("verdict_unverified_never_promoted", ArchiveStatus.UNKNOWN_ERROR,
    2, ArchiveStatus.OK, false)
VerdictCase("verdict_hard_source_error_wins", ArchiveStatus.DATA_CORRUPT,
    2, ArchiveStatus.DATA_CORRUPT, true)
VerdictCase("verdict_cancel_never_promoted", ArchiveStatus.CANCELLED,
    255, ArchiveStatus.OK, true)
VerdictCase("verdict_exit_one_stays_unknown", ArchiveStatus.UNKNOWN_ERROR,
    1, ArchiveStatus.OK_WITH_WARNING, true)
VerdictCase("verdict_zero_keeps_verify_warning", ArchiveStatus.OK_WITH_WARNING,
    0, ArchiveStatus.OK_WITH_WARNING, false)
VerdictCase("verdict_zero_clean", ArchiveStatus.OK,
    0, ArchiveStatus.OK, false)
; Only the measured GUI ambiguity may be promoted; every other code stays a failure even
; when the output happens to verify, because nothing about it was measured as recoverable.
VerdictGuiCase("verdict_console_two_not_promoted", ArchiveStatus.UNKNOWN_ERROR,
    2, ArchiveStatus.OK, true, false)
VerdictGuiCase("verdict_three_not_promoted", ArchiveStatus.UNKNOWN_ERROR,
    3, ArchiveStatus.OK, true, true)
VerdictGuiCase("verdict_four_not_promoted", ArchiveStatus.UNKNOWN_ERROR,
    4, ArchiveStatus.OK, true, true)
VerdictGuiCase("verdict_seven_not_promoted", ArchiveStatus.UNKNOWN_ERROR,
    7, ArchiveStatus.OK, true, true)
VerdictGuiCase("verdict_eight_not_promoted", ArchiveStatus.UNKNOWN_ERROR,
    8, ArchiveStatus.OK, true, true)
VerdictGuiCase("verdict_launch_failure_not_promoted", ArchiveStatus.UNKNOWN_ERROR,
    -1, ArchiveStatus.OK, true, true)
VerdictGuiCase("verdict_unknown_code_not_promoted", ArchiveStatus.UNKNOWN_ERROR,
    99, ArchiveStatus.OK, true, true)
; The listing is another process's output, so both its exit code and its structure are
; proved before a single entry is believed.
baseListing := h.RunCmdCapture(h.7z ' l -slt -bso1 -bse1 -bsp0 -sccUTF-8 -p"" "' oracleArc '"', "UTF-8")
OracleCase("oracle_accepts_validated_real_listing", baseListing.output, 0, true, "")
caseText := baseListing.output . "`nPath = PAYLOAD.BIN`nSize = 12000`nCRC = "
    . Crc32OfFileHex(root "\oracle-good\payload.bin") . "`nAttributes = A`n"
OracleCase("oracle_refuses_case_collision", caseText, 0, false, "listing repeats an entry")
ez := VerifyExtractedOutput(h, root "\empty.7z", root "\empty-out", "")
bm := VerifyExtractedOutput(h, root "\bom.7z", root "\bom-src", "")
Check(bm.verified && bm.checked = 2, "oracle_crc_includes_text_bom_bytes")
Check(ez.verified && ez.checked = 1 && ez.files = 1, "oracle_accepts_real_empty_file")
Check(ExtractionVerdict(2, ArchiveStatus.OK_WITH_WARNING, ez.verified, true)
    = ArchiveStatus.OK_WITH_WARNING, "oracle_empty_gui_warning_promoted")
FileAppend("x", root "\empty-out\empty.bin")
ezBad := VerifyExtractedOutput(h, root "\empty.7z", root "\empty-out", "")
Check(!ezBad.verified, "oracle_empty_rejects_nonempty_output")
FileDelete(root "\empty-out\empty.bin")
ezMissing := VerifyExtractedOutput(h, root "\empty.7z", root "\empty-out", "")
Check(!ezMissing.verified, "oracle_empty_rejects_missing_output")
DirCreate(root "\empty-out\empty.bin")
ezDir := VerifyExtractedOutput(h, root "\empty.7z", root "\empty-out", "")
Check(!ezDir.verified, "oracle_empty_rejects_directory_output")
badSize := StrReplace(baseListing.output, "Size = 12000", "Size = 0.0")
badSize := RegExReplace(badSize, "m)^CRC = [0-9A-F]+", "CRC = ")
Check(!ValidateArchiveListing(badSize, oracleArc).ok, "oracle_refuses_noninteger_zero_size")
OracleCase("oracle_refuses_nonzero_listing_exit", baseListing.output, 2, false,
    "listing process exited 2")
OracleCase("oracle_refuses_unreadable_listing",
    DropLine(baseListing.output, "\r?\nType = [^\r\n]*"), 0, false, "listing header has no archive type")
OracleCase("oracle_refuses_listing_with_hard_error",
    baseListing.output . "ERROR: Something is wrong`n", 0, false, "listing reports an error")
OracleCase("oracle_refuses_header_without_archive_path",
    StrReplace(baseListing.output, "Path = " . oracleArc, "Path = "), 0, false,
    "does not name the queried archive")
OracleCase("oracle_refuses_entry_missing_size",
    DropLine(baseListing.output, "\r?\nSize = \d+"), 0, false, "listing entry without a size")
OracleCase("oracle_refuses_entry_missing_checksum",
    DropLine(baseListing.output, "\r?\nCRC = [0-9A-Fa-f]+"), 0, false, "entry without a checksum")
OracleCase("oracle_refuses_entry_missing_attributes",
    DropLine(baseListing.output, "\r?\nAttributes = [^\r\n]*"), 0, false, "entry without attributes")
OracleCase("oracle_refuses_duplicate_entries",
    StrReplace(baseListing.output, "Path = payload.bin",
        "Path = payload.bin`nSize = 12000`nCRC = 1234ABCD`nAttributes = A`n`nPath = payload.bin", 1),
    0, false, "listing repeats an entry")
OracleCase("oracle_refuses_absolute_item_path",
    StrReplace(baseListing.output, "Path = payload.bin", "Path = C:\Windows\win.ini"), 0, false,
    "not a safe relative path")
OracleCase("oracle_refuses_unc_item_path",
    StrReplace(baseListing.output, "Path = payload.bin", "Path = \\server\share\x.bin"), 0, false,
    "not a safe relative path")
OracleCase("oracle_refuses_device_item_path",
    StrReplace(baseListing.output, "Path = payload.bin", "Path = \.\PhysicalDrive0"), 0, false,
    "not a safe relative path")
OracleCase("oracle_refuses_parent_traversal",
    StrReplace(baseListing.output, "Path = payload.bin", "Path = ..\escaped.bin"), 0, false,
    "not a safe relative path")
OracleCase("oracle_refuses_stream_item_path",
    StrReplace(baseListing.output, "Path = payload.bin", "Path = payload.bin:hidden"), 0, false,
    "not a safe relative path")
OracleCase("oracle_refuses_incomplete_final_entry",
    SubStr(baseListing.output, 1, InStr(baseListing.output, "Path = payload.bin") + 20), 0, false,
    "listing entry without a size")
; A reparse point ends verification without reading through it, whether it stands where a
; listed directory was extracted or sits unlisted beside the files that did verify.
oracleInput.Close()
if junctionReady {
    lj := VerifyExtractedOutput(h, root "\rp\source.7z", root "\rp\out", "")
    Check(!lj.verified && InStr(lj.reason, "reparse"), "oracle_refuses_reparse_entry")
    lj2 := VerifyExtractedOutput(h, root "\rp\source2.7z", root "\rp\out2", "")
    Check(!lj2.verified && InStr(lj2.reason, "reparse"), "oracle_refuses_reparse_directory")
    lr := VerifyExtractedOutput(h, root "\rp\source2.7z", root "\rp\rootLink", "")
    Check(!lr.verified && lr.checked = 0 && InStr(lr.reason, "reparse"), "oracle_refuses_root_junction")
    lp := VerifyExtractedOutput(h, root "\rp\source2.7z", root "\rp\parentLink\src2", "")
    Check(!lp.verified && lp.checked = 0 && InStr(lp.reason, "reparse"), "oracle_refuses_root_ancestor_junction")
    lh := OracleHost()
    lh.text := "Path = test.7z`nType = 7z`n----------`nPath = sub\inner.bin`nSize = 512`nCRC = "
        . Crc32OfFileHex(root "\rp\outside\inner.bin") . "`nAttributes = A`n"
    la := VerifyExtractedOutput(lh, "test.7z", root "\rp\out", "")
    Check(!la.verified && la.checked = 0 && InStr(la.reason, "reparse"), "oracle_ancestor_refused_before_crc")
} else {
    ; No silent skip: an unavailable reparse fixture has to show up as a failure.
    Check(false, "oracle_refuses_reparse_entry")
    Check(false, "oracle_refuses_reparse_directory")
    Check(false, "oracle_refuses_root_junction")
    Check(false, "oracle_refuses_root_ancestor_junction")
    Check(false, "oracle_ancestor_refused_before_crc")
}

timingLines := StrSplit(Trim(FileRead(A_ScriptDir "\SmartZip-timing.log")), "`n")
Check(HasTimingLabel(timingLines, "7z_extract"), "timing_7z_extract")
Check(HasTimingLabel(timingLines, "source_test"), "timing_source_test")
Check(HasTimingLabel(timingLines, "output_verify"), "timing_output_verify")
offDir := A_ScriptDir "\timing-off"
DirCreate(offDir)
offHost := {timingLog: false, scriptDirOverride: offDir}
WriteOperationTiming(offHost, "extract", A_TickCount - 25)
Check(!FileExist(offDir "\SmartZip-timing.log"), "timing_disabled_no_file")

Check(true, "harness_tail_completed")
} catch as tailError {
    ; A runtime error used to surface only as a suite timeout with no information at all.
    FileAppend(tailError.Message "`nline " tailError.Line, A_Args[1] "\harness-error.txt", "UTF-8")
    Check(false, "harness_tail_completed")
}
; Default-off timing does not create a log; enabled timing contains fixed labels only.
Check(FileExist(A_ScriptDir "\SmartZip-timing.log"), "timing_enabled")
ExitApp(0)
'@
$program = $program.Replace('__LIB__',(Join-Path $repo 'lib/ArchiveDiagnostics.ahk')).Replace('__METHODS__',$methods).Replace('__CAPTURE__',$capture).Replace('__SHORTCOPY__',$shortCopy).Replace('__JUNCTIONREADY__',$junctionLiteral)
$scriptPath = Join-Path $root 'integration.ahk'
$resultPath = Join-Path $root 'results.txt'
[IO.File]::WriteAllText($scriptPath,$program,[Text.UTF8Encoding]::new($true))
$exitCode = Invoke-AhkRunner -ScriptPath $scriptPath -ScriptArguments @($root, $resultPath) `
    -TimeoutMs 20000 -TimeoutMessage 'SFXV integration timeout'
$expectedLabels = @(
    'plain_probe_identity','plain_probe','plain_test','plain_test_identity','plain_extract',
    'plain_extract_identity','plain_payload','plain_routes_list_test_extract_finaltest',
    'plain_reuses_one_merge','plain_task_cleanup','plain_diagnostic_identity',
    'encrypted_probe_identity','encrypted_probe','encrypted_test','encrypted_test_identity',
    'encrypted_extract','encrypted_extract_identity','encrypted_payload',
    'encrypted_routes_list_test_extract_finaltest','encrypted_reuses_one_merge',
    'encrypted_task_cleanup','encrypted_diagnostic_identity',
    'warning_probe_identity','warning_probe','warning_test','warning_test_identity',
    'warning_extract','warning_extract_identity','warning_payload',
    'warning_routes_list_test_extract_finaltest','warning_reuses_one_merge',
    'warning_task_cleanup','warning_diagnostic_identity',
    'missing_first','adapter_merge','adapter_cleanup_idempotent',
    'pipeline_plain','pipeline_plain_one_merge','pipeline_plain_file_cleanup','pipeline_plain_scope_cleanup',
    'pipeline_encrypted','pipeline_encrypted_one_merge','pipeline_encrypted_file_cleanup',
    'pipeline_password_retries_exercised','pipeline_encrypted_scope_cleanup',
    'pipeline_cancel','pipeline_cancel_one_merge','pipeline_cancel_file_cleanup','pipeline_cancel_scope_cleanup',
    'pipeline_exception_propagates','pipeline_exception_scope_cleanup',
    'locked_input_io_error','partial_merge_cleanup','no_space_before_creation',
    'invalid_offset_rejected','short_write_cleanup','same_path_nested_borrow_keeps_owner',
    'different_path_restores_owner','owner_cleanup_idempotent','ordinary_formats_skip_sfxv_scan',
    'failed_prepare_reused','failed_prepare_once','next_task_retries','reused_failure_task_cleanup',
    'partial_merge_failure_reused','closed_success_not_reused','different_path_not_reused',
    'locked_cleanup_closed','locked_cleanup_pending','cleanup_retry_done',
    'unowned_child_preserved','empty_dir_removed_after_child_leaves',
    'scope_retry_attempted','scope_retry_bounded','scope_leftover_kept',
    'oracle_accepts_complete_output','oracle_rejects_damaged_output','oracle_rejects_missing_output',
    'oracle_rejects_unexpected_output','oracle_rejects_absent_directory','oracle_listing_parser',
    'oracle_rejects_missing_and_extra_pair',
    'verdict_promotes_verified_warning_only','verdict_verified_still_not_clean',
    'verdict_unverified_never_promoted','verdict_hard_source_error_wins',
    'verdict_cancel_never_promoted','verdict_exit_one_stays_unknown',
    'verdict_zero_keeps_verify_warning','verdict_zero_clean',
    'verdict_console_two_not_promoted','verdict_three_not_promoted','verdict_four_not_promoted',
    'verdict_seven_not_promoted','verdict_eight_not_promoted',
    'verdict_launch_failure_not_promoted','verdict_unknown_code_not_promoted',
    'oracle_accepts_validated_real_listing','oracle_refuses_nonzero_listing_exit',
    'oracle_refuses_unreadable_listing','oracle_refuses_listing_with_hard_error',
    'oracle_refuses_header_without_archive_path','oracle_refuses_entry_missing_size',
    'oracle_refuses_entry_missing_checksum','oracle_refuses_entry_missing_attributes',
    'oracle_refuses_duplicate_entries','oracle_refuses_absolute_item_path',
    'oracle_refuses_unc_item_path','oracle_refuses_device_item_path',
    'oracle_refuses_parent_traversal','oracle_refuses_stream_item_path',
    'oracle_refuses_incomplete_final_entry','oracle_refuses_missing_separator',
    'oracle_refuses_reparse_entry','oracle_refuses_reparse_directory',
    'oracle_refuses_case_collision','oracle_accepts_real_empty_file','oracle_empty_gui_warning_promoted',
    'oracle_enumerator_refuses_existing_key',
    'oracle_crc_includes_text_bom_bytes',
    'oracle_empty_rejects_nonempty_output','oracle_empty_rejects_missing_output',
    'oracle_empty_rejects_directory_output','oracle_refuses_noninteger_zero_size',
    'oracle_refuses_root_junction','oracle_refuses_root_ancestor_junction','oracle_ancestor_refused_before_crc',
    'timing_7z_extract','timing_source_test','timing_output_verify','timing_disabled_no_file',
    'harness_tail_completed',
    'timing_enabled'
)
Describe 'SFXV real 7-Zip production methods' {
    It 'runs source-extracted methods successfully' { $exitCode | Should Be 0 }
    It 'writes the harness result file' { (Test-Path $resultPath) | Should Be $true }
    It 'reports each expected label once and only PASS' {
        Assert-SfxvResults (Get-Content $resultPath -ErrorAction SilentlyContinue) $expectedLabels
    }
    $results = Get-SfxvResultMap (Get-Content $resultPath -ErrorAction SilentlyContinue)
    foreach ($label in $expectedLabels) {
        It $label { $results[$label] | Should Be 'PASS' }
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
        foreach ($line in $lines) { $line | Should Match '^(prepare|probe|probe_list_capture|probe_list_classify|probe_fallback_test|test|extract|7z_extract|source_test|output_verify|postprocess) duration_ms=\d+$' }
    }
    It 'records task preparation duration separately from borrowed operations' {
        $lines = Get-Content (Join-Path $root 'SmartZip-timing.log')
        @($lines | Where-Object { $_ -match '^prepare duration_ms=\d+$' }).Count | Should BeGreaterThan 0
    }
}
} finally {
    if ($null -eq $originalSfxvPassword) {
        Remove-Item Env:SMARTZIP_SFXV_PASSWORD -ErrorAction SilentlyContinue
    } else {
        $env:SMARTZIP_SFXV_PASSWORD = $originalSfxvPassword.Value
    }
}
