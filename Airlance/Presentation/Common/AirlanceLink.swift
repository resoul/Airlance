import Foundation

enum AirlanceLink: Equatable, Sendable {
    case chat(String)
    case invite(String)
    case user(String)

    static let host = "link.airlance.org"

    private static let appScheme = "airlance"
    private static let appHost = "link"

    init?(url: URL) {
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let isWeb = (scheme == "https" || scheme == "http") && host == Self.host
        let isApp = scheme == Self.appScheme && host == Self.appHost
        guard isWeb || isApp else {
            return nil
        }

        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 2, Self.isCode(parts[1]) else {
            return nil
        }

        switch parts[0] {
        case "c":
            self = .chat(parts[1])
        case "join":
            self = .invite(parts[1])
        case "u":
            self = .user(parts[1])
        default:
            return nil
        }
    }

    var displayText: String {
        switch self {
        case .chat(let code):
            "\(Self.host)/c/\(code)"
        case .invite(let code):
            "\(Self.host)/join/\(code)"
        case .user(let code):
            "\(Self.host)/u/\(code)"
        }
    }

    var webURL: URL? {
        URL(string: "https://\(displayText)")
    }

    private static func isCode(_ text: String) -> Bool {
        (1...64).contains(text.count) && text.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "_")
        }
    }
}
