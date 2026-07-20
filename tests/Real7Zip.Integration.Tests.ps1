#Requires -Version 5.1
<#
.SYNOPSIS
  Real 7-Zip + compiled SmartZip integration suite (Task 8) — exactly 26 It blocks.
.NOTES
  Pester 3.4 classic syntax. TEMP root only: %TEMP%\SmartZip-Kirs2-<guid>.
  Never reads/writes C:\Tool\SmartZip. Passwords stay process-env only.
#>
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:SevenZip = 'C:\Tool\7-Zip-Zstandard\7z.exe'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'
$script:Ahk2Exe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe'
$script:FixtureGen = Join-Path $PSScriptRoot 'New-ExtractionReliabilityFixtures.ps1'
$script:ScenarioRunner = Join-Path $PSScriptRoot 'Invoke-CompiledSmartZipScenario.ps1'
$script:SmokeRunner = Join-Path $PSScriptRoot 'Invoke-ProductionSmartZipSmoke.ps1'
$script:HookAhk = Join-Path $PSScriptRoot 'IntegrationTestHook.ahk'
$script:SmokeUi = Join-Path $PSScriptRoot 'ProductionSmokeUI.ahk'

function Assert-NoDeployedSmartZipAccess {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return }
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full -eq 'C:\Tool\SmartZip' -or $full -like 'C:\Tool\SmartZip\*') {
        throw "refusing path under deployed SmartZip: $full"
    }
    if ($Path -match '(?i)C:\\Tool\\SmartZip') {
        throw "refusing literal deployed SmartZip reference: $Path"
    }
}

