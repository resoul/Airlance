import Haptics
import ListUI
import UIKit

final class ChannelTypeController: ScreenViewController {
    private let id: String
    private let dependencies: ChannelSettingsDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private let linkCard = UIView()
    private let linkPrefix = UILabel()
    private let linkField = UITextField()
    private var isPrivate: Bool
    private var restrictsCopying: Bool

    init(id: String, dependencies: ChannelSettingsDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        self.router = router
        let settings = dependencies.settings
        isPrivate = settings.settings(id).isPrivate ?? false
        restrictsCopying = settings.restrictsCopying(id)
        linkField.text = settings.link(of: id)
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
        linkPrefix.text = "airlance.app/"
        linkField.autocapitalizationType = .none
        linkField.autocorrectionType = .no
        linkField.keyboardType = .asciiCapable
        linkField.addAction(
            UIAction { [weak self] _ in
                self?.updateSave()
            },
            for: .editingChanged
        )
        linkCard.addSubview(linkPrefix)
        linkCard.addSubview(linkField)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        let width = linkCard.bounds.width
        let prefix = ceil(linkPrefix.intrinsicContentSize.width)
        linkPrefix.frame = CGRect(x: 18, y: 0, width: prefix, height: linkCard.bounds.height)
        linkField.frame = CGRect(
            x: 18 + prefix,
            y: 0,
            width: max(0, width - 36 - prefix),
            height: linkCard.bounds.height
        )
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        navigationItem.title = presentation.strings.channelSettingsType
        navigationItem.rightBarButtonItem?.tintColor = theme.colors.accent
        listView.theme = .settings(theme)
        linkCard.backgroundColor = theme.colors.surface
        linkCard.layer.cornerRadius = 26
        linkCard.layer.cornerCurve = .continuous
        linkPrefix.font = theme.fonts.body
        linkPrefix.textColor = theme.colors.textSecondary
        linkField.font = theme.fonts.body
        linkField.textColor = theme.colors.textPrimary
        linkField.tintColor = theme.colors.accent
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        var items: [any ListItem] = [
            SpacerItem(id: "top", height: 8),
            SectionHeaderItem(id: "type-header", title: strings.channelSettingsLinkSection),
        ]
        items += typeRows().positioned() as [any ListItem]
        items.append(FootnoteItem(
            id: "type-hint",
            text: isPrivate ? strings.channelSettingsPrivateHint : strings.channelSettingsPublicHint
        ))
        if !isPrivate {
            items.append(ViewHostItem(id: "link", height: 52, content: linkCard))
            items.append(FootnoteItem(id: "link-hint", text: strings.channelSettingsLinkHint))
        }
        items.append(SectionHeaderItem(id: "copy-header", title: strings.channelSettingsCopySection))
        items.append(SettingsOptionItem(
            id: "copy",
            title: strings.channelSettingsCopy,
            accessory: .toggle(restrictsCopying),
            onToggle: { [weak self] isOn in
                self?.restrictsCopying = isOn
            }
        ))
        items.append(FootnoteItem(id: "copy-hint", text: strings.channelSettingsCopyHint))
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
        updateSave()
    }

    private func typeRows() -> [SettingsOptionItem] {
        let strings = presentation.strings

        return [
            SettingsOptionItem(
                id: "public",
                title: strings.channelSettingsPublic,
                accessory: .check(!isPrivate),
                onSelect: { [weak self] in
                    self?.setPrivate(false)
                }
            ),
            SettingsOptionItem(
                id: "private",
                title: strings.channelSettingsPrivate,
                accessory: .check(isPrivate),
                onSelect: { [weak self] in
                    self?.setPrivate(true)
                }
            ),
        ]
    }

    private func setPrivate(_ value: Bool) {
        guard value != isPrivate else {
            return
        }

        Haptics.play(.selection)
        isPrivate = value
        view.endEditing(true)
        render()
    }

    private var link: String {
        (linkField.text ?? "").trimmingCharacters(in: .whitespaces)
    }

    private func updateSave() {
        navigationItem.rightBarButtonItem?.isEnabled = isPrivate || MyProfile.isValidUsername(link)
    }

    private func save() {
        view.endEditing(true)
        let store = dependencies.settings
        let old = store.settings(id)
        if isPrivate != (old.isPrivate ?? false) {
            store.update(id, log: isPrivate ? .madePrivate : .madePublic) { settings in
                settings.isPrivate = isPrivate
            }
            dependencies.chatsStore.setPublic(!isPrivate, id: id)
        }
        if !isPrivate, link != store.link(of: id) {
            store.update(id, log: .linkChanged, detail: link) { settings in
                settings.link = link
            }
        }
        if restrictsCopying != store.restrictsCopying(id) {
            store.update(id, log: restrictsCopying ? .copyingRestricted : .copyingAllowed) { settings in
                settings.restrictsCopying = restrictsCopying
            }
        }
        Haptics.play(.success)
        router.back()
    }
}
