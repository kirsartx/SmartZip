#Requires -Version 5.1
<#
.SYNOPSIS
  Deterministic real-7-Zip extraction reliability fixtures for Task 8.

.DESCRIPTION
  Creates every archive, probe output, and manifest entry under -Root only.
  Never reads or writes C:\Tool\SmartZip. Password is process-only (env +
  ProcessStartInfo); never written to the manifest or printed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [Parameter(Mandatory = $false)]
    [string]$SevenZip = 'C:\Tool\7-Zip-Zstandard\7z.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-NoDeployedSmartZipAccess {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full -like 'C:\Tool\SmartZip*' -or $full -like 'C:\Tool\SmartZip\*') {
        throw "refusing path under deployed SmartZip: $full"
    }
}

function Get-Normalized7zStatus {
    param(
        [int]$ExitCode,
        [string]$Output
    )
    $text = if ($null -eq $Output) { '' } else { [string]$Output }
    $lines = $text -split "`r?`n"

    $hasCancelled = ($ExitCode -eq 255)
    $hasMissingVolume = $false
    $hasNeedPassword = $false
    $hasWrongPassword = $false
    $hasUnsupported = $false
    $hasTruncated = $false
    $hasHeaderCorrupt = $false
    $hasDataCorrupt = $false
    $hasNotArchive = $false
    $hasIoError = $false
    $hasWarning = $false
    $warningLines = New-Object System.Collections.Generic.List[string]

    foreach ($raw in $lines) {
        $trimmed = $raw.Trim()
        if (-not $trimmed) { continue }

        if ($trimmed -match '(?i)Wrong password\?' -or $trimmed.Contains('Cannot open encrypted archive')) {
            $hasWrongPassword = $true
        }
        if ($trimmed -match '(?i)Cannot find volume|Missing volume|Cannot open volume|Broken volume') {
            $hasMissingVolume = $true
        }
        if ($trimmed.Contains('Enter password (will not be echoed):')) {
            $hasNeedPassword = $true
        }
        if ($trimmed -match '(?i)Unsupported Method|Method is not supported') {
            $hasUnsupported = $true
        }
        if ($trimmed.Contains('Unexpected end of archive') -or $trimmed.Contains('Unexpected end of data')) {
            $hasTruncated = $true
        }
        if ($trimmed.Contains('Headers Error')) {
            $hasHeaderCorrupt = $true
        }
        if ($trimmed.Contains('CRC Failed') -or $trimmed.Contains('Data Error')) {
            $hasDataCorrupt = $true
        }
        if ($trimmed.Contains('Cannot open the file as archive') -or $trimmed.Contains('Can not open the file as archive') `
            -or $trimmed.Contains('Is not archive') -or $trimmed.Contains("Can't open as archive") `
            -or $trimmed -match '(?i)Cannot open the file as \[.+\] archive') {
            $hasNotArchive = $true
        }
        if ($trimmed -match '(?i)Access is denied|not enough space|The system cannot find the path|The network path was not found|Can not open output file|Cannot create output directory') {
            $hasIoError = $true
        }
        if ($trimmed -match '(?i)^Warnings?:\s*[1-9]' -or $trimmed.Contains('There are data after the end of archive') -or $trimmed.Contains('WARNINGS:')) {
            $hasWarning = $true
            [void]$warningLines.Add($trimmed)
        }
        if ($trimmed.Contains('There are data after the end of archive') -and -not $warningLines.Contains($trimmed)) {
            [void]$warningLines.Add($trimmed)
        }
    }

    if ($hasCancelled) { return 'CANCELLED' }
    if ($hasMissingVolume) { return 'MISSING_VOLUME' }
    if ($hasNeedPassword) { return 'NEED_PASSWORD' }
    if ($hasWrongPassword) { return 'WRONG_PASSWORD' }
    if ($hasUnsupported) { return 'UNSUPPORTED_METHOD' }
    if ($hasTruncated) { return 'TRUNCATED' }
    if ($hasHeaderCorrupt) { return 'HEADER_CORRUPT' }
    if ($hasDataCorrupt) { return 'DATA_CORRUPT' }
    if ($hasNotArchive) { return 'NOT_ARCHIVE' }
    if ($ExitCode -eq 0 -and ($hasWarning -or $warningLines.Count -gt 0)) { return 'OK_WITH_WARNING' }
    if ($ExitCode -eq 0) { return 'OK' }
    if ($hasIoError) { return 'IO_ERROR' }
    return 'UNKNOWN_ERROR'
}

