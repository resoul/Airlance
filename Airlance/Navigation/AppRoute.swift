import Routing

typealias AppRouter = Router<AppRoute>

enum AppRoute: Route {
    case chat(Int)
    case media(Int)
    case newChat
    case profile(Int)
    case settings

    var segment: RouteSegment {
        switch self {
        case .chat(let id):
            RouteSegment("chat", argument: String(id))
        case .media(let id):
            RouteSegment("media", argument: String(id))
        case .newChat:
            RouteSegment("newChat")
        case .profile(let id):
            RouteSegment("profile", argument: String(id))
        case .settings:
            RouteSegment("settings")
        }
    }

    var anchor: [AppRoute] {
        switch self {
        case .chat, .newChat, .settings:
            []
        case .media(let id), .profile(let id):
            [.chat(id)]
        }
    }

    var presentation: RoutePresentation {
        switch self {
        case .chat, .profile, .settings:
            .stack
        case .media:
            .fullScreen
        case .newChat:
            .sheet
        }
    }

    init?(segment: RouteSegment) {
        if let argument = segment.argument {
            guard let id = Int(argument) else {
                return nil
            }

            self.init(name: segment.name, id: id)
        } else {
            self.init(name: segment.name)
        }
    }

    private init?(name: String) {
        switch name {
        case "newChat":
            self = .newChat
        case "settings":
            self = .settings
        default:
            return nil
        }
    }

    private init?(name: String, id: Int) {
        switch name {
        case "chat":
            self = .chat(id)
        case "media":
            self = .media(id)
        case "profile":
            self = .profile(id)
        default:
            return nil
        }
    }
}
