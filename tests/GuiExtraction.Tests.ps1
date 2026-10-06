#Requires -Version 5.1
<#
.SYNOPSIS
  Real 7zG.exe / 7z.exe extraction contract behind SmartZip's exit-code decision.
.NOTES
  Launches the same executables with the same argument shape as Run7z, and reads their own
  exit codes: nothing is injected. Dialogs are dismissed by tests\GuiDismissDriver.ahk, which
  only ever posts to windows of the process id this suite passes it. TEMP root only, own PIDs
  only, bounded waits, and the output is checked by hash rather than by any message text.
#>
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $PSScriptRoot 'TestHelper.ps1')

$script:Engine7z = 'C:\Tool\7-Zip-Zstandard\7z.exe'
$script:EngineGui = 'C:\Tool\7-Zip-Zstandard\7zG.exe'
$script:Driver = Join-Path $PSScriptRoot 'GuiDismissDriver.ahk'
$script:AhkExe = Resolve-AhkExe
$script:Root = Join-Path $env:TEMP ('SmartZip-GuiExtraction-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $script:Root | Out-Null
$script:OwnedProcesses = New-Object 'System.Collections.Generic.List[System.Diagnostics.Process]'

function Get-LiveOwnedProcesses {
    param([System.Diagnostics.Process[]]$Processes)
    foreach ($process in $Processes) {
        $process.Refresh()
        if (-not $process.HasExited) { $process }
    }
}

$script:SmallCount = 4
$script:SmallSize = 1048576
# A cancel needs a run that outlives the click. This machine decodes hundreds of megabytes in
# well under the first cancel step, so the fixture is many small files: the per-file work keeps
# the progress dialog open for seconds, which is what a user would actually interrupt.
$script:BigCount = 6000
$script:BigSize = 16384
$script:TailBytes = 1529
$script:CorruptOffset = 2000000

function New-PayloadDir {
    param([string]$Dir, [int]$Count, [int]$Size, [switch]$Compressible)
    New-Item -ItemType Directory $Dir | Out-Null
    $block = New-Object byte[] $Size
    if ($Compressible) {
        $seed = New-Object byte[] 4096
        [Random]::new(20260920).NextBytes($seed)
        for ($o = 0; $o -lt $Size; $o += 4096) {
            [Array]::Copy($seed, 0, $block, $o, [Math]::Min(4096, $Size - $o))
        }
    } else {
        [Random]::new(20260920).NextBytes($block)
    }
    for ($i = 1; $i -le $Count; $i++) {
        [IO.File]::WriteAllBytes((Join-Path $Dir ('f{0:d3}.bin' -f $i)), $block)
    }
    return (Get-FileHash -LiteralPath (Join-Path $Dir 'f001.bin') -Algorithm SHA256).Hash
}

function New-SourceArchive {
    param([string]$PayloadDir, [string]$Archive, [string]$Level = '-mx=0', [switch]$NonSolid)
    Push-Location $PayloadDir
    try {
        $cmd = @('a', '-t7z', $Level)
        if ($NonSolid) { $cmd += '-ms=off' }
        $cmd += @('-bso0', '-bse0', '-bsp0', $Archive, '.\')
        & $script:Engine7z @cmd *> $null
        if ($LASTEXITCODE -ne 0) { throw "fixture archive failed with $LASTEXITCODE" }
    } finally { Pop-Location }
    return $Archive
}

function Copy-VariedArchive {
    param([string]$Source, [string]$Destination, [switch]$AppendTail, [switch]$FlipByte)
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    $fs = [IO.File]::Open($Destination, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite)
    try {
        if ($AppendTail) {
            $tail = New-Object byte[] $script:TailBytes
            [Random]::new(55).NextBytes($tail)
            $fs.Seek(0, [IO.SeekOrigin]::End) | Out-Null
            $fs.Write($tail, 0, $tail.Length)
        }
        if ($FlipByte) {
            if ($fs.Length -le $script:CorruptOffset) { throw 'fixture too small to corrupt' }
            $fs.Position = $script:CorruptOffset
            $b = $fs.ReadByte()
            $fs.Position = $script:CorruptOffset
            $fs.WriteByte(($b -bxor 0xFF))
        }
    } finally { $fs.Dispose() }
    return $Destination
}

function Invoke-Extract {
    param([string]$Exe, [string]$Archive, [string]$OutDir, [string]$Mode, [int]$TimeoutSec)
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $psi.Arguments = 'x "' + $Archive + '" -aou -o"' + $OutDir + '"'
    $psi.UseShellExecute = $false
    # The console build runs hidden in production; the GUI build is visible.
    $psi.CreateNoWindow = ($Exe -eq $script:Engine7z)
    $proc = [Diagnostics.Process]::Start($psi)
    $script:OwnedProcesses.Add($proc)
    $marker = Join-Path $script:Root ('marker-' + $proc.Id + '-' + $Mode + '.txt')
    $dpsi = New-Object Diagnostics.ProcessStartInfo
    $dpsi.FileName = $script:AhkExe
    $dpsi.Arguments = '"' + $script:Driver + '" ' + $proc.Id + ' ' + $Mode + ' "' + $marker + '" ' + (($TimeoutSec - 5) * 1000)
    $dpsi.UseShellExecute = $false
    $dpsi.CreateNoWindow = $true
    $driver = [Diagnostics.Process]::Start($dpsi)
    $script:OwnedProcesses.Add($driver)
    $timedOut = -not $proc.WaitForExit($TimeoutSec * 1000)
    $code = -1
    if (-not $timedOut) {
        try { $code = $proc.ExitCode } catch { $code = -2 }
    } else {
        try { $proc.Kill() } catch {}
        try { $proc.WaitForExit(3000) | Out-Null } catch {}
    }
    try { if (-not $driver.WaitForExit(8000)) { $driver.Kill() } } catch {}
    try { $driverText = $driver.ExitCode } catch { $driverText = -3 }
    $text = ''
    if (Test-Path -LiteralPath $marker) {
        # The driver writes UTF-8 with a BOM, which would defeat an anchored match.
        $text = [IO.File]::ReadAllText($marker).TrimStart([char]0xFEFF).TrimEnd('|')
    }
    return [pscustomobject]@{
        Exit = $code; TimedOut = $timedOut; Marker = $text; Pid = $proc.Id
        DriverExit = $driverText; Args = $psi.Arguments
    }
}

function Assert-Finished {
    param($Run)
    if ($Run.TimedOut) {
        throw ('extraction still running when the timeout expired; driver marker=' + $Run.Marker)
    }
}

function Get-OutputReport {
    param([string]$Dir, [string]$ExpectedHash, [int]$ExpectedCount, [int]$ExpectedSize)
    $files = @()
    if (Test-Path -LiteralPath $Dir) {
        $files = @(Get-ChildItem -LiteralPath $Dir -Recurse -File -ErrorAction SilentlyContinue)
    }
    $matched = 0
    foreach ($f in $files) {
        if ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -eq $ExpectedHash) { $matched++ }
    }
    return [pscustomobject]@{
        Count = $files.Count; Matched = $matched
        Bytes = [int64](($files | Measure-Object -Property Length -Sum).Sum)
        FullBytes = [int64]$ExpectedCount * [int64]$ExpectedSize
    }
}

function New-OutDir {
    param([string]$Name)
    $d = Join-Path $script:Root ('out-' + $Name + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory $d | Out-Null
    return $d
}

# Free space guard: the cancel fixture needs the payload, the archive and a partial output.
$drive = (New-Object IO.DriveInfo([IO.Path]::GetPathRoot($script:Root)))
if ($drive.AvailableFreeSpace -lt 2GB) {
    throw ("not enough free space on " + $drive.Name + " for the real-7zG fixtures: " +
        [math]::Round($drive.AvailableFreeSpace / 1GB, 2) + " GB free")
}

$script:SmallHash = New-PayloadDir -Dir (Join-Path $script:Root 'small') -Count $script:SmallCount -Size $script:SmallSize
$script:BaseArchive = New-SourceArchive -PayloadDir (Join-Path $script:Root 'small') -Archive (Join-Path $script:Root 'base.7z')
$script:TailArchive = Copy-VariedArchive -Source $script:BaseArchive -Destination (Join-Path $script:Root 'tail.7z') -AppendTail
$script:CorruptArchive = Copy-VariedArchive -Source $script:BaseArchive -Destination (Join-Path $script:Root 'corrupt.7z') -FlipByte

$script:BigHash = New-PayloadDir -Dir (Join-Path $script:Root 'big') -Count $script:BigCount `
    -Size $script:BigSize
$script:BigArchive = New-SourceArchive -PayloadDir (Join-Path $script:Root 'big') `
    -Archive (Join-Path $script:Root 'big.7z') -NonSolid
# Only the archive and its expected digest are needed from here on.
Remove-Item -LiteralPath (Join-Path $script:Root 'big') -Recurse -Force
Remove-Item -LiteralPath (Join-Path $script:Root 'small') -Recurse -Force

# A write failure that the extraction cannot talk its way out of: the output path is a file.
$script:BlockedOut = Join-Path $script:Root 'blocked'
[IO.File]::WriteAllBytes($script:BlockedOut, [byte[]](0))

# A separate live engine process must not be reported as this suite's leak.
# It belongs only to this sentinel fixture and waits for input, not user data.
$sentinelStart = New-Object Diagnostics.ProcessStartInfo
$sentinelStart.FileName = $script:Engine7z
$sentinelStart.Arguments = 'h -si'
$sentinelStart.UseShellExecute = $false
$sentinelStart.CreateNoWindow = $true
$sentinelStart.RedirectStandardInput = $true
$sentinelStart.RedirectStandardOutput = $true
$sentinelStart.RedirectStandardError = $true
$script:Sentinel = [Diagnostics.Process]::Start($sentinelStart)

Describe 'Real 7zG extraction contract' {

    It 'clean archive exits 0 on the GUI build with complete output and no dialog' {
        $out = New-OutDir 'clean'
        $r = Invoke-Extract -Exe $script:EngineGui -Archive $script:BaseArchive -OutDir $out `
            -Mode 'dismiss' -TimeoutSec 30
        Assert-Finished $r
        $r.Exit | Should Be 0
        $rep = Get-OutputReport -Dir $out `
            -ExpectedHash $script:SmallHash -ExpectedCount $script:SmallCount -ExpectedSize $script:SmallSize
        $rep.Count | Should Be $script:SmallCount
        $rep.Matched | Should Be $script:SmallCount
    }

    It 'trailing data exits 2 on the GUI build after the warning window is closed, output complete' {
        $out = New-OutDir 'tail'
        $r = Invoke-Extract -Exe $script:EngineGui -Archive $script:TailArchive -OutDir $out `
            -Mode 'dismiss' -TimeoutSec 30
        Assert-Finished $r
        $r.Exit | Should Be 2
        $r.Marker | Should Match '^1\|'
        $rep = Get-OutputReport -Dir $out -ExpectedHash $script:SmallHash `
            -ExpectedCount $script:SmallCount -ExpectedSize $script:SmallSize
        $rep.Matched | Should Be $script:SmallCount
        $rep.Bytes | Should Be $rep.FullBytes
    }

    It 'the same trailing-data archive exits 0 on the console build with identical output' {
        $out = New-OutDir 'console'
        $r = Invoke-Extract -Exe $script:Engine7z -Archive $script:TailArchive -OutDir $out `
            -Mode 'dismiss' -TimeoutSec 30
        Assert-Finished $r
        $r.Exit | Should Be 0
        $rep = Get-OutputReport -Dir $out -ExpectedHash $script:SmallHash `
            -ExpectedCount $script:SmallCount -ExpectedSize $script:SmallSize
        $rep.Matched | Should Be $script:SmallCount
    }

    It 'corrupted content exits 2 and leaves output that does not verify' {
        $out = New-OutDir 'corrupt'
        $r = Invoke-Extract -Exe $script:EngineGui -Archive $script:CorruptArchive -OutDir $out `
            -Mode 'dismiss' -TimeoutSec 30
        Assert-Finished $r
        $r.Exit | Should Be 2
        $rep = Get-OutputReport -Dir $out -ExpectedHash $script:SmallHash `
            -ExpectedCount $script:SmallCount -ExpectedSize $script:SmallSize
        ($rep.Matched -lt $script:SmallCount) | Should Be $true
    }

    It 'unwritable output exits non-zero and leaves no complete output' {
        $r = Invoke-Extract -Exe $script:EngineGui -Archive $script:BaseArchive -OutDir $script:BlockedOut `
            -Mode 'dismiss' -TimeoutSec 30
        Assert-Finished $r
        ($r.Exit -eq 0) | Should Be $false
        [IO.File]::Exists($script:BlockedOut) | Should Be $true
    }

    It 'cancelling a running 7zG extraction exits non-zero with partial output' {
        # The dialog is asked to cancel through its default control (control id 2, IDCANCEL),
        # which 7-Zip 26.02 ZS acts on at a file boundary. Measured here: Escape, WM_CLOSE and
        # the two owner-drawn buttons with empty labels (ids 444 and 446, which only pause the
        # run) do not produce a cancel, so the request that does is repeated until the
        # front-end stops. Exit code and bytes on disk are the front-end's own; if a run wins
        # the race and finishes, that attempt is retried rather than accepted.
        $ok = $false
        $last = ''
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $out = New-OutDir ('cancel' + $attempt)
            $r = Invoke-Extract -Exe $script:EngineGui -Archive $script:BigArchive -OutDir $out `
                -Mode 'cancel' -TimeoutSec 30
            Assert-Finished $r
            $rep = Get-OutputReport -Dir $out -ExpectedHash $script:BigHash `
                -ExpectedCount $script:BigCount -ExpectedSize $script:BigSize
            $last = 'exit=' + $r.Exit + ' bytes=' + $rep.Bytes + '/' + $rep.FullBytes +
                ' matched=' + $rep.Matched + ' marker=' + $r.Marker
            if (($r.Exit -ne 0) -and ($rep.Bytes -gt 0) -and ($rep.Bytes -lt $rep.FullBytes)) {
                $ok = $true
                break
            }
        }
        if (-not $ok) { throw ('no genuine mid-run cancel in three attempts; last=' + $last) }
        ($r.Exit -eq 0) | Should Be $false
        $r.Marker | Should Match 'cancel:'
        ($rep.Bytes -lt $rep.FullBytes) | Should Be $true
        ($rep.Matched -lt $script:BigCount) | Should Be $true
    }

    It 'leaves no 7z, 7zG or driver process behind' {
        $script:Sentinel.HasExited | Should Be $false
        # Prove the same detector sees a live process when explicitly owned.
        @(Get-LiveOwnedProcesses -Processes @($script:Sentinel)).Count | Should Be 1
        $script:OwnedProcesses.Count | Should BeGreaterThan 0
        $stray = @(Get-LiveOwnedProcesses -Processes $script:OwnedProcesses.ToArray())
        $stray.Count | Should Be 0
    }

    AfterAll {
        if (-not $script:Sentinel.HasExited) { $script:Sentinel.Kill(); $script:Sentinel.WaitForExit(3000) | Out-Null }
        $script:Sentinel.Dispose()
        foreach ($owned in $script:OwnedProcesses) {
            try {
                if (-not $owned.HasExited) { $owned.Kill(); $owned.WaitForExit(3000) | Out-Null }
            } finally { $owned.Dispose() }
        }
        if (Test-Path -LiteralPath $script:Root) {
            Remove-Item -LiteralPath $script:Root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
