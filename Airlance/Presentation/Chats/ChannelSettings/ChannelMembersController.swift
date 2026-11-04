import AirlanceUI
import Haptics
import ListUI
import Observers
import ToastUI
import UIKit

final class ChannelMembersController: ScreenViewController {
    private let id: String
    private let page: ChannelSettingsPage
    private let dependencies: ChannelSettingsDependencies
    private let listView = ListView(theme: ListTheme())
    private var observations: [ObservationToken] = []

    init(id: String, page: ChannelSettingsPage, dependencies: ChannelSettingsDependencies) {
        self.id = id
        self.page = page
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
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
        listView.theme = .settings(presentation.theme)
        navigationItem.title = title(presentation.strings)
        render()
    }

    private func title(_ strings: AppStrings) -> String {
        switch page {
        case .admins:
            return strings.channelSettingsAdmins
        case .banned:
            return strings.channelSettingsBanned
        default:
            return strings.channelSettingsSubscribers
        }
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        var items: [any ListItem] = [SpacerItem(id: "top", height: 8)]
        switch page {
        case .admins:
            items += adminItems()
        case .banned:
            items += bannedItems()
        default:
            items += subscriberItems()
        }
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
    }

    private var members: [GroupMember] {
        dependencies.members.members(in: id)
    }

    private func subscriberItems() -> [any ListItem] {
        let strings = presentation.strings
        var items: [any ListItem] = [
            actionRow("copy-link", title: strings.channelSettingsCopyLink, symbol: "link") { [weak self] in
                self?.copyLink()
            },
            FootnoteItem(id: "hint", text: strings.channelSettingsSubscribersHint),
        ]
        items += members.map { member in
            memberRow(member) { [weak self] in
                self?.subscriberTapped(member)
            }
        }

        return items
    }

    private func adminItems() -> [any ListItem] {
        let strings = presentation.strings
        let admins = members.filter { member in
            member.role < .member
        }
        var items: [any ListItem] = [
            actionRow("add-admin", title: strings.channelSettingsAddAdmin, symbol: "person.badge.plus") { [weak self] in
                self?.showAdminPicker()
            },
        ]
        items += admins.map { member in
            memberRow(member) { [weak self] in
                self?.adminTapped(member)
            }
        }
        items.append(FootnoteItem(id: "hint", text: strings.channelSettingsAdminsHint))
        items.append(SettingsOptionItem(
            id: "sign",
            title: strings.channelSettingsSign,
            accessory: .toggle(dependencies.settings.settings(id).signsMessages),
            onToggle: { [weak self] isOn in
                self?.setSigning(isOn)
            }
        ))
        items.append(FootnoteItem(id: "sign-hint", text: strings.channelSettingsSignHint))

        return items
    }

    private func bannedItems() -> [any ListItem] {
        let strings = presentation.strings
        var items: [any ListItem] = [
            actionRow("ban", title: strings.channelSettingsBan, symbol: "nosign") { [weak self] in
                self?.showBanPicker()
            },
            FootnoteItem(id: "hint", text: strings.channelSettingsBannedHint),
        ]
        items += dependencies.settings.settings(id).banned.map { banned in
            GroupMemberItem(
                member: GroupMember(id: banned.id, name: banned.name, role: .member, rights: [], isOnline: false),
                title: banned.name,
                detail: strings.channelSettingsBannedMember,
                badge: nil,
                symbol: nil
            ) { [weak self] in
                self?.bannedTapped(banned)
            }
        }

        return items
    }

    private func actionRow(
        _ id: String,
        title: String,
        symbol: String,
        action: @escaping @MainActor () -> Void
    ) -> SettingsOptionItem {
        SettingsOptionItem(
            id: id,
            title: title,
            symbol: symbol,
            isAction: true,
            onSelect: action
        )
    }

    private func memberRow(_ member: GroupMember, action: @escaping @MainActor () -> Void) -> GroupMemberItem {
        let strings = presentation.strings

        return GroupMemberItem(
            member: member,
            title: member.id == GroupMembersStore.me.id ? strings.chatYou : member.name,
            detail: member.isOnline ? strings.profileOnline : strings.profileLastSeen,
            badge: member.role == .member ? nil : strings.title(for: member.role),
            symbol: nil,
            onSelect: action
        )
    }
}

extension ChannelMembersController {
    private func menu(_ items: [PopupMenuItem]) {
        guard let host = view.window else {
            return
        }

        let anchor = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        PopupMenu.show(items, theme: presentation.theme, from: view.convert(anchor, to: host), in: host)
    }

    private func copyLink() {
        UIPasteboard.general.string = "https://airlance.app/\(dependencies.settings.link(of: id))"
        Haptics.play(.success)
        Toast(presentation.strings.chatCopied, symbol: "link").show(theme: presentation.theme, in: view)
    }

    private func subscriberTapped(_ member: GroupMember) {
        guard member.role != .owner else {
            return
        }

        menu([
            PopupMenuItem(
                title: presentation.strings.channelSettingsBan,
                symbol: "nosign",
                isDestructive: true
            ) { [weak self] in
                self?.ban(member)
            },
        ])
    }

    private func adminTapped(_ member: GroupMember) {
        guard member.role != .owner else {
            return
        }

        menu([
            PopupMenuItem(
                title: presentation.strings.channelSettingsRemoveAdmin,
                symbol: "person.badge.minus",
                isDestructive: true
            ) { [weak self] in
                self?.removeAdmin(member)
            },
        ])
    }

    private func showAdminPicker() {
        let candidates = members.filter { member in
            member.role == .member
        }
        menu(candidates.map { member in
            PopupMenuItem(title: member.name, symbol: "person") { [weak self] in
                self?.addAdmin(member)
            }
        })
    }

    private func showBanPicker() {
        let candidates = members.filter { member in
            member.role != .owner
        }
        menu(candidates.map { member in
            PopupMenuItem(title: member.name, symbol: "person") { [weak self] in
                self?.ban(member)
            }
        })
    }

    private func bannedTapped(_ banned: ChannelBannedMember) {
        menu([
            PopupMenuItem(
                title: presentation.strings.channelSettingsUnban,
                symbol: "arrow.uturn.backward"
            ) { [weak self] in
                self?.unban(banned)
            },
        ])
    }

    private func addAdmin(_ member: GroupMember) {
        dependencies.members.promote(member.id, rights: GroupRight.defaultAdmin, in: id)
        dependencies.settings.update(id, log: .adminAdded, detail: member.name) { _ in
        }
        Haptics.play(.success)
    }

    private func removeAdmin(_ member: GroupMember) {
        dependencies.members.demote(member.id, in: id)
        dependencies.settings.update(id, log: .adminRemoved, detail: member.name) { _ in
        }
    }

    private func ban(_ member: GroupMember) {
        dependencies.members.remove(member.id, from: id)
        dependencies.settings.update(id, log: .banned, detail: member.name) { settings in
            settings.banned.insert(ChannelBannedMember(id: member.id, name: member.name), at: 0)
        }
        Haptics.play(.warning)
    }

    private func unban(_ banned: ChannelBannedMember) {
        dependencies.members.add(
            GroupMember(id: banned.id, name: banned.name, role: .member, rights: [], isOnline: false),
            to: id
        )
        dependencies.settings.update(id, log: .unbanned, detail: banned.name) { settings in
            settings.banned.removeAll { item in
                item.id == banned.id
            }
        }
    }

    private func setSigning(_ isOn: Bool) {
        dependencies.settings.update(id, log: isOn ? .signaturesOn : .signaturesOff) { settings in
            settings.signsMessages = isOn
        }
    }
}
