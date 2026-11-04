import Haptics
import ListUI
import Observers
import ToastUI
import UIKit

struct ChannelSettingsDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
    let settings: ChannelSettingsStore
    let members: GroupMembersStore
    let onAir: OnAirStore
}

final class ChannelSettingsController: ScreenViewController {
    private let id: String
    private let dependencies: ChannelSettingsDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private var infoCard: ChannelInfoCard?
    private var observations: [ObservationToken] = []
    private var name: String
    private var about: String

    init(id: String, dependencies: ChannelSettingsDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        self.router = router
        name = dependencies.chatsStore.chat(id)?.name ?? ""
        about = dependencies.settings.settings(id).about ?? ProfilePeer(id: id, chat: nil).bio
        super.init(presentationSource: dependencies.presentationContext)
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
        view.addSubnode(listView)
        listView.scrollView.keyboardDismissMode = .interactive
        observations = [
            dependencies.settings.observe { [weak self] _ in
                self?.render()
            },
            dependencies.members.observe { [weak self] _ in
                self?.render()
            },
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        navigationItem.title = presentation.strings.channelSettingsTitle
        navigationItem.rightBarButtonItem?.tintColor = theme.colors.accent
        listView.theme = .settings(theme)
        infoCard = ChannelInfoCard(name: name, about: about, presentation: presentation)
        infoCard?.onChange = { [weak self] name, about in
            self?.name = name
            self?.about = about
            self?.navigationItem.rightBarButtonItem?.isEnabled = !name.isEmpty
        }
        render()
    }

    private func render() {
        guard isViewLoaded, let infoCard else {
            return
        }

        let strings = presentation.strings
        var items: [any ListItem] = [
            SpacerItem(id: "top", height: 8),
            ViewHostItem(id: "info", height: ChannelInfoCard.height, content: infoCard),
            FootnoteItem(id: "info-hint", text: strings.channelSettingsInfoHint),
        ]
        items += generalRows().positioned() as [any ListItem]
        items.append(SpacerItem(id: "gap-1", height: 24))
        items += peopleRows().positioned() as [any ListItem]
        items.append(SpacerItem(id: "gap-2", height: 24))
        items += activityRows().positioned() as [any ListItem]
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
    }

    private func generalRows() -> [SettingsOptionItem] {
        let strings = presentation.strings
        let isPrivate = dependencies.settings.settings(id).isPrivate ?? false

        return [
            pageRow(
                .type,
                title: strings.channelSettingsType,
                detail: isPrivate ? strings.channelSettingsPrivate : strings.channelSettingsPublic,
                symbol: "megaphone.fill",
                color: .systemOrange
            ),
            pageRow(
                .appearance,
                title: strings.channelAppearanceTitle,
                detail: nil,
                symbol: "paintbrush.fill",
                color: .systemCyan
            ),
            SettingsOptionItem(
                id: "reactions",
                title: strings.channelReactionsTitle,
                detail: reactionsDetail,
                symbol: "face.smiling.inverse",
                iconColor: .systemPink,
                accessory: .chevron,
                onSelect: { [weak self] in
                    self?.showReactions()
                }
            ),
        ]
    }

    private func peopleRows() -> [SettingsOptionItem] {
        let strings = presentation.strings
        let members = dependencies.members.members(in: id)
        let admins = members.filter { member in
            member.role < .member
        }
        let subscribers = dependencies.chatsStore.chat(id)?.memberCount ?? members.count

        return [
            pageRow(
                .admins,
                title: strings.channelSettingsAdmins,
                detail: String(admins.count),
                symbol: "checkmark.shield.fill",
                color: .systemGreen
            ),
            pageRow(
                .subscribers,
                title: strings.channelSettingsSubscribers,
                detail: strings.compactCount(subscribers),
                symbol: "person.2.fill",
                color: .systemBlue
            ),
            pageRow(
                .banned,
                title: strings.channelSettingsBanned,
                detail: String(dependencies.settings.settings(id).banned.count),
                symbol: "nosign",
                color: .systemRed
            ),
        ]
    }

    private func activityRows() -> [SettingsOptionItem] {
        let strings = presentation.strings
        var rows = [
            pageRow(
                .log,
                title: strings.channelSettingsLog,
                detail: nil,
                symbol: "list.bullet.rectangle",
                color: .systemGray
            ),
        ]
        if dependencies.onAir.channel(id) != nil {
            rows.insert(
                pageRow(
                    .boosts,
                    title: strings.channelSettingsBoosts,
                    detail: nil,
                    symbol: "bolt.fill",
                    color: .systemIndigo
                ),
                at: 0
            )
        }

        return rows
    }

    private func pageRow(
        _ page: ChannelSettingsPage,
        title: String,
        detail: String?,
        symbol: String,
        color: UIColor
    ) -> SettingsOptionItem {
        let router = router
        let id = id

        return SettingsOptionItem(
            id: page.rawValue,
            title: title,
            detail: detail,
            symbol: symbol,
            iconColor: color,
            accessory: .chevron,
            onSelect: {
                router.open(.channelSettings(id, page))
            }
        )
    }

    private var reactionsDetail: String {
        let strings = presentation.strings
        switch dependencies.settings.reactionRule(id) {
        case .all:
            return strings.channelReactionsAll
        case .some(let emojis):
            return String(emojis.count)
        case .none:
            return strings.channelReactionsNone
        }
    }
}

extension ChannelSettingsController {
    private func reactionsSaved() {
        Toast(presentation.strings.channelReactionsSaved, symbol: "face.smiling")
            .show(theme: presentation.theme, in: view)
    }

