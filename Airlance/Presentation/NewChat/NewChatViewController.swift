import UIKit

struct NewChatDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
}

final class NewChatViewController: ScreenViewController {
    private let dependencies: NewChatDependencies
    private let contactButtons: [UIButton]

    init(dependencies: NewChatDependencies, router: AppRouter) {
        self.dependencies = dependencies
        contactButtons = DemoChats.ids.map { id in
            UIButton.action {
                router.open(.profile(id))
            }
        }
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeActionButtons(contactButtons)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.newChatTitle

        for (id, button) in zip(DemoChats.ids, contactButtons) {
            button.apply(title: dependencies.chatsStore.chat(id)?.name ?? id, theme: presentation.theme)
        }
    }
}
