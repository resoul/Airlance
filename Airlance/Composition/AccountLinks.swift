import Foundation
import Protocol
import ToastUI
import UIKit

enum AccountLinkError: Error {
    case invalid
    case noConnection
}

@MainActor
struct AccountLinks {
    private static let waitStep: Duration = .milliseconds(500)
    private static let waitSteps = 20

    let account: AccountContext
    let servers: AccountServers
    let router: AppRouter
    let presentationContext: PresentationContext
    let window: UIWindow

    func open(_ link: AirlanceLink) {
        Task {
            do {
                let messaging = try await waitForMessaging()
                switch link {
                case .chat(let code), .invite(let code):
                    try await openChat(code, messaging: messaging)
                case .user(let username):
                    try await openUser(username, messaging: messaging)
                }
            } catch AccountLinkError.invalid {
                show(presentationContext.presentation.strings.applinkInvalid)
            } catch {
                show(presentationContext.presentation.strings.newChatFailed)
            }
        }
    }

    private func waitForMessaging() async throws -> AccountMessaging {
        for _ in 0..<Self.waitSteps {
            if let messaging = servers.server(for: account.accountID)?.messaging {
                return messaging
            }

            try await Task.sleep(for: Self.waitStep)
        }

        throw AccountLinkError.noConnection
    }

    private func openChat(_ code: String, messaging: AccountMessaging) async throws {
        let found = try await messaging.resolveChat(code)
        account.registerChatAvatar(found.chatID, link: found.details.link)
        if !account.chatsStore.isJoined(found.chatID) {
            account.chatsStore.addServerPreview(.preview(of: found, code: code))
        }
        router.show(.chat(found.chatID))
    }

    private func openUser(_ username: String, messaging: AccountMessaging) async throws {
        let person = try await messaging.resolveUser(username)
        account.registerAuthor(person)
        do {
            let id = try await messaging.openDirect(with: person)
            let name = [person.firstName, person.lastName].filter { part in
                !part.isEmpty
            }
            account.chatsStore.addServerPreview(.server(id: id, name: name.joined(separator: " ")))
            router.show(.chat(id))
        } catch {
            router.open(.profile(person.subject))
        }
    }

    private func show(_ text: String) {
        Toast(text).show(theme: presentationContext.presentation.theme, in: window)
    }
}
