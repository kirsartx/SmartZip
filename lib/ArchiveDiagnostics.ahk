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

DetectVolumeGroup(path, siblingNames) {
    empty := { isVolume: false, firstPath: "", members: [], missingVolumes: [], selectedIsFirst: false }
    if (path = "")
        return empty

    SplitPath(path, &selName, &dir)
    if (selName = "")
        return empty

    names := []
    if (siblingNames is Array) {
        for n in siblingNames {
            if (n != "")
                names.Push(String(n))
        }
    }
    nameSet := Map()
    for n in names
        nameSet[StrLower(n)] := n

    sel := selName
    selLower := StrLower(sel)

    ; Pattern A: name.partNN.rar
    if (RegExMatch(sel, "i)^(.+)\.part(\d+)\.rar$", &mPart)) {
        base := mPart[1]
        width := StrLen(mPart[2])
        selIndex := Integer(mPart[2])
        if (selIndex < 1)
            return empty
        firstName := base ".part" Format("{:0" width "}", 1) ".rar"
        indices := []
        indexToName := Map()
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.part(\d+)\.rar$", &mm) && StrLen(mm[1]) = width) {
                idx := Integer(mm[1])
                if (idx >= 1) {
                    indices.Push(idx)
                    indexToName[idx] := n
                }
            }
        }
        if (!indexToName.Has(selIndex)) {
            indices.Push(selIndex)
        }
        return _VolBuildNumericGroup(dir, firstName, sel, selIndex, 1, indices, indexToName)
    }

    ; Pattern B: name.rNN (old-style RAR volumes; base is name.rar)
    if (RegExMatch(sel, "i)^(.+)\.r(\d+)$", &mR) && !(selLower ~= "i)\.rar$")) {
        base := mR[1]
        width := StrLen(mR[2])
        if (width != 2)
            return empty
        selIndex := Integer(mR[2]) + 1  ; r00 => index 1 (second volume); rar base is index 0
        firstName := base ".rar"
        indices := []
        indexToName := Map()
        if (nameSet.Has(StrLower(firstName))) {
            indices.Push(0)
            indexToName[0] := nameSet[StrLower(firstName)]
        } else {
            ; still record expected first even if missing
        }
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm) && StrLen(mm[1]) = width) {
                idx := Integer(mm[1]) + 1
                indices.Push(idx)
                indexToName[idx] := n
            }
        }
        if (!indexToName.Has(selIndex)) {
            indices.Push(selIndex)
        }
        ; selectedIsFirst is never true for .rNN
        members := []
        missing := []
        maxIndex := selIndex
        for idx in indices
            if (idx > maxIndex)
                maxIndex := idx
        if ((maxIndex - 0 + 1) <= _VolMaxDerivationSpan()) {
            if (!nameSet.Has(StrLower(firstName)))
                missing.Push(firstName)
            idx := 1
            while (idx <= maxIndex) {
                if !indexToName.Has(idx)
                    missing.Push(base ".r" Format("{:0" width "}", idx - 1))
                idx++
            }
        }
        ; present members sorted: base (0) then r00,r01,...
        if (indexToName.Has(0))
            members.Push(dir "\" indexToName[0])
        sortedExtra := []
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm))
                sortedExtra.Push([Integer(mm[1]), n])
        }
        ; sort by r-number ascending (simple insertion)
        i := 1
        while (i <= sortedExtra.Length) {
            j := i
            while (j > 1 && sortedExtra[j][1] < sortedExtra[j - 1][1]) {
                tmp := sortedExtra[j - 1]
                sortedExtra[j - 1] := sortedExtra[j]
                sortedExtra[j] := tmp
                j--
            }
            i++
        }
        for pair in sortedExtra
            members.Push(dir "\" pair[2])
        return {
            isVolume: true,
            firstPath: dir "\" (nameSet.Has(StrLower(firstName)) ? nameSet[StrLower(firstName)] : firstName),
            members: members,
            missingVolumes: missing,
            selectedIsFirst: false
        }
    }

    ; Pattern C: name.rar that has sibling name.r00 or is alone but we only mark volume if rXX siblings exist
    if (RegExMatch(sel, "i)^(.+)\.rar$", &mBase) && !(selLower ~= "i)\.part\d+\.rar$")) {
        base := mBase[1]
        hasR := false
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm) && StrLen(mm[1]) = 2) {
                hasR := true
                break
            }
        }
        if (hasR) {
            firstName := base ".rar"
            members := []
            if (nameSet.Has(StrLower(firstName)))
                members.Push(dir "\" nameSet[StrLower(firstName)])
            sortedExtra := []
            for n in names {
                if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm) && StrLen(mm[1]) = 2)
                    sortedExtra.Push([Integer(mm[1]), n])
            }
            i := 1
            while (i <= sortedExtra.Length) {
                j := i
                while (j > 1 && sortedExtra[j][1] < sortedExtra[j - 1][1]) {
                    tmp := sortedExtra[j - 1]
                    sortedExtra[j - 1] := sortedExtra[j]
                    sortedExtra[j] := tmp
                    j--
                }
                i++
            }
            maxR := -1
            for pair in sortedExtra {
                members.Push(dir "\" pair[2])
                if (pair[1] > maxR)
                    maxR := pair[1]
            }
            missing := []
            if ((maxR + 2) <= _VolMaxDerivationSpan()) {
                if (!nameSet.Has(StrLower(firstName)))
                    missing.Push(firstName)
                r := 0
                while (r <= maxR) {
                    rn := base ".r" Format("{:02}", r)
                    if (!nameSet.Has(StrLower(rn)))
                        missing.Push(rn)
                    r++
                }
            }
            return {
                isVolume: true,
                firstPath: dir "\" (nameSet.Has(StrLower(firstName)) ? nameSet[StrLower(firstName)] : firstName),
                members: members,
                missingVolumes: missing,
                selectedIsFirst: true
            }
        }
    }

    ; Pattern D: name.ext.NNN  (e.g. .7z.001, .zip.001) OR bare name.NNN (name.001)
    if (RegExMatch(sel, "i)^(.+)\.(\d+)$", &mNum)) {
        stem := mNum[1]          ; may include .7z / .zip or plain stem
        digits := mNum[2]
        width := StrLen(digits)
        selIndex := Integer(digits)
        if (selIndex < 1)
            return empty
        firstName := stem "." Format("{:0" width "}", 1)
        indices := []
        indexToName := Map()
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(stem) "\.(\d+)$", &mm) && StrLen(mm[1]) = width) {
                idx := Integer(mm[1])
                if (idx >= 1) {
                    indices.Push(idx)
                    indexToName[idx] := n
                }
            }
        }
        if (!indexToName.Has(selIndex)) {
            indices.Push(selIndex)
        }
        return _VolBuildNumericGroup(dir, firstName, sel, selIndex, 1, indices, indexToName)
    }

    return empty
}

