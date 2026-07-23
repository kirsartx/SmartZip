# SmartZip Tests

Pester **3.4** (classic `Should` syntax) plus AutoHotkey v2 harnesses.

## Prerequisites

| Tool | Path / notes |
|---|---|
| 7-Zip Zstandard | `C:\Tool\7-Zip-Zstandard\7z.exe` (hard-coded in Real7Zip suite; user engine directory) |
| AutoHotkey 2.0.26 | `C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe` |
| Ahk2Exe | `...\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe` |
| PowerShell | 5.1+, Pester 3.4 |

Integration / smoke never read or write `C:\Tool\SmartZip`. Every archive, INI, log, compiled test EXE, and probe artifact stays under one unique:

`%TEMP%\SmartZip-Kirs3-<guid>`

## Exact command order and counts (Task 8 whole-branch gate)

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=172; 'ArchiveDiagnostics.Tests.ps1'=161
  'RunCmdCapture.Tests.ps1'=15; 'PasswordPreflight.Tests.ps1'=78
  'ExtractionLifecycle.Tests.ps1'=26; 'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=46; 'Real7Zip.Integration.Tests.ps1'=32
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

Expected exact totals after Task 8: static `172/172`, diagnostics `161/161`, capture `15/15`, password/workflow `78/78`, lifecycle `26/26`, nesting `30/30`, UI `46/46`, real integration `32/32`.

## Real-7-Zip integration suite

| File | Role |
|---|---|
| `New-ExtractionReliabilityFixtures.ps1` | Deterministic fixtures via real `7z.exe`; process-only `SMARTZIP_FIXTURE_PASSWORD` |
| `Invoke-CompiledSmartZipScenario.ps1` | Isolated TEMP scenario runner (120s cap, owned-PID cleanup) |
| `IntegrationTestHook.ahk` | Test-only callbacks: result JSON, GUI suppress, password dialog |
| `Real7Zip.Integration.Tests.ps1` | 32 integration assertions (30 scenarios + 2 TEMP-injection contracts) |
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

### Test-only TEMP injection (no production hook)

Production `SmartZip.ahk` **never** includes `tests\IntegrationTestHook.ahk`. It keeps only:

```ahk
#Include lib\ArchiveDiagnostics.ahk
```

and continues to call hooks only behind `IsSet(SmartZipTest_*)` guards (no production callback definitions).

`Real7Zip.Integration.Tests.ps1` stages a unique TEMP tree and **injects exactly once**, immediately after the ArchiveDiagnostics include:

```ahk
#Include lib\ArchiveDiagnostics.ahk
#Include *i tests\IntegrationTestHook.ahk
class SmartZip
```

Injection is fail-closed: production must not already reference the hook; the ArchiveDiagnostics include anchor must exist exactly once; replace is count-limited to one. The suite compiles **only** that TEMP-injected source (never repo `SmartZip.ahk`).

Defined callbacks when the TEMP hook is present:

- `SmartZipTest_OnResult` — redacted `SMARTZIP_TEST_RESULT_V1` JSON (no `passwordUsed`)
- `SmartZipTest_SuppressGui` — function form (not a bare variable) so class-method `IsSet` sees it; no diagnostic GUI / Run / clipboard
- `SmartZipTest_PasswordDialog` — deterministic dialog for wrong/cancel modes only

Production staging/build copies `SmartZip.ahk`, `lib`, and `ico.ico` **without** a `tests\` directory, so production has no hook include and uses the normal GUI path.

Passwords never appear in process arguments, console output, result JSON, diagnostics, or smoke reports. Scenario cleanup stops only task-owned PID trees and removes only task-owned TEMP paths.

### Timeouts

Compiled scenario and production smoke cap SmartZip execution at **120 seconds** per scenario. Leaked `SmartZip` / `7z` / `7zG` processes whose executable or command line points under the TEMP root fail the runner.
