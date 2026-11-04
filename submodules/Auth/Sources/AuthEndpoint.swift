import Foundation

struct AuthTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
    }
}

struct AuthKey: Decodable, Sendable {
    let kid: String
    let kty: String
    let n: String
    let e: String
}

struct AuthEndpoint: Sendable {
    private struct KeySet: Decodable {
        let keys: [AuthKey]
    }

    private struct Failure: Decodable {
        let error: String
    }

    private static let requestTimeout: TimeInterval = 15

    let configuration: AuthConfiguration

    func exchange(code: String, verifier: String) async throws -> AuthTokenResponse {
        let data = try await post("/oauth2/token", form: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": configuration.redirectURI,
            "client_id": configuration.clientID,
            "code_verifier": verifier,
        ])

        return try decode(AuthTokenResponse.self, from: data)
    }

    func refresh(token: String) async throws -> AuthTokenResponse {
        let data = try await post("/oauth2/token", form: [
            "grant_type": "refresh_token",
            "refresh_token": token,
            "client_id": configuration.clientID,
        ])

        return try decode(AuthTokenResponse.self, from: data)
    }

    func revoke(token: String) async throws {
        _ = try await post("/oauth2/revoke", form: ["token": token, "client_id": configuration.clientID])
    }

    func keys() async throws -> [AuthKey] {
        var request = URLRequest(url: try url("/oauth2/jwks"), timeoutInterval: Self.requestTimeout)
        request.httpMethod = "GET"
        let data = try await perform(request)

        return try decode(KeySet.self, from: data).keys
    }

    private func post(_ path: String, form: [String: String]) async throws -> Data {
        var request = URLRequest(url: try url(path), timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.encoded(form).utf8)

        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 200 {
            return data
        }

        if (400..<500).contains(status) {
            let code = (try? JSONDecoder().decode(Failure.self, from: data))?.error ?? "HTTP \(status)"
            throw AuthError.refused(code)
        }

        throw AuthError.unavailable("HTTP \(status)")
    }

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: configuration.issuer + path) else {
            throw AuthError.malformedResponse
        }

        return url
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AuthError.malformedResponse
        }
    }

    private static func encoded(_ form: [String: String]) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let pairs = form.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }

        return pairs.joined(separator: "&")
    }
}
