$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TestHelper.ps1')
$repo = Split-Path $PSScriptRoot -Parent
Describe 'SFXV split recognition' {
    It 'recognizes any member and detects missing first and interior pieces conservatively' {
        $root = Join-Path $env:TEMP ('SmartZip-Sfxv-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $root | Out-Null
        $program = @'
#Requires AutoHotkey v2.0
#Include __LIB__
Check(value) {
    if !value
        ExitApp(1)
}
names := ["game.exe", "game.001.sfxv", "game.002.sfxv", "game.003.sfxv"]
for name in names {
    g := DetectVolumeGroup(A_Temp "\" name, names)
    Check(g.isVolume && g.firstPath = A_Temp "\game.exe")
    Check(g.members.Length = 4 && !g.missingVolumes.Length)
    Check(g.selectedIsFirst = (name = "game.exe"))
    Check(IsVolumeNameCandidate(name))
}
g := DetectVolumeGroup(A_Temp "\game.003.sfxv", ["game.exe", "game.003.sfxv"])
Check(g.missingVolumes.Length = 2 && g.missingVolumes[1] = "game.001.sfxv")
g := DetectVolumeGroup(A_Temp "\game.001.sfxv", ["game.001.sfxv"])
Check(g.isVolume && g.missingVolumes[1] = "game.exe")
Check(!DetectVolumeGroup(A_Temp "\game.exe", ["game.exe", "other.001.sfxv"]).isVolume)
Check(!DetectVolumeGroup(A_Temp "\game.000.sfxv", ["game.exe"]).isVolume)
Check(!DetectVolumeGroup(A_Temp "\game.01.sfxv", ["game.exe"]).isVolume)
ExitApp(0)
'@
        $program = $program.Replace('__LIB__', (Join-Path $repo 'lib/ArchiveDiagnostics.ahk'))
        $scriptPath = Join-Path $root 'recognition.ahk'
        [IO.File]::WriteAllText($scriptPath, $program, [Text.UTF8Encoding]::new($true))
        $p = Start-Process (Resolve-AhkExe) -ArgumentList @('/ErrorStdOut', ('"' + $scriptPath + '"')) -PassThru -NoNewWindow
        if (-not $p.WaitForExit(30000)) { $p.Kill(); throw 'SFXV recognition timeout' }
        $p.ExitCode | Should Be 0
    }
}
