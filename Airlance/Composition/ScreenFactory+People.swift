import Protocol
import UIKit

extension ScreenFactory {
    func makeContacts() -> UIViewController {
        ContactsViewController(
            dependencies: ContactsDependencies(
                presentationContext: scene.presentationContext,
                contactsSync: app.contactsSync,
                permissionStore: app.permissionStore,
                permissionFlow: scene.permissionFlow,
                serverContacts: account.serverContacts,
                openChat: contactChatOpener()
            ),
            router: router
        )
    }

    private func contactChatOpener() -> @MainActor (ServerContact) async throws -> Void {
        let servers = app.servers
        let id = account.accountID
        let chats = account.chatsStore
        let router = router

        return { contact in
            guard let messaging = servers.server(for: id)?.messaging else {
                throw AccountMessagingError.refused
            }

            let chatID = try await messaging.openDirect(with: contact.person)
            chats.addServerPreview(.server(id: chatID, name: contact.displayName))
            router.show(.chat(chatID))
        }
    }

    func makeNewContact() -> UIViewController {
        NewContactViewController(
            dependencies: NewContactDependencies(
                presentationContext: scene.presentationContext,
                contactsSync: app.contactsSync,
                serverContacts: account.serverContacts,
                search: newChatSearch()?.search
            ),
            router: router
        )
    }
}
