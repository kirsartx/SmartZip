function Assert-SfxvResults {
    param(
        [string[]] $Lines,
        [string[]] $ExpectedLabels
    )

    if (-not $ExpectedLabels -or $ExpectedLabels.Count -eq 0) {
        throw 'Assert-SfxvResults: the expected label set must not be empty'
    }
    if (-not $Lines -or $Lines.Count -eq 0) {
        throw 'Assert-SfxvResults: the harness produced no result lines'
    }

    $seen = @{}
    $unknown = @()
    foreach ($line in $Lines) {
        if ($line -match '^([^=]+)=PASS$') {
            $label = $matches[1]
        } else {
            throw ('Assert-SfxvResults: result line is malformed or not PASS: [' + $line + ']')
        }
        if ($seen.ContainsKey($label)) {
            throw ('Assert-SfxvResults: label reported more than once: ' + $label)
        }
        $seen[$label] = $true
        if ($ExpectedLabels -notcontains $label) {
            $unknown += $label
        }
    }

    if ($unknown.Count -gt 0) {
        throw ('Assert-SfxvResults: harness reported labels that are not expected: ' + ($unknown -join ', '))
    }
    $missing = @($ExpectedLabels | Where-Object { -not $seen.ContainsKey($_) })
    if ($missing.Count -gt 0) {
        throw ('Assert-SfxvResults: harness did not report expected labels: ' + ($missing -join ', '))
    }
}

function Get-SfxvResultMap {
    param([string[]] $Lines)

    $map = @{}
    foreach ($line in @($Lines)) {
        if ($line -match '^([^=]+)=(.*)$') {
            $map[$matches[1]] = $matches[2]
        }
    }
    return $map
}
