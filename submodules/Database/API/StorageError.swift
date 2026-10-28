public enum StorageError: Error {
    case encodingFailed(key: String, underlying: any Error)
    case writeFailed(key: String, underlying: any Error)
    case readFailed(underlying: any Error)
    case tableWriteFailed(underlying: any Error)
}
