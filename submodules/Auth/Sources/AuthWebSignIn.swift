import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
public final class AuthWebSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let configuration: AuthConfiguration
    private let endpoint: AuthEndpoint
    private let anchor: UIWindow
    private var session: ASWebAuthenticationSession?

    public init(configuration: AuthConfiguration, anchor: UIWindow) {
        self.configuration = configuration
        endpoint = AuthEndpoint(configuration: configuration)
        self.anchor = anchor
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }

    public func start() async throws -> AuthSignIn {
        let verifier = Self.randomToken()
        let state = Self.randomToken()
        let nonce = Self.randomToken()
        let url = try authorizeURL(verifier: verifier, state: state, nonce: nonce)
        let callback = try await present(url: url)
        let code = try code(from: callback, state: state)
        do {
            let response = try await endpoint.exchange(code: code, verifier: verifier)
            guard let idToken = response.idToken, let refreshToken = response.refreshToken else {
                throw AuthError.malformedResponse
            }

            let verified = try AuthIDToken.verify(
                idToken,
                nonce: nonce,
                configuration: configuration,
                keys: try await endpoint.keys()
            )

            return AuthSignIn(
                subject: verified.subject,
                email: verified.email,
                tokens: AuthTokens(
                    accessToken: response.accessToken,
                    refreshToken: refreshToken,
                    expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
                )
            )
        } catch let error as URLError {
            throw AuthError.unavailable(error.localizedDescription)
        }
    }

    private func authorizeURL(verifier: String, state: String, nonce: String) throws -> URL {
        let challenge = AuthBase64URL.encode(Data(SHA256.hash(data: Data(verifier.utf8))))
        var components = URLComponents(string: configuration.issuer + "/oauth2/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "scope", value: "openid email"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let url = components?.url else {
            throw AuthError.malformedResponse
        }

        return url
    }

    private func present(url: URL) async throws -> URL {
        let scheme = configuration.redirectScheme

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, any Error>) in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled)
                } else {
                    continuation.resume(throwing: AuthError.unavailable(error?.localizedDescription ?? "no callback"))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            if !session.start() {
                continuation.resume(throwing: AuthError.unavailable("can't open the sign-in window"))
            }
        }
    }

    private func code(from callback: URL, state: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in
            items.first { item in
                item.name == name
            }?.value
        }
        guard value("state") == state else {
            throw AuthError.stateMismatch
        }

        guard value("iss") == configuration.issuer else {
            throw AuthError.issuerMismatch
        }

        if let error = value("error") {
            throw AuthError.refused(error)
        }

        guard let code = value("code") else {
            throw AuthError.malformedResponse
        }

        return code
    }

    private static func randomToken() -> String {
        let bytes = SymmetricKey(size: .bits256).withUnsafeBytes { buffer in
            Data(buffer)
        }

        return AuthBase64URL.encode(bytes)
    }
}
