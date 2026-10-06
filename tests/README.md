# SmartZip Tests

Pester **3.4** (classic `Should` syntax) plus AutoHotkey v2 harnesses.

## Prerequisites

| Tool | Path / notes |
|---|---|
| 7-Zip Zstandard | `C:\Tool\7-Zip-Zstandard\7z.exe` (user engine directory) |
| AutoHotkey v2 | Auto-detected by `tests/TestHelper.ps1` (checks `%TEMP%\ahk_tools`, Program Files) |
| Ahk2Exe | Auto-detected by `tests/TestHelper.ps1` |
| PowerShell | 5.1+, Pester 3.4 |

Integration / smoke never read or write `C:\Tool\SmartZip`. Every archive, INI, log, compiled test EXE, and probe artifact stays under one unique:

`%TEMP%\SmartZip-Kirs4-<guid>`

## Exact command order and counts (final contract gate)

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=184
  'ArchiveDiagnostics.Tests.ps1'=193
  'RunCmdCapture.Tests.ps1'=16
  'PasswordPreflight.Tests.ps1'=98
  'ExtractionLifecycle.Tests.ps1'=39
  'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=53
  'Real7Zip.Integration.Tests.ps1'=36
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
& 'C:\Tool\7-Zip-Zstandard\7z.exe' i | Select-Object -First 5
```

Expected exact totals: static `184/184`, diagnostics `193/193`, capture `16/16`, password/workflow `98/98`, lifecycle `39/39`, nesting `30/30`, UI `53/53`, real integration `36/36`; overall `649/649`.

The final review adds two executable warning-token assertions and fifteen executable password-recovery contract assertions. The focused six-suite run is `596/596`; capture and real integration retain their unchanged expected counts for the next whole-branch gate.

## Real-7-Zip integration suite

### Directory-scan optimization regression

Run `Invoke-Pester -Script '.\tests\DirectoryScanOptimization.Tests.ps1' -PassThru`
in addition to the eight-suite gate. Expected: 1 passed, 0 failed. This runs 120
volume-detection comparisons against commit `de80a38` (requires local Git history),
including plain files, numeric evidence, missing volumes, old RAR and case variants.
The eight-suite total is 649; with this regression the total is 650.

### SFXV self-extracting split regression

Run the following in addition to the contract gate:

```powershell
Invoke-Pester -Script './tests/Sfxv.Tests.ps1' -PassThru
Invoke-Pester -Script './tests/Sfxv.Integration.Tests.ps1' -PassThru
Invoke-Pester -Script './tests/Sfxv.ResultContract.Tests.ps1' -PassThru
```

Expected: `Sfxv.Tests.ps1` 1/1, `Sfxv.Integration.Tests.ps1` 137/137 and
`Sfxv.ResultContract.Tests.ps1` 10/10.
The integration suite creates data-only MZ/SFXV fixtures, strips the self-extractor
stub into a temporary regular 7z stream, and verifies plain, encrypted, warning,
missing-volume, cleanup, and timing behavior. It never executes an archive EXE.
The extra temporary file requires free space roughly equal to the archive payload;
the original SFXV volumes are never modified or deleted.
The integration harness also executes the source-extracted zipx task and password
resolver with real 7-Zip; UI/finalization are replaced by pass-through seams.
It checks one merged path across password retries, cancel/exception cleanup,
nested ownership restoration, locked input, unavailable space (overridden space
query), and short writes (source-extracted merge with a short-writing file wrapper).
Preparation timing is logged separately as `prepare`. The full total is 805.

`RunCmdCapture` collects raw pipe bytes and decodes once after exit and draining, so
UTF-8 characters split across writes cannot corrupt archive entry names. The capture
suite emits each byte of a Chinese character separately with a delay. CRC reads explicitly
seek to byte zero after FileOpen's BOM detection; real UTF-8/UTF-16 BOM fixtures prove
that the BOM is part of the checksum, not skipped as text encoding metadata.

### Extraction verdict and output integrity

`7z.exe` and `7zG.exe` do not share an exit-code contract: for an archive carrying trailing
bytes, the console reports `0` plus a warning while the GUI front-end reports `2` — and the GUI
also returns `2` for genuinely corrupt and for cancelled extractions. `ExtractionVerdict` is
therefore the only place a status is chosen, and it is exercised directly by the labels
`verdict_*` in `Sfxv.Integration.Tests.ps1`: a user break stays `CANCELLED` and any hard result
from the source test wins. Promotion is pinned to the one ambiguity that was measured, so it
needs the GUI front-end **and** exit `2` **and** proven output: a console `2`, and codes `1`,
`3`, `4`, `7`, `8`, `-1` or any other, stay `UNKNOWN_ERROR` even when `outputVerified=true`,
because nothing about them was measured as recoverable. `usedGui` comes from the same
`hideRunSize` comparison that chose the executable, never from a guess.

`VerifyExtractedOutput` compares every non-directory item of `7z l -slt` against the file that
was actually written, by size and by CRC-32 (`ntdll!RtlComputeCrc32`, streaming). Expected and
written files are compared **as sets**, so one missing plus one extra cannot cancel out. It
refuses to claim anything when an item is missing, renamed, unexpected, or a nonempty file
is listed without a checksum. A checksum-less empty file must exist as a regular file with
exactly zero bytes. A CRC or read exception ends verification as a conservative failure rather than
an error escaping into the caller's failure isolation. Because that costs a full read of the
output, it runs only when an exit code is ambiguous, and it is skipped entirely when
`excludeArgs` or `codePage` could change the expected file set.

The listing is another process's output, so it is proved before it is believed (`oracle_*`):
its exit code must be `0` (a failing process that printed usable-looking rows still refuses),
the header must name the archive that was queried, the `----------` separator must be there to
tell the header from the entries, and every entry must carry a size, attributes and - for
nonempty files - a checksum, with no repeated entry (including case/separator collisions) and
no truncated tail. Size must be an integer, not a coerced fractional zero. Entry paths must be safe
relative paths: absolute, UNC, device, stream and `..` shapes are refused, the resolved target
must sit inside the output directory behind a directory boundary, and a reparse point aborts
verification rather than reading a file the extraction never wrote. This includes the output
root and its ancestors, checked before content reads. This assumes a stable tree; it is not
an atomic defense against concurrent hostile filesystem changes. Enumeration refuses
duplicate case-folded output keys instead of silently merging them. Its regression pre-seeds
the first key and enumerates a real file; a full case-sensitive NTFS fixture requires privileges
not available in the current test environment.
A promoted run is still not a clean success: `isCleanSuccess` and `mayDeleteSource` stay false.

Evidence stays per process. `result.output` holds the extract stage's own text, while the
follow-up source test is reported as `verify (source test) exitCode=` /
`verify (source test) output:` plus an `outputCheck=` line, so an extract exit code can never be
read next to another run's `Everything is Ok`.

### Real 7zG extraction contract

`tests/GuiExtraction.Tests.ps1` drives the executables themselves - the same
`x "<archive>" -aou -o"<dir>"` shape `Run7z` builds - and reads their **own** exit codes:
nothing is injected. `tests/GuiDismissDriver.ahk` is the only thing that touches those
windows, and only ones belonging to the process id the suite passes it, so a 7-Zip window the
user opened is never touched. It walks the top-level Z-order outward because 7-Zip keeps its
progress dialog open underneath the box that follows, and `GetParent` reports that owner for a
dialog. Measured there, on 7-Zip 26.02 ZS:

* a clean archive exits `0` by itself, with every output file hashing to the original;
* trailing data exits `2` after the dialog is acknowledged, with the output complete;
* the same archive on `7z.exe` exits `0` with identical output - the two sides of
  `hideRunSize`, which is why the ambiguous code has to be resolved by what was written;
* corrupted content exits `2` and leaves output that does not verify;
* an unwritable output path exits non-zero and writes nothing complete;
* a mid-run cancel request exits non-zero and leaves output that is demonstrably partial.

Cancel needs its own note, because the reachable gestures are not what one would assume:
Escape, `WM_CLOSE` and a click on the default control (id 2) leave a running extraction
untouched, and the first owner-drawn button (id 444) only pauses it. The second button (id
446) cancels, but only for a non-solid archive - inside a solid block 7-Zip can stop at a file
boundary, so the fixture is built with `-ms=off`. The driver therefore presses the dialog's
buttons in turn and records which one answered in its marker, which the suite prints on
failure. A cancel is asserted as bytes on disk strictly between zero and the full set, never
as a substituted exit code.

### Harness result completeness

The GUI suite tracks retained Process objects for its own extraction and driver processes.
It keeps a separate stdin-blocked 7z sentinel alive to prove unrelated jobs are ignored, and
proves the detector reports that same sentinel when explicitly passed as an owned process.
No broad name/time-window process scan is used to judge leaks.

Every label the AHK harness writes is listed once in `$expectedLabels` inside
`Sfxv.Integration.Tests.ps1`. That set is authored by hand from the `Check` calls and is
never derived from `results.txt`, and registration is unconditional. A missing, duplicated,
unknown, truncated or non-`PASS` line therefore fails both
`reports each expected label once and only PASS` and that label's own test, instead of
quietly lowering the number of registered tests. Adding a `Check` requires adding its
label to `$expectedLabels`. `tests/SfxvResultHelper.ps1` holds the checker and is covered
by `Sfxv.ResultContract.Tests.ps1`.

The suite restores `SMARTZIP_SFXV_PASSWORD` to whatever the parent process had (and
removes it only when it had been absent), and a timeout terminates just the runner process
it started. The runner is launched with `[Diagnostics.Process]`, because `Start-Process
-PassThru` does not reliably expose `ExitCode` under Windows PowerShell 5.1, which would
otherwise compare the crash gate against an empty value.

### SFXV input lifecycle contract

`SfxvInput` separates three states: `taskActive` (the owning task still accepts borrows),
`closed` (a successful temporary file is no longer borrowable) and `cleanupComplete` (the
file and directory that instance owns are gone). A preparation that already failed stays
terminal for the task and is reused without a second scan or merge; the next task retries.
`Close()` stops borrowing first, deletes only the owned `archive.7z`, then removes the
directory **non-recursively**, so a file the task did not create is preserved.
`SfxvTaskScope.Close()` restores the previous owner before retrying cleanup at most three
times with 50 ms between attempts (about 100 ms of extra waiting in the worst case), and a
retry never re-merges. A cleanup that still fails keeps its path and is reported through the
existing redacted log when `logLevel` allows it. Residual temporary files remain possible
while another process holds the merge, so this suite does not claim zero residue in every
case.

PowerShell 5.1 decodes a `.ps1` without a byte-order mark using the system ANSI codepage,
so any suite containing non-ASCII literals must be saved as UTF-8 **with BOM**; otherwise
its own search strings stop matching the sources they slice.

| File | Role |
|---|---|
| `New-ExtractionReliabilityFixtures.ps1` | Deterministic fixtures via real `7z.exe`; process-only `SMARTZIP_FIXTURE_PASSWORD` |
| `Invoke-CompiledSmartZipScenario.ps1` | Isolated TEMP scenario runner (120s cap, owned-PID cleanup) |
| `IntegrationTestHook.ahk` | Test-only callbacks: result JSON, GUI suppress, password dialog |
| `Real7Zip.Integration.Tests.ps1` | 36 integration assertions (including output-state fixtures and 2 TEMP-injection contracts) |
| `SfxvResultHelper.ps1` | Test-only `Assert-SfxvResults` / `Get-SfxvResultMap`, shared by the two SFXV suites |
| `Sfxv.ResultContract.Tests.ps1` | 10 assertions that the result checker itself cannot pass a bad batch |
| `Invoke-ProductionSmartZipSmoke.ps1` | Hook-free production smoke (valid / crcPartial / splitMissing / encryptedHeader) |
| `ProductionSmokeUI.ahk` | Hook-free UI driver (closes warning/incomplete dialogs only) |
| `GuiDismissDriver.ahk` | Window driver for the real-7zG suite: posts only to the pid it is given |
| `GuiExtraction.Tests.ps1` | 7 assertions on the real `7zG.exe` / `7z.exe` contract, with output checked by hash |

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
