internal import FlatBuffers
internal import ProtocolSchema

extension EnvelopeWriter {
    static func writeAutomation(
        _ message: AutomationWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch message {
        case .scheduledGet:
            let start = Airlance_Wire_ScheduledGet.startScheduledGet(&builder)

            return (.scheduledget, Airlance_Wire_ScheduledGet.endScheduledGet(&builder, start: start))
        case .scheduledAdd(let request):
            return (.scheduledadd, writeAdd(request, into: &builder))
        case .scheduledEdit(let id, let text, let sendAtUnixMs):
            let idOffset = builder.create(string: id)
            let textOffset = builder.create(string: text)
            let root = Airlance_Wire_ScheduledEdit.createScheduledEdit(
                &builder,
                idOffset: idOffset,
                textOffset: textOffset,
                sendAtUnixMs: sendAtUnixMs
            )

            return (.schedulededit, root)
        case .scheduledCancel(let id):
            let text = builder.create(string: id)

            return (.scheduledcancel, Airlance_Wire_ScheduledCancel.createScheduledCancel(&builder, idOffset: text))
        case .scheduledSendNow(let id):
            let text = builder.create(string: id)

            return (.scheduledsendnow, Airlance_Wire_ScheduledSendNow.createScheduledSendNow(&builder, idOffset: text))
        case .scheduledChanged:
            let start = Airlance_Wire_ScheduledChanged.startScheduledChanged(&builder)

            return (.scheduledchanged, Airlance_Wire_ScheduledChanged.endScheduledChanged(&builder, start: start))
        default:
            return writeAgentMessage(message, into: &builder)
        }
    }

    private static func writeAgentMessage(
        _ message: AutomationWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch message {
        case .agentSave(let agent, let rotate):
            return (.agentsave, writeSave(agent, rotate: rotate, into: &builder))
        case .agentDelete(let id):
            let text = builder.create(string: id)

            return (.agentdelete, Airlance_Wire_AgentDelete.createAgentDelete(&builder, idOffset: text))
        case .agentRunsGet(let id):
            let text = builder.create(string: id)

            return (.agentrunsget, Airlance_Wire_AgentRunsGet.createAgentRunsGet(&builder, idOffset: text))
        case .foldersGet:
            let start = Airlance_Wire_FoldersGet.startFoldersGet(&builder)

            return (.foldersget, Airlance_Wire_FoldersGet.endFoldersGet(&builder, start: start))
        case .foldersPut(let list):
            return (.foldersput, writeFoldersPut(list, into: &builder))
        default:
            let start = Airlance_Wire_AgentsGet.startAgentsGet(&builder)

            return (.agentsget, Airlance_Wire_AgentsGet.endAgentsGet(&builder, start: start))
        }
    }

    private static func writeFoldersPut(_ list: ServerFolderList, into builder: inout FlatBufferBuilder) -> Offset {
        let rows = list.folders.map { folder in
            writeFolder(folder, into: &builder)
        }
        let vector = builder.createVector(ofOffsets: rows)

        return Airlance_Wire_FoldersPut.createFoldersPut(
            &builder,
            foldersVectorOffset: vector,
            allChatsPosition: list.allChatsPosition,
            showsTags: list.showsTags
        )
    }

    private static func writeFolder(_ folder: ServerFolder, into builder: inout FlatBufferBuilder) -> Offset {
        let id = builder.create(string: folder.id)
        let name = builder.create(string: folder.name)
        let emoji = builder.create(string: folder.emoji)
        let included = folder.included.map { peer in
            builder.create(string: peer)
        }
        let excluded = folder.excluded.map { peer in
            builder.create(string: peer)
        }
        let includedVector = builder.createVector(ofOffsets: included)
        let excludedVector = builder.createVector(ofOffsets: excluded)

        return Airlance_Wire_FolderData.createFolderData(
            &builder,
            idOffset: id,
            nameOffset: name,
            emojiOffset: emoji,
            color: folder.color,
            categories: folder.categories,
            exclusions: folder.exclusions,
            includedVectorOffset: includedVector,
            excludedVectorOffset: excludedVector
        )
    }

    private static func writeAdd(_ request: ScheduledAddRequest, into builder: inout FlatBufferBuilder) -> Offset {
        let client = builder.create(string: request.clientID)
        let chat = builder.create(string: request.chatID)
        let text = builder.create(string: request.text)
        let zone = builder.create(string: request.timezone)

        return Airlance_Wire_ScheduledAdd.createScheduledAdd(
            &builder,
            clientIdOffset: client,
            chatIdOffset: chat,
            textOffset: text,
            sendAtUnixMs: request.sendAtUnixMs,
            repeatRule: request.repeatRule,
            timezoneOffset: zone
        )
    }

    private static func writeSave(_ agent: ServerAgent, rotate: Bool, into builder: inout FlatBufferBuilder) -> Offset {
        let id = builder.create(string: agent.id)
        let client = builder.create(string: agent.clientID)
        let name = builder.create(string: agent.name)
        let chat = builder.create(string: agent.chatID)
        let keyword = builder.create(string: agent.keyword)
        let zone = builder.create(string: agent.timezone)
        let text = builder.create(string: agent.text)

        return Airlance_Wire_AgentSave.createAgentSave(
            &builder,
            idOffset: id,
            clientIdOffset: client,
            nameOffset: name,
            chatIdOffset: chat,
            triggerKind: agent.trigger.rawValue,
            keywordOffset: keyword,
            hour: agent.hour,
            minute: agent.minute,
            weekdays: agent.weekdays,
            timezoneOffset: zone,
            textOffset: text,
            enabled: agent.isEnabled,
            rotateWebhook: rotate
        )
    }
}
