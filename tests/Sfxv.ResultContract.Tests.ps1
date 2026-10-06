$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SfxvResultHelper.ps1')

Describe 'SFXV harness result contract' {
    It 'fails when the harness produced no result lines' {
        { Assert-SfxvResults @() @('a') } | Should Throw 'no result lines'
    }
    It 'fails when a label is reported more than once' {
        { Assert-SfxvResults @('a=PASS','a=PASS') @('a') } | Should Throw 'more than once'
    }
    It 'fails when a label does not report PASS' {
        { Assert-SfxvResults @('a=FAIL') @('a') } | Should Throw 'malformed or not PASS'
    }
    It 'fails when the harness reports a label that was not expected' {
        { Assert-SfxvResults @('a=PASS','b=PASS') @('a') } | Should Throw 'are not expected'
    }
    It 'fails when an expected label is missing' {
        { Assert-SfxvResults @('a=PASS') @('a','b') } | Should Throw 'did not report'
    }
    It 'fails when the expected label set itself is empty' {
        { Assert-SfxvResults @('a=PASS') @() } | Should Throw 'must not be empty'
    }
    It 'fails when the final result line is truncated' {
        { Assert-SfxvResults @('a=PASS','b=PA') @('a','b') } | Should Throw 'malformed or not PASS'
    }
    It 'fails on a blank result line' {
        { Assert-SfxvResults @('a=PASS','') @('a') } | Should Throw 'malformed or not PASS'
    }
    It 'accepts exactly the expected passing labels' {
        { Assert-SfxvResults @('a=PASS') @('a') } | Should Not Throw
    }
    It 'maps labels to their reported status for per-label assertions' {
        (Get-SfxvResultMap @('a=PASS','b=FAIL'))['b'] | Should Be 'FAIL'
    }
}
