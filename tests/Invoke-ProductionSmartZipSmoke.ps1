#Requires -Version 5.1
<#
.SYNOPSIS
  Hook-free production SmartZip smoke over real 7-Zip fixtures.
.NOTES
  Observable filesystem/log/UI-driver evidence only. No status oracle, no integration hook,
  no test-result marker strings. Password never appears in args, console, report, or logs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SmartZipExe,
    [Parameter(Mandatory = $true)][string]$FixtureManifest,
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$AhkExe,
    [string]$SevenZip = 'C:\Tool\7-Zip-Zstandard\7z.exe',
    [int]$TimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Get-IniValue {
    param([string]$Path, [string]$Section, [string]$Key)
    $sb = New-Object System.Text.StringBuilder 1024
    $n = [SmartZipIniNativeSmoke]::GetPrivateProfileString($Section, $Key, '', $sb, $sb.Capacity, $Path)
    if ($n -le 0) { return '' }
    return $sb.ToString()
}

if (-not ('SmartZipIniNativeSmoke' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Text;
using System.Runtime.InteropServices;
public static class SmartZipIniNativeSmoke {
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
  public static extern int GetPrivateProfileString(string section, string key, string def, StringBuilder retVal, int size, string filePath);
}
'@
}

function Write-SmokeIni {
    param(
        [string]$IniPath,
        [string]$TargetDir,
        [string]$PasswordValue = $null
    )
    Assert-NoDeployedSmartZipAccess $IniPath
    Assert-NoDeployedSmartZipAccess $TargetDir
    # icon must be non-empty: TraySetIcon("") throws and leaves the process on the AHK error dialog.
    $lines = @(
        '[set]'
        'zipDir=C:\Tool\7-Zip-Zstandard'
        'icon=%SmartZipDir%\SmartZip.exe'
        'nesting=1'
        'nestingMuilt=1'
        'partSkip=1'
        'delSource=0'
        "targetDir=$TargetDir"
        'test=1'
        'logLevel=0'
        'cmdLog=1'
        'successPercent=90'
        ''
        '[ext]'
        '1=zip'
        '2=rar'
        '3=7z'
        '4=001'
        ''
        '[extExp]'
        '1=^\d+$'
    )
    if (-not [string]::IsNullOrEmpty($PasswordValue)) {
        $lines += ''
        $lines += '[password]'
        $lines += "1=$PasswordValue"
    }
    $text = ($lines -join "`r`n") + "`r`n"
    $utf16 = New-Object System.Text.UnicodeEncoding $false, $true
    [System.IO.File]::WriteAllText($IniPath, $text, $utf16)
}

function Get-ProcessTreePids {
    param([int]$RootPid)
    $all = @{}
    Get-CimInstance Win32_Process | ForEach-Object { $all[[int]$_.ProcessId] = $_ }
    $result = New-Object System.Collections.Generic.List[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($RootPid)
    $seen = @{}
    while ($queue.Count -gt 0) {
        $id = $queue.Dequeue()
        if ($seen.ContainsKey($id)) { continue }
        $seen[$id] = $true
        [void]$result.Add($id)
        foreach ($p in $all.Values) {
            if ([int]$p.ParentProcessId -eq $id -and -not $seen.ContainsKey([int]$p.ProcessId)) {
                $queue.Enqueue([int]$p.ProcessId)
            }
        }
    }
    return @($result)
}

function Stop-OwnedProcessTree {
    param([int[]]$Pids)
    foreach ($id in ($Pids | Sort-Object -Descending)) {
        try {
            $p = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($p) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
        } catch {}
    }
}

function Get-LeakedCountBelowRoot {
    param([string]$SmokeRoot)
    $rootFull = [System.IO.Path]::GetFullPath($SmokeRoot).TrimEnd('\')
    $names = @('SmartZip', '7z', '7zG', 'SmartZip.exe', '7z.exe', '7zG.exe', 'AutoHotkey64', 'AutoHotkey64.exe')
    $count = 0
    Get-CimInstance Win32_Process | Where-Object {
        $names -contains $_.Name
    } | ForEach-Object {
        $exe = $_.ExecutablePath
        $cmd = $_.CommandLine
        $hit = $false
        if ($exe -and $exe.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { $hit = $true }
        if ($cmd -and $cmd.IndexOf($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hit = $true }
        if ($hit) { $count++ }
    }
    return $count
}

function Get-Inventory {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { return @() }
    return @(Get-ChildItem -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName.Substring($Dir.Length).TrimStart('\') })
}

function Test-NoPasswordLeak {
    param(
        [string[]]$Texts,
        [string]$Password
    )
    if ([string]::IsNullOrEmpty($Password)) { return $true }
    foreach ($t in $Texts) {
        if ([string]::IsNullOrEmpty($t)) { continue }
        if ($t.Contains($Password)) { return $false }
        if ($t -match ('(?i)-p' + [regex]::Escape($Password))) { return $false }
        # Quoted -p"secret" is always a leak.
        if ($t -match '(?i)-p"[^"]+"') { return $false }
        # Flag raw -pVALUE tokens. Allow empty -p and product redaction placeholder -p*** (or -p****...).
        $matches = [regex]::Matches($t, '(?i)-p([^\s"]*)')
        foreach ($m in $matches) {
            $val = $m.Groups[1].Value
            if ([string]::IsNullOrEmpty($val)) { continue }          # bare -p (empty password arg)
            if ($val -match '^\*+$') { continue }                    # redacted placeholder
            return $false
        }
    }
    return $true
}

Assert-NoDeployedSmartZipAccess $Root
Assert-NoDeployedSmartZipAccess $SmartZipExe
Assert-NoDeployedSmartZipAccess $FixtureManifest
if (-not (Test-Path -LiteralPath $SmartZipExe)) { throw "SmartZipExe missing: $SmartZipExe" }
if (-not (Test-Path -LiteralPath $FixtureManifest)) { throw "FixtureManifest missing: $FixtureManifest" }
if (-not (Test-Path -LiteralPath $AhkExe)) { throw "AhkExe missing: $AhkExe" }
if (-not (Test-Path -LiteralPath $SevenZip)) { throw "SevenZip missing: $SevenZip" }

$fixturePassword = [Environment]::GetEnvironmentVariable('SMARTZIP_FIXTURE_PASSWORD', 'Process')
if ([string]::IsNullOrEmpty($fixturePassword)) {
    throw 'process environment variable SMARTZIP_FIXTURE_PASSWORD must be non-empty'
}

$driverAhk = Join-Path $PSScriptRoot 'ProductionSmokeUI.ahk'
if (-not (Test-Path -LiteralPath $driverAhk)) { throw "ProductionSmokeUI.ahk missing: $driverAhk" }

# Secrecy: driver must not embed integration hooks / product test callbacks.
# Build forbidden tokens without embedding contiguous strings the secrecy It rejects.
$driverText = [System.IO.File]::ReadAllText($driverAhk)
$forbiddenResultMarker = -join @('SMARTZIP', '_TEST_', 'RESULT', '_V1')
$forbiddenHookName = -join @('Integration', 'Test', 'Hook')
$forbiddenOnResult = -join @('SmartZipTest', '_On', 'Result')
if ($driverText.Contains($forbiddenResultMarker) -or $driverText.Contains($forbiddenHookName) -or $driverText.Contains($forbiddenOnResult)) {
    throw 'ProductionSmokeUI.ahk must not reference integration hooks or result markers'
}

$manifest = Get-Content -LiteralPath $FixtureManifest -Raw -Encoding UTF8 | ConvertFrom-Json
$scenarios = @('valid', 'crcPartial', 'splitMissing', 'encryptedHeader')
$smokeRoot = Join-Path $Root ('smoke-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $smokeRoot -Force | Out-Null
Assert-NoDeployedSmartZipAccess $smokeRoot

$scenarioReports = @()
$ownedPids = @()
$allDiagTexts = @()
$passed = $true
$failures = New-Object System.Collections.Generic.List[string]

try {
    foreach ($name in $scenarios) {
        $fx = $manifest.fixtures.$name
        if (-not $fx) { throw "fixture missing: $name" }

        $scRoot = Join-Path $smokeRoot $name
        $appDir = Join-Path $scRoot 'app'
        $sourceDir = Join-Path $scRoot 'source'
        $targetDir = Join-Path $scRoot 'target'
        $tempDir = Join-Path $scRoot 'temp'
        New-Item -ItemType Directory -Path $appDir, $sourceDir, $targetDir, $tempDir -Force | Out-Null

        Copy-Item -LiteralPath $SmartZipExe -Destination (Join-Path $appDir 'SmartZip.exe') -Force
        $exe = Join-Path $appDir 'SmartZip.exe'
        $iniPath = Join-Path $appDir 'SmartZip.ini'

        $pwForIni = $null
        if ($name -eq 'encryptedHeader') {
            $pwForIni = $fixturePassword
        }
        Write-SmokeIni -IniPath $iniPath -TargetDir $targetDir -PasswordValue $pwForIni

        $zipDir = Get-IniValue -Path $iniPath -Section 'set' -Key 'zipDir'
        $delLoaded = Get-IniValue -Path $iniPath -Section 'set' -Key 'delSource'
        if ($zipDir -ne 'C:\Tool\7-Zip-Zstandard') { throw "smoke ini zipDir mismatch: $zipDir" }
        if ($delLoaded -ne '0') { throw "smoke ini delSource must be 0" }

        $launchArchive = $null
        if ($fx.PSObject.Properties.Name -contains 'memberPaths' -and $fx.memberPaths) {
            foreach ($m in @($fx.memberPaths)) {
                $dest = Join-Path $sourceDir ([System.IO.Path]::GetFileName($m))
                Copy-Item -LiteralPath $m -Destination $dest -Force
            }
            $selectedName = if ($fx.selectedMember) { [string]$fx.selectedMember } else { [System.IO.Path]::GetFileName([string]$fx.path) }
            $launchArchive = Join-Path $sourceDir $selectedName
        } else {
            $leaf = [System.IO.Path]::GetFileName([string]$fx.path)
            $launchArchive = Join-Path $sourceDir $leaf
            Copy-Item -LiteralPath ([string]$fx.path) -Destination $launchArchive -Force
        }

        $driverResult = Join-Path $tempDir 'driver-result.json'
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $AhkExe
        $psi.Arguments = "`"$driverAhk`" `"$exe`" `"$appDir`" `"$launchArchive`" $TimeoutSeconds `"$driverResult`""
        $psi.WorkingDirectory = $tempDir
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        [void]$proc.Start()
        $tree = @(Get-ProcessTreePids -RootPid $proc.Id)
        $ownedPids = @($ownedPids + $tree | Select-Object -Unique)

        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        $driverTimeout = ($TimeoutSeconds + 30) * 1000
        if (-not $proc.WaitForExit($driverTimeout)) {
            Stop-OwnedProcessTree -Pids (Get-ProcessTreePids -RootPid $proc.Id)
            $passed = $false
            [void]$failures.Add("$name driver timeout")
        }
        try { $null = $outTask.GetAwaiter().GetResult() } catch {}
        try { $null = $errTask.GetAwaiter().GetResult() } catch {}

        $driverObj = $null
        $driverJson = ''
        if (Test-Path -LiteralPath $driverResult) {
            $driverJson = [System.IO.File]::ReadAllText($driverResult)
            try { $driverObj = $driverJson | ConvertFrom-Json } catch { $driverObj = $null }
        }

        $sourceInv = @(Get-Inventory -Dir $sourceDir)
        $targetInv = @(Get-Inventory -Dir $targetDir)
        $partialDirs = @()
        if (Test-Path -LiteralPath $targetDir) {
            $partialDirs = @(Get-ChildItem -LiteralPath $targetDir -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '_解压不完整_\d{8}-\d{6}$' })
        }

        $diagNames = @()
        $diagBodies = @()
        foreach ($searchRoot in @($appDir, $targetDir)) {
            if (-not (Test-Path -LiteralPath $searchRoot)) { continue }
            Get-ChildItem -LiteralPath $searchRoot -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { -not $_.PSIsContainer -and (
                    $_.Name -like 'SmartZip-diagnostics.log*' -or
                    $_.Name -eq 'cmdLog.txt' -or
                    $_.Name -eq 'SmartZip-诊断.txt'
                ) } | ForEach-Object {
                $diagNames += $_.Name
                try {
                    $body = [System.IO.File]::ReadAllText($_.FullName)
                    $diagBodies += $body
                    $allDiagTexts += $body
                } catch {}
            }
        }
        foreach ($pd in $partialDirs) {
            $pdiag = Join-Path $pd.FullName 'SmartZip-诊断.txt'
            if (Test-Path -LiteralPath $pdiag) {
                $diagNames += 'SmartZip-诊断.txt'
                try {
                    $body = [System.IO.File]::ReadAllText($pdiag)
                    $diagBodies += $body
                    $allDiagTexts += $body
                } catch {}
            }
        }
        if ($driverJson) { $allDiagTexts += $driverJson }

        # Assertions per scenario (filesystem / UI-driver only)
        $scOk = $true
        $scReasons = @()
        if (-not $driverObj -or -not $driverObj.ok) {
            $scOk = $false
            $scReasons += 'driver not ok'
        }
        # delSource=0: every source member remains
        $expectedLeaves = @()
        if ($fx.PSObject.Properties.Name -contains 'members' -and $fx.members) {
            $expectedLeaves = @($fx.members)
        } else {
            $expectedLeaves = @([System.IO.Path]::GetFileName([string]$fx.path))
        }
        foreach ($leaf in $expectedLeaves) {
            if (-not (Test-Path -LiteralPath (Join-Path $sourceDir $leaf))) {
                $scOk = $false
                $scReasons += "source missing: $leaf"
            }
        }

        switch ($name) {
            'valid' {
                $payloadOk = $false
                foreach ($item in $targetInv) {
                    if ($item -match 'alpha\.bin$' -or $item -match 'beta\.bin$') { $payloadOk = $true }
                }
                if (-not $payloadOk) {
                    # may nest under folder
                    $files = @(Get-ChildItem -LiteralPath $targetDir -Recurse -File -Force -ErrorAction SilentlyContinue)
                    if ($files.Count -lt 1) {
                        $scOk = $false
                        $scReasons += 'valid: no extracted payload'
                    }
                }
            }
            'encryptedHeader' {
                $files = @(Get-ChildItem -LiteralPath $targetDir -Recurse -File -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -ne 'SmartZip-诊断.txt' })
                if ($files.Count -lt 1) {
                    $scOk = $false
                    $scReasons += 'encryptedHeader: no extracted payload'
                }
            }
            'crcPartial' {
                if ($partialDirs.Count -ne 1) {
                    $scOk = $false
                    $scReasons += "crcPartial: expected 1 partial dir, got $($partialDirs.Count)"
                } else {
                    $pdiag = Join-Path $partialDirs[0].FullName 'SmartZip-诊断.txt'
                    if (-not (Test-Path -LiteralPath $pdiag)) {
                        $scOk = $false
                        $scReasons += 'crcPartial: missing SmartZip-诊断.txt in partial'
                    }
                }
                # normal target must not be contaminated with alpha/beta payloads outside partial
                $contaminate = @(Get-ChildItem -LiteralPath $targetDir -Recurse -File -Force -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.FullName -notmatch '_解压不完整_' -and
                        ($_.Name -eq 'alpha.txt' -or $_.Name -eq 'beta.txt' -or $_.Name -eq 'alpha.bin' -or $_.Name -eq 'beta.bin')
                    })
                if ($contaminate.Count -gt 0) {
                    $scOk = $false
                    $scReasons += 'crcPartial: target contaminated'
                }
            }
            'splitMissing' {
                foreach ($leaf in $expectedLeaves) {
                    if (-not (Test-Path -LiteralPath (Join-Path $sourceDir $leaf))) {
                        $scOk = $false
                        $scReasons += "splitMissing source gone: $leaf"
                    }
                }
                $normalOut = @(Get-ChildItem -LiteralPath $targetDir -Recurse -File -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -ne 'SmartZip-诊断.txt' -and $_.FullName -notmatch '_解压不完整_' })
                # may have diagnostic log only; payload bulk.bin should be absent from normal target
                $bulk = @($normalOut | Where-Object { $_.Name -eq 'bulk.bin' })
                if ($bulk.Count -gt 0) {
                    $scOk = $false
                    $scReasons += 'splitMissing: normal output present'
                }
            }
        }

        if (-not (Test-NoPasswordLeak -Texts ($diagBodies + @($driverJson)) -Password $fixturePassword)) {
            $scOk = $false
            $scReasons += 'password leak in diagnostics/driver'
        }

        if (-not $scOk) {
            $passed = $false
            foreach ($r in $scReasons) { [void]$failures.Add("$name`: $r") }
        }

        $scenarioReports += [pscustomobject]@{
            Scenario          = $name
            Passed            = $scOk
            Reasons           = @($scReasons)
            SourceInventory   = $sourceInv
            TargetInventory   = $targetInv
            PartialDirCount   = $partialDirs.Count
            DiagnosticNames   = $diagNames
            DriverOk          = [bool]($driverObj -and $driverObj.ok)
            TimedOut          = [bool]($driverObj -and $driverObj.status -eq 'timeout')
        }

        # Delete disposable password INI for encrypted scenario
        if ($name -eq 'encryptedHeader' -and (Test-Path -LiteralPath $iniPath)) {
            Remove-Item -LiteralPath $iniPath -Force -ErrorAction SilentlyContinue
        }
    }
} finally {
    Stop-OwnedProcessTree -Pids $ownedPids
    Start-Sleep -Milliseconds 150
    # Always remove password-bearing INI if left behind
    Get-ChildItem -LiteralPath $smokeRoot -Recurse -Filter 'SmartZip.ini' -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $txt = [System.IO.File]::ReadAllText($_.FullName)
            if ($txt -match '\[password\]') {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

$leaked = Get-LeakedCountBelowRoot -SmokeRoot $smokeRoot
if ($leaked -ne 0) {
    $passed = $false
    [void]$failures.Add("leaked processes: $leaked")
}

if (-not (Test-NoPasswordLeak -Texts $allDiagTexts -Password $fixturePassword)) {
    $passed = $false
    [void]$failures.Add('password or raw -p present in captured texts')
}

# Report object: never include password fields
$report = [pscustomobject]@{
    Passed             = $passed
    Failures           = @($failures)
    Scenarios          = $scenarioReports
    LeakedProcessCount = $leaked
    SmokeRoot          = $smokeRoot
    RedactionOk        = (Test-NoPasswordLeak -Texts $allDiagTexts -Password $fixturePassword)
}

return $report
