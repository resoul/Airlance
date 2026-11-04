import AirlanceUI
@preconcurrency import AsyncDisplayKit
import Haptics
import ListUI
import Observers
import UIKit

struct ProfileEditDependencies {
    let presentationContext: PresentationContext
    let store: MyProfileStore
}

final class ProfileEditController: ScreenViewController {
    let dependencies: ProfileEditDependencies
    var draft: MyProfile

    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private let avatarView = ProfileEditAvatarView()
    private var nameCard: ProfileEditNameCard?
    private var bioCard: ProfileEditBioCard?
    private var observation: ObservationToken?
    private var isSaved = false

    init(dependencies: ProfileEditDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        draft = dependencies.store.profile
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak self] _ in
                self?.closeTapped()
            }
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            primaryAction: UIAction { [weak self] _ in
                self?.save()
            }
        )
        view.addSubnode(listView)
        listView.scrollView.keyboardDismissMode = .interactive
        avatarView.onTap = { [weak self] in
            self?.photoTapped()
        }
        observation = dependencies.store.observe { [weak self] profile in
            self?.draft.username = profile.username
            self?.render()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        if listView.contentInsets.top != view.safeAreaInsets.top {
            listView.contentInsets = view.safeAreaInsets
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent, !isSaved, let photo = draft.photo, photo != dependencies.store.profile.photo {
            dependencies.store.media.remove(photo)
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        navigationItem.rightBarButtonItem?.tintColor = theme.colors.accent
        listView.theme = .settings(theme)
        nameCard = ProfileEditNameCard(
            first: draft.firstName,
            last: draft.lastName,
            strings: presentation.strings,
            theme: theme
        )
        nameCard?.onChange = { [weak self] first, last in
            self?.draft.firstName = first
            self?.draft.lastName = last
            self?.updateSave()
        }
        bioCard = ProfileEditBioCard(text: draft.bio, strings: presentation.strings, theme: theme)
        bioCard?.onChange = { [weak self] text in
            self?.draft.bio = text
        }
        render()
    }

    func render() {
        guard isViewLoaded, let nameCard, let bioCard else {
            return
        }

        let strings = presentation.strings
        avatarView.apply(
            dependencies.store.avatar(for: draft),
            title: strings.profileEditChangePhoto,
            theme: presentation.theme
        )
        var items: [any ListItem] = [
            ViewHostItem(
                id: "avatar",
                height: ProfileEditAvatarView.height,
                content: avatarView,
                inset: 0,
                revision: draft.photo?.name.hashValue ?? 0
            ),
            ViewHostItem(id: "name", height: ProfileEditNameCard.height, content: nameCard),
            FootnoteItem(id: "name-hint", text: strings.profileEditNameHint),
            ViewHostItem(id: "bio", height: ProfileEditBioCard.height, content: bioCard),
            FootnoteItem(id: "bio-hint", text: strings.profileEditBioHint),
        ]
        items += birthdayRows().positioned() as [any ListItem]
        items.append(FootnoteItem(id: "birthday-hint", text: visibilityHint))
        items += accountRows().positioned() as [any ListItem]
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
        updateSave()
    }

    private func updateSave() {
        let hasName = !draft.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = hasName
    }

    private func accountRows() -> [SettingsOptionItem] {
        let strings = presentation.strings
        let router = router

        return [
            SettingsOptionItem(
                id: "phone",
                title: strings.profileEditPhone,
                detail: draft.phone,
                symbol: "phone.fill",
                iconColor: .systemGreen
            ),
            SettingsOptionItem(
                id: "username",
                title: strings.profileEditUsername,
                detail: draft.username.isEmpty ? strings.profileEditNotSet : "@\(draft.username)",
                symbol: "at",
                iconColor: .systemIndigo,
                accessory: .chevron,
                onSelect: {
                    router.open(.settingsPage(.editUsername))
                }
            ),
        ]
    }

    private func closeTapped() {
        view.endEditing(true)
        guard draft != dependencies.store.profile else {
            router.back()

            return
        }

        let strings = presentation.strings
        PopupAlert.show(
            title: nil,
            message: strings.profileEditDiscard,
            actions: [
                PopupAlertAction(title: strings.profileEditDiscardAction, style: .destructive) { [weak self] in
                    self?.router.back()
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }

    private func save() {
        view.endEditing(true)
        draft.firstName = draft.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.lastName = draft.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.bio = draft.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaved = true
        dependencies.store.update(draft)
        Haptics.play(.success)
        router.back()
    }

    @objc
    private func keyboardChanged(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let overlap = max(view.safeAreaInsets.bottom, view.bounds.height - view.convert(frame, from: nil).minY)
        var insets = view.safeAreaInsets
        insets.bottom = overlap
        listView.contentInsets = insets
    }
}
