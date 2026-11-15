$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TestHelper.ps1')

Describe 'Bounded isolated AHK test execution' {
    BeforeAll {
        $script:InfrastructureRoot = Join-Path $env:TEMP ('SmartZip-Infrastructure-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:InfrastructureRoot | Out-Null
    }
    AfterAll {
        Remove-Item -LiteralPath $script:InfrastructureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    It 'creates different owned stages and removes only those stages' {
        $one = New-AhkTestStage -Name 'isolation'
        $two = New-AhkTestStage -Name 'isolation'
        try {
            $one | Should Not Be $two
            [IO.File]::WriteAllText((Join-Path $two 'keep.txt'), 'keep')
            Remove-AhkTestStage $one
            (Test-Path -LiteralPath $one) | Should Be $false
            (Test-Path -LiteralPath (Join-Path $two 'keep.txt')) | Should Be $true
        } finally { Remove-AhkTestStage $one; Remove-AhkTestStage $two }
    }
    It 'returns the actual nonzero child exit code' {
        $path = Join-Path $script:InfrastructureRoot 'exit7.ahk'
        [IO.File]::WriteAllText($path, "#Requires AutoHotkey v2.0`nExitApp(7)")
        (Invoke-AhkRunner -ScriptPath $path) | Should Be 7
    }
    It 'rejects nonzero exits even when a result was written' {
        $path = Join-Path $script:InfrastructureRoot 'result7.ahk'
        $out = Join-Path $script:InfrastructureRoot 'result7.txt'
        [IO.File]::WriteAllText($path, "#Requires AutoHotkey v2.0`nFileAppend(`"done`", A_Args[1])`nExitApp(7)")
        { Invoke-AhkResultRunner -ScriptPath $path -ScriptArguments @($out) -ResultPath $out } | Should Throw 'exit=7'
        (Test-Path -LiteralPath $out) | Should Be $true
    }
    It 'rejects a successful process without its result file' {
        $path = Join-Path $script:InfrastructureRoot 'empty.ahk'
        [IO.File]::WriteAllText($path, "#Requires AutoHotkey v2.0`nExitApp(0)")
        { Invoke-AhkResultRunner -ScriptPath $path -ResultPath (Join-Path $script:InfrastructureRoot 'absent.txt') } | Should Throw 'No result'
    }
    It 'bounds a stalled runner and terminates the owned process' {
        $path = Join-Path $script:InfrastructureRoot 'sleep.ahk'
        $pidFile = Join-Path $script:InfrastructureRoot 'runner-pid.txt'
        [IO.File]::WriteAllText($path, "#Requires AutoHotkey v2.0`nFileAppend(DllCall(`"GetCurrentProcessId`"), A_Args[1])`nSleep(20000)")
        $watch = [Diagnostics.Stopwatch]::StartNew()
        { Invoke-AhkRunner -ScriptPath $path -ScriptArguments @($pidFile) -TimeoutMs 1500 } | Should Throw 'timed out'
        $watch.ElapsedMilliseconds | Should BeLessThan 7000
        $runnerId = [int][IO.File]::ReadAllText($pidFile)
        (Get-Process -Id $runnerId -ErrorAction SilentlyContinue) | Should BeNullOrEmpty
    }
    It 'does not accept a stale result from an earlier invocation' {
        $path = Join-Path $script:InfrastructureRoot 'stale.ahk'
        $out = Join-Path $script:InfrastructureRoot 'stale.txt'
        [IO.File]::WriteAllText($path, "#Requires AutoHotkey v2.0`nExitApp(0)")
        [IO.File]::WriteAllText($out, 'stale')
        { Invoke-AhkResultRunner -ScriptPath $path -ResultPath $out } | Should Throw 'No result'
    }
    It 'preserves arguments containing spaces and the working directory' {
        $path = Join-Path $script:InfrastructureRoot 'quoted args.ahk'
        $out = Join-Path $script:InfrastructureRoot 'quoted result.txt'
        [IO.File]::WriteAllText($path, "#Requires AutoHotkey v2.0`nFileAppend(A_Args[2] `"|`" A_WorkingDir, A_Args[1], `"UTF-8-RAW`")")
        Invoke-AhkResultRunner -ScriptPath $path -ScriptArguments @($out, 'value with spaces') -WorkingDirectory $script:InfrastructureRoot -ResultPath $out | Out-Null
        [IO.File]::ReadAllText($out) | Should Be ('value with spaces|' + $script:InfrastructureRoot)
    }
    It 'captures independent stdout and stderr paths' {
        $path = Join-Path $script:InfrastructureRoot 'streams.ahk'
        $stdout = Join-Path $script:InfrastructureRoot 'stdout.txt'
        $stderr = Join-Path $script:InfrastructureRoot 'stderr.txt'
        [IO.File]::WriteAllText($path, "#Requires AutoHotkey v2.0`nFileAppend(`"out`", `"*`", `"UTF-8-RAW`")`nFileAppend(`"err`", `"**`", `"UTF-8-RAW`")")
        (Invoke-AhkRunner -ScriptPath $path -StandardOutputPath $stdout -StandardErrorPath $stderr) | Should Be 0
        [IO.File]::ReadAllText($stdout) | Should Be 'out'
        [IO.File]::ReadAllText($stderr) | Should Be 'err'
    }
    It 'refuses cleanup outside a generated stage' {
        { Remove-AhkTestStage (Split-Path $PSScriptRoot -Parent) } | Should Throw 'Refusing'
    }
}
