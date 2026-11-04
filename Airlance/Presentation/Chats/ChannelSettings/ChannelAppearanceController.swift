import ChatHistory
import Haptics
import ListUI
import Theme
import ToastUI
import UIKit

enum ChannelPalette {
    static let freeCount = 7
    static let colors: [UInt32] = [
        0x4A90D9, 0x5FAE3C, 0xD1863A, 0xC8574C, 0x9060DB, 0x4A9DB5, 0xC25A92,
        0x2F6FB0, 0x2E8B6F, 0xE0A92E, 0xE36F5A, 0x6B4FC7, 0x31B8A6, 0x7F8A99,
    ]

    static func color(_ value: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

final class ChannelAppearanceController: ScreenViewController {
    private let id: String
    private let dependencies: ChannelSettingsDependencies
    private let router: AppRouter
    private let previewHost = UIView()
    private let previewWallpaper = ChatWallpaperView()
    private let previewList = ListView(theme: ListTheme())
    private let listView = ListView(theme: ListTheme())
    private let palette = ChannelColorPaletteView()
    private let wallpapers = ThemeCardsView(layout: .grid(columns: 3), aspect: 1.5)
    private var color: UInt32?
    private var wallpaper: ChatWallpaper?
    private var previewHeight: CGFloat = 0

    init(id: String, dependencies: ChannelSettingsDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        self.router = router
        let settings = dependencies.settings.settings(id)
        color = settings.color
        wallpaper = settings.wallpaper
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
        previewHost.clipsToBounds = true
        previewHost.addSubview(previewWallpaper)
        previewHost.addSubview(previewList.view)
        previewList.view.isUserInteractionEnabled = false
        view.addSubview(previewHost)
        palette.onSelect = { [weak self] index in
            self?.colorTapped(index)
        }
        wallpapers.onSelect = { [weak self] index in
            self?.wallpaperTapped(index)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let changed = listView.frame.width != view.bounds.width
        let top = view.safeAreaInsets.top
        previewHost.frame = CGRect(x: 0, y: top, width: view.bounds.width, height: previewHeight)
        previewWallpaper.frame = previewHost.bounds
        previewList.frame = previewHost.bounds
        listView.frame = view.bounds
        var insets = view.safeAreaInsets
        insets.top += previewHeight
        listView.contentInsets = insets
        if changed {
            render()
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        navigationItem.title = presentation.strings.channelAppearanceTitle
        navigationItem.rightBarButtonItem?.tintColor = theme.colors.accent
        view.backgroundColor = theme.colors.background
        previewHost.backgroundColor = theme.colors.background
        listView.theme = .settings(theme)
        previewList.theme = ListTheme(
            background: .clear,
            rowBackground: .clear,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.caption
        )
        render()
    }

    private var level: OnAirLevel {
        OnAirLevel(score: dependencies.onAir.channel(id)?.score ?? 0)
    }

    private var kinds: [ChatWallpaper] {
        WallpapersController.kinds
    }

    private func render() {
        guard isViewLoaded, view.bounds.width > 0 else {
            return
        }

        renderPreview()
        renderControls()
        let strings = presentation.strings
        let width = view.bounds.width - 32
        let selected = kinds.firstIndex(of: wallpaper ?? ChatWallpaper.none) ?? 0
        var items: [any ListItem] = [
            SpacerItem(id: "top", height: 12),
            ViewHostItem(
                id: "palette",
                height: palette.height(for: width),
                content: palette,
                revision: Int(color ?? 0)
            ),
            FootnoteItem(id: "color-hint", text: strings.channelAppearanceColorHint),
            ViewHostItem(
                id: "wallpapers",
                height: wallpapers.height(for: width, count: kinds.count, captions: true),
                content: wallpapers,
                revision: selected
            ),
            FootnoteItem(id: "wallpaper-hint", text: wallpaperHint),
        ]
        if dependencies.onAir.channel(id) != nil, !level.allowsAllChannelColors || !level.allowsChannelWallpaper {
            items.append(SettingsOptionItem(
                id: "levels",
                title: strings.channelReactionsUpgrade,
                symbol: "bolt.fill",
                iconColor: .systemIndigo,
                accessory: .chevron,
                onSelect: { [weak self] in
                    self?.showLevels()
                }
            ))
        }
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
    }

    private func renderControls() {
        let strings = presentation.strings
        let theme = presentation.theme
        palette.apply(
            colors: ChannelPalette.colors,
            selected: color,
            unlocked: level.allowsAllChannelColors ? ChannelPalette.colors.count : ChannelPalette.freeCount,
            theme: theme
        )
        let models = kinds.map { kind in
            ThemeCardModel(
                wallpaper: kind.resolved(for: theme.appearance),
                background: theme.colors.background,
                outgoing: theme.chat.outgoingColors,
                incoming: theme.colors.surface,
                caption: strings.title(for: kind)
            )
        }
        wallpapers.apply(models, selected: kinds.firstIndex(of: wallpaper ?? ChatWallpaper.none), theme: theme)
    }

    private var wallpaperHint: String {
        let strings = presentation.strings
        guard level.allowsChannelWallpaper else {
            return strings.channelAppearanceWallpaperLocked(OnAirLevel.silver.title(strings))
        }

        return strings.channelAppearanceWallpaperHint
    }

    private func renderPreview() {
        let theme = presentation.theme
        let resolved = wallpaper.flatMap { kind in
            kind == ChatWallpaper.none ? nil : kind.resolved(for: theme.appearance)
        } ?? theme.chat.wallpaper
        previewWallpaper.apply(resolved)
        let settings = ChannelSettings(color: color, wallpaper: wallpaper)
        let style = HistoryStyle(theme: theme).applying(settings)
        let items = previewItems(style: style)
        previewList.apply(items: items, animated: false)
        let rows = items.reduce(CGFloat(0)) { total, item in
            total + item.height(for: view.bounds.width, theme: previewList.theme)
        }
        let height = rows + 16
        if height != previewHeight {
            previewHeight = height
            view.setNeedsLayout()
        }
    }

    private func previewItems(style: HistoryStyle) -> [any ListItem] {
        let strings = presentation.strings
        let name = dependencies.chatsStore.chat(id)?.name ?? ""
        let quoted = HistoryMessage(
            id: "quoted",
            authorID: id,
            authorName: name,
            isOutgoing: false,
            date: Date(),
            content: .text(strings.channelAppearancePreviewQuote)
        )
        let preview = LinkPreview(
            site: "Airlance",
            title: strings.channelAppearancePreviewLinkTitle,
            summary: strings.channelAppearancePreviewLinkText,
            photo: nil,
            hasLargePhoto: false
        )
        let message = HistoryMessage(
            id: "preview-\(color ?? 0)-\(wallpaper?.rawValue ?? "")",
            authorID: id,
            authorName: name,
            isOutgoing: false,
            date: Date(),
            content: .text(strings.channelAppearancePreviewText),
            reply: MessageReply(quoted),
            link: MessageLink(url: "https://airlance.app", preview: preview)
        )
        let snapshot = HistorySnapshot(previewRequest(message, style: style))

        return snapshot.rows.compactMap { row -> (any ListItem)? in
            guard case .message(let id, let layout) = row else {
                return nil
            }

            return MessageBubbleItem(layout: layout, color: style.bubble(outgoing: false), messageID: id)
        }
    }

    private func previewRequest(_ message: HistoryMessage, style: HistoryStyle) -> HistorySnapshot.Request {
        let strings = presentation.strings

        return HistorySnapshot.Request(
            messages: [message],
            contextBefore: nil,
            contextAfter: nil,
            unreadFrom: nil,
            showsNames: true,
            showsAvatars: false,
            width: view.bounds.width,
            scale: traitCollection.displayScale,
            style: style,
            locale: strings.pack.locale,
            titles: HistorySnapshot.Titles(strings: strings),
            previous: [:]
        )
    }
}

extension ChannelAppearanceController {
    private func colorTapped(_ index: Int) {
        guard index < ChannelPalette.freeCount || level.allowsAllChannelColors else {
            denied(presentation.strings.channelAppearanceColorLocked(OnAirLevel.bronze.title(presentation.strings)))

            return
        }

        Haptics.play(.selection)
        let value = ChannelPalette.colors[index]
        color = color == value ? nil : value
        render()
    }

    private func wallpaperTapped(_ index: Int) {
        guard kinds.indices.contains(index) else {
            return
        }

        guard level.allowsChannelWallpaper || kinds[index] == ChatWallpaper.none else {
            denied(presentation.strings.channelAppearanceWallpaperLocked(OnAirLevel.silver.title(presentation.strings)))

            return
        }

        Haptics.play(.selection)
        wallpaper = kinds[index] == ChatWallpaper.none ? nil : kinds[index]
        render()
    }

    private func denied(_ text: String) {
        Haptics.play(.warning)
        Toast(text, symbol: "lock.fill").show(theme: presentation.theme, in: view)
    }

    private func showLevels() {
        let content = ChannelLevelsController(channelID: id, store: dependencies.onAir, presentation: presentation)
        let sheet = FloatingSheetController(content: content, theme: presentation.theme) { _ in
            720
        }
        present(sheet, animated: false)
    }

    private func save() {
        let color = color
        let wallpaper = wallpaper
        let old = dependencies.settings.settings(id)
        if old.color != color || old.wallpaper != wallpaper {
            dependencies.settings.update(id, log: .appearanceChanged) { settings in
                settings.color = color
                settings.wallpaper = wallpaper
            }
        }
        Haptics.play(.success)
        router.back()
    }
}

final class ChannelColorPaletteView: UIView {
    private static let columns = 7
    private static let side: CGFloat = 34

    var onSelect: (@MainActor (Int) -> Void)?

    private var buttons: [UIButton] = []

    func height(for width: CGFloat) -> CGFloat {
        let rows = (ChannelPalette.colors.count + Self.columns - 1) / Self.columns

        return CGFloat(rows) * (Self.side + 14) + 18
    }

    func apply(colors: [UInt32], selected: UInt32?, unlocked: Int, theme: AppTheme) {
        backgroundColor = theme.colors.surface
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        if buttons.count != colors.count {
            buttons.forEach { button in
                button.removeFromSuperview()
            }
            buttons = colors.indices.map { index in
                let button = UIButton(type: .custom)
                button.addAction(
                    UIAction { [weak self] _ in
                        self?.onSelect?(index)
                    },
                    for: .touchUpInside
                )
                addSubview(button)

                return button
            }
        }
        for (index, button) in buttons.enumerated() {
            let color = ChannelPalette.color(colors[index])
            button.backgroundColor = color
            button.layer.cornerRadius = Self.side / 2
            button.layer.borderWidth = colors[index] == selected ? 3 : 0
            button.layer.borderColor = theme.colors.textPrimary.cgColor
            button.alpha = index < unlocked ? 1 : 0.35
            let isLocked = index >= unlocked
            button.setImage(isLocked ? UIImage(systemName: "lock.fill") : nil, for: .normal)
            button.tintColor = .white
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let gap = (bounds.width - 24 - Self.side * CGFloat(Self.columns)) / CGFloat(Self.columns - 1)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(
                x: 12 + CGFloat(index % Self.columns) * (Self.side + gap),
                y: 16 + CGFloat(index / Self.columns) * (Self.side + 14),
                width: Self.side,
                height: Self.side
            )
        }
    }
}
