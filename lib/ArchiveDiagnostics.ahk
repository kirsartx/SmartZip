; Pure archive diagnostics for SmartZip (compile-time include only).
; No UI, no process launch, no file I/O side effects.
#Requires AutoHotkey v2.0

class ArchiveStatus {
    static OK := "OK"
    static OK_WITH_WARNING := "OK_WITH_WARNING"
    static NEED_PASSWORD := "NEED_PASSWORD"
    static WRONG_PASSWORD := "WRONG_PASSWORD"
    static MISSING_VOLUME := "MISSING_VOLUME"
    static NOT_ARCHIVE := "NOT_ARCHIVE"
    static UNSUPPORTED_METHOD := "UNSUPPORTED_METHOD"
    static HEADER_CORRUPT := "HEADER_CORRUPT"
    static TRUNCATED := "TRUNCATED"
    static DATA_CORRUPT := "DATA_CORRUPT"
    static CANCELLED := "CANCELLED"
    static IO_ERROR := "IO_ERROR"
    static UNKNOWN_ERROR := "UNKNOWN_ERROR"
}

class ArchiveResult {
    __New(status, stage, exitCode := -1, archivePath := "", output := "") {
        this.status := status
        this.stage := stage
        this.exitCode := exitCode
        this.archivePath := archivePath
        this.archiveType := ""
        this.passwordUsed := ""
        this.volumeFirst := ""
        this.missingVolumes := []
        this.warningLines := []
        this.errorLines := []
        this.tempOutputDir := ""
        this.partialOutputDir := ""
        this.isCleanSuccess := (status = ArchiveStatus.OK)
        this.mayDeleteSource := (status = ArchiveStatus.OK)
        this.output := output
    }
}

