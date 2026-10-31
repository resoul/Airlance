import Stories
import UIKit

@MainActor
final class ScreenFactory {
    private let app: ApplicationContext
    private let scene: SceneContext
    private let account: AccountContext
    private let positions: ChatScrollPositions
    private let router: AppRouter

    init(
        app: ApplicationContext,
        scene: SceneContext,
        account: AccountContext,
        positions: ChatScrollPositions,
        router: AppRouter
    ) {
        self.app = app
        self.scene = scene
        self.account = account
        self.positions = positions
        self.router = router
    }

    func makeContacts() -> UIViewController {
        ContactsViewController(
            dependencies: ContactsDependencies(
                presentationContext: scene.presentationContext,
                contactsSync: app.contactsSync,
                permissionStore: app.permissionStore,
                permissionFlow: scene.permissionFlow
            ),
            router: router
        )
    }

    func makeNewContact() -> UIViewController {
        NewContactViewController(
            dependencies: NewContactDependencies(
                presentationContext: scene.presentationContext,
                contactsSync: app.contactsSync
            ),
            router: router
        )
    }

    func makeInvite() -> UIViewController {
        InviteViewController(
            dependencies: InviteDependencies(
                presentationContext: scene.presentationContext,
                contactsSync: app.contactsSync
            ),
            router: router
        )
    }

    func makeChats() -> UIViewController {
        ChatsViewController(
            dependencies: ChatsDependencies(
                presentationContext: scene.presentationContext,
                chatsStore: account.chatsStore,
                historyStore: account.historyStore,
                storiesStore: account.storiesStore,
                chatFolders: account.chatFolders
            ),
            router: router
        )
    }

    func makeChatArchive() -> UIViewController {
        ChatArchiveViewController(
            dependencies: ChatArchiveDependencies(
                presentationContext: scene.presentationContext,
                chatsStore: account.chatsStore,
                storiesStore: account.storiesStore
            ),
            router: router
        )
    }

    func makeCalls() -> UIViewController {
        CallsViewController(
            dependencies: CallsDependencies(
                presentationContext: scene.presentationContext,
                callsStore: account.callsStore,
                storiesStore: account.storiesStore
            ),
            router: router
        )
    }

    func makeChat(id: String) -> UIViewController {
        ChatViewController(
            id: id,
            dependencies: ChatDependencies(
                presentationContext: scene.presentationContext,
                chatsStore: account.chatsStore,
                historyStore: account.historyStore,
                chatPositions: positions,
                permissionFlow: scene.permissionFlow,
                videoNotes: account.videoNotes,
                media: account.media
            ),
            router: router
        )
    }

    func makeVideoNotes() -> UIViewController {
        VideoNoteSettingsController(
            dependencies: VideoNoteSettingsDependencies(
                presentationContext: scene.presentationContext,
                settings: account.videoNotes
            )
        )
    }

    func makeMedia(id: String) -> UIViewController {
        MediaViewController(
            id: id,
            dependencies: MediaDependencies(
                presentationContext: scene.presentationContext,
                chatsStore: account.chatsStore
            ),
            router: router
        )
    }

    func makeBrowser(url: URL) -> UIViewController {
        BrowserViewController(
            url: url,
            dependencies: BrowserDependencies(
                presentationContext: scene.presentationContext,
                dataStoreID: account.accountID.rawValue
            )
        )
    }

    func makeNewChat() -> UIViewController {
        NewChatViewController(
            dependencies: NewChatDependencies(
                presentationContext: scene.presentationContext,
                chatsStore: account.chatsStore
            ),
            router: router
        )
    }

    func makePermissions() -> UIViewController {
        PermissionsViewController(
            dependencies: PermissionsDependencies(
                presentationContext: scene.presentationContext,
                permissionStore: app.permissionStore
            )
        )
    }

    func makeProfile(id: String) -> UIViewController {
        ProfileViewController(
            id: id,
            dependencies: ProfileDependencies(
                presentationContext: scene.presentationContext,
                chatsStore: account.chatsStore
            ),
            router: router
        )
    }

    func makeStories(peerID: String) -> UIViewController {
        let store = account.storiesStore
        let strings = scene.presentationContext.presentation.strings
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
            presentationContext: scene.presentationContext,
            chatFolders: account.chatFolders,
            chatsStore: account.chatsStore
        )
    }

    func makeSettings() -> UIViewController {
        SettingsViewController(
            dependencies: SettingsDependencies(
                presentationContext: scene.presentationContext,
                themeStore: app.themeStore,
                localizationStore: app.localizationStore,
                accounts: scene
            ),
            router: router
        )
    }

    func makeAppearance() -> UIViewController {
        AppearanceViewController(
            dependencies: AppearanceDependencies(
                presentationContext: scene.presentationContext,
                themeStore: app.themeStore,
                localizationStore: app.localizationStore
            )
        )
    }
}
