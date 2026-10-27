import Observers
import UIKit

struct ChatsDependencies {
    let presentationContext: PresentationContext
}

final class ChatsViewController: UIViewController {
    private let dependencies: ChatsDependencies
    private let router: AppRouter
    private let chatButtons: [UIButton]
    private let newChatButton: UIButton
    private let settingsButton: UIButton
    private var presentationObservation: ObservationToken?

    init(dependencies: ChatsDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        chatButtons = DemoChats.ids.map { id in
            UIButton.action {
                router.open(.chat(id))
            }
        }
        newChatButton = UIButton.action {
            router.open(.newChat)
        }
        settingsButton = UIButton.action {
            router.open(.settings)
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeActionButtons(chatButtons + [newChatButton, settingsButton])

        presentationObservation = dependencies.presentationContext.observe { [weak self] data in
            self?.apply(data)
        }
    }

    private func apply(_ data: PresentationData) {
        navigationItem.title = data.strings.chatsTitle
        view.backgroundColor = data.theme.colors.background

        for (id, button) in zip(DemoChats.ids, chatButtons) {
            button.apply(title: data.strings.chatTitle(id), theme: data.theme)
        }

        newChatButton.apply(title: data.strings.chatsNewChat, theme: data.theme)
        settingsButton.apply(title: data.strings.chatsSettings, theme: data.theme)
    }
}
