#Requires -Version 5.1
<#
.SYNOPSIS
  Run one isolated compiled-SmartZip scenario under a TEMP root.
.NOTES
  Every artifact stays under -Root (SmartZip-Kirs3-* TEMP). Never touches C:\Tool\SmartZip.
  Passwords are process-env / disposable INI only — never args, console, or report fields.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SmartZipExe,
    [Parameter(Mandatory = $true)][string]$FixtureManifest,
    [Parameter(Mandatory = $true)][string]$Scenario,
    [Parameter(Mandatory = $true)][string]$Root,
    [ValidateSet(0, 1)][int]$DelSource = 0,
    [ValidateSet('none', 'correctSaved', 'wrongDialog', 'dialogCancel')]$PasswordMode = 'none',
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
    $n = [SmartZipIniNative]::GetPrivateProfileString($Section, $Key, '', $sb, $sb.Capacity, $Path)
    if ($n -le 0) { return '' }
    return $sb.ToString()
}

if (-not ('SmartZipIniNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Text;
using System.Runtime.InteropServices;
public static class SmartZipIniNative {
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
  public static extern int GetPrivateProfileString(string section, string key, string def, StringBuilder retVal, int size, string filePath);
}
'@
}

function Write-ScenarioIni {
    param(
        [string]$IniPath,
        [string]$TargetDir,
        [int]$DelSourceValue,
        [string]$PasswordValue = $null
    )
    Assert-NoDeployedSmartZipAccess $IniPath
    Assert-NoDeployedSmartZipAccess $TargetDir
    # icon must be non-empty: TraySetIcon("") throws "Can't load icon" and leaves the
    # process on the AHK error dialog (valid scenario hangs with no hook result).
    # Compiled scenario app dir only has SmartZip.exe; use it as the icon source.
    $lines = @(
        '[set]'
        'zipDir=C:\Tool\7-Zip-Zstandard'
        'icon=%SmartZipDir%\SmartZip.exe'
        'nesting=1'
        'nestingMuilt=1'
        'partSkip=1'
        "delSource=$DelSourceValue"
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
    param([string]$ScenarioRoot)
    $rootFull = [System.IO.Path]::GetFullPath($ScenarioRoot).TrimEnd('\')
    $names = @('SmartZip', '7z', '7zG', 'SmartZip.exe', '7z.exe', '7zG.exe')
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

Assert-NoDeployedSmartZipAccess $Root
Assert-NoDeployedSmartZipAccess $SmartZipExe
Assert-NoDeployedSmartZipAccess $FixtureManifest
if (-not (Test-Path -LiteralPath $SmartZipExe)) { throw "SmartZipExe missing: $SmartZipExe" }
if (-not (Test-Path -LiteralPath $FixtureManifest)) { throw "FixtureManifest missing: $FixtureManifest" }

$manifest = Get-Content -LiteralPath $FixtureManifest -Raw -Encoding UTF8 | ConvertFrom-Json
$fx = $manifest.fixtures.$Scenario
if (-not $fx) { throw "scenario key not in manifest: $Scenario" }

$scenarioRoot = Join-Path $Root ("scenario-" + $Scenario + "-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
Assert-NoDeployedSmartZipAccess $scenarioRoot
$appDir = Join-Path $scenarioRoot 'app'
$sourceDir = Join-Path $scenarioRoot 'source'
$targetDir = Join-Path $scenarioRoot 'target'
$tempDir = Join-Path $scenarioRoot 'temp'
New-Item -ItemType Directory -Path $appDir, $sourceDir, $targetDir, $tempDir -Force | Out-Null

$ownedPids = @()
$resultPath = Join-Path $tempDir 'result.json'
$stdoutPath = Join-Path $tempDir 'stdout.txt'
$stderrPath = Join-Path $tempDir 'stderr.txt'
$exitCode = -1
$stdout = ''
$stderr = ''
$resultObj = $null
$resultJson = ''
$partialDirs = @()
$diagTexts = @()
$archivePath = $null
$finalLeak = 0

try {
    Copy-Item -LiteralPath $SmartZipExe -Destination (Join-Path $appDir 'SmartZip.exe') -Force
    $exe = Join-Path $appDir 'SmartZip.exe'
    $iniPath = Join-Path $appDir 'SmartZip.ini'

    $savedPassword = $null
    if ($PasswordMode -eq 'correctSaved') {
        $savedPassword = [Environment]::GetEnvironmentVariable('SMARTZIP_FIXTURE_PASSWORD', 'Process')
        if ([string]::IsNullOrEmpty($savedPassword)) { throw 'SMARTZIP_FIXTURE_PASSWORD required for correctSaved' }
    }
    Write-ScenarioIni -IniPath $iniPath -TargetDir $targetDir -DelSourceValue $DelSource -PasswordValue $savedPassword

    $zipDir = Get-IniValue -Path $iniPath -Section 'set' -Key 'zipDir'
    $delLoaded = Get-IniValue -Path $iniPath -Section 'set' -Key 'delSource'
    $testLoaded = Get-IniValue -Path $iniPath -Section 'set' -Key 'test'
    $ext3 = Get-IniValue -Path $iniPath -Section 'ext' -Key '3'
    if ($zipDir -ne 'C:\Tool\7-Zip-Zstandard') { throw "ini zipDir mismatch: $zipDir" }
    if ($delLoaded -ne [string]$DelSource) { throw "ini delSource mismatch: $delLoaded" }
    if ($testLoaded -ne '1') { throw "ini test mismatch: $testLoaded" }
    if ($ext3 -ne '7z') { throw "ini ext 3 mismatch: $ext3 (IsArchive(7z) false)" }

    # Copy scenario source member(s)
    $srcPath = [string]$fx.path
    Assert-NoDeployedSmartZipAccess $srcPath
    $launchPaths = @()
    if ($fx.PSObject.Properties.Name -contains 'memberPaths' -and $fx.memberPaths) {
        foreach ($m in @($fx.memberPaths)) {
            $dest = Join-Path $sourceDir ([System.IO.Path]::GetFileName($m))
            Copy-Item -LiteralPath $m -Destination $dest -Force
        }
        $selectedName = if ($fx.selectedMember) { [string]$fx.selectedMember } else { [System.IO.Path]::GetFileName($srcPath) }
        $archivePath = Join-Path $sourceDir $selectedName
        # Launch selected first, then remaining siblings (volume once-processing / partSkip).
        $launchPaths = @($archivePath)
        foreach ($leaf in @($fx.members)) {
            $p = Join-Path $sourceDir $leaf
            if ($p -ne $archivePath -and (Test-Path -LiteralPath $p)) {
                $launchPaths += $p
            }
        }
    } else {
        $leaf = [System.IO.Path]::GetFileName($srcPath)
        $archivePath = Join-Path $sourceDir $leaf
        Copy-Item -LiteralPath $srcPath -Destination $archivePath -Force
        $launchPaths = @($archivePath)
    }
    if (-not (Test-Path -LiteralPath $archivePath)) { throw "scenario source missing after copy: $archivePath" }

    $env:SMARTZIP_TEST_RESULT_PATH = $resultPath
    $env:SMARTZIP_TEST_PASSWORD_MODE = $PasswordMode

    $argParts = @('x') + @($launchPaths | ForEach-Object { '"' + $_ + '"' })
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = [string]::Join(' ', $argParts)
    $psi.WorkingDirectory = $appDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $ownedPids = @(Get-ProcessTreePids -RootPid $proc.Id)
    Start-Sleep -Milliseconds 200
    $ownedPids = @(Get-ProcessTreePids -RootPid $proc.Id)

    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
        $ownedPids = @($ownedPids + (Get-ProcessTreePids -RootPid $proc.Id) | Select-Object -Unique)
        Stop-OwnedProcessTree -Pids $ownedPids
        throw "scenario $Scenario timed out after ${TimeoutSeconds}s"
    }
    try { $stdout = $outTask.GetAwaiter().GetResult() } catch { $stdout = '' }
    try { $stderr = $errTask.GetAwaiter().GetResult() } catch { $stderr = '' }
    $exitCode = $proc.ExitCode
    [System.IO.File]::WriteAllText($stdoutPath, $stdout, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($stderrPath, $stderr, [System.Text.UTF8Encoding]::new($false))

    $ownedPids = @($ownedPids + (Get-ProcessTreePids -RootPid $proc.Id) | Select-Object -Unique)

    if (Test-Path -LiteralPath $resultPath) {
        $resultJson = [System.IO.File]::ReadAllText($resultPath, [System.Text.Encoding]::UTF8)
        try { $resultObj = $resultJson | ConvertFrom-Json } catch { $resultObj = $null }
    }

    if (Test-Path -LiteralPath $targetDir) {
        $partialDirs = @(Get-ChildItem -LiteralPath $targetDir -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '_解压不完整_\d{8}-\d{6}$' } |
            ForEach-Object { $_.FullName })
    }

    foreach ($searchRoot in @($appDir, $targetDir)) {
        if (-not (Test-Path -LiteralPath $searchRoot)) { continue }
        Get-ChildItem -LiteralPath $searchRoot -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and (
                $_.Name -like 'SmartZip-diagnostics.log*' -or
                $_.Name -eq 'cmdLog.txt' -or
                $_.Name -eq 'SmartZip-诊断.txt'
            ) } | ForEach-Object {
            try { $diagTexts += [System.IO.File]::ReadAllText($_.FullName) } catch {}
        }
    }
    foreach ($pd in $partialDirs) {
        Get-ChildItem -LiteralPath $pd -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } | ForEach-Object {
            try { $diagTexts += [System.IO.File]::ReadAllText($_.FullName) } catch {}
        }
    }
} finally {
    Stop-OwnedProcessTree -Pids $ownedPids
    Start-Sleep -Milliseconds 150
    $finalLeak = Get-LeakedCountBelowRoot -ScenarioRoot $scenarioRoot
    Remove-Item Env:SMARTZIP_TEST_RESULT_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:SMARTZIP_TEST_PASSWORD_MODE -ErrorAction SilentlyContinue
}

if ($finalLeak -ne 0) {
    throw "scenario $Scenario leaked $finalLeak SmartZip/7z/7zG process(es) under $scenarioRoot"
}

return [pscustomobject]@{
    Scenario           = $Scenario
    ScenarioRoot       = $scenarioRoot
    ExitCode           = $exitCode
    Result             = $resultObj
    ResultJson         = $resultJson
    StdOut             = $stdout
    StdErr             = $stderr
    SourceInventory    = @(Get-Inventory -Dir $sourceDir)
    TargetInventory    = @(Get-Inventory -Dir $targetDir)
    SourceDir          = $sourceDir
    TargetDir          = $targetDir
    AppDir             = $appDir
    ArchivePath        = $archivePath
    PartialDirs        = $partialDirs
    DiagnosticTexts    = $diagTexts
    LeakedProcessCount = 0
    PasswordMode       = $PasswordMode
    DelSource          = $DelSource
}
