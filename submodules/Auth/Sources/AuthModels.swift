import Foundation

public struct AuthConfiguration: Sendable {
    public let issuer: String
    public let clientID: String
    public let redirectScheme: String
    public let redirectURI: String

    public init(issuer: String, clientID: String, redirectScheme: String, redirectURI: String) {
        self.issuer = issuer
        self.clientID = clientID
        self.redirectScheme = redirectScheme
        self.redirectURI = redirectURI
    }
}

public struct AuthTokens: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
}

public struct AuthSignIn: Sendable {
    public let subject: String
    public let email: String?
    public let tokens: AuthTokens
}

public enum AuthError: Error, Sendable {
    case cancelled
    case sessionEnded
    case stateMismatch
    case issuerMismatch
    case invalidIDToken(String)
    case malformedResponse
    case refused(String)
    case unavailable(String)

    public var detail: String {
        switch self {
        case .cancelled:
            "cancelled"
        case .sessionEnded:
            "session ended"
        case .stateMismatch:
            "state mismatch"
        case .issuerMismatch:
            "issuer mismatch"
        case .invalidIDToken(let reason):
            "ID token: \(reason)"
        case .malformedResponse:
            "malformed response"
        case .refused(let code), .unavailable(let code):
            code
        }
    }
}
