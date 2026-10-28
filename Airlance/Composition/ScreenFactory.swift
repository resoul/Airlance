import Stories
import UIKit

@MainActor
final class ScreenFactory {
    private let app: AppEnvironment
    private let router: AppRouter

    init(app: AppEnvironment, router: AppRouter) {
        self.app = app
        self.router = router
    }

    func makeContacts() -> UIViewController {
        ContactsViewController(
            dependencies: ContactsDependencies(
                presentationContext: app.presentationContext,
                contactsSync: app.contactsSync,
                permissionStore: app.permissionStore,
                permissionFlow: app.permissionFlow
            ),
            router: router
        )
    }

    func makeNewContact() -> UIViewController {
        NewContactViewController(
            dependencies: NewContactDependencies(
                presentationContext: app.presentationContext,
                contactsSync: app.contactsSync
            ),
            router: router
        )
    }

    func makeInvite() -> UIViewController {
        InviteViewController(
            dependencies: InviteDependencies(
                presentationContext: app.presentationContext,
                contactsSync: app.contactsSync
            ),
            router: router
        )
    }

    func makeChats() -> UIViewController {
        ChatsViewController(
            dependencies: ChatsDependencies(
                presentationContext: app.presentationContext,
                chatsStore: app.account.chatsStore,
                storiesStore: app.account.storiesStore,
                chatFolders: app.account.chatFolders
            ),
            router: router
        )
    }

    func makeCalls() -> UIViewController {
        CallsViewController(
            dependencies: CallsDependencies(
                presentationContext: app.presentationContext,
                callsStore: app.account.callsStore,
                storiesStore: app.account.storiesStore
            ),
            router: router
        )
    }

    func makeChat(id: Int) -> UIViewController {
        ChatViewController(
            id: id,
            dependencies: ChatDependencies(
                presentationContext: app.presentationContext,
                permissionFlow: app.permissionFlow
            ),
            router: router
        )
    }

    func makeMedia(id: Int) -> UIViewController {
        MediaViewController(
            id: id,
            dependencies: MediaDependencies(presentationContext: app.presentationContext),
            router: router
        )
    }

    func makeNewChat() -> UIViewController {
        NewChatViewController(
            dependencies: NewChatDependencies(presentationContext: app.presentationContext),
            router: router
        )
    }

    func makePermissions() -> UIViewController {
        PermissionsViewController(
            dependencies: PermissionsDependencies(
                presentationContext: app.presentationContext,
                permissionStore: app.permissionStore
            )
        )
    }

    func makeProfile(id: Int) -> UIViewController {
        ProfileViewController(
            id: id,
            dependencies: ProfileDependencies(presentationContext: app.presentationContext),
            router: router
        )
    }

    func makeStories(peerID: String) -> UIViewController {
        let store = app.account.storiesStore
        let strings = app.presentationContext.presentation.strings
        let now = Date()
        let viewer = StoryViewerController(
            authors: store.ordered.map { story in
                StoryPeers.author(story, strings: strings, now: now)
            },
            startPeerID: peerID
        )
        viewer.onSeen = { peerID, item in
            store.markSeen(peerID, through: item)
        }
        viewer.onClose = { [router] in
            router.dismiss()
        }

        return viewer
    }

    func makeChatFolders() -> UIViewController {
        FoldersViewController(dependencies: folderDependencies, router: router)
    }

    func makeChatFolderEditor(id: String?) -> UIViewController {
        FolderEditorViewController(folderID: id, dependencies: folderDependencies, router: router)
    }

    private var folderDependencies: FoldersDependencies {
        FoldersDependencies(
            presentationContext: app.presentationContext,
            chatFolders: app.account.chatFolders,
            chatsStore: app.account.chatsStore
        )
    }

    func makeSettings() -> UIViewController {
        SettingsViewController(
            dependencies: SettingsDependencies(
                presentationContext: app.presentationContext,
                themeStore: app.themeStore,
                localizationStore: app.localizationStore
            ),
            router: router
        )
    }

    func makeAppearance() -> UIViewController {
        AppearanceViewController(
            dependencies: AppearanceDependencies(
                presentationContext: app.presentationContext,
                themeStore: app.themeStore,
                localizationStore: app.localizationStore
            )
        )
    }
}
