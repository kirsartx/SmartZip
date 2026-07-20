#requires -Version 5.0
<#
.SYNOPSIS
  Pester 3.4 wrapper for ArchiveDiagnostics.Harness.ahk
.NOTES
  Classic Should syntax only. Run:
    Invoke-Pester -Script tests/ArchiveDiagnostics.Tests.ps1 -PassThru
#>

$ErrorActionPreference = 'Stop'

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:HarnessPath = Join-Path $PSScriptRoot 'ArchiveDiagnostics.Harness.ahk'
$script:LibPath = Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'
$script:StaticPath = Join-Path $PSScriptRoot 'SmartZip.Static.Tests.ps1'
$script:Results = @{}

function Invoke-ArchiveHarness {
    param(
        [ValidateSet('classify', 'volumes', 'all')]
        [string]$Mode = 'classify'
    )
    if (-not (Test-Path -LiteralPath $script:AhkExe)) {
        throw "AutoHotkey not found: $($script:AhkExe)"
    }
    if (-not (Test-Path -LiteralPath $script:HarnessPath)) {
        throw "Harness not found: $($script:HarnessPath)"
    }
    $outFile = Join-Path $env:TEMP ("ArchiveDiagnostics.Harness.{0}.{1}.out.txt" -f $Mode, [guid]::NewGuid().ToString('N'))
    $errFile = Join-Path $env:TEMP ("ArchiveDiagnostics.Harness.{0}.{1}.err.txt" -f $Mode, [guid]::NewGuid().ToString('N'))
    $args = @('/ErrorStdOut', $script:HarnessPath, $outFile, $Mode)
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList $args -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput (Join-Path $env:TEMP 'ArchiveDiagnostics.Harness.stdout.txt') `
        -RedirectStandardError $errFile
    $map = @{}
    if (Test-Path -LiteralPath $outFile) {
        Get-Content -LiteralPath $outFile -Encoding UTF8 | ForEach-Object {
            $line = $_
            if ($line -match '^(PASS|FAIL)\s+(\S+)') {
                $map[$matches[2]] = $matches[1]
            }
            elseif ($line -match '^SUMMARY\s+passed=(\d+)\s+failed=(\d+)') {
                $map['__summary_passed'] = $matches[1]
                $map['__summary_failed'] = $matches[2]
            }
        }
    }
    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        Map      = $map
        OutFile  = $outFile
        ErrFile  = $errFile
    }
}

# Invoke Classify7zResult once and return status|passwordUsed|errorLineCount for ZS regressions.
function Invoke-Classify7zProbe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Output,
        [int]$ExitCode = 2,
        [string]$Stage = 'probe',
        [string]$ArchivePath = 'C:\tmp\fake.7z'
    )
    if (-not (Test-Path -LiteralPath $script:AhkExe)) {
        throw "AutoHotkey not found: $($script:AhkExe)"
    }
    $id = [guid]::NewGuid().ToString('N')
    $outFile = Join-Path $env:TEMP ("ArchiveDiagnostics.ClassifyProbe.{0}.out.txt" -f $id)
    $errFile = Join-Path $env:TEMP ("ArchiveDiagnostics.ClassifyProbe.{0}.err.txt" -f $id)
    $scriptFile = Join-Path $env:TEMP ("ArchiveDiagnostics.ClassifyProbe.{0}.ahk" -f $id)
    $libEsc = $script:LibPath -replace '\\', '\\'
    $outEsc = $outFile -replace '\\', '\\'
    $archEsc = $ArchivePath -replace '\\', '\\'
    $stageEsc = $Stage -replace '"', '``"'
    # Embed output as AHK continuation via Chr codes to avoid quoting pitfalls.
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Output)
    $chrParts = foreach ($b in $bytes) { "Chr($b)" }
    $outputExpr = if ($chrParts.Count -gt 0) { $chrParts -join ' . ' } else { '""' }
    $ahk = @"
#Requires AutoHotkey v2.0
#SingleInstance Off
FileEncoding "UTF-8"
#Include $libEsc
outputText := $outputExpr
r := Classify7zResult("$stageEsc", $ExitCode, outputText, "$archEsc")
payload := r.status . "|" . r.passwordUsed . "|" . r.errorLines.Length
FileAppend payload, "$outEsc", "UTF-8"
"@
    try {
        Set-Content -LiteralPath $scriptFile -Value $ahk -Encoding UTF8
        $p = Start-Process -FilePath $script:AhkExe -ArgumentList @('/ErrorStdOut', $scriptFile) `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput (Join-Path $env:TEMP ("ArchiveDiagnostics.ClassifyProbe.{0}.stdout.txt" -f $id)) `
            -RedirectStandardError $errFile
        if ($p.ExitCode -ne 0) {
            $errText = if (Test-Path -LiteralPath $errFile) { Get-Content -LiteralPath $errFile -Raw } else { '' }
            throw "Classify probe AHK exit=$($p.ExitCode) err=$errText"
        }
        if (-not (Test-Path -LiteralPath $outFile)) {
            throw "Classify probe produced no output file"
        }
        $raw = (Get-Content -LiteralPath $outFile -Encoding UTF8 -Raw).Trim()
        $parts = $raw -split '\|', 3
        return [pscustomobject]@{
            Status         = $parts[0]
            PasswordUsed   = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            ErrorLineCount = if ($parts.Count -gt 2) { [int]$parts[2] } else { 0 }
            Raw            = $raw
        }
    }
    finally {
        Remove-Item -LiteralPath $scriptFile, $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

Describe 'ArchiveDiagnosticsFiles' {
    It 'lib/ArchiveDiagnostics.ahk exists' {
        $script:LibPath | Should Exist
    }
    It 'tests/ArchiveDiagnostics.Harness.ahk exists' {
        $script:HarnessPath | Should Exist
    }
    It 'AutoHotkey 2.0.26 toolchain exists' {
        $script:AhkExe | Should Exist
    }
}

Describe 'ArchiveDiagnosticsClassify' {
    BeforeAll {
        $script:ClassifyRun = Invoke-ArchiveHarness -Mode classify
        $script:Results = $script:ClassifyRun.Map
    }

    It 'harness exits 0 on classify mode' {
        $script:ClassifyRun.ExitCode | Should Be 0
    }

    $caseNames = @(
        'status_ok',
        'status_ok_with_warning',
        'status_need_password',
        'status_wrong_password',
        'status_missing_volume',
        'status_not_archive',
        'status_unsupported_method',
        'status_header_corrupt',
        'status_truncated',
        'status_data_corrupt',
        'status_cancelled',
        'status_io_error',
        'status_unknown_error',
        'result_status',
        'result_stage',
        'result_exit_code',
        'result_archive_path',
        'result_output',
        'result_archive_type_default',
        'result_password_used_default',
        'result_volume_first_default',
        'result_missing_volumes_array',
        'result_warning_lines_array',
        'result_error_lines_array',
        'result_temp_output_dir_default',
        'result_partial_output_dir_default',
        'result_is_clean_success_ok',
        'result_may_delete_source_ok',
        'result_is_clean_success_warning_false',
        'result_may_delete_source_warning_false',
        'cancelled_exit_255',
        'cancelled_not_clean',
        'cancelled_no_delete',
        'missing_volume_beats_headers',
        'need_password_enter_prompt',
        'wrong_password_beats_headers',
        'wrong_password_keeps_multiple_error_lines',
        'wrong_password_cannot_open_encrypted',
        'unsupported_method',
        'truncated_unexpected_end',
        'header_corrupt_plain',
        'wrong_password_beats_crc_phrase',
        'data_corrupt_crc_failed',
        'data_corrupt_data_error',
        'not_archive',
        'ok_with_warning',
        'ok_with_warning_not_clean',
        'ok_with_warning_no_delete',
        'ok_with_warning_collects_warnings',
        'ok_clean',
        'ok_clean_is_clean',
        'ok_clean_may_delete',
        'ok_never_sets_password_used',
        'io_error_access_denied',
        'io_error_disk_full',
        'unknown_error',
        'priority_wrong_password_multi',
        'collects_wrong_password_line',
        'collects_headers_error_line_secondary',
        'redact_strips_password_value',
        'redact_replaces_with_placeholder',
        'redact_keeps_full_path_when_requested',
        'redact_name_mode_strips_password',
        'redact_name_mode_strips_directories',
        'redact_name_mode_keeps_filename',
        'redact_unquoted_dash_p',
        'redact_unquoted_dash_p_placeholder',
        'classifier_never_sets_password_used'
    )

    # Keep the canonical 140 ArchiveDiagnostics Its while folding real 7-Zip ZS
    # not-archive strings (discovered via C:\Tool\7-Zip-Zstandard\7z.exe) into them.
    $zsNotArchiveExtras = @{
        'not_archive' = @(
            @{
                Label    = 'zs_bracket_format'
                Output   = "Open ERROR: Cannot open the file as [7z] archive`n"
                Expected = 'NOT_ARCHIVE'
            },
            @{
                Label    = 'zs_is_not_archive'
                Output   = "Is not archive`n"
                Expected = 'NOT_ARCHIVE'
            },
            @{
                Label    = 'zs_cant_open_as_archive'
                Output   = "Can't open as archive: 1`n"
                Expected = 'NOT_ARCHIVE'
            },
            @{
                Label    = 'zs_real_combo'
                Output   = @"
Open ERROR: Cannot open the file as [7z] archive

ERRORS:
Is not archive

Can't open as archive: 1
"@
                Expected = 'NOT_ARCHIVE'
            }
        )
        'status_not_archive' = @(
            @{
                Label    = 'zs_bracket_zip_type'
                Output   = "ERROR: Cannot open the file as [zip] archive`n"
                Expected = 'NOT_ARCHIVE'
            },
            @{
                Label    = 'zs_bracket_casefold'
                Output   = "error: cannot open the file as [7Z] archive`n"
                Expected = 'NOT_ARCHIVE'
            }
        )
        'wrong_password_cannot_open_encrypted' = @(
            @{
                Label    = 'zs_wrong_password_beats_not_archive'
                Output   = "ERROR: Cannot open encrypted archive. Wrong password?`nIs not archive`n"
                Expected = 'WRONG_PASSWORD'
            }
        )
        'classifier_never_sets_password_used' = @(
            @{
                Label              = 'zs_not_archive_never_sets_password_used'
                Output            = "Open ERROR: Cannot open the file as [7z] archive`nIs not archive`nCan't open as archive: 1`n"
                Expected          = 'NOT_ARCHIVE'
                RequireEmptyPass  = $true
            }
        )
    }

    foreach ($name in $caseNames) {
        It "case $name PASS" {
            $script:Results.ContainsKey($name) | Should Be $true
            $script:Results[$name] | Should Be 'PASS'
            if ($zsNotArchiveExtras.ContainsKey($name)) {
                foreach ($extra in $zsNotArchiveExtras[$name]) {
                    $probe = Invoke-Classify7zProbe -Output $extra.Output -ExitCode 2
                    $probe.Status | Should Be $extra.Expected
                    if ($extra.ContainsKey('RequireEmptyPass') -and $extra.RequireEmptyPass) {
                        $probe.PasswordUsed | Should Be ''
                    }
                }
            }
        }
    }
}