function Invoke-7z {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [string]$WorkingDirectory = $null,

        [int]$TimeoutMs = 120000
    )

    if (-not (Test-Path -LiteralPath $SevenZip)) {
        throw "7-Zip executable missing: $SevenZip"
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $SevenZip
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    if ($WorkingDirectory) {
        Assert-NoDeployedSmartZipAccess $WorkingDirectory
        $psi.WorkingDirectory = $WorkingDirectory
    }

    # ArgumentList property (preferred) keeps password out of a single printable string in our code paths.
    if ($psi.PSObject.Properties.Name -contains 'ArgumentList') {
        foreach ($a in $ArgumentList) { [void]$psi.ArgumentList.Add($a) }
    } else {
        # Windows PowerShell 5.1 ProcessStartInfo has no ArgumentList; build escaped args without logging them.
        $escaped = foreach ($a in $ArgumentList) {
            if ($a -match '[\s"]') { '"' + ($a -replace '"', '\"') + '"' } else { $a }
        }
        $psi.Arguments = [string]::Join(' ', $escaped)
    }

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    if (-not $p.WaitForExit($TimeoutMs)) {
        try { $p.Kill() } catch {}
        throw "7-Zip timed out after ${TimeoutMs}ms"
    }
    $combined = ($stdout + "`n" + $stderr).Trim()
    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        Output   = $combined
    }
}

function Get-DirectoryByteSize {
    param([string]$Dir)
    $sum = [int64]0
    Get-ChildItem -LiteralPath $Dir -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $sum += $_.Length
    }
    return $sum
}

function New-SeededPayloads {
    param([string]$PayloadDir)

    Assert-NoDeployedSmartZipAccess $PayloadDir
    if (-not (Test-Path -LiteralPath $PayloadDir)) {
        New-Item -ItemType Directory -Path $PayloadDir -Force | Out-Null
    }

    $rng = New-Object System.Random(20260720)
    $binLarge = New-Object byte[] 98304  # 96 KiB
    $rng.NextBytes($binLarge)
    $binSmall = New-Object byte[] 8192   # 8 KiB
    $rng.NextBytes($binSmall)

    $fileA = Join-Path $PayloadDir 'alpha.bin'
    $fileB = Join-Path $PayloadDir 'beta.bin'
    $fileT = Join-Path $PayloadDir 'note.txt'
    [System.IO.File]::WriteAllBytes($fileA, $binLarge)
    [System.IO.File]::WriteAllBytes($fileB, $binSmall)
    [System.IO.File]::WriteAllText($fileT, "SmartZip Kirs.2 fixture note`nline-2 fixed UTF-8`n", [System.Text.UTF8Encoding]::new($false))

    return [pscustomobject]@{
        Files      = @($fileA, $fileB, $fileT)
        SourceBytes = [int64]($binLarge.Length + $binSmall.Length + [System.Text.Encoding]::UTF8.GetByteCount("SmartZip Kirs.2 fixture note`nline-2 fixed UTF-8`n"))
        LargePath  = $fileA
        SmallPath  = $fileB
        TextPath   = $fileT
    }
}

