import Protocol
import Stories
import UIKit

@MainActor
final class ScreenFactory {
    let app: ApplicationContext
    let scene: SceneContext
    let account: AccountContext
    private let positions: ChatScrollPositions
    let router: AppRouter

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
                storyLifetime: storyLifetime,
                chatFolders: account.chatFolders,
                permissionFlow: scene.permissionFlow,
                videoNotes: account.videoNotes,
                media: account.media,
                connectionStatus: account.connectionStatus
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
                media: account.media,
                translation: app.translation,
                contacts: app.contactsSync.store,
                connectionStatus: account.connectionStatus,
                openAppLink: appLinkOpener
            ),
            router: router
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
                chatsStore: account.chatsStore,
                search: newChatSearch()
            ),
            router: router
        )
    }

    func newChatSearch() -> NewChatSearch? {
        guard !account.record.isDemo else {
            return nil
        }

        let servers = app.servers
        let id = account.accountID

        return NewChatSearch(
            search: { query in
                guard let messaging = servers.server(for: id)?.messaging else {
                    throw AccountMessagingError.refused
                }

                return try await messaging.search(query)
            },
            open: { person in
                guard let messaging = servers.server(for: id)?.messaging else {
                    throw AccountMessagingError.refused
                }

                return try await messaging.openDirect(with: person)
            },
            chats: { [weak account] query in
                guard let messaging = servers.server(for: id)?.messaging else {
                    throw AccountMessagingError.refused
                }

                let found = try await messaging.searchChats(query)
                for chat in found {
                    account?.registerChatAvatar(chat.chatID, link: chat.details.link)
                }

                return found
            }
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
                chatsStore: account.chatsStore,
                groupMembers: account.groupMembers,
                onAir: account.onAir,
                publicProfile: publicProfileLoader(),
                serverContacts: account.serverContacts,
                privacy: account.privacy
            ),
            router: router
        )
    }

    private func publicProfileLoader() -> @MainActor (String) async -> ProfileData? {
        let servers = app.servers
        let id = account.accountID

        return { subject in
            await servers.server(for: id)?.messaging?.publicProfile(subject)
        }
    }

    private var storyLifetime: @MainActor () -> StoryLifetime {
        let storage = account.storage

        return {
            StoryLifetime(rawValue: storage.value(for: .storyLifetimeHours)) ?? .hours24
        }
    }

    func makeStories(peerID: String) -> UIViewController {
        let store = account.storiesStore
        let strings = scene.presentationContext.presentation.strings
        let now = Date()
        let viewer = StoryViewerController(
            authors: store.ordered.map { story in
                StoryPeers.author(story, store: store, strings: strings, now: now)
            },
            startPeerID: store.story(for: peerID)?.peerID ?? peerID
        )
        viewer.onSeen = { peerID, item in
            store.markSeen(peerID, through: item)
        }
        viewer.onClose = { [router] in
            router.dismiss()
        }
        viewer.labels = StoryStudioStrings.labels(strings)
        viewer.onInteraction = { [router] interaction in
            StoryInteractions.handle(interaction, router: router, store: store)
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
                accounts: scene,
                myProfile: account.myProfile
            ),
            router: router
        )
    }

    func makeStorage() -> UIViewController {
        StorageViewController(
            dependencies: StorageDependencies(
                presentationContext: scene.presentationContext,
                media: account.media
            )
        )
    }

    func makeAppearance() -> UIViewController {
        AppearanceViewController(dependencies: appearanceDependencies, router: router)
    }
}
