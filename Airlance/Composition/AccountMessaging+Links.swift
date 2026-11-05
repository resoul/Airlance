import Protocol

extension AccountMessaging {
    func resolveChat(_ code: String) async throws -> ServerChat {
        guard case .chat(.chat(let chat)) = try await connection.request(.group(.resolve(code: code))) else {
            throw AccountLinkError.invalid
        }

        return chat
    }

    func resolveUser(_ username: String) async throws -> SearchPerson {
        let reply = try await connection.request(.group(.userResolve(username: username)))
        guard case .search(.results(let people)) = reply, let person = people.first else {
            throw AccountLinkError.invalid
        }

        return person
    }

    func resetInvite(_ chatID: String) async throws -> String {
        guard case .chat(.chat(let chat)) = try await connection.request(.group(.inviteReset(chatID: chatID))) else {
            throw AccountMessagingError.refused
        }

        try await save(chat)

        return chat.details.inviteToken
    }

    func setPinned(_ isPinned: Bool, chatID: String) async throws {
        try await storage.setPinned(isPinned, chatID: chatID)
        do {
            let reply = try await connection.request(.group(.pinSet(chatID: chatID, isPinned: isPinned)))
            guard case .chat(.chat(let chat)) = reply else {
                throw AccountMessagingError.refused
            }

            try await save(chat)
        } catch {
            try? await storage.setPinned(!isPinned, chatID: chatID)
            throw error
        }
    }
}