function New-ArchiveFromFiles {
    param(
        [string]$ArchivePath,
        [string[]]$Files,
        [string[]]$ExtraArgs = @()
    )
    Assert-NoDeployedSmartZipAccess $ArchivePath
    $parent = Split-Path -Parent $ArchivePath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path -LiteralPath $ArchivePath) {
        Remove-Item -LiteralPath $ArchivePath -Force
    }
    $args = @('a', '-t7z', '-y') + $ExtraArgs + @($ArchivePath) + $Files
    $r = Invoke-7z -ArgumentList $args
    if ($r.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $ArchivePath)) {
        throw "failed to create archive $ArchivePath exit=$($r.ExitCode)"
    }
    return $r
}

function Test-ArchiveStatus {
    param(
        [string]$ArchivePath,
        [string]$Password = ''
    )
    $args = @('t', '-bso1', '-bse1', '-bsp0', '-sccUTF-8')
    if ($Password -ne '') {
        $args += "-p$Password"
    } else {
        $args += '-p'
    }
    $args += $ArchivePath
    $r = Invoke-7z -ArgumentList $args
    $status = Get-Normalized7zStatus -ExitCode $r.ExitCode -Output $r.Output
    return [pscustomobject]@{
        ExitCode = $r.ExitCode
        Output   = $r.Output
        Status   = $status
    }
}

function Find-CorruptionOffset {
    param(
        [string]$SourceArchive,
        [string]$WorkDir,
        [string]$TargetStatus,
        [int]$MaxCandidates = 64
    )
    Assert-NoDeployedSmartZipAccess $WorkDir
    $bytes = [System.IO.File]::ReadAllBytes($SourceArchive)
    $len = $bytes.Length
    if ($len -lt 32) { throw "archive too small to corrupt: $SourceArchive" }

    # Prefer end-header region (7z next-header lives near EOF) then mid-body samples.
    $candidates = New-Object System.Collections.Generic.List[int]
    for ($i = 1; $i -le 24; $i++) {
        $off = $len - 8 - ($i * 3)
        if ($off -gt 32 -and $off -lt $len) { [void]$candidates.Add($off) }
    }
    for ($i = 0; $i -lt 40; $i++) {
        $off = 32 + [int](($len - 64) * ($i / 40.0))
        if ($off -gt 32 -and $off -lt ($len - 8)) { [void]$candidates.Add($off) }
    }
    $unique = $candidates | Select-Object -Unique | Select-Object -First $MaxCandidates

    $idx = 0
    foreach ($off in $unique) {
        $idx++
        $probe = Join-Path $WorkDir ("probe_{0}_{1}.7z" -f $TargetStatus, $idx)
        $copy = [byte[]]::new($bytes.Length)
        [Array]::Copy($bytes, $copy, $bytes.Length)
        $copy[$off] = $copy[$off] -bxor 0xFF
        [System.IO.File]::WriteAllBytes($probe, $copy)
        $tr = Test-ArchiveStatus -ArchivePath $probe
        if ($tr.Status -eq $TargetStatus) {
            return [pscustomobject]@{
                Offset     = $off
                ProbePath  = $probe
                ExitCode   = $tr.ExitCode
                Output     = $tr.Output
                Status     = $tr.Status
            }
        }
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    }
    throw "could not find offset producing status $TargetStatus for $SourceArchive"
}

