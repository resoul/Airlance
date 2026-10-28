import Security

public enum KeychainError: Error, Sendable {
    case unexpectedStatus(OSStatus)
    case encodingFailed
    case decodingFailed
    case randomFailed(OSStatus)
}
