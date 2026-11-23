; Archive diagnostics and explicitly scoped split-input I/O for SmartZip.
; Including this file has no side effects; no archive executable is ever launched.
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
        ; Evidence from the follow-up source test belongs to that process, not to the
        ; extract process, so it is kept in fields of its own.
        this.verifyExitCode := -1
        this.verifyOutput := ""
        this.outputCheck := ""
        this.outputState := "none"
        this.passwordRetryEligible := false
        this.encryptionEvidence := false
        this.retainedOutputDir := ""
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

        ; These announcements echo a path, not a diagnostic verdict.
        if RegExMatch(trimmed, "i)^(Listing|Testing|Extracting) archive: ")
            continue

        if RegExMatch(trimmed, "i)^Type\s*=\s*(.+)$", &typeMatch)
            result.archiveType := Trim(typeMatch[1])

        ; Technical records are data, including archive/entry names and comments.
        ; Match diagnostics on messages, not phrases embedded in field values.
        ; ERROR/WARNING properties are real diagnostics in 7-Zip's listing format.
        if (RegExMatch(trimmed, "^([A-Za-z][A-Za-z0-9 ]*) = ", &fieldMatch)
            && !(Trim(fieldMatch[1]) ~= "i)^(Errors?(?: Type)?|Warnings?)$")) {
            if (stage = "probe" && trimmed ~= "i)^Encrypted\s*=\s*\+") {
                hasNeedPassword := true
                result.encryptionEvidence := true
            }
            continue
        }

        isWarn := false
        isErr := false

        ; Classic: "Wrong password?" ; 7-Zip ZS content-enc: "ERROR: Wrong password : file"
        if (trimmed ~= "i)Wrong password" || InStr(trimmed, "Cannot open encrypted archive")) {
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
        ; Keep accepting compact metadata from callers as well as standard -slt records.
        if (stage = "probe" && trimmed ~= "i)^Encrypted\s*=\s*\+") {
            hasNeedPassword := true
            result.encryptionEvidence := true
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
        if (trimmed ~= "i)in encrypted file") {
            result.encryptionEvidence := true
        }
        ; 7-Zip classic: "Cannot open the file as archive"
        ; 7-Zip ZS: "Cannot open the file as [7z] archive" / "Is not archive" / "Can't open as archive"
        if (InStr(trimmed, "Cannot open the file as archive") || InStr(trimmed, "Can not open the file as archive")
            || InStr(trimmed, "Is not archive") || InStr(trimmed, "Can't open as archive")
            || trimmed ~= "i)Cannot open the file as \[.+\] archive") {
            hasNotArchive := true
            isErr := true
        }
        if (trimmed ~= "i)Access is denied" || trimmed ~= "i)not enough space" || trimmed ~= "i)The system cannot find the path" || trimmed ~= "i)The network path was not found" || trimmed ~= "i)Can not open output file" || trimmed ~= "i)Cannot create output directory") {
            hasIoError := true
            isErr := true
        }
        if (trimmed ~= "i)^Warnings?:\s*[1-9]" || InStr(trimmed, "There are data after the end of archive") || trimmed == "WARNINGS:") {
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
    } else if (exitCode = 1 && (hasWarning || result.warningLines.Length > 0)
        && !hasMissingVolume && !hasNeedPassword && !hasWrongPassword
        && !hasUnsupported && !hasTruncated && !hasHeaderCorrupt
        && !hasDataCorrupt && !hasNotArchive && !hasIoError
        && result.errorLines.Length = 0) {
        ; Exit 1 warning success only with recognized warning evidence and no hard-error evidence
        result.status := ArchiveStatus.OK_WITH_WARNING
    } else if (hasIoError) {
        result.status := ArchiveStatus.IO_ERROR
    } else {
        result.status := ArchiveStatus.UNKNOWN_ERROR
    }

    result.isCleanSuccess := (result.status = ArchiveStatus.OK)
    result.mayDeleteSource := (result.status = ArchiveStatus.OK)
    result.passwordUsed := ""
    if (result.status = ArchiveStatus.DATA_CORRUPT && result.encryptionEvidence)
        result.passwordRetryEligible := true
    else
        result.passwordRetryEligible := false
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

_VolHasPatternDEvidence(stem, selIndex, indices) {
    if (stem ~= "i)\.(7z|zip|rar|tar|wim)$")
        return true
    if (selIndex = 1)
        return true
    for idx in indices {
        if (idx >= 1 && idx != selIndex)
            return true
    }
    return false
}

; A photo suffix is only a candidate when an archive signature starts at byte zero.
; 7-Zip still verifies the format; the signature alone says nothing about integrity.
IsPhotoArchiveCandidate(path, ext) {
    switch StrLower(ext) {
        case "png", "jpg", "jpeg":
        default:
            return false
    }

    file := ""
    try {
        file := FileOpen(path, "r")
        header := Buffer(8)
        file.Pos := 0  ; FileOpen may skip a text BOM; signatures must start at zero.
        count := file.RawRead(header)
    } catch OSError {
        return false
    } finally {
        if IsObject(file)
            file.Close()
    }

    if (count < 4)
        return false
    signature := NumGet(header, 0, "UInt")
    switch signature {
        case 0x04034B50, 0x06054B50, 0x06064B50:  ; ZIP local file or empty ZIP/ZIP64
            return true
        case 0xAFBC7A37:  ; 7z
            return count >= 6 && NumGet(header, 4, "UShort") = 0x1C27
        case 0x21726152:  ; RAR4 or RAR5
            return count >= 7 && NumGet(header, 4, "UShort") = 0x071A
                && (NumGet(header, 6, "UChar") = 0 || (count >= 8 && NumGet(header, 6, "UShort") = 1))
    }
    ; ZIP spanning markers also need a ZIP record immediately behind them.
    if (count = 8 && (signature = 0x30304B50 || signature = 0x08074B50)) {
        zipRecord := NumGet(header, 4, "UInt")
        return zipRecord = 0x04034B50 || zipRecord = 0x06054B50 || zipRecord = 0x06064B50
    }
    return false
}

; Conservative filename gate for every supported volume pattern. This is only a
; candidate check: numeric suffixes still need DetectVolumeGroup's evidence.
IsVolumeNameCandidate(path) {
    SplitPath(path, &name)
    return RegExMatch(name, "i)^.+\.(?:rar|r\d{2}|\d+|exe|\d{3}\.sfxv)$") != 0
}

DetectVolumeGroup(path, siblingNames) {
    empty := { isVolume: false, firstPath: "", members: [], missingVolumes: [], selectedIsFirst: false }
    if (path = "")
        return empty

    SplitPath(path, &selName, &dir)
    if (selName = "")
        return empty

    if !IsVolumeNameCandidate(selName)
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

    ; EXE is byte volume zero, .001.sfxv is byte volume one. Names are
    ; evidence only: continuous numbering does not prove the final piece exists.
    if RegExMatch(sel, "i)^(.+)\.(exe|\d{3}\.sfxv)$", &sx) {
        base := sx[1]
        selected := StrLower(sx[2]) = "exe" ? 0 : Integer(SubStr(sx[2], 1, 3))
        if (selected = 0 && StrLower(sx[2]) != "exe")
            return empty
        pieces := Map()
        maxPiece := selected
        for n in names {
            if RegExMatch(n, "i)^" _VolEscape(base) "\.([0-9]{3})\.sfxv$", &piece) {
                index := Integer(piece[1])
                if index > 0 {
                    pieces[index] := n
                    maxPiece := Max(maxPiece, index)
                }
            }
        }
        if (!selected && !pieces.Count)
            return empty
        first := base ".exe"
        members := [], missing := []
        if nameSet.Has(StrLower(first)) {
            first := nameSet[StrLower(first)]
            members.Push(dir "\" first)
        } else
            missing.Push(first)
        Loop maxPiece {
            if pieces.Has(A_Index)
                members.Push(dir "\" pieces[A_Index])
            else
                missing.Push(base "." Format("{:03}", A_Index) ".sfxv")
        }
        return {isVolume: true, kind: "sfxv", firstPath: dir "\" first,
            members: members, missingVolumes: missing, selectedIsFirst: selected = 0}
    }

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
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm) && StrLen(mm[1]) = width)
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
        if (!_VolHasPatternDEvidence(stem, selIndex, indices))
            return empty
        return _VolBuildNumericGroup(dir, firstName, sel, selIndex, 1, indices, indexToName)
    }

    return empty
}

; A .exe + .NNN.sfxv set is a byte-split self-extracting archive. 7-Zip does
; not support opening a 7z archive from stdin, so the SFX stub is removed into
; a temporary 7z file. Original pieces are never changed or removed.
AcquireSfxvInput(host, path) {
    if host.HasOwnProp("sfxvTaskInput") && SfxvInputMatches(host.sfxvTaskInput, path)
        return SfxvBorrowedInput(host.sfxvTaskInput)
    return SfxvInput(path)
}

SfxvInputMatches(input, path) {
    if (!IsObject(input) || !input.taskActive)
        return false
    if !(StrLower(path) = StrLower(input.originalPath)
        || (input.volumeFirst != "" && StrLower(path) = StrLower(input.volumeFirst)))
        return false
    ; A preparation that already failed is terminal for the task: its status is
    ; reused without another scan or merge. Only a successful input still has a
    ; temporary file, so only that one has to stay open to be borrowed.
    return input.status != "" || !input.closed
}

class SfxvBorrowedInput {
    __New(input) {
        for name in ["commandPath", "status", "volumeFirst", "missingVolumes"]
            this.%name% := input.%name%
    }
    Close() {
        ; The enclosing synchronous task owns the file.
    }
}

class SfxvTaskScope {
    __New(host, path) {
        this.host := host
        this.previous := host.HasOwnProp("sfxvTaskInput") ? host.sfxvTaskInput : ""
        this.hadPrevious := host.HasOwnProp("sfxvTaskInput")
        this.input := ""
        this.closed := false
        if !SfxvInputMatches(this.previous, path) && IsSfxvNameCandidate(path) {
            started := A_TickCount
            this.input := SfxvInput(path)
            ; The task, not the input's own cleanup state, decides how long the
            ; preparation result stays reusable.
            this.input.taskActive := true
            host.sfxvTaskInput := this.input
            if this.input.volumeFirst != ""
                WriteOperationTiming(host, "prepare", started)
        }
    }
    Close() {
        if this.closed
            return
        this.closed := true
        if IsObject(this.input) {
            this.input.taskActive := false
            if this.hadPrevious
                this.host.sfxvTaskInput := this.previous
            else
                this.host.DeleteProp("sfxvTaskInput")
            ; A temporary merge can stay open for a moment after 7-Zip exits.
            ; Retrying the delete never re-prepares the archive.
            Loop 3 {
                this.input.Close()
                if this.input.cleanupComplete
                    break
                if A_Index < 3
                    Sleep 50
            }
            if !this.input.cleanupComplete
                try this.host.Loging(RedactDiagnostic(
                    "SFXV 临时文件未能删除: " this.input.directory), A_LineNumber, 1)
        }
    }
}

IsSfxvNameCandidate(path) {
    SplitPath(path, &name)
    return RegExMatch(name, "i)^.+\.(?:exe|\d{3}\.sfxv)$") != 0
}

class SfxvInput {
    __New(path) {
        this.originalPath := path
        this.commandPath := path
        this.directory := ""
        this.status := ""
        this.volumeFirst := ""
        this.missingVolumes := []
        this.taskActive := false
        this.closed := false
        this.cleanupComplete := false

        try this.Prepare(path)
        catch {
            this.status := ArchiveStatus.IO_ERROR
            this.Close()
        }
    }

    Prepare(path) {
        SplitPath(path, , &dir)
        if (!IsSfxvNameCandidate(path) || !DirExist(dir))
            return

        names := []
        loop files dir "\*.*", "F"
            names.Push(A_LoopFileName)
        group := DetectVolumeGroup(path, names)
        if (!group.isVolume || !group.HasOwnProp("kind") || group.kind != "sfxv")
            return

        this.volumeFirst := group.firstPath
        this.missingVolumes := group.missingVolumes
        if (group.missingVolumes.Length || !FileExist(group.firstPath)) {
            this.status := ArchiveStatus.MISSING_VOLUME
            return
        }

        offset := FindSfx7zOffset(group.firstPath)
        if (offset < 0) {
            this.status := ArchiveStatus.NOT_ARCHIVE
            return
        }

        required := -offset
        for member in group.members
            required += FileGetSize(member)
        if (required <= 0 || this.AvailableBytes(dir) < required) {
            this.status := ArchiveStatus.IO_ERROR
            return
        }

        Loop 8 {
            candidate := dir "\__smartzip_sfxv_" A_TickCount "_" Random(100000, 999999)
            if !DirExist(candidate) {
                this.directory := candidate
                break
            }
        }
        if (this.directory = "") {
            this.status := ArchiveStatus.IO_ERROR
            return
        }
        try DirCreate(this.directory)
        catch {
            this.directory := ""
            this.status := ArchiveStatus.IO_ERROR
            return
        }
        this.commandPath := this.directory "\archive.7z"
        if !MergeSfxvPieces(group.members, offset, this.commandPath) {
            this.status := ArchiveStatus.IO_ERROR
            this.Close()
        }
    }

    AvailableBytes(dir) {
        if !DllCall("GetDiskFreeSpaceExW", "Str", dir, "Int64P", &available := 0,
            "Ptr", 0, "Ptr", 0)
            throw OSError()
        return available
    }

    Close() {
        if this.cleanupComplete
            return
        ; Closing ends borrowing at once; it does not assert the files are gone,
        ; which a temporary file still open in another process can prevent.
        this.closed := true
        ownsFile := this.commandPath != "" && this.commandPath != this.originalPath
        if (ownsFile && FileExist(this.commandPath))
            try FileDelete(this.commandPath)
        if (this.directory != "" && DirExist(this.directory))
            try DirDelete(this.directory, false)
        this.cleanupComplete := DirExist(this.directory) = ""
            && (!ownsFile || FileExist(this.commandPath) = "")
    }
}

MergeSfxvPieces(members, firstOffset, destination) {
    source := ""
    target := ""
    try {
        if (!members.Length || firstOffset < 0 || firstOffset >= FileGetSize(members[1]))
            return false
        target := FileOpen(destination, "w")
        if !target
            return false
        ioBuf := Buffer(1024 * 1024, 0)
        for index, member in members {
            source := FileOpen(member, "r")
            if !source
                throw Error("Cannot open SFXV volume")
            if (index = 1)
                source.Pos := firstOffset
            remaining := source.Length - source.Pos
            while remaining > 0 {
                read := source.RawRead(ioBuf, Min(ioBuf.Size, remaining))
                if (read <= 0 || target.RawWrite(ioBuf, read) != read)
                    throw Error("Incomplete SFXV copy")
                remaining -= read
            }
            source.Close()
            source := ""
        }
        target.Close()
        target := ""
        return FileExist(destination) != ""
    } catch {
        if source
            try source.Close()
        if target
            try target.Close()
        try FileDelete(destination)
        return false
    }
}

FindSfx7zOffset(path) {
    file := FileOpen(path, "r")
    if !file
        throw Error("Cannot read SFXV header")
    try {
    size := Min(FileGetSize(path), 16 * 1024 * 1024)
    if (size < 6) {
        file.Close()
        return -1
    }
    dataBuf := Buffer(size, 0)
    read := file.RawRead(dataBuf, size)
    file.Close()
    if (read <= 0)
        return -1
    Loop (read - 5) {
        pos := A_Index - 1
        if (NumGet(dataBuf, pos, "UChar") = 0x37
            && NumGet(dataBuf, pos + 1, "UChar") = 0x7A
            && NumGet(dataBuf, pos + 2, "UChar") = 0xBC
            && NumGet(dataBuf, pos + 3, "UChar") = 0xAF
            && NumGet(dataBuf, pos + 4, "UChar") = 0x27
            && NumGet(dataBuf, pos + 5, "UChar") = 0x1C)
            return pos
    }
    return -1
    } finally {
        file.Close()
    }
}

WriteOperationTiming(host, operation, started) {
    if (!host.HasOwnProp("timingLog") || !host.timingLog)
        return
    logPath := A_ScriptDir "\SmartZip-timing.log"
    if host.HasOwnProp("scriptDirOverride") && host.scriptDirOverride != ""
        logPath := host.scriptDirOverride "\SmartZip-timing.log"
    try FileAppend(operation " duration_ms=" (A_TickCount - started) "`r`n", logPath, "UTF-8")
}

; Output-side integrity evidence for an extraction. A 7-Zip process exit code cannot
; separate a warned-but-complete run from a corrupted or cancelled one (measured: the GUI
; returns 2 for all three), so the verdict comes from what was actually written, checked
; against the archive's own per-item size and CRC-32. Anything unprovable returns
; verified=false; this function never upgrades a result on its own.
VerifyExtractedOutput(host, archivePath, outputDir, password := "") {
    report := {verified: false, reason: "", summary: "", items: 0, files: 0,
        dirs: 0, checked: 0, mismatched: 0, missing: 0, noChecksum: 0, unexpected: 0,
        aborted: "", listingExit: -1}
    try {
        if !DirExist(outputDir) {
            report.reason := "output directory absent"
            return report
        }
        rootFull := NormalizedFullPath(outputDir)
        if (rootFull = "") {
            report.reason := "output directory could not be normalized"
            return report
        }
        if PathHasReparsePoint(rootFull) {
            report.reason := "output directory or ancestor is a reparse point"
            return report
        }
        cmd := host.7z ' l -slt -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' archivePath '"'
        cap := host.RunCmdCapture(cmd, "UTF-8")
        report.listingExit := IsObject(cap) ? cap.exitCode : -1
        if (report.listingExit != 0) {
            report.reason := "listing process exited " report.listingExit
            return report
        }
        listing := ValidateArchiveListing(IsObject(cap) ? cap.output : "", archivePath)
        if (!listing.ok) {
            report.reason := listing.reason
            return report
        }
        expectedFiles := Map()
        for item in listing.items {
            report.items++
            if !IsSafeRelativeEntryPath(item.path) {
                report.reason := "listing entry path is not a safe relative path"
                return report
            }
            target := outputDir "\" item.path
            targetFull := NormalizedFullPath(target)
            if (targetFull = "" || SubStr(targetFull, 1, StrLen(rootFull) + 1) != rootFull "\") {
                report.reason := "listing entry resolves outside the output directory"
                return report
            }
            if PathHasReparsePoint(targetFull) {
                report.reason := "listing entry is a reparse point"
                return report
            }
            if item.isDir {
                report.dirs++
                if !DirExist(targetFull)
                    report.missing++
                continue
            }
            expectedFiles[StrLower(StrReplace(item.path, "/", "\"))] := true
            report.files++
            if !FileExist(targetFull) || _IsDirectory(targetFull)
                continue
            if (FileGetSize(targetFull) != item.size) {
                report.mismatched++
                continue
            }
            if (item.checksum = "") {
                ; 7z omits CRC for empty files. Existence, regular-file identity
                ; and exact zero length prove their content without a checksum.
                if (item.size = 0)
                    report.checked++
                else
                    report.noChecksum++
                continue
            }
            actual := Crc32OfFileHex(targetFull)
            if (actual = "" || actual != item.checksum)
                report.mismatched++
            else
                report.checked++
        }
        writtenFiles := Map()
        CollectWrittenFiles(outputDir, rootFull, writtenFiles, report)
        if (report.aborted != "") {
            report.reason := report.aborted
            report.summary := "aborted during enumeration"
            return report
        }
        ; Compare the two sets, not their sizes: one missing and one extra must not cancel out.
        for rel in writtenFiles {
            if !expectedFiles.Has(rel)
                report.unexpected++
        }
        for rel in expectedFiles {
            if !writtenFiles.Has(rel)
                report.missing++
        }
        if (report.mismatched)
            report.reason := "size or CRC mismatch"
        else if (report.missing)
            report.reason := "listed item was not written"
        else if (report.noChecksum)
            report.reason := "no checksum for a listed file"
        else if (report.unexpected)
            report.reason := "output holds files the archive does not list"
        else if !report.checked
            report.reason := "nothing verified"
        else
            report.verified := true
        report.summary := ("checked=" report.checked "/" report.files " dirs=" report.dirs
            " mismatched=" report.mismatched " missing=" report.missing
            " no-checksum=" report.noChecksum " unexpected=" report.unexpected)
        return report
    } catch as failure {
        ; A verification that cannot be completed is a conservative failure, never an error
        ; that escapes and bypasses the caller's failure isolation.
        report.verified := false
        report.reason := "verification failed: " failure.Message " (line " failure.Line ")"
        report.summary := "aborted"
        return report
    }
}

_IsDirectory(path) {
    return InStr(FileExist(path), "D") != 0
}

CollectWrittenFiles(dir, rootFull, sink, report) {
    if PathHasReparsePoint(dir) {
        report.aborted := "output directory or ancestor is a reparse point"
        return
    }
    Loop files dir "\*", "F" {
        full := NormalizedFullPath(A_LoopFileFullPath)
        if (full = "") {
            report.aborted := "written file could not be normalized"
            return
        }
        if (SubStr(full, 1, StrLen(rootFull) + 1) != rootFull "\") {
            report.aborted := "written file resolves outside the output directory"
            return
        }
        if (IsReparsePoint(full)) {
            report.aborted := "written file is a reparse point"
            return
        }
        rel := SubStr(full, StrLen(rootFull) + 2)
        key := StrLower(rel)
        if sink.Has(key) {
            report.aborted := "output filename collision"
            return
        }
        sink[key] := true
    }
    Loop files dir "\*", "D" {
        ; Descending into a link would read files that the extraction never wrote,
        ; so a reparse directory ends the walk instead.
        if (IsReparsePoint(A_LoopFileFullPath)) {
            report.aborted := "output holds a reparse point directory"
            return
        }
        CollectWrittenFiles(A_LoopFileFullPath, rootFull, sink, report)
        if (report.aborted != "")
            return
    }
}

ParseArchiveListing(text) {
    items := []
    cur := ""
    started := false
    Loop Parse text, "`n", "`r" {
        line := Trim(A_LoopField)
        if (!started) {
            if (line = "----------")
                started := true
            continue
        }
        if SubStr(line, 1, 6) = "Path =" {
            cur := {path: Trim(SubStr(line, 7)), size: 0, checksum: "", isDir: false,
                hasSize: false, hasAttr: false}
            items.Push(cur)
            continue
        }
        if !IsObject(cur)
            continue
        if SubStr(line, 1, 6) = "Size =" {
            sizeText := Trim(SubStr(line, 7))
            cur.hasSize := RegExMatch(sizeText, "^\d+$") != 0
            if cur.hasSize
                cur.size := sizeText + 0
        } else if SubStr(line, 1, 5) = "CRC =" {
            cur.checksum := StrUpper(Trim(SubStr(line, 6)))
        } else if SubStr(line, 1, 12) = "Attributes =" {
            attr := Trim(SubStr(line, 13))
            cur.isDir := SubStr(attr, 1, 1) = "D"
            cur.hasAttr := true
        }
    }
    return items
}

Crc32OfFileHex(path) {
    file := ""
    try file := FileOpen(path, "r")
    if !file
        return ""
    ; FileOpen auto-detects text BOMs even before RawRead. CRC covers every byte.
    file.Pos := 0
    crc := 0
    buf := Buffer(4 * 1024 * 1024, 0)
    try {
        Loop {
            read := file.RawRead(buf, buf.Size)
            if (read <= 0)
                break
            crc := DllCall("ntdll\RtlComputeCrc32", "UInt", crc, "Ptr", buf.Ptr, "UInt", read, "UInt")
        }
    } catch as e {
        file.Close()
        throw Error("Crc32OfFileHex failed", -1, e)
    }
    file.Close()
    hex := StrUpper(Format("{1:x}", crc))
    while (StrLen(hex) < 8)
        hex := "0" hex
    return hex
}

; The extract process's own exit code is the only evidence about that process, and the GUI
; front-end returns 2 for a warned-but-complete run, a corrupted run and a cancelled run
; alike. So an ambiguous code is resolved by decision: a hard result from the source test
; or a user break always wins, and promotion needs proven output integrity. A promoted run
; is still only OK_WITH_WARNING, so it never looks like a clean success.
ExtractionVerdict(extractExit, verifyStatus, outputVerified, usedGui) {
    if (extractExit = 255)
        return ArchiveStatus.CANCELLED
    if (verifyStatus != ArchiveStatus.OK && verifyStatus != ArchiveStatus.OK_WITH_WARNING)
        return verifyStatus
    if (extractExit = 0)
        return verifyStatus
    ; Promotion is limited to the one ambiguity that was measured: 7zG returns 2 for a run
    ; that finished with a trailing-data warning, while the console build returns 0 for the
    ; same archive. Any other code - a console 2, a launch failure, a usage, memory, or
    ; request-unsupported error, or an unassigned -1 - stays a failure even if the output
    ; happens to verify, because nothing about it was measured as recoverable.
    if (usedGui && extractExit = 2 && outputVerified)
        return ArchiveStatus.OK_WITH_WARNING
    return ArchiveStatus.UNKNOWN_ERROR
}

; Listing structure and text are a separate process's output, so they are validated before
; anything is believed. Returns {ok, reason, items}.
ValidateArchiveListing(text, archivePath) {
    result := {ok: false, reason: "", items: []}
    if (text = "" || !InStr(text, "Path = ")) {
        result.reason := "empty listing"
        return result
    }
    if (RegExMatch(text, "im)^(\s*)ERROR:\s|Cannot open|Can'?t open as archive|Is not archive")) {
        result.reason := "listing reports an error"
        return result
    }
    headerEnd := InStr(text, "`n----------")
    if (!headerEnd) {
        result.reason := "listing has no item separator"
        return result
    }
    header := SubStr(text, 1, headerEnd)
    if (!RegExMatch(header, "im)^Type\s*=\s*\S")) {
        result.reason := "listing header has no archive type"
        return result
    }
    if (!RegExMatch(header, "im)^Path\s*=\s*" . EscapeLiteral(String(archivePath)) . "\s*$")) {
        result.reason := "listing header does not name the queried archive"
        return result
    }
    items := ParseArchiveListing(text)
    if !items.Length {
        result.reason := "listing names no items"
        return result
    }
    seen := Map()
    seen.CaseSense := false
    for item in items {
        entryKey := StrReplace(item.path, "/", "\")
        if (entryKey = "" || seen.Has(entryKey)) {
            result.reason := seen.Has(entryKey) ? "listing repeats an entry" : "listing entry without a path"
            return result
        }
        seen[entryKey] := true
        if (!item.HasOwnProp("hasSize") || !item.hasSize) {
            result.reason := "listing entry without a size"
            return result
        }
        if (!item.HasOwnProp("hasAttr") || !item.hasAttr) {
            result.reason := "listing entry without attributes"
            return result
        }
        if (!item.isDir && item.size != 0 && item.checksum = "") {
            result.reason := "listing file entry without a checksum"
            return result
        }
        if !IsSafeRelativeEntryPath(item.path) {
            result.reason := "listing entry path is not a safe relative path"
            return result
        }
    }
    result.ok := true
    result.items := items
    return result
}

EscapeLiteral(s) {
    out := ""
    Loop Parse s {
        ch := A_LoopField
        out .= InStr("\.*+?^${}()|[]", ch) ? "\" ch : ch
    }
    return out
}

; Absolute, UNC, device, stream and traversal shapes are all refused: reading through them
; would leave the output directory.
IsSafeRelativeEntryPath(path) {
    if (path = "" || InStr(path, ":") || InStr(path, "\\") || InStr(path, "//"))
        return false
    if (SubStr(path, 1, 1) = "\" || SubStr(path, 1, 1) = "/")
        return false
    for part in StrSplit(path, "\") {
        if (part = "" || part = "." || part = "..")
            return false
    }
    for part in StrSplit(path, "/") {
        if (part = "" || part = "." || part = "..")
            return false
    }
    return true
}

NormalizedFullPath(path) {
    need := DllCall("kernel32\GetFullPathNameW", "Str", path, "UInt", 0, "Ptr", 0, "Ptr", 0)
    if (need = 0 || need > 32767)
        return ""
    buf := Buffer(need * 2 + 2, 0)
    if !DllCall("kernel32\GetFullPathNameW", "Str", path, "UInt", need + 1, "Ptr", buf.Ptr, "Ptr", 0)
        return ""
    return RTrim(StrGet(buf.Ptr, "UTF-16"), "\")
}

IsReparsePoint(path) {
    attr := DllCall("kernel32\GetFileAttributesW", "Str", path, "UInt")
    if (attr = 0xFFFFFFFF)
        return false
    return (attr & 0x400) != 0
}

; GetFullPathNameW is lexical only. Check every component before reading content,
; including the output root and its ancestors, not just the final listed file.
; This protects a stable tree; it is not an atomic defense against concurrent changes.
PathHasReparsePoint(path) {
    current := path
    while current != "" {
        if IsReparsePoint(current)
            return true
        SplitPath(current, , &parent)
        if (parent = current)
            break
        current := parent
    }
    return false
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
