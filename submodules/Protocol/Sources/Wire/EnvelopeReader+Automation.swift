internal import FlatBuffers
import Foundation
internal import ProtocolSchema

extension EnvelopeReader {
    func automation(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .scheduledget:
            let _: Airlance_Wire_ScheduledGet = try checkedRoot(body)

            return .automation(.scheduledGet)
        case .scheduledadd:
            let table: Airlance_Wire_ScheduledAdd = try checkedRoot(body)

            return .automation(.scheduledAdd(ScheduledAddRequest(
                clientID: table.clientId ?? "",
                chatID: table.chatId ?? "",
                text: table.text ?? "",
                sendAtUnixMs: table.sendAtUnixMs,
                repeatRule: table.repeatRule,
                timezone: table.timezone ?? ""
            )))
        case .scheduledcancel:
            let table: Airlance_Wire_ScheduledCancel = try checkedRoot(body)

            return .automation(.scheduledCancel(id: table.id ?? ""))
        case .scheduledsendnow:
            let table: Airlance_Wire_ScheduledSendNow = try checkedRoot(body)

            return .automation(.scheduledSendNow(id: table.id ?? ""))
        case .scheduledchanged:
            let _: Airlance_Wire_ScheduledChanged = try checkedRoot(body)

            return .automation(.scheduledChanged)
        default:
            return try automationData(kind: kind, body: body)
        }
    }

    private func automationData(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .schedulededit:
            let table: Airlance_Wire_ScheduledEdit = try checkedRoot(body)

            return .automation(.scheduledEdit(
                id: table.id ?? "",
                text: table.text ?? "",
                sendAtUnixMs: table.sendAtUnixMs
            ))
        case .scheduleddata:
            let table: Airlance_Wire_ScheduledData = try checkedRoot(body)

            return .automation(.scheduled(table.items.map(Self.serverScheduled)))
        case .agentsget:
            let _: Airlance_Wire_AgentsGet = try checkedRoot(body)

            return .automation(.agentsGet)
        case .agentdelete:
            let table: Airlance_Wire_AgentDelete = try checkedRoot(body)

            return .automation(.agentDelete(id: table.id ?? ""))
        case .agentsdata:
            let table: Airlance_Wire_AgentsData = try checkedRoot(body)

            return .automation(.agents(table.agents.map(Self.serverAgent), webhookToken: table.webhookToken ?? ""))
        case .agentrunsget:
            let table: Airlance_Wire_AgentRunsGet = try checkedRoot(body)

            return .automation(.agentRunsGet(id: table.id ?? ""))
        case .agentrunsdata:
            let table: Airlance_Wire_AgentRunsData = try checkedRoot(body)

            return .automation(.agentRuns(table.runs.map(Self.serverRun)))
        case .agentsave:
            let table: Airlance_Wire_AgentSave = try checkedRoot(body)

            return .automation(.agentSave(Self.serverAgent(table), rotateWebhook: table.rotateWebhook))
        default:
            return try foldersMessage(kind: kind, body: body)
        }
    }

    private func foldersMessage(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .foldersget:
            let _: Airlance_Wire_FoldersGet = try checkedRoot(body)

            return .automation(.foldersGet)
        case .foldersput:
            let table: Airlance_Wire_FoldersPut = try checkedRoot(body)

            return .automation(.foldersPut(ServerFolderList(
                folders: table.folders.map(Self.serverFolder),
                allChatsPosition: table.allChatsPosition,
                showsTags: table.showsTags,
                revision: 0
            )))
        case .foldersdata:
            let table: Airlance_Wire_FoldersData = try checkedRoot(body)

            return .automation(.folders(ServerFolderList(
                folders: table.folders.map(Self.serverFolder),
                allChatsPosition: table.allChatsPosition,
                showsTags: table.showsTags,
                revision: table.revision
            )))
        case .folderschanged:
            let _: Airlance_Wire_FoldersChanged = try checkedRoot(body)

            return .automation(.foldersChanged)
        default:
            return .unsupported(kind: kind)
        }
    }

    private static func serverFolder(_ table: Airlance_Wire_FolderData) -> ServerFolder {
        ServerFolder(
            id: table.id ?? "",
            name: table.name ?? "",
            emoji: table.emoji ?? "",
            color: table.color,
            categories: table.categories,
            exclusions: table.exclusions,
            included: table.included.compactMap(\.self),
            excluded: table.excluded.compactMap(\.self)
        )
    }

    private static func serverScheduled(_ table: Airlance_Wire_ScheduledItem) -> ServerScheduled {
        ServerScheduled(
            id: table.id ?? "",
            chatID: table.chatId ?? "",
            clientID: table.clientId ?? "",
            text: table.text ?? "",
            sendAtUnixMs: table.sendAtUnixMs,
            repeatRule: table.repeatRule,
            failure: table.failure ?? ""
        )
    }

    private static func serverRun(_ table: Airlance_Wire_AgentRunData) -> ServerAgentRun {
        ServerAgentRun(status: table.status, detail: table.detail ?? "", ranAtUnixMs: table.ranAtUnixMs)
    }

    private static func serverAgent(_ table: Airlance_Wire_AgentData) -> ServerAgent {
        ServerAgent(
            id: table.id ?? "",
            clientID: table.clientId ?? "",
            name: table.name ?? "",
            chatID: table.chatId ?? "",
            chatTitle: table.chatTitle ?? "",
            trigger: ServerAgentTrigger(rawValue: table.triggerKind) ?? .joined,
            keyword: table.keyword ?? "",
            hour: table.hour,
            minute: table.minute,
            weekdays: table.weekdays,
            timezone: table.timezone ?? "",
            text: table.text ?? "",
            isEnabled: table.enabled,
            nextRunUnixMs: table.nextRunUnixMs
        )
    }

    private static func serverAgent(_ table: Airlance_Wire_AgentSave) -> ServerAgent {
        ServerAgent(
            id: table.id ?? "",
            clientID: table.clientId ?? "",
            name: table.name ?? "",
            chatID: table.chatId ?? "",
            trigger: ServerAgentTrigger(rawValue: table.triggerKind) ?? .joined,
            keyword: table.keyword ?? "",
            hour: table.hour,
            minute: table.minute,
            weekdays: table.weekdays,
            timezone: table.timezone ?? "",
            text: table.text ?? "",
            isEnabled: table.enabled
        )
    }
}