Classify7zResult(stage, exitCode, output, archivePath := "") {
    result := ArchiveResult(ArchiveStatus.UNKNOWN_ERROR, stage, exitCode, archivePath, output)
    text := output = "" ? "" : String(output)
    lines := StrSplit(text, "`n", "`r")

    hasCancelled := (exitCode = 255)
    hasMissingVolume := false
    hasNeedPassword := false
    hasWrongPassword := false
    hasUnsupported := false
    hasTruncated := false
    hasHeaderCorrupt := false
    hasDataCorrupt := false
    hasNotArchive := false
    hasIoError := false
    hasWarning := false

    for line in lines {
        trimmed := Trim(line)
        if (trimmed = "")
            continue

        if RegExMatch(trimmed, "i)^Type\s*=\s*(.+)$", &typeMatch)
            result.archiveType := Trim(typeMatch[1])

        isWarn := false
        isErr := false

        if (trimmed ~= "i)Wrong password\?" || InStr(trimmed, "Cannot open encrypted archive")) {
            hasWrongPassword := true
            isErr := true
        }
        if (trimmed ~= "i)Cannot find volume" || trimmed ~= "i)Missing volume" || trimmed ~= "i)Cannot open volume" || trimmed ~= "i)Broken volume") {
            hasMissingVolume := true
            isErr := true
            if RegExMatch(trimmed, 'i)(?:Cannot find|Missing|Cannot open|Broken) volume(?:\s*:)?\s*(.+)$', &volumeMatch) {
                missingName := Trim(volumeMatch[1], ' "`t')
                if (missingName != "")
                    result.missingVolumes.Push(missingName)
            }
        }
        if (InStr(trimmed, "Enter password (will not be echoed):")) {
            hasNeedPassword := true
            isErr := true
        }
        if (trimmed ~= "i)Unsupported Method" || trimmed ~= "i)Unsupported method" || trimmed ~= "i)Method is not supported") {
            hasUnsupported := true
            isErr := true
        }
        if (InStr(trimmed, "Unexpected end of archive") || InStr(trimmed, "Unexpected end of data")) {
            hasTruncated := true
            isErr := true
        }
        if (InStr(trimmed, "Headers Error")) {
            hasHeaderCorrupt := true
            isErr := true
        }
        if (InStr(trimmed, "CRC Failed") || InStr(trimmed, "Data Error")) {
            hasDataCorrupt := true
            isErr := true
        }
        if (InStr(trimmed, "Cannot open the file as archive") || InStr(trimmed, "Can not open the file as archive")) {
            hasNotArchive := true
            isErr := true
        }
        if (trimmed ~= "i)Access is denied" || trimmed ~= "i)not enough space" || trimmed ~= "i)The system cannot find the path" || trimmed ~= "i)The network path was not found" || trimmed ~= "i)Can not open output file" || trimmed ~= "i)Cannot create output directory") {
            hasIoError := true
            isErr := true
        }
        if (trimmed ~= "i)^Warnings?:\s*[1-9]" || InStr(trimmed, "There are data after the end of archive") || InStr(trimmed, "WARNINGS:")) {
            hasWarning := true
            isWarn := true
        }
        if (InStr(trimmed, "Everything is Ok") = 0 && (InStr(trimmed, "ERROR:") = 1 || InStr(trimmed, "ERROR: ") || trimmed ~= "i)^Error:")) {
            isErr := true
        }

        if (isErr)
            result.errorLines.Push(trimmed)
        else if (isWarn)
            result.warningLines.Push(trimmed)
        else if (InStr(trimmed, "There are data after the end of archive"))
            result.warningLines.Push(trimmed)
    }

    ; Priority ladder (spec §4.2)
    if (hasCancelled) {
        result.status := ArchiveStatus.CANCELLED
    } else if (hasMissingVolume) {
        result.status := ArchiveStatus.MISSING_VOLUME
    } else if (hasNeedPassword) {
        result.status := ArchiveStatus.NEED_PASSWORD
    } else if (hasWrongPassword) {
        result.status := ArchiveStatus.WRONG_PASSWORD
    } else if (hasUnsupported) {
        result.status := ArchiveStatus.UNSUPPORTED_METHOD
    } else if (hasTruncated) {
        result.status := ArchiveStatus.TRUNCATED
    } else if (hasHeaderCorrupt) {
        result.status := ArchiveStatus.HEADER_CORRUPT
    } else if (hasDataCorrupt) {
        result.status := ArchiveStatus.DATA_CORRUPT
    } else if (hasNotArchive) {
        result.status := ArchiveStatus.NOT_ARCHIVE
    } else if (exitCode = 0 && (hasWarning || result.warningLines.Length > 0)) {
        result.status := ArchiveStatus.OK_WITH_WARNING
    } else if (exitCode = 0) {
        result.status := ArchiveStatus.OK
    } else if (hasIoError) {
        result.status := ArchiveStatus.IO_ERROR
    } else {
        result.status := ArchiveStatus.UNKNOWN_ERROR
    }

    result.isCleanSuccess := (result.status = ArchiveStatus.OK)
    result.mayDeleteSource := (result.status = ArchiveStatus.OK)
    result.passwordUsed := ""
    return result
}

RedactDiagnostic(text, includeFullPath := true) {
    s := text = "" ? "" : String(text)
    ; Quoted -p"..." and -p'...'
    s := RegExReplace(s, "i)(-p)([" Chr(34) "'])([^" Chr(34) "']*)\2", "$1***")
    ; Unquoted -pVALUE (stop at whitespace)
    s := RegExReplace(s, 'i)(-p)(?!\*\*\*)(\S+)', "$1***")
    if (!includeFullPath) {
        ; Replace Windows paths with leaf names only
        s := RegExReplace(s, 'i)([a-z]:\\(?:[^\\/:*?"<>|\r\n]+\\)*)([^\\/:*?"<>|\r\n]+)', "$2")
        s := RegExReplace(s, '(\\\\(?:[^\\/:*?"<>|\r\n]+\\)*)([^\\/:*?"<>|\r\n]+)', "$2")
    }
    return s
}