Describe 'ArchiveDiagnosticsVolumes' {
    BeforeAll {
        $script:VolumeRun = Invoke-ArchiveHarness -Mode volumes
        $script:VolResults = $script:VolumeRun.Map
    }

    It 'harness exits 0 on volumes mode' {
        $script:VolumeRun.ExitCode | Should Be 0
    }

    $volumeCases = @(
        'sevenz_001_is_volume',
        'sevenz_001_selected_is_first',
        'sevenz_001_first_path',
        'sevenz_001_member_count',
        'sevenz_001_member_first',
        'sevenz_001_member_second',
        'sevenz_001_no_missing',
        'sevenz_002_is_volume',
        'sevenz_002_not_first',
        'sevenz_002_redirects_first_path',
        'sevenz_002_no_missing_when_first_present',
        'zip_001_is_volume',
        'zip_001_selected_is_first',
        'zip_001_first_path',
        'zip_001_member_count',
        'zip_001_no_missing',
        'bare_001_is_volume',
        'bare_001_selected_is_first',
        'bare_001_first_path',
        'bare_001_member_count',
        'part01_rar_is_volume',
        'part01_rar_selected_is_first',
        'part01_rar_first_path',
        'part01_rar_member_count',
        'part01_rar_no_missing',
        'part10_rar_is_volume',
        'part10_rar_not_first',
        'part10_rar_redirects_to_part01',
        'part10_rar_reports_gap_missing_count',
        'part10_rar_missing_includes_part02',
        'part10_rar_missing_includes_part09',
        'part10_rar_missing_excludes_present_first',
        'part10_rar_missing_excludes_selected',
        'rar_base_is_volume',
        'rar_base_selected_is_first',
        'rar_base_first_path',
        'rar_r00_member_count',
        'rar_r00_member_base',
        'rar_r00_member_r00',
        'rar_r00_member_r01',
        'rar_r00_complete_no_missing',
        'r00_is_volume',
        'r00_not_first',
        'rxx_redirects_and_reports_gap',
        'missing_first_still_volume',
        'missing_first_selected_not_first',
        'missing_first_first_path_derived',
        'missing_first_listed',
        'missing_middle_is_volume',
        'missing_middle_selected_first',
        'missing_middle_lists_002',
        'missing_middle_members_present_only',
        'non_volume_is_false',
        'non_volume_empty_first',
        'non_volume_empty_members',
        'non_volume_empty_missing',
        'non_volume_selected_not_first',
        'solo_001_is_volume',
        'solo_001_is_first',
        'solo_001_first_path',
        'solo_001_one_member',
        'solo_001_no_fabricated_missing',
        'orphan_r00_is_volume',
        'orphan_r00_not_first',
        'orphan_r00_derives_rar_first',
        'orphan_r00_missing_base_rar',
        'orphan_r00_does_not_fabricate_r99'
    )

    # Keep the canonical 67 volume Its while folding follow-up coverage into them.
    $extraCases = @{
        'part10_rar_reports_gap_missing_count' = @('part10_rar_missing_excludes_part11')
        'missing_first_still_volume' = @(
            'absent_selected_is_volume', 'absent_selected_first_path',
            'absent_selected_member_count', 'absent_selected_member_only_present',
            'absent_selected_not_member', 'absent_selected_listed_missing'
        )
        'sevenz_002_is_volume' = @(
            'present_first_sibling_casing_is_volume', 'present_first_sibling_casing'
        )
        'non_volume_is_false' = @(
            'numeric_000_not_volume', 'numeric_000_empty_first', 'numeric_000_empty_members',
            'numeric_000_empty_missing', 'numeric_000_selected_not_first',
            'numeric_7z_000_not_volume', 'numeric_7z_000_empty_first', 'numeric_7z_000_empty_members',
            'numeric_7z_000_empty_missing', 'numeric_7z_000_selected_not_first',
            'part00_not_volume', 'part00_empty_first', 'part00_empty_members',
            'part00_empty_missing', 'part00_selected_not_first'
        )
        'solo_001_is_volume' = @(
            'large_suffix_is_volume', 'large_suffix_empty_missing', 'large_suffix_retains_members',
            'large_suffix_retains_001', 'large_suffix_retains_5000'
        )
        'missing_middle_is_volume' = @(
            'invalid_sibling_zero_is_volume', 'invalid_sibling_zero_ignored',
            'invalid_sibling_zero_not_member', 'invalid_sibling_zero_keeps_001',
            'invalid_sibling_zero_keeps_002',
            'mixed_numeric_width_is_volume', 'mixed_numeric_width_member_count',
            'mixed_numeric_width_excludes_other_width',
            'mixed_part_width_is_volume', 'mixed_part_width_member_count',
            'mixed_part_width_excludes_other_width',
            'inclusive_bound_is_volume', 'inclusive_bound_empty_missing',
            'inclusive_bound_keeps_members', 'inclusive_bound_keeps_last'
        )
        'r00_is_volume' = @(
            'mixed_rar_width_is_volume', 'mixed_rar_width_member_count',
            'mixed_rar_width_excludes_other_width'
        )
    }

    foreach ($name in $volumeCases) {
        It "volume case $name PASS" {
            $script:VolResults.ContainsKey($name) | Should Be $true
            $script:VolResults[$name] | Should Be 'PASS'
            if ($extraCases.ContainsKey($name)) {
                foreach ($extraName in $extraCases[$name]) {
                    $script:VolResults.ContainsKey($extraName) | Should Be $true
                    $script:VolResults[$extraName] | Should Be 'PASS'
                }
            }
        }
    }
}
