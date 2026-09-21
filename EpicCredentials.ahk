#Requires AutoHotkey v2.0

EpicCredentialPath() {
    return A_ScriptDir "\State\credentials.dpapi"
}

EpicEnsureCredentials() {
    if !FileExist(EpicCredentialPath())
        throw Error("Set credentials in NYU Sync")
}

EpicDataBlob(bytes) {
    blob := Buffer(A_PtrSize = 8 ? 16 : 8, 0)
    NumPut("UInt", bytes.Size, blob)
    NumPut("Ptr", bytes.Ptr, blob, A_PtrSize)
    return blob
}

EpicReadCredentials() {
    encrypted := FileRead(EpicCredentialPath(), "RAW")
    if encrypted.Size < 32 || encrypted.Size > 65536
        throw Error("Invalid encrypted credential file")
    input := EpicDataBlob(encrypted)
    output := Buffer(A_PtrSize = 8 ? 16 : 8, 0)
    try {
        if !DllCall("Crypt32\CryptUnprotectData", "Ptr", input, "Ptr", 0,
            "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 1, "Ptr", output)
            throw Error("Credentials cannot be decrypted by this Windows account")
        pointer := NumGet(output, A_PtrSize, "Ptr")
        size := NumGet(output, 0, "UInt")
        payload := StrGet(pointer, size, "UTF-8")
        parts := StrSplit(payload, "`n", , 3)
        payload := ""
        if parts.Length != 3 || parts[1] != "NYUSynchronization/1" || !parts[2] || !parts[3]
            throw Error("Invalid credential payload")
        return {user: parts[2], password: parts[3]}
    } finally {
        if pointer := NumGet(output, A_PtrSize, "Ptr") {
            DllCall("msvcrt\memset", "Ptr", pointer, "Int", 0, "UPtr", NumGet(output, 0, "UInt"), "CDecl Ptr")
            DllCall("LocalFree", "Ptr", pointer)
        }
    }
}
