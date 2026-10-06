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
# Start-Process -PassThru leaves ExitCode empty under Windows PowerShell 5.1, which turns
# every "exit code must be 0" gate into a comparison against nothing.
function Invoke-AhkRunner {
    param(
        [string] $ScriptPath,
        [string[]] $ScriptArguments = @(),
        [int] $TimeoutMs = 30000,
        [string] $TimeoutMessage = 'AutoHotkey runner timed out'
    )
    $quoted = @('/ErrorStdOut', ('"' + $ScriptPath + '"'))
    foreach ($a in $ScriptArguments) { $quoted += ('"' + $a + '"') }
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = Resolve-AhkExe
    $psi.Arguments = $quoted -join ' '
    $psi.UseShellExecute = $false
    $runner = [Diagnostics.Process]::Start($psi)
    try {
        if (-not $runner.WaitForExit($TimeoutMs)) {
            # Only the process this call started is terminated.
            try { $runner.Kill() } catch {}
            try { $runner.WaitForExit(5000) } catch {}
            throw $TimeoutMessage
        }
        return $runner.ExitCode
    } finally {
        $runner.Dispose()
    }
}