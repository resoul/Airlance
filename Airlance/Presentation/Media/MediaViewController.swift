import UIKit

struct MediaDependencies {
    let presentationContext: PresentationContext
}

final class MediaViewController: ScreenViewController {
    private let id: Int
    private let dependencies: MediaDependencies
    private let profileButton: UIButton
    private let notificationButton: UIButton

    init(id: Int, dependencies: MediaDependencies, router: AppRouter) {
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

        navigationItem.title = strings.mediaTitle(id)
        profileButton.apply(title: strings.chatProfile, theme: presentation.theme)
        notificationButton.apply(title: strings.notificationFrom(DemoChats.next(after: id)), theme: presentation.theme)
    }
}
