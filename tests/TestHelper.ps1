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