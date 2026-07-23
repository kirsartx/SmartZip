; Optional compile-time include for TEMP integration builds only.
; Production staging excludes the tests/ directory, so this file is never present there.
; When this file is included, all three callbacks are defined (IsSet == true).
;
; SuppressGui must be a function (not a bare variable): class methods see global
; functions via IsSet/call, but a free global variable is invisible inside methods,
; so `IsSet(SmartZipTest_SuppressGui) && SmartZipTest_SuppressGui` would fail open
; and leave the diagnostic GUI blocking WaitForExit.

SmartZipTest_SuppressGui(*) {
    return true
}

SmartZipTest_PasswordDialog(path) {
    mode := EnvGet("SMARTZIP_TEST_PASSWORD_MODE")
    if (mode = "" || mode = "none" || mode = "correctSaved")
        throw Error("SmartZipTest_PasswordDialog must not be called in mode=" mode " path=" path)
    if (mode = "wrongDialog") {
        wrong := EnvGet("SMARTZIP_FIXTURE_WRONG_PASSWORD")
        if (wrong = "")
            throw Error("SMARTZIP_FIXTURE_WRONG_PASSWORD empty for wrongDialog")
        return { action: "use", password: wrong }
    }
    if (mode = "dialogCancel")
        return { action: "cancel", password: "" }
    throw Error("unknown SMARTZIP_TEST_PASSWORD_MODE=" mode)
}

SmartZipTest_OnResult(result) {
    outPath := EnvGet("SMARTZIP_TEST_RESULT_PATH")
    if (outPath = "")
        return
    ; Redacted JSON: omit passwordUsed; redact output/warning/error; marker present.
    status := result.status
    stage := result.stage
    exitCode := result.exitCode
    mayDelete := result.mayDeleteSource ? "true" : "false"
    isClean := result.isCleanSuccess ? "true" : "false"
    partial := ""
    if result.HasOwnProp("partialOutputDir")
        partial := result.partialOutputDir
    archivePath := result.archivePath
    SplitPath(archivePath, &baseName)

    redOutput := RedactDiagnostic(result.output, false)
    warnJoined := ""
    for w in result.warningLines {
        if (warnJoined != "")
            warnJoined .= " | "
        warnJoined .= RedactDiagnostic(w, false)
    }
    errJoined := ""
    for e in result.errorLines {
        if (errJoined != "")
            errJoined .= " | "
        errJoined .= RedactDiagnostic(e, false)
    }

    esc(s) {
        t := String(s)
        t := StrReplace(t, "\", "\\")
        t := StrReplace(t, '"', '\"')
        t := StrReplace(t, "`r", "\r")
        t := StrReplace(t, "`n", "\n")
        t := StrReplace(t, "`t", "\t")
        return t
    }

    json := "{"
        . '"marker":"SMARTZIP_TEST_RESULT_V1",'
        . '"status":"' esc(status) '",'
        . '"stage":"' esc(stage) '",'
        . '"exitCode":' exitCode ','
        . '"isCleanSuccess":' isClean ','
        . '"mayDeleteSource":' mayDelete ','
        . '"archiveBaseName":"' esc(baseName) '",'
        . '"partialOutputDir":"' esc(partial) '",'
        . '"warning":"' esc(warnJoined) '",'
        . '"error":"' esc(errJoined) '",'
        . '"output":"' esc(SubStr(redOutput, 1, 2048)) '"'
        . "}"
    try FileDelete(outPath)
    FileAppend(json, outPath, "UTF-8")
}
