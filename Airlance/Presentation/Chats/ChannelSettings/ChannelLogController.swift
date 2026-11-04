import ListUI
import Observers
import UIKit

final class ChannelLogController: ScreenViewController {
    private let id: String
    private let store: ChannelSettingsStore
    private let listView = ListView(theme: ListTheme())
    private var observation: ObservationToken?

    init(id: String, store: ChannelSettingsStore, presentationSource: PresentationContext) {
        self.id = id
        self.store = store
        super.init(presentationSource: presentationSource)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        observation = store.observe { [weak self] _ in
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        listView.theme = .settings(presentation.theme)
        navigationItem.title = presentation.strings.channelSettingsLog
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let log = store.settings(id).log
        let formatter = DateFormatter()
        formatter.locale = strings.pack.locale
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        var items: [any ListItem] = [SpacerItem(id: "top", height: 8)]
        if log.isEmpty {
            items.append(FootnoteItem(id: "empty", text: strings.channelLogEmpty))
        }
        let rows = log.enumerated().map { index, entry in
            SettingsOptionItem(
                id: "entry-\(index)-\(entry.date.timeIntervalSince1970)",
                title: Self.title(entry, strings: strings),
                subtitle: formatter.string(from: entry.date)
            )
        }
        items += rows.positioned() as [any ListItem]
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
    }

    private static func title(_ entry: ChannelLogEntry, strings: AppStrings) -> String {
        switch entry.kind {
        case .renamed:
            strings.channelLogRenamed(entry.detail)
        case .aboutChanged:
            strings.channelLogAbout
        case .madePublic:
            strings.channelLogPublic
        case .madePrivate:
            strings.channelLogPrivate
        case .linkChanged:
            strings.channelLogLink(entry.detail)
        case .copyingRestricted:
            strings.channelLogCopyOff
        case .copyingAllowed:
            strings.channelLogCopyOn
        case .reactionsChanged:
            strings.channelLogReactions
        case .signaturesOn:
            strings.channelLogSignOn
        case .signaturesOff:
            strings.channelLogSignOff
        case .adminAdded:
            strings.channelLogAdminAdded(entry.detail)
        case .adminRemoved:
            strings.channelLogAdminRemoved(entry.detail)
        case .banned:
            strings.channelLogBanned(entry.detail)
        case .unbanned:
            strings.channelLogUnbanned(entry.detail)
        case .appearanceChanged:
            strings.channelLogAppearance
        }
    }
}
