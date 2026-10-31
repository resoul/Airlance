import Haptics
import UIKit

extension AttachSheet {
    func setupTabs() {
        tabBar.axis = .horizontal
        tabBar.distribution = .fillEqually
        for tab in tabs {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(
                systemName: symbol(of: tab),
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 20)
            )
            configuration.title = title(of: tab)
            configuration.imagePlacement = .top
            configuration.imagePadding = 4
            let font = presentation.theme.fonts.caption.withSize(11)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = font

                return attributes
            }
            button.configuration = configuration
            button.tag = tab.rawValue
            button.addAction(
                UIAction { [weak self] _ in
                    Haptics.play(.selection)
                    self?.select(tab)
                },
                for: .touchUpInside
            )
            tabBar.addArrangedSubview(button)
        }
        sheet.addSubview(tabBar)
    }

    func setupSendBar() {
        let colors = presentation.theme.colors
        sendBar.backgroundColor = colors.surface
        sendBar.alpha = 0
        sendBar.transform = CGAffineTransform(translationX: 0, y: 40)
        let box = UIView()
        box.backgroundColor = colors.background
        box.layer.cornerRadius = 19
        sendBar.addSubview(box)
        caption.placeholder = presentation.strings.attachCaption
        caption.font = presentation.theme.fonts.body
        caption.textColor = colors.textPrimary
        caption.tintColor = colors.accent
        caption.returnKeyType = .done
        caption.delegate = self
        box.addSubview(caption)
        sendButton.backgroundColor = colors.accent
        sendButton.layer.cornerRadius = 23
        sendButton.tintColor = colors.onAccent
        let arrow = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        sendButton.setImage(UIImage(systemName: "arrow.up", withConfiguration: arrow), for: .normal)
        sendButton.accessibilityLabel = presentation.strings.chatSend
        sendButton.addAction(
            UIAction { [weak self] _ in
                self?.send()
            },
            for: .touchUpInside
        )
        sendBar.addSubview(sendButton)
        countLabel.backgroundColor = colors.accent
        countLabel.textColor = colors.onAccent
        countLabel.font = .systemFont(ofSize: 12, weight: .bold)
        countLabel.textAlignment = .center
        countLabel.layer.cornerRadius = 11
        countLabel.layer.borderWidth = 2
        countLabel.layer.borderColor = colors.surface.cgColor
        countLabel.clipsToBounds = true
        sendBar.addSubview(countLabel)
        sheet.addSubview(sendBar)
    }

    func select(_ tab: Tab) {
        selected = tab
        let colors = presentation.theme.colors
        for case let button as UIButton in tabBar.arrangedSubviews {
            button.tintColor = button.tag == tab.rawValue ? colors.accent : colors.textSecondary
        }
        setTitle(gallery.selection.isEmpty || tab != .gallery
            ? title(of: tab)
            : presentation.strings.attachSelected(String(gallery.selection.count)))
        showContent()
        guard tab == .gallery || tab == .location, let authorize else {
            return
        }

        Task { [weak self] in
            let allowed = await authorize(tab)
            guard let self else {
                return
            }

            if allowed {
                self.refused.remove(tab)
            } else {
                self.refused.insert(tab)
            }
            self.accessResolved(tab, allowed: allowed)
        }
    }

    private func accessResolved(_ tab: Tab, allowed: Bool) {
        if allowed, tab == .gallery, !libraryShown {
            libraryShown = true
            gallery.show(AttachLibrary(), limited: isLimited?() ?? false)
        }
        if allowed, tab == .location {
            location.start()
        }
        if selected == tab {
            showContent()
        }
    }

    func showContent() {
        let strings = presentation.strings
        let locked = refused.contains(selected)
        switch selected {
        case .gallery:
            placeholder.show(
                symbol: "photo.on.rectangle.angled",
                text: strings.attachGalleryLocked,
                action: strings.attachAllow
            )
        case .file:
            placeholder.show(symbol: "doc.fill", text: strings.attachFileHint, action: strings.attachChooseFile)
        case .location:
            placeholder.show(
                symbol: "location.slash.fill",
                text: strings.attachLocationLocked,
                action: strings.attachAllow
            )
        case .poll:
            placeholder.show(symbol: "chart.bar.fill", text: strings.attachPollHint, action: strings.attachCreatePoll)
        }
        let showsGallery = selected == .gallery && !locked
        let showsLocation = selected == .location && !locked
        UIView.animate(withDuration: 0.25) {
            self.gallery.alpha = showsGallery ? 1 : 0
            self.location.alpha = showsLocation ? 1 : 0
            self.placeholder.alpha = showsGallery || showsLocation ? 0 : 1
        }
        let showsSend = selected == .gallery && !gallery.selection.isEmpty
        setSendBarShown(showsSend)
    }

    func selectionChanged(_ count: Int) {
        countLabel.text = "\(count)"
        setTitle(count == 0 ? title(of: .gallery) : presentation.strings.attachSelected(String(count)))
        setSendBarShown(count > 0)
    }

    private func setSendBarShown(_ isShown: Bool) {
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.sendBar.alpha = isShown ? 1 : 0
            self.sendBar.transform = isShown ? .identity : CGAffineTransform(translationX: 0, y: 40)
            self.tabBar.alpha = isShown ? 0 : 1
        }
    }

    func cameraTapped() {
        close { [onCamera] in
            onCamera?()
        }
    }

    func placeholderTapped() {
        switch selected {
        case .file:
            close { [onFile] in
                onFile?()
            }
        case .poll:
            close { [onPoll] in
                onPoll?()
            }
        case .gallery, .location:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func send() {
        let assets = gallery.selection.compactMap(gallery.asset(for:))
        let text = (caption.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        close { [onSendMedia] in
            onSendMedia?(assets, text)
        }
    }

    private func symbol(of tab: Tab) -> String {
        switch tab {
        case .gallery:
            "photo.on.rectangle"
        case .file:
            "doc"
        case .location:
            "location"
        case .poll:
            "chart.bar.xaxis"
        }
    }

    func title(of tab: Tab) -> String {
        let strings = presentation.strings
        switch tab {
        case .gallery:
            return strings.attachGallery
        case .file:
            return strings.attachFile
        case .location:
            return strings.attachLocation
        case .poll:
            return strings.pollAttach
        }
    }
}

final class AttachPlaceholder: UIView {
    var onAction: (@MainActor () -> Void)?

    private let icon = UIImageView()
    private let text = UILabel()
    private let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        icon.contentMode = .center
        addSubview(icon)
        text.textAlignment = .center
        text.numberOfLines = 0
        addSubview(text)
        button.addAction(
            UIAction { [weak self] _ in
                self?.onAction?()
            },
            for: .touchUpInside
        )
        addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        let colors = presentation.theme.colors
        icon.tintColor = colors.accent
        text.font = presentation.theme.fonts.body
        text.textColor = colors.textSecondary
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = colors.accent
        configuration.baseForegroundColor = colors.onAccent
        button.configuration = configuration
    }

    func show(symbol: String, text value: String, action: String) {
        icon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 46))
        text.text = value
        button.configuration?.title = action
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let midY = bounds.height / 2
        icon.frame = CGRect(x: 0, y: midY - 90, width: bounds.width, height: 60)
        text.frame = CGRect(x: 30, y: midY - 20, width: bounds.width - 60, height: 48)
        button.frame = CGRect(x: (bounds.width - 200) / 2, y: midY + 40, width: 200, height: 42)
    }
}
