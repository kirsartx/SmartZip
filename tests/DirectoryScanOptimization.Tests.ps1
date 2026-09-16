$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TestHelper.ps1')
$repo = Split-Path $PSScriptRoot -Parent

Describe 'Directory scan optimization' {
    It 'preserves volume detection against the pre-optimization implementation' {
        $baseline = (git -C $repo show de80a38:lib/ArchiveDiagnostics.ahk) -join "`n"
        $start = $baseline.IndexOf('DetectVolumeGroup(path, siblingNames) {')
        $end = $baseline.IndexOf('_VolEscape(s) {', $start)
        if ($start -lt 0 -or $end -le $start) { throw 'Baseline volume implementation missing' }
        $oldFunction = $baseline.Substring($start, $end - $start).Replace(
            'DetectVolumeGroup(path, siblingNames)', 'BaselineDetectVolumeGroup(path, siblingNames)')
        $temp = Join-Path $env:TEMP ('SmartZip-Scan-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $temp | Out-Null
        $lib = Join-Path $repo 'lib/ArchiveDiagnostics.ahk'
        $program = @'
#Requires AutoHotkey v2.0
#Include __LIB__
__BASELINE__
Fingerprint(r) {
    value := r.isVolume "|" r.firstPath "|" r.selectedIsFirst
    for item in r.members
        value .= "|m:" item
    for item in r.missingVolumes
        value .= "|x:" item
    return value
}
names := ["plain.txt", "image.jpg", "file.zip", "file.7z", "report.2024",
    "pack.part01.rar", "pack.part02.rar", "old.rar", "old.r00", "old.r02",
    "data.001", "data.003", "archive.7z.001", "archive.7z.002",
    "sample.RAR", "sample.R00", "zero.000", "bad.r1", "bad.r000",
    "noextension", "x.custom", "x.01", "x.02", "part.part0.rar"]
sets := [[], names, ["report.0001", "report.2024"], ["old.r00"], ["data.001"]]
checks := 0
for siblings in sets {
    for name in names {
        path := A_Temp "\" name
        old := BaselineDetectVolumeGroup(path, siblings)
        current := DetectVolumeGroup(path, siblings)
        if Fingerprint(old) != Fingerprint(current)
            ExitApp(1)
        if old.isVolume && !IsVolumeNameCandidate(path)
            ExitApp(2)
        checks++
    }
}
if IsVolumeNameCandidate(A_Temp "\archive.rar\plain.txt")
    ExitApp(3)
FileAppend("comparisons=" checks, A_Args[1], "UTF-8")
ExitApp(0)
'@
        $program = $program.Replace('__LIB__', $lib).Replace('__BASELINE__', $oldFunction)
        $scriptPath = Join-Path $temp 'scan.ahk'
        $resultPath = Join-Path $temp 'result.txt'
        [IO.File]::WriteAllText($scriptPath, $program, [Text.UTF8Encoding]::new($true))
        $process = Start-Process -FilePath (Resolve-AhkExe) -ArgumentList @(
            '/ErrorStdOut', ('"' + $scriptPath + '"'), ('"' + $resultPath + '"')) -PassThru -NoNewWindow
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            throw 'Volume comparison timed out'
        }
        $process.ExitCode | Should Be 0
        (Get-Content -Raw $resultPath) | Should Be 'comparisons=120'
    }
}
