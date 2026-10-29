import UIKit

struct MediaDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
}

final class MediaViewController: ScreenViewController {
    private let id: String
    private let dependencies: MediaDependencies
    private let profileButton: UIButton
    private let notificationButton: UIButton

    init(id: String, dependencies: MediaDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        profileButton = UIButton.action {
            router.open(.profile(id))
        }
        notificationButton = UIButton.action {
            router.show(.chat(DemoChats.next(after: id)))
        }
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeActionButtons([profileButton, notificationButton])
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let strings = presentation.strings

        let store = dependencies.chatsStore
        let next = DemoChats.next(after: id)
        navigationItem.title = strings.mediaTitle(store.chat(id)?.name ?? id)
        profileButton.apply(title: strings.chatProfile, theme: presentation.theme)
        let sender = store.chat(next)?.name ?? next
        notificationButton.apply(title: strings.notificationFrom(sender), theme: presentation.theme)
    }
}
