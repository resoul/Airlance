import UIKit

struct ChatDependencies {
    let presentationContext: PresentationContext
    let permissionFlow: PermissionFlow
}

final class ChatViewController: ScreenViewController {
    private let id: Int
    private let dependencies: ChatDependencies
    private let profileButton: UIButton
    private let mediaButton: UIButton
    private let attachPhotoButton = UIButton(type: .system)
    private let videoMessageButton = UIButton(type: .system)
    private let notificationButton: UIButton

    init(id: Int, dependencies: ChatDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        profileButton = UIButton.action {
            router.open(.profile(id))
        }
        mediaButton = UIButton.action {
            router.open(.media(id))
        }
        notificationButton = UIButton.action {
            router.show(.chat(DemoChats.next(after: id)))
        }
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        attachPhotoButton.addTarget(self, action: #selector(attachPhoto), for: .touchUpInside)
        videoMessageButton.addTarget(self, action: #selector(recordVideoMessage), for: .touchUpInside)
        placeActionButtons([profileButton, mediaButton, attachPhotoButton, videoMessageButton, notificationButton])
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let strings = presentation.strings

        navigationItem.title = strings.chatTitle(id)
        profileButton.apply(title: strings.chatProfile, theme: presentation.theme)
        mediaButton.apply(title: strings.chatMedia, theme: presentation.theme)
        attachPhotoButton.apply(title: strings.chatAttachPhoto, theme: presentation.theme)
        videoMessageButton.apply(title: strings.chatVideoMessage, theme: presentation.theme)
        notificationButton.apply(title: strings.notificationFrom(DemoChats.next(after: id)), theme: presentation.theme)
    }

    private func authorize(_ purpose: PermissionPurpose) {
        Task {
            _ = await dependencies.permissionFlow.authorize(purpose, from: self)
        }
    }

    @objc
    private func attachPhoto() {
        authorize(.attachMedia)
    }

    @objc
    private func recordVideoMessage() {
        authorize(.videoMessage)
    }
}
