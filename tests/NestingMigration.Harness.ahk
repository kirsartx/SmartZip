#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\lib\ArchiveDiagnostics.ahk

outPath := A_Args.Length >= 1 ? A_Args[1] : A_Temp "\NestingMigration.out.txt"
passCount := 0
failCount := 0
lines := []

AssertEq(actual, expected, name) {
    global passCount, failCount, lines
    a := String(actual), e := String(expected)
    if (a = e) {
        passCount++
        lines.Push("PASS " name)
    } else {
        failCount++
        lines.Push("FAIL " name " expected=[" e "] actual=[" a "]")
    }
}

AssertTrue(cond, name) => AssertEq(cond ? "1" : "0", "1", name)
AssertFalse(cond, name) => AssertEq(cond ? "1" : "0", "0", name)

; Mirrors product IsArchive (Task 6)
IsArchiveExt(ext, extMap, extExp) {
    ext := StrLower(ext)
    if !ext
        return false
    if extMap.Has(ext)
        return true
    for i in extExp
        if ext ~= "i)" i
            return true
    return false
}

IsNestedArchiveCandidate(path, ext, extMap, extExp, siblingNames) {
    if IsArchiveExt(ext, extMap, extExp)
        return true
    g := DetectVolumeGroup(path, siblingNames)
    return g.isVolume
}

; Migration: remove only case-sensitive exact lowercase zi / 7 / z
MigrateDeprecatedExtExp(rules) {
    out := []
    for r in rules {
        if (r == "zi" || r == "7" || r == "z")
            continue
        out.Push(r)
    }
    return out
}

; Nested source action (product: Task 5 zipx + Task 6 guards)
NestedSourceAction(status, isNested, isVolumeMember) {
    if (!isNested || isVolumeMember)
        return "none"
    if (status = ArchiveStatus.OK)
        return "recycle_nested"
    return "none"
}

; test=0 still forces TestArchive before source handling
ShouldForceTestArchive(testFlag, mayHandleSource, nestedMayRecycle := false) {
    return (testFlag ? true : false) || (mayHandleSource ? true : false)
        || (nestedMayRecycle ? true : false)
}

ShouldEnterNestedAfterProbe(status) {
    return status = ArchiveStatus.OK
        || status = ArchiveStatus.OK_WITH_WARNING
        || status = ArchiveStatus.NEED_PASSWORD
        || status = ArchiveStatus.WRONG_PASSWORD
}

extMap := Map("zip", true, "7z", true, "rar", true, "001", true)
extExp := ["^\d+$", "zi", "7", "z", "ZI", "custom$"]

; 1) empty extension is not archive / not auto candidate
AssertFalse(IsArchiveExt("", extMap, extExp), "empty_ext_not_archive")
AssertFalse(IsNestedArchiveCandidate("C:\\t\\file", "", extMap, extExp, ["file"]), "empty_ext_not_candidate")

; 2) exact configured extension is candidate hint
AssertTrue(IsArchiveExt("zip", extMap, extExp), "exact_zip_is_candidate")
AssertTrue(IsArchiveExt("7Z", extMap, extExp), "exact_7z_casefold_candidate")

; 3) custom regex is candidate hint only (still just nomination)
AssertTrue(IsArchiveExt("123", extMap, extExp), "digit_regex_candidate")
AssertTrue(IsArchiveExt("mycustom", extMap, ["custom$"]), "custom_regex_candidate")
AssertFalse(IsArchiveExt("nope", extMap, ["custom$"]), "custom_regex_non_match")

; 4) volume pattern is candidate even when ext not in map
sibs := ["pack.7z.001", "pack.7z.002"]
AssertTrue(IsNestedArchiveCandidate("C:\\v\\pack.7z.001", "001", Map(), [], sibs), "volume_pattern_candidate")
g := DetectVolumeGroup("C:\\v\\pack.7z.001", sibs)
AssertTrue(g.isVolume, "volume_detect_is_volume")
AssertTrue(g.selectedIsFirst, "volume_detect_first")

; 5) migration removes only zi, 7, z
migrated := MigrateDeprecatedExtExp(extExp)
AssertEq(migrated.Length, 3, "migrate_count_three_kept")
AssertEq(migrated[1], "^\d+$", "migrate_keeps_digit_regex")
AssertTrue(migrated[2] == "ZI" && migrated[3] == "custom$", "migrate_keeps_other_custom")
for r in migrated {
    AssertFalse(r == "zi", "migrate_no_zi")
    AssertFalse(r == "7", "migrate_no_7")
    AssertFalse(r == "z", "migrate_no_z")
}

; 6) migration preserves order of non-matching rules and leaves unrelated alone
onlyCustom := MigrateDeprecatedExtExp(["foo", "zi", "bar", "7", "z", "baz"])
AssertEq(onlyCustom.Length, 3, "migrate_preserves_three_customs")
AssertEq(onlyCustom[1], "foo", "migrate_order_foo")
AssertEq(onlyCustom[2], "bar", "migrate_order_bar")
AssertEq(onlyCustom[3], "baz", "migrate_order_baz")

; 7) nested source recycle only for nested OK; never permanent, warn/fail, or volumes
AssertEq(NestedSourceAction(ArchiveStatus.OK, true, false), "recycle_nested", "nested_ok_recycles")
AssertEq(NestedSourceAction(ArchiveStatus.OK_WITH_WARNING, true, false), "none", "nested_warn_preserves")
AssertEq(NestedSourceAction(ArchiveStatus.DATA_CORRUPT, true, false), "none", "nested_fail_preserves")
AssertEq(NestedSourceAction(ArchiveStatus.OK, true, true), "none", "nested_volume_never_deletes")
AssertEq(NestedSourceAction(ArchiveStatus.OK, false, false), "none", "top_level_not_nested_delete_here")

; 8) test flag vs source-handling force
AssertTrue(ShouldForceTestArchive(1, false), "test1_always_forces_test")
AssertTrue(ShouldForceTestArchive(0, true), "test0_forces_test_before_source_handle")
AssertTrue(ShouldForceTestArchive(0, false, true)
    && !ShouldForceTestArchive(0, false, false), "test0_nested_forces_and_nohandle_skips")

; 9) Candidate hint is not authority: product fragment must additionally prove call order.
AssertTrue(ShouldEnterNestedAfterProbe(ArchiveStatus.OK)
    && ShouldEnterNestedAfterProbe(ArchiveStatus.NEED_PASSWORD)
    && !ShouldEnterNestedAfterProbe(ArchiveStatus.NOT_ARCHIVE)
    && !ShouldEnterNestedAfterProbe(ArchiveStatus.HEADER_CORRUPT),
    "nested_requires_probe_stage_before_extract")

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