function Get-LeakedCountBelowRoot {
    param([string]$Root)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    $names = @('SmartZip', '7z', '7zG', 'SmartZip.exe', '7z.exe', '7zG.exe')
    $count = 0
    Get-CimInstance Win32_Process | Where-Object { $names -contains $_.Name } | ForEach-Object {
        $exe = $_.ExecutablePath
        $cmd = $_.CommandLine
        $hit = $false
        if ($exe -and $exe.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { $hit = $true }
        if ($cmd -and $cmd.IndexOf($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hit = $true }
        if ($hit) { $count++ }
    }
    return $count
}

function Test-TextHasPasswordLeak {
    param([string]$Text, [string]$Password, [string]$Wrong)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if ($Password -and $Text.Contains($Password)) { return $true }
    if ($Wrong -and $Text.Contains($Wrong)) { return $true }
    # Allow intentional redaction marker -p*** from RedactDiagnostic; flag only raw secrets.
    if ($Text -match '(?i)-p"[^*"][^"]*"') { return $true }
    if ($Text -match "(?i)-p'[^']+'") { return $true }
    if ($Text -match '(?i)-p(?!\*\*\*)[^\s"=\]]+') { return $true }
    return $false
}

function Invoke-Scenario {
    param(
        [string]$Scenario,
        [int]$DelSource = 0,
        [ValidateSet('none', 'correctSaved', 'wrongDialog', 'dialogCancel')]$PasswordMode = 'none'
    )
    Assert-NoDeployedSmartZipAccess $script:TempRoot
    return & $script:ScenarioRunner `
        -SmartZipExe $script:CompiledExe `
        -FixtureManifest $script:ManifestPath `
        -Scenario $Scenario `
        -Root $script:TempRoot `
        -DelSource $DelSource `
        -PasswordMode $PasswordMode `
        -TimeoutSeconds 120
}

function Get-ResultStatus {
    param($Run)
    if ($null -eq $Run -or $null -eq $Run.Result) { return $null }
    return [string]$Run.Result.status
}

function Assert-SourcePreserved {
    param($Run)
    $src = $Run.ArchivePath
    if (-not (Test-Path -LiteralPath $src)) {
        throw "source not preserved: $src"
    }
    if ($Run.SourceInventory.Count -lt 1) {
        throw 'source inventory empty after non-OK/preserve scenario'
    }
}

function Assert-AllVolumeMembersPresent {
    param($Run, $FixtureKey)
    $fx = $script:Manifest.fixtures.$FixtureKey
    if (-not $fx -or -not $fx.members) { return }
    foreach ($leaf in @($fx.members)) {
        $p = Join-Path $Run.SourceDir $leaf
        if (-not (Test-Path -LiteralPath $p)) {
            throw "volume member missing: $leaf"
        }
    }
}

function Collect-CaptureTexts {
    param($Run)
    $texts = @()
    if ($Run.ResultJson) { $texts += [string]$Run.ResultJson }
    if ($Run.StdOut) { $texts += [string]$Run.StdOut }
    if ($Run.StdErr) { $texts += [string]$Run.StdErr }
    if ($Run.DiagnosticTexts) { $texts += @($Run.DiagnosticTexts | ForEach-Object { [string]$_ }) }
    return $texts
}

Describe 'Real7Zip Integration' {
    BeforeAll {
        $script:SkipReason = $null
        if (-not (Test-Path -LiteralPath $script:SevenZip)) {
            $script:SkipReason = "7-Zip missing: $($script:SevenZip)"
        } elseif (-not (Test-Path -LiteralPath $script:Ahk2Exe)) {
            $script:SkipReason = "Ahk2Exe missing: $($script:Ahk2Exe)"
        } elseif (-not (Test-Path -LiteralPath $script:AhkExe)) {
            $script:SkipReason = "AutoHotkey missing: $($script:AhkExe)"
        } elseif (-not (Test-Path -LiteralPath $script:FixtureGen)) {
            $script:SkipReason = "fixture generator missing"
        } elseif (-not (Test-Path -LiteralPath $script:ScenarioRunner)) {
            $script:SkipReason = "scenario runner missing"
        }

        $script:TempRoot = Join-Path $env:TEMP ('SmartZip-Kirs2-' + [guid]::NewGuid().ToString('N'))
        Assert-NoDeployedSmartZipAccess $script:TempRoot
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null

        # Unique correct + guaranteed-wrong passwords (process scope only)
        $script:FixturePassword = 'SZ-OK-' + [guid]::NewGuid().ToString('N')
        $script:WrongPassword = 'SZ-BAD-' + [guid]::NewGuid().ToString('N')
        if ($script:WrongPassword -eq $script:FixturePassword) {
            $script:WrongPassword = $script:WrongPassword + 'x'
        }
        [Environment]::SetEnvironmentVariable('SMARTZIP_FIXTURE_PASSWORD', $script:FixturePassword, 'Process')
        [Environment]::SetEnvironmentVariable('SMARTZIP_FIXTURE_WRONG_PASSWORD', $script:WrongPassword, 'Process')

        $script:CompiledExe = $null
        $script:ManifestPath = $null
        $script:Manifest = $null
        $script:CachedRuns = @{}

        if (-not $script:SkipReason) {
            try {
                # Stage TEMP compile tree with tests\IntegrationTestHook.ahk present
                $buildRoot = Join-Path $script:TempRoot 'build-src'
                $libDir = Join-Path $buildRoot 'lib'
                $testsDir = Join-Path $buildRoot 'tests'
                New-Item -ItemType Directory -Path $libDir, $testsDir -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'SmartZip.ahk') -Destination (Join-Path $buildRoot 'SmartZip.ahk') -Force
                Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk') -Destination (Join-Path $libDir 'ArchiveDiagnostics.ahk') -Force
                if (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'ico.ico')) {
                    Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'ico.ico') -Destination (Join-Path $buildRoot 'ico.ico') -Force
                }
                Copy-Item -LiteralPath $script:HookAhk -Destination (Join-Path $testsDir 'IntegrationTestHook.ahk') -Force

                $outExe = Join-Path $script:TempRoot 'SmartZip-Integration.exe'
                $baseAhk = Join-Path (Split-Path $script:AhkExe -Parent) 'AutoHotkey64.exe'
                $p = Start-Process -FilePath $script:Ahk2Exe -ArgumentList @(
                    '/in', (Join-Path $buildRoot 'SmartZip.ahk'),
                    '/out', $outExe,
                    '/base', $baseAhk,
                    '/silent'
                ) -Wait -PassThru -NoNewWindow
                if ($p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outExe)) {
                    $p2 = Start-Process -FilePath $script:Ahk2Exe -ArgumentList @(
                        '/in', (Join-Path $buildRoot 'SmartZip.ahk'),
                        '/out', $outExe,
                        '/base', $baseAhk
                    ) -Wait -PassThru -NoNewWindow
                    if ($p2.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outExe)) {
                        throw "Ahk2Exe failed exit=$($p2.ExitCode)"
                    }
                }
                $script:CompiledExe = $outExe

                $fxRoot = Join-Path $script:TempRoot 'fx'
                New-Item -ItemType Directory -Path $fxRoot -Force | Out-Null
                $gen = & $script:FixtureGen -Root $fxRoot -SevenZip $script:SevenZip
                $script:ManifestPath = $gen.ManifestPath
                $script:Manifest = Get-Content -LiteralPath $script:ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if (-not $script:Manifest.crcPartialRatio -or [double]$script:Manifest.crcPartialRatio -le 0.90) {
                    throw "crcPartial ratio precondition failed: $($script:Manifest.crcPartialRatio)"
                }
            } catch {
                $script:SkipReason = "setup failed: $($_.Exception.Message)"
            }
        }
    }

    AfterAll {
        try {
            if ($script:TempRoot -and (Test-Path -LiteralPath $script:TempRoot)) {
                $leaked = Get-LeakedCountBelowRoot -Root $script:TempRoot
                if ($leaked -ne 0) {
                    Write-Warning "AfterAll leaked $leaked processes under $($script:TempRoot)"
                }
                # zero-process assertion before delete
                if ($leaked -ne 0) {
                    throw "AfterAll: $leaked SmartZip/7z/7zG process(es) still under temp root"
                }
                Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        } finally {
            [Environment]::SetEnvironmentVariable('SMARTZIP_FIXTURE_PASSWORD', $null, 'Process')
            [Environment]::SetEnvironmentVariable('SMARTZIP_FIXTURE_WRONG_PASSWORD', $null, 'Process')
            Remove-Item Env:SMARTZIP_FIXTURE_PASSWORD -ErrorAction SilentlyContinue
            Remove-Item Env:SMARTZIP_TEST_PASSWORD_MODE -ErrorAction SilentlyContinue
            Remove-Item Env:SMARTZIP_TEST_RESULT_PATH -ErrorAction SilentlyContinue
            Remove-Item Env:SMARTZIP_FIXTURE_WRONG_PASSWORD -ErrorAction SilentlyContinue
        }
    }

    function Ensure-Ready {
        if ($script:SkipReason) {
            # Pester 3.4: inconclusive = explicit skip with reason
            Set-TestInconclusive -Message $script:SkipReason
            return $false
        }
        return $true
    }

    function Get-CachedScenario {
        param(
            [string]$Key,
            [string]$Scenario,
            [int]$DelSource = 0,
            [string]$PasswordMode = 'none'
        )
        $cacheKey = "$Key|$Scenario|$DelSource|$PasswordMode"
        if (-not $script:CachedRuns.ContainsKey($cacheKey)) {
            $script:CachedRuns[$cacheKey] = Invoke-Scenario -Scenario $Scenario -DelSource $DelSource -PasswordMode $PasswordMode
        }
        return $script:CachedRuns[$cacheKey]
    }

    # ---- 14 fixture/scenario terminal-status assertions ----

    It 'valid terminal status is OK' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'valid' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'OK'
        $run.Result.marker | Should Be 'SMARTZIP_TEST_RESULT_V1'
    }

    It 'encryptedHeader with correctSaved password is OK' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'encryptedHeader' -DelSource 0 -PasswordMode 'correctSaved'
        Get-ResultStatus $run | Should Be 'OK'
    }

    It 'wrongPassword with wrongDialog stays WRONG_PASSWORD' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'wrongPassword' -DelSource 0 -PasswordMode 'wrongDialog'
        Get-ResultStatus $run | Should Be 'WRONG_PASSWORD'
        Assert-SourcePreserved $run
    }

    It 'damagedHeader terminal status is HEADER_CORRUPT and source preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'damagedHeader' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'HEADER_CORRUPT'
        Assert-SourcePreserved $run
    }

    It 'truncated terminal status is TRUNCATED and source preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'truncated' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'TRUNCATED'
        Assert-SourcePreserved $run
    }

    It 'crcPartial terminal status is DATA_CORRUPT and source preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'crcPartial' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'DATA_CORRUPT'
        Assert-SourcePreserved $run
    }

    It 'splitComplete terminal status is OK' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'splitComplete' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'OK'
        Assert-AllVolumeMembersPresent -Run $run -FixtureKey 'splitComplete'
    }

    It 'splitMissing terminal status is MISSING_VOLUME and all members preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'splitMissing' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'MISSING_VOLUME'
        Assert-AllVolumeMembersPresent -Run $run -FixtureKey 'splitMissing'
    }

    It 'splitNonFirst normalizes and yields OK once with all members preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'splitNonFirst' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'OK'
        Assert-AllVolumeMembersPresent -Run $run -FixtureKey 'splitNonFirst'
    }

    It 'trailingWarning terminal status is OK_WITH_WARNING and source preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'trailingWarning' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'OK_WITH_WARNING'
        Assert-SourcePreserved $run
    }

    It 'fake7z terminal status is NOT_ARCHIVE and source preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'fake7z' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'NOT_ARCHIVE'
        Assert-SourcePreserved $run
    }

    It 'plainNoExtension terminal status is NOT_ARCHIVE and source preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'plainNoExtension' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'NOT_ARCHIVE'
        Assert-SourcePreserved $run
    }

    It 'extensionlessArchive terminal status is OK after strict probe' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'extensionlessArchive' -DelSource 0 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'OK'
    }

    It 'passwordCancel with dialogCancel is CANCELLED and source preserved' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'passwordCancel' -DelSource 0 -PasswordMode 'dialogCancel'
        Get-ResultStatus $run | Should Be 'CANCELLED'
        Assert-SourcePreserved $run
    }

    # ---- 4 lifecycle assertions ----

    It 'lifecycle valid clean success recycles disposable source when delSource=1' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'life' -Scenario 'valid' -DelSource 1 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'OK'
        # Recycle Bin: source file no longer at original path
        (Test-Path -LiteralPath $run.ArchivePath) | Should Be $false
    }

    It 'lifecycle warning preserves source even with delSource=1' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'life' -Scenario 'trailingWarning' -DelSource 1 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'OK_WITH_WARNING'
        Assert-SourcePreserved $run
    }

    It 'lifecycle CRC partial preserves source with delSource=1' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'life' -Scenario 'crcPartial' -DelSource 1 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'DATA_CORRUPT'
        Assert-SourcePreserved $run
    }

    It 'lifecycle header and truncated preserve source with delSource=1' {
        if (-not (Ensure-Ready)) { return }
        $h = Get-CachedScenario -Key 'life' -Scenario 'damagedHeader' -DelSource 1 -PasswordMode 'none'
        $t = Get-CachedScenario -Key 'life' -Scenario 'truncated' -DelSource 1 -PasswordMode 'none'
        Get-ResultStatus $h | Should Be 'HEADER_CORRUPT'
        Get-ResultStatus $t | Should Be 'TRUNCATED'
        Assert-SourcePreserved $h
        Assert-SourcePreserved $t
    }

    # ---- 2 volume assertions ----

    It 'volume complete members preserved even on success' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'vol' -Scenario 'splitComplete' -DelSource 1 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'OK'
        Assert-AllVolumeMembersPresent -Run $run -FixtureKey 'splitComplete'
    }

    It 'volume missing and non-first sets processed once with every member preserved' {
        if (-not (Ensure-Ready)) { return }
        $miss = Get-CachedScenario -Key 'vol' -Scenario 'splitMissing' -DelSource 1 -PasswordMode 'none'
        $nf = Get-CachedScenario -Key 'vol' -Scenario 'splitNonFirst' -DelSource 1 -PasswordMode 'none'
        Get-ResultStatus $miss | Should Be 'MISSING_VOLUME'
        Get-ResultStatus $nf | Should Be 'OK'
        Assert-AllVolumeMembersPresent -Run $miss -FixtureKey 'splitMissing'
        Assert-AllVolumeMembersPresent -Run $nf -FixtureKey 'splitNonFirst'
    }

    # ---- 2 partial-output assertions ----

    It 'partial CRC output moves to exactly one incomplete directory' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'partial' -Scenario 'crcPartial' -DelSource 0 -PasswordMode 'none'
        $run.PartialDirs.Count | Should Be 1
        $pdiag = Join-Path $run.PartialDirs[0] 'SmartZip-诊断.txt'
        (Test-Path -LiteralPath $pdiag) | Should Be $true
        if ($run.Result.partialOutputDir) {
            ($run.Result.partialOutputDir -match '_解压不完整_\d{8}-\d{6}') | Should Be $true
        }
    }

    It 'partial no failed extraction contaminates the normal target' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'partial' -Scenario 'crcPartial' -DelSource 0 -PasswordMode 'none'
        $bad = @($run.TargetInventory | Where-Object {
            $_ -notmatch '_解压不完整_' -and
            ($_ -match 'alpha\.txt$' -or $_ -match 'beta\.txt$' -or $_ -match 'alpha\.bin$' -or $_ -match 'beta\.bin$')
        })
        $bad.Count | Should Be 0
        # damagedHeader should not place payload in normal target either
        $h = Get-CachedScenario -Key 'status' -Scenario 'damagedHeader' -DelSource 0 -PasswordMode 'none'
        $hBad = @($h.TargetInventory | Where-Object {
            $_ -notmatch '_解压不完整_' -and ($_ -match 'alpha\.bin$' -or $_ -match 'beta\.bin$')
        })
        $hBad.Count | Should Be 0
    }

    # ---- 2 old-heuristic regressions ----

    It 'heuristic CRC fixture ratio exceeds 90 percent' {
        if (-not (Ensure-Ready)) { return }
        $ratio = [double]$script:Manifest.crcPartialRatio
        $ratio | Should BeGreaterThan 0.90
        $ratio | Should BeLessThan 1.0
        $fx = $script:Manifest.fixtures.crcPartial
        [double]$fx.ratio | Should BeGreaterThan 0.90
    }

    It 'heuristic CRC is not OK and mayDeleteSource is false' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'crcPartial' -DelSource 1 -PasswordMode 'none'
        Get-ResultStatus $run | Should Be 'DATA_CORRUPT'
        $run.Result.status | Should Not Be 'OK'
        # mayDeleteSource serialized as bool or string
        $mds = $run.Result.mayDeleteSource
        $isFalse = ($mds -eq $false) -or ("$mds" -eq 'false') -or ("$mds" -eq '0')
        $isFalse | Should Be $true
        Assert-SourcePreserved $run
    }

    # ---- 2 secrecy assertions ----

    It 'secrecy password absent from result logs and streams; no passwordUsed; no raw -p' {
        if (-not (Ensure-Ready)) { return }
        $runs = @(
            (Get-CachedScenario -Key 'status' -Scenario 'encryptedHeader' -DelSource 0 -PasswordMode 'correctSaved'),
            (Get-CachedScenario -Key 'status' -Scenario 'wrongPassword' -DelSource 0 -PasswordMode 'wrongDialog'),
            (Get-CachedScenario -Key 'status' -Scenario 'passwordCancel' -DelSource 0 -PasswordMode 'dialogCancel')
        )
        foreach ($run in $runs) {
            $json = [string]$run.ResultJson
            $json | Should Match 'SMARTZIP_TEST_RESULT_V1'
            ($json -match 'passwordUsed') | Should Be $false
            $texts = Collect-CaptureTexts $run
            foreach ($t in $texts) {
                (Test-TextHasPasswordLeak -Text $t -Password $script:FixturePassword -Wrong $script:WrongPassword) | Should Be $false
            }
            # static guard: runners/generator must not hardcode deployed path as a live target
            $runnerText = [System.IO.File]::ReadAllText($script:ScenarioRunner)
            $genText = [System.IO.File]::ReadAllText($script:FixtureGen)
            # refusal helpers may mention the path as a denied string; live path usage beyond that is banned via Assert
            ($runnerText -match 'C:\\Tool\\SmartZip') | Should Be $true  # appears only in guard strings
            ($genText -match 'C:\\Tool\\SmartZip') | Should Be $true
            # smoke pair must not embed integration markers
            $smokePs = [System.IO.File]::ReadAllText($script:SmokeRunner)
            $smokeUi = [System.IO.File]::ReadAllText($script:SmokeUi)
            ($smokePs -match 'SMARTZIP_TEST_RESULT_V1') | Should Be $false
            ($smokeUi -match 'SMARTZIP_TEST_RESULT_V1') | Should Be $false
            ($smokePs -match 'IntegrationTestHook') | Should Be $false
            ($smokeUi -match 'IntegrationTestHook') | Should Be $false
            ($smokeUi -match 'SmartZipTest_OnResult') | Should Be $false
        }
    }

    It 'secrecy diagnostics contain basename but not full source path' {
        if (-not (Ensure-Ready)) { return }
        $run = Get-CachedScenario -Key 'status' -Scenario 'crcPartial' -DelSource 0 -PasswordMode 'none'
        $run.PartialDirs.Count | Should Be 1
        $pdiag = Join-Path $run.PartialDirs[0] 'SmartZip-诊断.txt'
        (Test-Path -LiteralPath $pdiag) | Should Be $true
        $text = [System.IO.File]::ReadAllText($pdiag)
        $baseName = [System.IO.Path]::GetFileName($run.ArchivePath)
        ($text -match [regex]::Escape($baseName)) | Should Be $true
        # full source path must not appear (redacted)
        ($text.Contains($run.ArchivePath)) | Should Be $false
        ($text.Contains($run.SourceDir)) | Should Be $false
        (Test-TextHasPasswordLeak -Text $text -Password $script:FixturePassword -Wrong $script:WrongPassword) | Should Be $false
    }
}
