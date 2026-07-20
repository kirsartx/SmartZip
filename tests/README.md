# SmartZip Tests

Pester **3.4** (classic `Should` syntax) plus AutoHotkey v2 harnesses.

## Prerequisites

| Tool | Path / notes |
|---|---|
| 7-Zip Zstandard | `C:\Tool\7-Zip-Zstandard\7z.exe` (real engine for Task 8) |
| AutoHotkey 2.0.26 | `C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe` |
| Ahk2Exe | `...\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe` |
| PowerShell | 5.1+, Pester 3.4 |

Integration / smoke never read or write `C:\Tool\SmartZip`. Every archive, INI, log, compiled test EXE, and probe artifact stays under one unique:

`%TEMP%\SmartZip-Kirs2-<guid>`

## Exact command order and counts (Task 9 / whole-branch gate)

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=150; 'ArchiveDiagnostics.Tests.ps1'=140
  'RunCmdCapture.Tests.ps1'=15; 'PasswordPreflight.Tests.ps1'=70
  'ExtractionLifecycle.Tests.ps1'=26; 'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=36; 'Real7Zip.Integration.Tests.ps1'=26
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
```

Expected exact totals: static `150/150`, diagnostics `140/140` (including focused volume `68/68`), capture `15/15`, password/workflow `70/70`, lifecycle `26/26`, nesting `30/30`, UI `36/36`, real integration `26/26`.

## Task 8 real-7-Zip suite

| File | Role |
|---|---|
| `New-ExtractionReliabilityFixtures.ps1` | Deterministic fixtures via real `7z.exe`; process-only `SMARTZIP_FIXTURE_PASSWORD` |
| `Invoke-CompiledSmartZipScenario.ps1` | Isolated TEMP scenario runner (120s cap, owned-PID cleanup) |
| `IntegrationTestHook.ahk` | Optional compile-time include: result JSON, GUI suppress, password dialog |
| `Real7Zip.Integration.Tests.ps1` | 26 integration assertions |
| `Invoke-ProductionSmartZipSmoke.ps1` | Hook-free production smoke (valid / crcPartial / splitMissing / encryptedHeader) |
| `ProductionSmokeUI.ahk` | Hook-free UI driver (closes warning/incomplete dialogs only) |

### Fixture meanings

| Key | Expected terminal status |
|---|---|
| `valid` | `OK` |
| `encryptedHeader` | `NEED_PASSWORD` probe; correct saved → `OK` |
| `wrongPassword` | `WRONG_PASSWORD` |
| `damagedHeader` | `HEADER_CORRUPT` |
| `truncated` | `TRUNCATED` |
| `crcPartial` | `DATA_CORRUPT` with genuine `0.90 < ratio < 1.0` |
| `splitComplete` | `OK` (all volumes present) |
| `splitMissing` | `MISSING_VOLUME` |
| `splitNonFirst` | `OK` after first-volume normalization / once-processing |
| `trailingWarning` | `OK_WITH_WARNING` |
| `fake7z` / `plainNoExtension` | `NOT_ARCHIVE` |
| `extensionlessArchive` | `OK` after strict probe |
| `passwordCancel` | `CANCELLED` |

### Test-only build seam

`SmartZip.ahk` includes:

```ahk
#Include *i tests\IntegrationTestHook.ahk
```

Task 8 compiles from a TEMP tree that **includes** `tests\IntegrationTestHook.ahk`, so the three callbacks are defined:

- `SmartZipTest_OnResult` — redacted `SMARTZIP_TEST_RESULT_V1` JSON (no `passwordUsed`)
- `SmartZipTest_SuppressGui` — no diagnostic GUI / Run / clipboard
- `SmartZipTest_PasswordDialog` — deterministic dialog for wrong/cancel modes only

Task 10 production staging copies `SmartZip.ahk`, `lib`, and `ico.ico` **without** `tests\`, so the optional include is absent and production uses the normal GUI path.

Passwords never appear in process arguments, console output, result JSON, diagnostics, or smoke reports. Scenario cleanup stops only task-owned PID trees and removes only task-owned TEMP paths.

### Timeouts

Compiled scenario and production smoke cap SmartZip execution at **120 seconds** per scenario. Leaked `SmartZip` / `7z` / `7zG` processes whose executable or command line points under the TEMP root fail the runner.
