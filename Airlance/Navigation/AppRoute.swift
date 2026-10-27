import Routing

typealias AppRouter = Router<AppRoute>

enum AppRoute: Route {
    case chat(Int)
    case profile(Int)
    case settings

    var segment: RouteSegment {
        switch self {
        case .chat(let id):
            RouteSegment("chat", argument: String(id))
        case .profile(let id):
            RouteSegment("profile", argument: String(id))
        case .settings:
            RouteSegment("settings")
        }
    }

    var anchor: [AppRoute] {
        switch self {
        case .chat, .settings:
            []
        case .profile(let id):
            [.chat(id)]
        }
    }

    init?(segment: RouteSegment) {
        switch (segment.name, segment.argument.flatMap(Int.init)) {
        case ("chat", let id?):
            self = .chat(id)
        case ("profile", let id?):
            self = .profile(id)
        case ("settings", nil) where segment.argument == nil:
            self = .settings
        default:
            return nil
        }
    }
}
