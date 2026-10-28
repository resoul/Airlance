import UIKit

struct ProfileDependencies {
    let presentationContext: PresentationContext
}

final class ProfileViewController: ScreenViewController {
    private let id: Int
    private let dependencies: ProfileDependencies
    private let messageButton: UIButton
    private let notificationButton: UIButton

    init(id: Int, dependencies: ProfileDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        messageButton = UIButton.action {
            router.show(.chat(id))
        }
        notificationButton = UIButton.action {
            router.show(.chat(DemoChats.next(after: id)))
        }
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        placeActionButtons([messageButton, notificationButton])
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let strings = presentation.strings

        navigationItem.title = strings.profileTitle(id)
        messageButton.apply(title: strings.profileMessage, theme: presentation.theme)
        notificationButton.apply(title: strings.notificationFrom(DemoChats.next(after: id)), theme: presentation.theme)
    }
}
