import Observers
import Theme
import UIKit

struct ChatAppearanceDependencies {
    let presentationContext: PresentationContext
    let themeStore: ThemeStore
}

final class ChatAppearanceViewController: ScreenViewController {
    private let dependencies: ChatAppearanceDependencies
    private let preview = ChatAppearancePreview()
    private let fillLabel = UILabel()
    private let radiusLabel = UILabel()
    private let textSizeLabel = UILabel()
    private let wallpaperLabel = UILabel()
    private let fillControl = UISegmentedControl(items: BubbleFill.allCases.map(\.rawValue))
    private let radiusSlider = UISlider()
    private let textSizeSlider = UISlider()
    private let radiusValue = UILabel()
    private let textSizeValue = UILabel()
    private let swatches = ChatWallpaper.allCases.map { kind in
        WallpaperSwatch(kind: kind)
    }
    private var draft: ChatAppearance
    private var settingsObservation: ObservationToken?

    private var sectionLabels: [UILabel] {
        [fillLabel, radiusLabel, textSizeLabel, wallpaperLabel]
    }

    init(dependencies: ChatAppearanceDependencies) {
        self.dependencies = dependencies
        draft = dependencies.themeStore.settings.chat
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        setUpControls()
        setUpLayout()
        settingsObservation = dependencies.themeStore.observeSettings { [weak self] settings in
            self?.showSettings(settings.chat)
        }
    }

    private func setUpControls() {
        fillControl.addTarget(self, action: #selector(fillChanged), for: .valueChanged)
        configure(radiusSlider, range: ChatAppearance.radiusRange)
        configure(textSizeSlider, range: ChatAppearance.textSizeRange)
        for swatch in swatches {
            swatch.addAction(
                UIAction { [weak self, kind = swatch.kind] _ in
                    self?.save { chat in
                        chat.wallpaper = kind
                    }
                },
                for: .touchUpInside
            )
        }
    }

    private func configure(_ slider: UISlider, range: ClosedRange<Int>) {
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.addTarget(self, action: #selector(sliderMoved), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    private func setUpLayout() {
        let swatchRow = UIStackView(arrangedSubviews: swatches)
        swatchRow.distribution = .equalSpacing
        let stack = UIStackView(arrangedSubviews: [
            preview,
            section(fillLabel, fillControl),
            section(radiusLabel, row(radiusSlider, radiusValue)),
            section(textSizeLabel, row(textSizeSlider, textSizeValue)),
            section(wallpaperLabel, swatchRow),
        ])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        let content = scroll.contentLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            preview.heightAnchor.constraint(equalToConstant: 190),
        ])
    }

    private func section(_ label: UILabel, _ control: UIView) -> UIStackView {
        let section = UIStackView(arrangedSubviews: [label, control])
        section.axis = .vertical
        section.spacing = 10

        return section
    }

    private func row(_ slider: UISlider, _ value: UILabel) -> UIStackView {
        value.textAlignment = .right
        value.widthAnchor.constraint(equalToConstant: 36).isActive = true
        let row = UIStackView(arrangedSubviews: [slider, value])
        row.spacing = 12

        return row
    }

    private func showSettings(_ chat: ChatAppearance) {
        guard !radiusSlider.isTracking, !textSizeSlider.isTracking else {
            return
        }

        draft = chat
        fillControl.selectedSegmentIndex = BubbleFill.allCases.firstIndex(of: chat.fill) ?? 0
        radiusSlider.value = Float(chat.bubbleRadius)
        textSizeSlider.value = Float(chat.textSize)
        for swatch in swatches {
            swatch.isChosen = swatch.kind == chat.wallpaper
        }
        renderDraft()
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let strings = presentation.strings
        navigationItem.title = strings.settingsChatAppearance
        fillLabel.text = strings.chatAppearanceFill
        radiusLabel.text = strings.chatAppearanceRadius
        textSizeLabel.text = strings.chatAppearanceTextSize
        wallpaperLabel.text = strings.chatAppearanceWallpaper
        for (index, fill) in BubbleFill.allCases.enumerated() {
            fillControl.setTitle(strings.title(for: fill), forSegmentAt: index)
        }
        for label in sectionLabels {
            label.font = theme.fonts.subheadline
            label.textColor = theme.colors.textSecondary
        }
        for label in [radiusValue, textSizeValue] {
            label.font = theme.fonts.subheadline
            label.textColor = theme.colors.textPrimary
        }
        fillControl.selectedSegmentTintColor = theme.colors.accent
        fillControl.setTitleTextAttributes([.font: theme.fonts.subheadline], for: .normal)
        for slider in [radiusSlider, textSizeSlider] {
            slider.minimumTrackTintColor = theme.colors.accent
        }
        for swatch in swatches {
            swatch.apply(theme, title: strings.title(for: swatch.kind))
        }
        renderDraft()
    }

    private func renderDraft() {
        radiusValue.text = "\(draft.bubbleRadius)"
        textSizeValue.text = "\(draft.textSize)"
        let theme = presentation.theme
        let saved = CGFloat(max(1, dependencies.themeStore.settings.chat.textSize))
        let font = theme.chat.messageFont
        preview.apply(
            ChatPreviewModel(
                incoming: presentation.strings.chatAppearancePreviewIncoming,
                outgoing: presentation.strings.chatAppearancePreviewOutgoing,
                font: font.withSize(font.pointSize * CGFloat(draft.textSize) / saved),
                radius: CGFloat(draft.bubbleRadius),
                outgoingColors: theme.chat.outgoingColors,
                incomingColor: theme.colors.surface,
                incomingText: theme.colors.textPrimary,
                outgoingText: theme.colors.onAccent,
                background: theme.colors.background,
                wallpaper: theme.chat.wallpaper
            )
        )
    }

    private func save(_ change: (inout ChatAppearance) -> Void) {
        change(&draft)
        renderDraft()
        persist()
    }

    private func persist() {
        let chat = draft
        let store = dependencies.themeStore
        Task { [weak self] in
            do {
                try await store.setChat(chat)
            } catch {
                self?.showSettings(store.settings.chat)
            }
        }
    }

    @objc
    private func fillChanged() {
        let fill = BubbleFill.allCases[fillControl.selectedSegmentIndex]
        save { chat in
            chat.fill = fill
        }
    }

    @objc
    private func sliderMoved() {
        draft.bubbleRadius = Int(radiusSlider.value.rounded())
        draft.textSize = Int(textSizeSlider.value.rounded())
        renderDraft()
    }

    @objc
    private func sliderReleased() {
        sliderMoved()
        persist()
    }
}
