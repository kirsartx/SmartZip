# Shared test helper: resolve AutoHotkey v2 and Ahk2Exe toolchain paths dynamically.
function Resolve-AhkExe {
    $candidates = @(
        (Join-Path $env:TEMP 'ahk_tools\ahk-v2\AutoHotkey64.exe'),
        (Join-Path $env:TEMP 'smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'),
        'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    throw 'AutoHotkey64.exe not found in any expected location. Set $script:AhkExe manually.'
}

function Resolve-Ahk2Exe {
    $candidates = @(
        (Join-Path $env:TEMP 'ahk_tools\ahk2exe\Ahk2Exe.exe'),
        (Join-Path $env:TEMP 'smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe'),
        'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe'
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

# Run an .ahk script and return its real exit code.
# Use a retained Process object for a bounded wait and an explicit exit-code read.
function Invoke-AhkRunner {
    [CmdletBinding()]
    param(
        [string] $ScriptPath,
        [string[]] $ScriptArguments = @(),
        [int] $TimeoutMs = 30000,
        [string] $TimeoutMessage = 'AutoHotkey runner timed out',
        [string] $WorkingDirectory,
        [string] $StandardOutputPath,
        [string] $StandardErrorPath
    )
    $quoted = @('/ErrorStdOut', ('"' + $ScriptPath + '"'))
    foreach ($a in $ScriptArguments) { $quoted += ('"' + $a + '"') }
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = Resolve-AhkExe
    $psi.Arguments = $quoted -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $redirect = $StandardOutputPath -or $StandardErrorPath
    if ($redirect) {
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    }
    $runner = [Diagnostics.Process]::Start($psi)
    if ($redirect) {
        $stdout = $runner.StandardOutput.ReadToEndAsync()
        $stderr = $runner.StandardError.ReadToEndAsync()
    }
    try {
        if (-not $runner.WaitForExit($TimeoutMs)) {
            # Only the process this call started is terminated.
            try { $runner.Kill() } catch {}
            try { $runner.WaitForExit(5000) } catch {}
            throw $TimeoutMessage
        }
        if ($redirect) {
            if (-not $stdout.Wait(2000) -or -not $stderr.Wait(2000)) { throw 'AHK output pipe did not close' }
            if ($StandardOutputPath) { [IO.File]::WriteAllText($StandardOutputPath, $stdout.Result, [Text.UTF8Encoding]::new($false)) }
            if ($StandardErrorPath) { [IO.File]::WriteAllText($StandardErrorPath, $stderr.Result, [Text.UTF8Encoding]::new($false)) }
        }
        return $runner.ExitCode
    } finally {
        $runner.Dispose()
    }
}

function Invoke-AhkResultRunner {
    param(
        [string]$ScriptPath,
        [string[]]$ScriptArguments = @(),
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [int]$TimeoutMs = 30000,
        [string]$WorkingDirectory,
        [string]$StandardOutputPath,
        [string]$StandardErrorPath
    )
    if (Test-Path -LiteralPath $ResultPath) { Remove-Item -LiteralPath $ResultPath -Force }
    $code = Invoke-AhkRunner -ScriptPath $ScriptPath -ScriptArguments $ScriptArguments -TimeoutMs $TimeoutMs `
        -WorkingDirectory $WorkingDirectory -StandardOutputPath $StandardOutputPath -StandardErrorPath $StandardErrorPath
    if ($code -ne 0) { throw "AHK harness failed exit=$code" }
    if (-not (Test-Path -LiteralPath $ResultPath -PathType Leaf)) { throw "No result from AHK harness: $ResultPath" }
    return $code
}

function New-AhkTestStage {
    param([ValidatePattern('^[A-Za-z0-9-]+$')][string]$Name = 'Harness')
    $path = Join-Path ([IO.Path]::GetTempPath()) ('SmartZip-Test-' + $Name + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function Remove-AhkTestStage {
    param([string]$Path)
    if (-not $Path) { return }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if ([IO.Path]::GetDirectoryName($full) -ne $tempRoot -or
        [IO.Path]::GetFileName($full) -notmatch '^SmartZip-Test-[A-Za-z0-9-]+-[a-f0-9]{32}$') {
        throw "Refusing cleanup outside an owned test stage: $full"
    }
    if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}
