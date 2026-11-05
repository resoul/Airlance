import DeviceContacts
import Haptics
import UIKit

final class PhoneEditController: ScreenViewController, UITextFieldDelegate {
    private let store: MyProfileStore
    private let router: AppRouter
    private let card = UIView()
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
        field.text = store.profile.phone
        field.keyboardType = .phonePad
        field.textContentType = .telephoneNumber
        field.delegate = self
        hint.numberOfLines = 0
        view.addSubview(card)
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
        card.frame = CGRect(x: 16, y: view.safeAreaInsets.top + 16, width: width - 32, height: 52)
        field.frame = CGRect(x: 18, y: 0, width: card.bounds.width - 36, height: 52)
        let size = hint.sizeThatFits(CGSize(width: width - 64, height: .greatestFiniteMagnitude))
        hint.frame = CGRect(x: 32, y: card.frame.maxY + 8, width: width - 64, height: ceil(size.height))
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let strings = presentation.strings
        navigationItem.title = strings.profileEditPhone
        navigationItem.rightBarButtonItem?.tintColor = theme.colors.accent
        view.backgroundColor = theme.colors.background
        card.backgroundColor = theme.colors.surface
        card.layer.cornerRadius = 26
        card.layer.cornerCurve = .continuous
        field.placeholder = strings.profileEditPhonePlaceholder
        field.font = theme.fonts.body
        field.textColor = theme.colors.textPrimary
        field.tintColor = theme.colors.accent
        hint.text = strings.profileEditPhoneHint
        hint.font = theme.fonts.caption
        hint.textColor = theme.colors.textSecondary
        view.setNeedsLayout()
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let current = textField.text as NSString? ?? ""

        return current.replacingCharacters(in: range, with: string).count <= MyProfile.phoneLimit
    }

    private func save() {
        var profile = store.profile
        let text = (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = PhoneDigits.international(text, region: PhoneDigits.currentRegion)
        profile.phone = text.isEmpty || text.hasPrefix("+") ? text : "+" + digits
        store.update(profile)
        Haptics.play(.success)
        router.back()
    }
}
