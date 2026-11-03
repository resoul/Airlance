import Haptics
import Theme
import UIKit

final class ChatMetricController: ScreenViewController {
    enum Metric {
        case textSize
        case corners

        var range: ClosedRange<Int> {
            switch self {
            case .textSize:
                ChatAppearance.textSizeRange
            case .corners:
                ChatAppearance.radiusRange
            }
        }
    }

    private let dependencies: AppearanceDependencies
    private let metric: Metric
    private let preview = ChatAppearancePreview()
    private let panel = UIView()
    private let slider = UISlider()
    private let minLabel = UILabel()
    private let maxLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let applyButton = UIButton(type: .system)
    private let divider = UIView()
    private var value: Int

    init(dependencies: AppearanceDependencies, metric: Metric) {
        self.dependencies = dependencies
        self.metric = metric
        let chat = dependencies.themeStore.settings.chat
        value = metric == .textSize ? chat.textSize : chat.bubbleRadius
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        preview.layer.cornerRadius = 0
        preview.alignsToBottom = true
        view.addSubview(preview)
        slider.minimumValue = Float(metric.range.lowerBound)
        slider.maximumValue = Float(metric.range.upperBound)
        slider.value = Float(value)
        slider.addAction(UIAction { [weak self] _ in
            self?.moved()
        }, for: .valueChanged)
        for view in [slider, minLabel, maxLabel, cancelButton, applyButton, divider] {
            panel.addSubview(view)
        }
        cancelButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)
        applyButton.addAction(UIAction { [weak self] _ in
            self?.save()
        }, for: .touchUpInside)
        view.addSubview(panel)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bottom = view.safeAreaInsets.bottom
        let height: CGFloat = 132 + bottom
        panel.frame = CGRect(x: 0, y: view.bounds.height - height, width: view.bounds.width, height: height)
        preview.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: panel.frame.minY)
        preview.contentInsets = UIEdgeInsets(top: view.safeAreaInsets.top, left: 0, bottom: 0, right: 0)
        let width = panel.bounds.width
        minLabel.frame = CGRect(x: 16, y: 18, width: 30, height: 36)
        maxLabel.frame = CGRect(x: width - 46, y: 18, width: 30, height: 36)
        slider.frame = CGRect(x: 52, y: 18, width: width - 104, height: 36)
        divider.frame = CGRect(x: width / 2, y: 76, width: 1 / max(view.traitCollection.displayScale, 1), height: 56)
        cancelButton.frame = CGRect(x: 0, y: 76, width: width / 2, height: 56)
        applyButton.frame = CGRect(x: width / 2, y: 76, width: width / 2, height: 56)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let strings = presentation.strings
        let colors = presentation.theme.colors
        navigationItem.title = metric == .textSize ? strings.chatAppearanceTextSize : strings.themeCorners
        view.backgroundColor = colors.background
        panel.backgroundColor = colors.surface
        divider.backgroundColor = colors.separator
        slider.minimumTrackTintColor = colors.accent
        minLabel.text = metric == .textSize ? "A" : "▢"
        maxLabel.text = metric == .textSize ? "A" : "◯"
        minLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        maxLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        for label in [minLabel, maxLabel] {
            label.textColor = colors.textSecondary
            label.textAlignment = .center
        }
        cancelButton.setTitle(strings.chatCancel, for: .normal)
        applyButton.setTitle(strings.themeApply, for: .normal)
        cancelButton.titleLabel?.font = presentation.theme.fonts.body
        applyButton.titleLabel?.font = presentation.theme.fonts.body.withWeight(.semibold)
        cancelButton.tintColor = colors.textPrimary
        applyButton.tintColor = colors.accent
        renderPreview()
    }

    private func renderPreview() {
        preview.apply(.make(
            presentation,
            radius: metric == .corners ? value : nil,
            textSize: metric == .textSize ? value : nil
        ))
    }

    private func moved() {
        let next = Int(slider.value.rounded())
        guard next != value else {
            return
        }

        value = next
        Haptics.play(.selection)
        renderPreview()
    }

    private func save() {
        let store = dependencies.themeStore
        var chat = store.settings.chat
        switch metric {
        case .textSize:
            chat.textSize = value
        case .corners:
            chat.bubbleRadius = value
        }
        Task {
            try? await store.setChat(chat)
        }
        Haptics.play(.success)
        navigationController?.popViewController(animated: true)
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])

        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
