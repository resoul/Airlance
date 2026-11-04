import Foundation
import Keychain

public actor AuthTokenStore {
    private static let refreshMargin: TimeInterval = 30
    private static let retryDelay: Duration = .seconds(1)

    private let endpoint: AuthEndpoint
    private let keychain: Keychain
    private var refreshing: [String: Task<AuthTokens, any Error>] = [:]

    public init(configuration: AuthConfiguration, keychain: Keychain) {
        endpoint = AuthEndpoint(configuration: configuration)
        self.keychain = keychain
    }

    public func save(_ tokens: AuthTokens, account: String) throws {
        try keychain.set(tokens, for: Self.key(account))
    }

    public func validAccessToken(account: String) async throws -> String {
        if let task = refreshing[account] {
            return try await task.value.accessToken
        }

        guard let tokens = try keychain.value(for: Self.key(account)) else {
            throw AuthError.sessionEnded
        }

        guard tokens.expiresAt.timeIntervalSinceNow <= Self.refreshMargin else {
            return tokens.accessToken
        }

        let task = Task {
            try await refresh(tokens, account: account)
        }
        refreshing[account] = task
        defer {
            refreshing[account] = nil
        }

        return try await task.value.accessToken
    }

    public func signOut(account: String) async {
        _ = try? await refreshing[account]?.value
        guard let tokens = try? keychain.value(for: Self.key(account)) else {
            return
        }

        try? await endpoint.revoke(token: tokens.refreshToken)
        try? keychain.remove(Self.key(account))
    }

    nonisolated public func remove(account: String) throws {
        try keychain.remove(Self.key(account))
    }

    private func refresh(_ tokens: AuthTokens, account: String) async throws -> AuthTokens {
        do {
            return try await rotate(tokens, account: account)
        } catch is URLError {
            try await Task.sleep(for: Self.retryDelay)
        }
        do {
            return try await rotate(tokens, account: account)
        } catch let error as URLError {
            throw AuthError.unavailable(error.localizedDescription)
        }
    }

    private func rotate(_ tokens: AuthTokens, account: String) async throws -> AuthTokens {
        let response: AuthTokenResponse
        do {
            response = try await endpoint.refresh(token: tokens.refreshToken)
        } catch AuthError.refused("invalid_grant") {
            try keychain.remove(Self.key(account))
            throw AuthError.sessionEnded
        }

        let next = AuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? tokens.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
        try keychain.set(next, for: Self.key(account))

        return next
    }

    private static func key(_ account: String) -> KeychainKey<AuthTokens> {
        KeychainKey("account.\(account).authTokens")
    }
}
