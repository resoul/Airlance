import Observers
import UIKit

struct ChatsDependencies {
    let presentationContext: PresentationContext
}

final class ChatsViewController: UIViewController {
    private let dependencies: ChatsDependencies
    private let router: AppRouter
    private let chatButtons: [UIButton]
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
        placeActionButtons(chatButtons + [settingsButton])

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

        settingsButton.apply(title: data.strings.chatsSettings, theme: data.theme)
    }
}