    private func showReactions() {
        view.endEditing(true)
        let store = dependencies.settings
        let onAir = dependencies.onAir
        let channelID = id
        let content = ChannelReactionsController(
            rule: store.reactionRule(channelID),
            perPost: store.settings(channelID).reactionsPerPost,
            presentation: presentation
        ) {
            OnAirLevel(score: onAir.channel(channelID)?.score ?? 0).reactionLimit
        }
        content.onSave = { [weak self] rule, perPost in
            store.update(channelID, log: .reactionsChanged) { settings in
                settings.reactionRule = rule
                settings.reactionsPerPost = perPost
            }
            Haptics.play(.success)
            self?.reactionsSaved()
        }
        if onAir.channel(channelID) != nil {
            content.onUpgrade = { [weak self, weak content] in
                guard let self, let sheet = content?.floatingSheet else {
                    return
                }

                let levels = ChannelLevelsController(
                    channelID: channelID,
                    store: onAir,
                    presentation: self.presentation
                )
                let top = FloatingSheetController(content: levels, theme: self.presentation.theme) { _ in
                    720
                }
                sheet.present(top, animated: false)
            }
        }
        let sheet = FloatingSheetController(content: content, theme: presentation.theme) { width in
            ChannelReactionsController.height(for: width)
        }
        present(sheet, animated: false)
    }

    private func save() {
        view.endEditing(true)
        let store = dependencies.settings
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAbout = about.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        if trimmedName != dependencies.chatsStore.chat(id)?.name {
            dependencies.chatsStore.rename(id, to: trimmedName)
            store.update(id, log: .renamed, detail: trimmedName) { settings in
                settings.name = trimmedName
            }
        }
        if trimmedAbout != store.settings(id).about ?? ProfilePeer(id: id, chat: nil).bio {
            store.update(id, log: .aboutChanged) { settings in
                settings.about = trimmedAbout
            }
        }
        Haptics.play(.success)
        router.back()
    }
}

final class ChannelInfoCard: UIView, UITextViewDelegate {
    static let height: CGFloat = 146

    var onChange: (@MainActor (_ name: String, _ about: String) -> Void)?

    private let nameField = UITextField()
    private let separator = UIView()
    private let aboutView = UITextView()
    private let placeholder = UILabel()

    init(name: String, about: String, presentation: PresentationData) {
        super.init(frame: .zero)
        let theme = presentation.theme
        let strings = presentation.strings
        backgroundColor = theme.colors.surface
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        nameField.text = name
        nameField.placeholder = strings.channelSettingsName
        nameField.font = theme.fonts.body
        nameField.textColor = theme.colors.textPrimary
        nameField.tintColor = theme.colors.accent
        nameField.addAction(
            UIAction { [weak self] _ in
                self?.changed()
            },
            for: .editingChanged
        )
        separator.backgroundColor = theme.colors.separator
        aboutView.text = about
        aboutView.backgroundColor = .clear
        aboutView.font = theme.fonts.body
        aboutView.textColor = theme.colors.textPrimary
        aboutView.tintColor = theme.colors.accent
        aboutView.textContainerInset = UIEdgeInsets(top: 12, left: 13, bottom: 8, right: 13)
        aboutView.delegate = self
        placeholder.text = strings.channelSettingsAbout
        placeholder.font = theme.fonts.body
        placeholder.textColor = theme.colors.textSecondary
        placeholder.isHidden = !about.isEmpty
        placeholder.isUserInteractionEnabled = false
        for subview in [nameField, separator, aboutView, placeholder] as [UIView] {
            addSubview(subview)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        nameField.frame = CGRect(x: 18, y: 0, width: bounds.width - 36, height: 52)
        separator.frame = CGRect(x: 18, y: 52, width: bounds.width - 18, height: 0.5)
        aboutView.frame = CGRect(x: 0, y: 53, width: bounds.width, height: bounds.height - 53)
        placeholder.frame = CGRect(x: 18, y: 65, width: bounds.width - 36, height: ceil(placeholder.font.lineHeight))
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
        changed()
    }

    private func changed() {
        onChange?(nameField.text ?? "", aboutView.text ?? "")
    }
}