function Find-CrcPartialFixture {
    param(
        [string]$SourceArchive,
        [string]$WorkDir,
        [int64]$SourceBytes,
        [int]$MaxCandidates = 80
    )
    Assert-NoDeployedSmartZipAccess $WorkDir
    $bytes = [System.IO.File]::ReadAllBytes($SourceArchive)
    $len = $bytes.Length

    # Late-stream offsets: solid/copy packed data near EOF often yields partial write
    # with DATA_CORRUPT and exit 2 while still extracting >90% of source bytes.
    $candidates = New-Object System.Collections.Generic.List[int]
    $start = [Math]::Max(64, [int]($len * 0.55))
    $end = [Math]::Max($start + 1, $len - 12)
    for ($i = 0; $i -lt $MaxCandidates; $i++) {
        $off = $start + [int](($end - $start) * ($i / [double][Math]::Max(1, $MaxCandidates - 1)))
        if ($off -gt 32 -and $off -lt ($len - 8)) { [void]$candidates.Add($off) }
    }
    # denser sampling in the final 15%
    $tailStart = [Math]::Max(64, [int]($len * 0.85))
    for ($off = $tailStart; $off -lt ($len - 8); $off += 3) {
        [void]$candidates.Add($off)
    }

    $idx = 0
    foreach ($off in ($candidates | Select-Object -Unique)) {
        $idx++
        $probe = Join-Path $WorkDir ("crc_probe_{0}.7z" -f $idx)
        $extractDir = Join-Path $WorkDir ("crc_out_{0}" -f $idx)
        $copy = [byte[]]::new($bytes.Length)
        [Array]::Copy($bytes, $copy, $bytes.Length)
        $copy[$off] = $copy[$off] -bxor 0x5A
        [System.IO.File]::WriteAllBytes($probe, $copy)

        if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

        $xr = Invoke-7z -ArgumentList @('x', '-y', "-o$extractDir", $probe)
        $extracted = Get-DirectoryByteSize -Dir $extractDir
        $ratio = if ($SourceBytes -gt 0) { $extracted / [double]$SourceBytes } else { 0 }
        $status = Get-Normalized7zStatus -ExitCode $xr.ExitCode -Output $xr.Output

        if ($xr.ExitCode -eq 2 -and $status -eq 'DATA_CORRUPT' -and $ratio -gt 0.90 -and $ratio -lt 1.0) {
            return [pscustomobject]@{
                Offset         = $off
                Path           = $probe
                ExtractedBytes = $extracted
                SourceBytes    = $SourceBytes
                Ratio          = $ratio
                ExitCode       = $xr.ExitCode
                Status         = 'DATA_CORRUPT'
            }
        }
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw "could not produce crcPartial fixture with 0.90 < ratio < 1.0 and exit 2"
}

# --- main ---
Assert-NoDeployedSmartZipAccess $Root
if ($Root -like 'C:\Tool\SmartZip*' ) { throw 'Root must not be under C:\Tool\SmartZip' }
if (-not (Test-Path -LiteralPath $SevenZip)) {
    throw "7-Zip executable missing: $SevenZip"
}
$fixturePassword = [Environment]::GetEnvironmentVariable('SMARTZIP_FIXTURE_PASSWORD', 'Process')
if ([string]::IsNullOrEmpty($fixturePassword)) {
    throw 'process environment variable SMARTZIP_FIXTURE_PASSWORD must be non-empty'
}

if (-not (Test-Path -LiteralPath $Root)) {
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
}

$fxDir = Join-Path $Root 'fixtures'
$workDir = Join-Path $Root 'fixture-work'
$payloadDir = Join-Path $workDir 'payload'
New-Item -ItemType Directory -Path $fxDir -Force | Out-Null
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$payloads = New-SeededPayloads -PayloadDir $payloadDir
$twoFiles = @($payloads.LargePath, $payloads.SmallPath)
$sourceBytesTwo = [int64]((Get-Item -LiteralPath $payloads.LargePath).Length + (Get-Item -LiteralPath $payloads.SmallPath).Length)

$manifest = [ordered]@{
    version              = 1
    sevenZip             = $SevenZip
    # Portable SHA-256 (avoid Get-FileHash module auto-load issues under some hosts)
    passwordSha256       = ([System.BitConverter]::ToString(
                                [System.Security.Cryptography.SHA256]::Create().ComputeHash(
                                    [System.Text.Encoding]::UTF8.GetBytes($fixturePassword)
                                )
                            ).Replace('-', ''))
    fixtures             = [ordered]@{}
    crcPartialRatio      = $null
    crcPartialSourceBytes = $null
    crcPartialExtractedBytes = $null
}

# valid
$validPath = Join-Path $fxDir 'valid.7z'
New-ArchiveFromFiles -ArchivePath $validPath -Files $twoFiles | Out-Null
$tr = Test-ArchiveStatus -ArchivePath $validPath
if ($tr.Status -ne 'OK') { throw "valid fixture status=$($tr.Status)" }
$manifest.fixtures['valid'] = [ordered]@{
    key            = 'valid'
    path           = $validPath
    members        = @([System.IO.Path]::GetFileName($validPath))
    expectedStatus = 'OK'
    selectedMember = [System.IO.Path]::GetFileName($validPath)
}

# encryptedHeader (header encryption)
$encPath = Join-Path $fxDir 'encryptedHeader.7z'
New-ArchiveFromFiles -ArchivePath $encPath -Files $twoFiles -ExtraArgs @('-mhe=on', "-p$fixturePassword") | Out-Null
$trNeed = Test-ArchiveStatus -ArchivePath $encPath -Password ''
if ($trNeed.Status -ne 'NEED_PASSWORD') {
    # some 7z builds report WRONG_PASSWORD for empty -p on encrypted headers; require password prompt path
    if ($trNeed.Status -ne 'WRONG_PASSWORD' -and $trNeed.Status -ne 'NEED_PASSWORD') {
        throw "encryptedHeader empty-password status=$($trNeed.Status)"
    }
}
$trOk = Test-ArchiveStatus -ArchivePath $encPath -Password $fixturePassword
if ($trOk.Status -ne 'OK') { throw "encryptedHeader correct password status=$($trOk.Status)" }
$manifest.fixtures['encryptedHeader'] = [ordered]@{
    key            = 'encryptedHeader'
    path           = $encPath
    members        = @([System.IO.Path]::GetFileName($encPath))
    expectedStatus = 'OK'   # with correctSaved password mode
    probeStatus    = 'NEED_PASSWORD'
    selectedMember = [System.IO.Path]::GetFileName($encPath)
}
$manifest.fixtures['wrongPassword'] = [ordered]@{
    key            = 'wrongPassword'
    path           = $encPath
    members        = @([System.IO.Path]::GetFileName($encPath))
    expectedStatus = 'WRONG_PASSWORD'
    selectedMember = [System.IO.Path]::GetFileName($encPath)
    sharedWith     = 'encryptedHeader'
}
$manifest.fixtures['passwordCancel'] = [ordered]@{
    key            = 'passwordCancel'
    path           = $encPath
    members        = @([System.IO.Path]::GetFileName($encPath))
    expectedStatus = 'CANCELLED'
    selectedMember = [System.IO.Path]::GetFileName($encPath)
    sharedWith     = 'encryptedHeader'
}

# copy-mode (-mx0) base for header/truncation corruption
$copyBase = Join-Path $workDir 'copybase.7z'
New-ArchiveFromFiles -ArchivePath $copyBase -Files $twoFiles -ExtraArgs @('-mx0', '-ms=off') | Out-Null

# damagedHeader: mutate a copy; accept only HEADER_CORRUPT classification
$headerHit = Find-CorruptionOffset -SourceArchive $copyBase -WorkDir $workDir -TargetStatus 'HEADER_CORRUPT'
$damagedPath = Join-Path $fxDir 'damagedHeader.7z'
Copy-Item -LiteralPath $headerHit.ProbePath -Destination $damagedPath -Force
$manifest.fixtures['damagedHeader'] = [ordered]@{
    key            = 'damagedHeader'
    path           = $damagedPath
    members        = @([System.IO.Path]::GetFileName($damagedPath))
    expectedStatus = 'HEADER_CORRUPT'
    selectedMember = [System.IO.Path]::GetFileName($damagedPath)
    offset         = $headerHit.Offset
}

# truncated
$truncPath = Join-Path $fxDir 'truncated.7z'
$fullBytes = [System.IO.File]::ReadAllBytes($copyBase)
if ($fullBytes.Length -le 128) { throw 'copybase too small to truncate' }
$truncBytes = New-Object byte[] ($fullBytes.Length - 128)
[Array]::Copy($fullBytes, $truncBytes, $truncBytes.Length)
[System.IO.File]::WriteAllBytes($truncPath, $truncBytes)
$trTrunc = Test-ArchiveStatus -ArchivePath $truncPath
if ($trTrunc.Status -ne 'TRUNCATED') {
    throw "truncated fixture status=$($trTrunc.Status) expected TRUNCATED"
}
$manifest.fixtures['truncated'] = [ordered]@{
    key            = 'truncated'
    path           = $truncPath
    members        = @([System.IO.Path]::GetFileName($truncPath))
    expectedStatus = 'TRUNCATED'
    selectedMember = [System.IO.Path]::GetFileName($truncPath)
}

# crcPartial: two-file archive (highly compressible solid stream) so a late data-byte
# flip yields 0.90 < extracted/source < 1.0 with exit 2 / DATA_CORRUPT. Store-mode
# CRC flips still write 100% of declared sizes, which cannot satisfy the strict upper bound.
$crcPayloadDir = Join-Path $workDir 'crc-payload'
New-Item -ItemType Directory -Path $crcPayloadDir -Force | Out-Null
$sb = New-Object System.Text.StringBuilder
$line = 'line fixed pattern ABCDEFGHIJKLMNOP payload for solid crc probe XXX'
for ($i = 0; $i -lt 8000; $i++) {
    [void]$sb.AppendLine(("line {0} {1}" -f $i, $line))
}
$crcLarge = Join-Path $crcPayloadDir 'alpha.txt'
$crcSmall = Join-Path $crcPayloadDir 'beta.txt'
[System.IO.File]::WriteAllText($crcLarge, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($crcSmall, ('tail-file-' * 50), [System.Text.UTF8Encoding]::new($false))
$crcSourceBytes = [int64]((Get-Item -LiteralPath $crcLarge).Length + (Get-Item -LiteralPath $crcSmall).Length)
$crcBase = Join-Path $workDir 'crcbase.7z'
New-ArchiveFromFiles -ArchivePath $crcBase -Files @($crcLarge, $crcSmall) -ExtraArgs @('-mx5', '-ms=on') | Out-Null
$crcHit = Find-CrcPartialFixture -SourceArchive $crcBase -WorkDir $workDir -SourceBytes $crcSourceBytes
$crcPath = Join-Path $fxDir 'crcPartial.7z'
Copy-Item -LiteralPath $crcHit.Path -Destination $crcPath -Force
$manifest.crcPartialRatio = [math]::Round($crcHit.Ratio, 6)
$manifest.crcPartialSourceBytes = $crcHit.SourceBytes
$manifest.crcPartialExtractedBytes = $crcHit.ExtractedBytes
$manifest.fixtures['crcPartial'] = [ordered]@{
    key            = 'crcPartial'
    path           = $crcPath
    members        = @([System.IO.Path]::GetFileName($crcPath))
    expectedStatus = 'DATA_CORRUPT'
    selectedMember = [System.IO.Path]::GetFileName($crcPath)
    offset         = $crcHit.Offset
    ratio          = $crcHit.Ratio
    sourceBytes    = $crcHit.SourceBytes
    extractedBytes = $crcHit.ExtractedBytes
}

# splitComplete / splitMissing / splitNonFirst
$splitDir = Join-Path $fxDir 'split'
New-Item -ItemType Directory -Path $splitDir -Force | Out-Null
# Build a payload large enough for multiple 64k volumes
$splitPayload = Join-Path $workDir 'split-payload'
New-Item -ItemType Directory -Path $splitPayload -Force | Out-Null
$rng2 = New-Object System.Random(20260720)
$big = New-Object byte[] 200000
$rng2.NextBytes($big)
$bigPath = Join-Path $splitPayload 'bulk.bin'
[System.IO.File]::WriteAllBytes($bigPath, $big)
$splitBase = Join-Path $splitDir 'volume.7z'
if (Test-Path -LiteralPath $splitBase) { Remove-Item -LiteralPath $splitBase -Force }
Get-ChildItem -LiteralPath $splitDir -Filter 'volume.7z*' -File -ErrorAction SilentlyContinue | Remove-Item -Force
$sr = Invoke-7z -ArgumentList @('a', '-t7z', '-v64k', '-mx0', '-y', $splitBase, $bigPath)
if ($sr.ExitCode -ne 0) { throw "split archive create failed exit=$($sr.ExitCode)" }
$splitMembers = @(Get-ChildItem -LiteralPath $splitDir -Filter 'volume.7z*' -File | Sort-Object Name | ForEach-Object { $_.FullName })
if ($splitMembers.Count -lt 3) { throw "expected >=3 split volumes, got $($splitMembers.Count)" }
$firstVol = $splitMembers | Where-Object { $_ -match '\.7z\.001$' } | Select-Object -First 1
if (-not $firstVol) { $firstVol = $splitMembers[0] }
$secondVol = $splitMembers | Where-Object { $_ -match '\.7z\.002$' } | Select-Object -First 1
if (-not $secondVol) { $secondVol = $splitMembers[1] }
$trSplit = Test-ArchiveStatus -ArchivePath $firstVol
if ($trSplit.Status -ne 'OK') { throw "splitComplete status=$($trSplit.Status)" }

$manifest.fixtures['splitComplete'] = [ordered]@{
    key            = 'splitComplete'
    path           = $firstVol
    members        = @($splitMembers | ForEach-Object { [System.IO.Path]::GetFileName($_) })
    memberPaths    = @($splitMembers)
    expectedStatus = 'OK'
    selectedMember = [System.IO.Path]::GetFileName($firstVol)
}

# splitMissing: copy set then delete a middle volume
$missDir = Join-Path $fxDir 'split-missing'
New-Item -ItemType Directory -Path $missDir -Force | Out-Null
$missMembers = @()
foreach ($m in $splitMembers) {
    $dest = Join-Path $missDir ([System.IO.Path]::GetFileName($m))
    Copy-Item -LiteralPath $m -Destination $dest -Force
    $missMembers += $dest
}
$middle = $missMembers | Where-Object { $_ -match '\.7z\.002$' } | Select-Object -First 1
if (-not $middle) { $middle = $missMembers[1] }
Remove-Item -LiteralPath $middle -Force
$missFirst = $missMembers | Where-Object { $_ -match '\.7z\.001$' } | Select-Object -First 1
$remaining = @(Get-ChildItem -LiteralPath $missDir -File | ForEach-Object { $_.FullName })
$manifest.fixtures['splitMissing'] = [ordered]@{
    key            = 'splitMissing'
    path           = $missFirst
    members        = @($remaining | ForEach-Object { [System.IO.Path]::GetFileName($_) })
    memberPaths    = $remaining
    deletedMember  = [System.IO.Path]::GetFileName($middle)
    expectedStatus = 'MISSING_VOLUME'
    selectedMember = [System.IO.Path]::GetFileName($missFirst)
}

# splitNonFirst: point at .002 with full set present
$nonFirstDir = Join-Path $fxDir 'split-nonfirst'
New-Item -ItemType Directory -Path $nonFirstDir -Force | Out-Null
$nfMembers = @()
foreach ($m in $splitMembers) {
    $dest = Join-Path $nonFirstDir ([System.IO.Path]::GetFileName($m))
    Copy-Item -LiteralPath $m -Destination $dest -Force
    $nfMembers += $dest
}
$nfSecond = $nfMembers | Where-Object { $_ -match '\.7z\.002$' } | Select-Object -First 1
$nfFirst = $nfMembers | Where-Object { $_ -match '\.7z\.001$' } | Select-Object -First 1
$manifest.fixtures['splitNonFirst'] = [ordered]@{
    key            = 'splitNonFirst'
    path           = $nfSecond
    firstPath      = $nfFirst
    members        = @($nfMembers | ForEach-Object { [System.IO.Path]::GetFileName($_) })
    memberPaths    = $nfMembers
    expectedStatus = 'OK'
    selectedMember = [System.IO.Path]::GetFileName($nfSecond)
}

# trailingWarning
$warnPath = Join-Path $fxDir 'trailingWarning.7z'
$vbytes = [System.IO.File]::ReadAllBytes($validPath)
$extra = [System.Text.Encoding]::ASCII.GetBytes('TRAILING_WARN_16')  # 16 bytes
$combined = New-Object byte[] ($vbytes.Length + $extra.Length)
[Array]::Copy($vbytes, 0, $combined, 0, $vbytes.Length)
[Array]::Copy($extra, 0, $combined, $vbytes.Length, $extra.Length)
[System.IO.File]::WriteAllBytes($warnPath, $combined)
$trWarn = Test-ArchiveStatus -ArchivePath $warnPath
if ($trWarn.Status -ne 'OK_WITH_WARNING') {
    throw "trailingWarning status=$($trWarn.Status) expected OK_WITH_WARNING"
}
$manifest.fixtures['trailingWarning'] = [ordered]@{
    key            = 'trailingWarning'
    path           = $warnPath
    members        = @([System.IO.Path]::GetFileName($warnPath))
    expectedStatus = 'OK_WITH_WARNING'
    selectedMember = [System.IO.Path]::GetFileName($warnPath)
}

# fake7z
$fakePath = Join-Path $fxDir 'fake7z.7z'
[System.IO.File]::WriteAllText($fakePath, "this is not a 7z archive`n", [System.Text.UTF8Encoding]::new($false))
$trFake = Test-ArchiveStatus -ArchivePath $fakePath
if ($trFake.Status -ne 'NOT_ARCHIVE') { throw "fake7z status=$($trFake.Status)" }
$manifest.fixtures['fake7z'] = [ordered]@{
    key            = 'fake7z'
    path           = $fakePath
    members        = @([System.IO.Path]::GetFileName($fakePath))
    expectedStatus = 'NOT_ARCHIVE'
    selectedMember = [System.IO.Path]::GetFileName($fakePath)
}

# plainNoExtension
$plainPath = Join-Path $fxDir 'plainNoExtension'
[System.IO.File]::WriteAllText($plainPath, "ordinary utf-8 file without extension`n", [System.Text.UTF8Encoding]::new($false))
$trPlain = Test-ArchiveStatus -ArchivePath $plainPath
if ($trPlain.Status -ne 'NOT_ARCHIVE') { throw "plainNoExtension status=$($trPlain.Status)" }
$manifest.fixtures['plainNoExtension'] = [ordered]@{
    key            = 'plainNoExtension'
    path           = $plainPath
    members        = @([System.IO.Path]::GetFileName($plainPath))
    expectedStatus = 'NOT_ARCHIVE'
    selectedMember = [System.IO.Path]::GetFileName($plainPath)
}

# extensionlessArchive
$extlessPath = Join-Path $fxDir 'extensionlessArchive'
Copy-Item -LiteralPath $validPath -Destination $extlessPath -Force
$trExt = Test-ArchiveStatus -ArchivePath $extlessPath
if ($trExt.Status -ne 'OK') { throw "extensionlessArchive status=$($trExt.Status)" }
$manifest.fixtures['extensionlessArchive'] = [ordered]@{
    key            = 'extensionlessArchive'
    path           = $extlessPath
    members        = @([System.IO.Path]::GetFileName($extlessPath))
    expectedStatus = 'OK'
    selectedMember = [System.IO.Path]::GetFileName($extlessPath)
}

$manifestPath = Join-Path $Root 'fixture-manifest.json'
$json = $manifest | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($manifestPath, $json, [System.Text.UTF8Encoding]::new($false))

# Return object for callers (do not echo password)
return [pscustomobject]@{
    ManifestPath = $manifestPath
    Manifest     = $manifest
    FixtureRoot  = $fxDir
}
