import Routing

typealias AppRouter = Router<AppRoute>

enum AppRoute: Route {
    case contacts
    case chats
    case calls
    case settings
    case chat(Int)
    case media(Int)
    case newChat
    case newContact
    case invite
    case permissions
    case appearance
    case profile(Int)
    case stories(String)
    case chatFolders
    case newChatFolder
    case chatFolder(String)

    static let tabs: [AppRoute] = [.contacts, .calls, .chats, .settings]

    var segment: RouteSegment {
        switch self {
        case .contacts:
            RouteSegment("contacts")
        case .chats:
            RouteSegment("chats")
        case .calls:
            RouteSegment("calls")
        case .settings:
            RouteSegment("settings")
        case .chat(let id):
            RouteSegment("chat", argument: String(id))
        case .media(let id):
            RouteSegment("media", argument: String(id))
        case .newChat:
            RouteSegment("newChat")
        case .newContact:
            RouteSegment("newContact")
        case .invite:
            RouteSegment("invite")
        case .permissions:
            RouteSegment("permissions")
        case .appearance:
            RouteSegment("appearance")
        case .profile(let id):
            RouteSegment("profile", argument: String(id))
        case .stories(let peerID):
            RouteSegment("stories", argument: peerID)
        case .chatFolders:
            RouteSegment("chatFolders")
        case .newChatFolder:
            RouteSegment("newChatFolder")
        case .chatFolder(let id):
            RouteSegment("chatFolder", argument: id)
        }
    }

    var anchor: [AppRoute] {
        switch self {
        case .contacts, .calls, .chats, .settings:
            []
        case .chat, .newChat, .stories:
            [.chats]
        case .newContact, .invite:
            [.contacts]
        case .media(let id), .profile(let id):
            [.chats, .chat(id)]
        case .permissions, .appearance, .chatFolders:
            [.settings]
        case .newChatFolder, .chatFolder:
            [.settings, .chatFolders]
        }
    }

    var presentation: RoutePresentation {
        switch self {
        case .contacts, .calls, .chats, .settings:
            .tab
        case .chat, .permissions, .appearance, .profile, .chatFolders, .chatFolder:
            .stack
        case .media, .stories:
            .fullScreen
        case .newChat, .newContact, .invite, .newChatFolder:
            .sheet
        }
    }

    init?(segment: RouteSegment) {
        if segment.name == "stories", let argument = segment.argument {
            self = .stories(argument)
        } else if segment.name == "chatFolder", let argument = segment.argument {
            self = .chatFolder(argument)
        } else if let argument = segment.argument {
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
        case "contacts":
            self = .contacts
        case "chats":
            self = .chats
        case "calls":
            self = .calls
        case "settings":
            self = .settings
        case "newChat":
            self = .newChat
        case "newContact":
            self = .newContact
        case "invite":
            self = .invite
        case "permissions":
            self = .permissions
        case "appearance":
            self = .appearance
        case "chatFolders":
            self = .chatFolders
        case "newChatFolder":
            self = .newChatFolder
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
