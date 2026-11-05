import AirlanceUI
@preconcurrency import AsyncDisplayKit
import DeviceContacts
import Haptics
import ListUI
import Observers
import UIKit

struct ProfileEditDependencies {
    let presentationContext: PresentationContext
    let store: MyProfileStore
    let contacts: DeviceContactsStore
    let permissionFlow: PermissionFlow
    let videoNotes: VideoNoteSettings
}

final class ProfileEditController: ScreenViewController {
    let dependencies: ProfileEditDependencies
    var draft: MyProfile

    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    let avatarView = ProfileEditAvatarView()
    private var nameCard: ProfileEditNameCard?
    private var bioCard: ProfileEditBioCard?
    private var birthdayCard: ProfileEditBirthdayCard?
    private var isBirthdayExpanded = false
    private var observation: ObservationToken?
    private(set) lazy var camera = AvatarCameraFlow(
        media: dependencies.store.media,
        permissions: dependencies.permissionFlow,
        videoNotes: dependencies.videoNotes
    )

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
        avatarView.onAvatarTap = { [weak self] in
            self?.showPhotoViewer()
        }
        observation = dependencies.store.observe { [weak self] profile in
            self?.draft.username = profile.username
            self?.draft.phone = profile.phone
            self?.draft.photoItems = profile.photoItems
            self?.draft.photoRemovals = profile.photoRemovals
            self?.draft.mainPhotoID = profile.mainPhotoID
            self?.render()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        if listView.contentInsets.top != view.safeAreaInsets.top {
            listView.contentInsets = view.safeAreaInsets
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        navigationItem.rightBarButtonItem?.tintColor = theme.colors.accent
        listView.theme = .settings(theme)
        applyNavigationBar(background: theme.colors.background)
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
        birthdayCard = makeBirthdayCard(presentation)
        render()
    }

    func render(animated: Bool = false) {
        guard isViewLoaded, let nameCard, let bioCard, let birthdayCard else {
            return
        }

        let strings = presentation.strings
        avatarView.apply(
            dependencies.store.avatar(for: draft),
            title: strings.profileEditChangePhoto,
            theme: presentation.theme
        )
        birthdayCard.apply(
            birthday: draft.birthday,
            text: birthdayText ?? strings.profileEditSet,
            isExpanded: isBirthdayExpanded,
            theme: presentation.theme
        )
        var items: [any ListItem] = [
            avatarItem,
            ViewHostItem(id: "name", height: ProfileEditNameCard.height, content: nameCard),
            FootnoteItem(id: "name-hint", text: strings.profileEditNameHint),
            ViewHostItem(id: "bio", height: ProfileEditBioCard.height, content: bioCard),
            FootnoteItem(id: "bio-hint", text: strings.profileEditBioHint),
        ]
        items.append(ViewHostItem(
            id: "birthday",
            height: ProfileEditBirthdayCard.height(isExpanded: isBirthdayExpanded),
            content: birthdayCard
        ))
        items.append(FootnoteItem(
            id: "birthday-hint",
            text: visibilityHint,
            link: strings.profileEditAction
        ) { [weak self] in
            self?.showVisibilityMenu()
        })
        items += accountRows().positioned() as [any ListItem]
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: animated)
        updateSave()
    }

    private func makeBirthdayCard(_ presentation: PresentationData) -> ProfileEditBirthdayCard {
        let card = ProfileEditBirthdayCard(strings: presentation.strings, theme: presentation.theme)
        card.onToggle = { [weak self] in
            self?.birthdayTapped()
        }
        card.onChange = { [weak self, weak card] birthday in
            guard let self else {
                return
            }

            self.draft.birthday = birthday
            card?.setValue(self.birthdayText ?? "")
        }
        card.onRemove = { [weak self] in
            self?.draft.birthday = nil
            self?.isBirthdayExpanded = false
            self?.render(animated: true)
        }

        return card
    }

    private func birthdayTapped() {
        view.endEditing(true)
        if draft.birthday == nil {
            draft.birthday = Self.defaultBirthday
            isBirthdayExpanded = true
        } else {
            isBirthdayExpanded.toggle()
        }
        Haptics.play(.selection)
        render(animated: true)
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
                detail: draft.phone.isEmpty ? strings.profileEditNotSet : draft.phone,
                symbol: "phone.fill",
                iconColor: .systemGreen,
                accessory: .chevron,
                onSelect: {
                    router.open(.settingsPage(.editPhone))
                }
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
