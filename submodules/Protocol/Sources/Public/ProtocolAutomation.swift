public struct ServerScheduled: Sendable, Equatable {
    public let id: String
    public let chatID: String
    public let clientID: String
    public let text: String
    public let sendAtUnixMs: Int64
    public let repeatRule: Int32
    public let failure: String

    public init(
        id: String,
        chatID: String,
        clientID: String,
        text: String,
        sendAtUnixMs: Int64,
        repeatRule: Int32,
        failure: String
    ) {
        self.id = id
        self.chatID = chatID
        self.clientID = clientID
        self.text = text
        self.sendAtUnixMs = sendAtUnixMs
        self.repeatRule = repeatRule
        self.failure = failure
    }
}

public struct ScheduledAddRequest: Sendable, Equatable {
    public let clientID: String
    public let chatID: String
    public let text: String
    public let sendAtUnixMs: Int64
    public let repeatRule: Int32
    public let timezone: String

    public init(
        clientID: String,
        chatID: String,
        text: String,
        sendAtUnixMs: Int64,
        repeatRule: Int32,
        timezone: String
    ) {
        self.clientID = clientID
        self.chatID = chatID
        self.text = text
        self.sendAtUnixMs = sendAtUnixMs
        self.repeatRule = repeatRule
        self.timezone = timezone
    }
}

public enum ServerAgentTrigger: Int32, Sendable, Equatable, CaseIterable {
    case schedule = 0
    case joined = 1
    case keyword = 2
    case webhook = 3
}

public struct ServerAgent: Sendable, Equatable {
    public var id: String
    public var clientID: String
    public var name: String
    public var chatID: String
    public var chatTitle: String
    public var trigger: ServerAgentTrigger
    public var keyword: String
    public var hour: Int32
    public var minute: Int32
    public var weekdays: Int32
    public var timezone: String
    public var text: String
    public var isEnabled: Bool
    public var nextRunUnixMs: Int64

    public init(
        id: String = "",
        clientID: String,
        name: String = "",
        chatID: String = "",
        chatTitle: String = "",
        trigger: ServerAgentTrigger = .joined,
        keyword: String = "",
        hour: Int32 = 9,
        minute: Int32 = 0,
        weekdays: Int32 = 127,
        timezone: String = "",
        text: String = "",
        isEnabled: Bool = true,
        nextRunUnixMs: Int64 = 0
    ) {
        self.id = id
        self.clientID = clientID
        self.name = name
        self.chatID = chatID
        self.chatTitle = chatTitle
        self.trigger = trigger
        self.keyword = keyword
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.timezone = timezone
        self.text = text
        self.isEnabled = isEnabled
        self.nextRunUnixMs = nextRunUnixMs
    }
}

public struct ServerAgentRun: Sendable, Equatable {
    public let status: Int32
    public let detail: String
    public let ranAtUnixMs: Int64

    public init(status: Int32, detail: String, ranAtUnixMs: Int64) {
        self.status = status
        self.detail = detail
        self.ranAtUnixMs = ranAtUnixMs
    }
}

public struct ServerFolder: Sendable, Equatable {
    public let id: String
    public let name: String
    public let emoji: String
    public let color: Int32
    public let categories: Int32
    public let exclusions: Int32
    public let included: [String]
    public let excluded: [String]

    public init(
        id: String,
        name: String,
        emoji: String,
        color: Int32,
        categories: Int32,
        exclusions: Int32,
        included: [String],
        excluded: [String]
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.categories = categories
        self.exclusions = exclusions
        self.included = included
        self.excluded = excluded
    }
}

public struct ServerFolderList: Sendable, Equatable {
    public let folders: [ServerFolder]
    public let allChatsPosition: Int32
    public let showsTags: Bool
    public let revision: Int64

    public init(folders: [ServerFolder], allChatsPosition: Int32, showsTags: Bool, revision: Int64) {
        self.folders = folders
        self.allChatsPosition = allChatsPosition
        self.showsTags = showsTags
        self.revision = revision
    }
}

public enum AutomationWireMessage: Sendable, Equatable {
    case scheduledGet
    case scheduledAdd(ScheduledAddRequest)
    case scheduledEdit(id: String, text: String, sendAtUnixMs: Int64)
    case scheduledCancel(id: String)
    case scheduledSendNow(id: String)
    case scheduled([ServerScheduled])
    case scheduledChanged
    case agentsGet
    case agentSave(ServerAgent, rotateWebhook: Bool)
    case agentDelete(id: String)
    case agents([ServerAgent], webhookToken: String)
    case agentRunsGet(id: String)
    case agentRuns([ServerAgentRun])
    case foldersGet
    case foldersPut(ServerFolderList)
    case folders(ServerFolderList)
    case foldersChanged
}