_VolEscape(s) {
    out := ""
    Loop Parse s {
        ch := A_LoopField
        if (InStr("\.\+\*\?\[\]\(\)\{\}\^\$\|", ch))
            out .= "\" ch
        else
            out .= ch
    }
    return out
}

_VolMaxDerivationSpan() {
    ; Safe bound: never allocate a missing-volume list for more than 4096 indices.
    return 4096
}

_VolBuildNumericGroup(dir, firstName, selName, selIndex, firstIndex, indices, indexToName) {
    ; unique sort indices
    uniq := []
    seen := Map()
    for idx in indices {
        if (!seen.Has(idx)) {
            seen[idx] := true
            uniq.Push(idx)
        }
    }
    i := 1
    while (i <= uniq.Length) {
        j := i
        while (j > 1 && uniq[j] < uniq[j - 1]) {
            tmp := uniq[j - 1]
            uniq[j - 1] := uniq[j]
            uniq[j] := tmp
            j--
        }
        i++
    }

    maxIndex := uniq.Length ? uniq[uniq.Length] : selIndex
    if (selIndex > maxIndex)
        maxIndex := selIndex

    width := 0
    partSuffix := ""
    if (RegExMatch(firstName, "i)^(.+\.part)(\d+)(\.rar)$", &mp)) {
        stem := mp[1]
        width := StrLen(mp[2])
        partSuffix := mp[3]
    } else if (RegExMatch(firstName, "\.(\d+)$", &mw)) {
        width := StrLen(mw[1])
    }
    if (width = 0)
        width := 3

    if (partSuffix = "") {
        stem := ""
        if (RegExMatch(firstName, "i)^(.+)\.(\d+)$", &ms))
            stem := ms[1]
    }

    members := []
    missing := []
    firstOutputName := indexToName.Has(firstIndex) ? indexToName[firstIndex] : firstName
    if ((maxIndex - firstIndex + 1) > _VolMaxDerivationSpan()) {
        for idx in uniq {
            if (indexToName.Has(idx))
                members.Push(dir "\" indexToName[idx])
        }
        return {
            isVolume: true,
            firstPath: dir "\" firstOutputName,
            members: members,
            missingVolumes: missing,
            selectedIsFirst: (selIndex = firstIndex)
        }
    }
    idx := firstIndex
    while (idx <= maxIndex) {
        nm := stem (partSuffix = "" ? "." : "") Format("{:0" width "}", idx) partSuffix
        if (indexToName.Has(idx)) {
            members.Push(dir "\" indexToName[idx])
        } else {
            missing.Push(nm)
        }
        idx++
    }

    return {
        isVolume: true,
        firstPath: dir "\" firstOutputName,
        members: members,
        missingVolumes: missing,
        selectedIsFirst: (selIndex = firstIndex)
    }
}
