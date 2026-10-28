import AirlanceUI
import DeviceContacts
import UIKit

struct NewContactDependencies {
    let presentationContext: PresentationContext
    let contactsSync: ContactsSync
}

final class NewContactViewController: ScreenViewController {
    private let dependencies: NewContactDependencies
    private let router: AppRouter
    private let givenField = UITextField()
    private let familyField = UITextField()
    private let phoneField = UITextField()
    private let nameCard = UIView()
    private let phoneCard = UIView()
    private let separator = UIView()
    private var isSaving = false

    private var fields: [UITextField] {
        [givenField, familyField, phoneField]
    }

    private var draft: DeviceContactDraft {
        DeviceContactDraft(
            givenName: givenField.text ?? "",
            familyName: familyField.text ?? "",
            phoneNumber: phoneField.text ?? ""
        )
    }

    init(dependencies: NewContactDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in
                self?.save()
            }
        )
        setUpFields()
        setUpLayout()
        updateDone()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        givenField.becomeFirstResponder()
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let colors = presentation.theme.colors
        let strings = presentation.strings
        let placeholders = [strings.newContactFirstName, strings.newContactLastName, strings.newContactPhone]

        navigationItem.title = strings.newContactTitle
        for card in [nameCard, phoneCard] {
            card.backgroundColor = colors.surface
        }
        separator.backgroundColor = colors.separator
        for (field, placeholder) in zip(fields, placeholders) {
            field.font = presentation.theme.fonts.body
            field.textColor = colors.textPrimary
            field.tintColor = colors.accent
            field.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: colors.textSecondary]
            )
        }
    }

    private func setUpFields() {
        givenField.textContentType = .givenName
        familyField.textContentType = .familyName
        phoneField.textContentType = .telephoneNumber
        phoneField.keyboardType = .phonePad
        givenField.returnKeyType = .next
        familyField.returnKeyType = .next

        for field in fields {
            field.addAction(
                UIAction { [weak self] _ in
                    self?.updateDone()
                },
                for: .editingChanged
            )
        }
        givenField.addAction(
            UIAction { [weak self] _ in
                self?.familyField.becomeFirstResponder()
            },
            for: .editingDidEndOnExit
        )
        familyField.addAction(
            UIAction { [weak self] _ in
                self?.phoneField.becomeFirstResponder()
            },
            for: .editingDidEndOnExit
        )
    }

    private func setUpLayout() {
        let nameStack = UIStackView(arrangedSubviews: [givenField, separator, familyField])
        nameStack.axis = .vertical
        let phoneStack = UIStackView(arrangedSubviews: [phoneField])
        embed(nameStack, in: nameCard)
        embed(phoneStack, in: phoneCard)

        let stack = UIStackView(arrangedSubviews: [nameCard, phoneCard])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        var constraints = [
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / max(view.traitCollection.displayScale, 1)),
        ]
        constraints += fields.map { field in
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func embed(_ stack: UIStackView, in card: UIView) {
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
    }

    private func updateDone() {
        navigationItem.rightBarButtonItem?.isEnabled = draft.isValid && !isSaving
    }

    private func save() {
        let draft = draft
        guard draft.isValid, !isSaving else {
            return
        }

        isSaving = true
        updateDone()
        Task {
            do {
                try await dependencies.contactsSync.store.add(draft)
                router.dismiss()
            } catch {
                isSaving = false
                updateDone()
                showError()
            }
        }
    }

    private func showError() {
        let strings = presentation.strings
        PopupAlert.show(
            title: nil,
            message: strings.newContactError,
            actions: [PopupAlertAction(title: strings.permissionAlertOk, style: .cancel)],
            theme: presentation.theme,
            in: view
        )
    }
}
