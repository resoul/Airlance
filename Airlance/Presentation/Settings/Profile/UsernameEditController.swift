import Haptics
import UIKit

final class UsernameEditController: ScreenViewController, UITextFieldDelegate {
    private let store: MyProfileStore
    private let router: AppRouter
    private let card = UIView()
    private let prefix = UILabel()
    private let field = UITextField()
    private let hint = UILabel()

    init(presentationSource: PresentationContext, store: MyProfileStore, router: AppRouter) {
        self.store = store
        self.router = router
        super.init(presentationSource: presentationSource)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            primaryAction: UIAction { [weak self] _ in
                self?.save()
            }
        )
        field.text = store.profile.username
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.keyboardType = .asciiCapable
        field.delegate = self
        field.addAction(
            UIAction { [weak self] _ in
                self?.update()
            },
            for: .editingChanged
        )
        prefix.text = "@"
        hint.numberOfLines = 0
        view.addSubview(card)
        card.addSubview(prefix)
        card.addSubview(field)
        view.addSubview(hint)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        field.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        let top = view.safeAreaInsets.top + 16
        card.frame = CGRect(x: 16, y: top, width: width - 32, height: 52)
        prefix.frame = CGRect(x: 18, y: 0, width: 18, height: 52)
        field.frame = CGRect(x: 36, y: 0, width: card.bounds.width - 54, height: 52)
        let size = hint.sizeThatFits(CGSize(width: width - 64, height: .greatestFiniteMagnitude))
        hint.frame = CGRect(x: 32, y: card.frame.maxY + 8, width: width - 64, height: ceil(size.height))
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        navigationItem.title = presentation.strings.profileEditUsername
        navigationItem.rightBarButtonItem?.tintColor = theme.colors.accent
        view.backgroundColor = theme.colors.background
        card.backgroundColor = theme.colors.surface
        card.layer.cornerRadius = 26
        card.layer.cornerCurve = .continuous
        prefix.font = theme.fonts.body
        prefix.textColor = theme.colors.textSecondary
        field.font = theme.fonts.body
        field.textColor = theme.colors.textPrimary
        field.tintColor = theme.colors.accent
        hint.font = theme.fonts.caption
        update()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        save()

        return false
    }

    private var username: String {
        field.text ?? ""
    }

    private var isValid: Bool {
        username.isEmpty || MyProfile.isValidUsername(username)
    }

    private func update() {
        let strings = presentation.strings
        let colors = presentation.theme.colors
        hint.text = isValid ? strings.profileEditUsernameHint : strings.profileEditUsernameInvalid
        hint.textColor = isValid ? colors.textSecondary : .systemRed
        navigationItem.rightBarButtonItem?.isEnabled = isValid
        view.setNeedsLayout()
    }

    private func save() {
        guard isValid else {
            Haptics.play(.warning)

            return
        }

        var profile = store.profile
        profile.username = username
        store.update(profile)
        Haptics.play(.success)
        router.back()
    }
}
