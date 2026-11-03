import Haptics
import UIKit

final class StoryAdjustPanel: UIView {
    static let height: CGFloat = 268

    private enum Slider: CaseIterable {
        case brightness
        case contrast
        case saturation
        case warmth
        case vignette
    }

    var onChange: (@MainActor (StoryAdjustments) -> Void)?

    private let strings: StoryStudioStrings
    private let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let filters = UIScrollView()
    private let resetButton = UIButton(type: .system)
    private var filterButtons: [UIButton] = []
    private var sliders: [(Slider, UILabel, UISlider)] = []
    private(set) var adjustments: StoryAdjustments

    init(adjustments: StoryAdjustments, strings: StoryStudioStrings) {
        self.adjustments = adjustments
        self.strings = strings
        super.init(frame: .zero)
        backdrop.layer.cornerRadius = 22
        backdrop.layer.cornerCurve = .continuous
        backdrop.clipsToBounds = true
        addSubview(backdrop)
        setUpFilters()
        setUpSliders()
        resetButton.setTitle(strings.label(.reset), for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        resetButton.tintColor = .systemYellow
        resetButton.addAction(UIAction { [weak self] _ in
            self?.reset()
        }, for: .touchUpInside)
        backdrop.contentView.addSubview(resetButton)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setUpFilters() {
        filters.showsHorizontalScrollIndicator = false
        filterButtons = StoryFilter.allCases.map { filter in
            let button = UIButton(type: .system)
            button.setTitle(strings.label(Self.label(filter)), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.layer.cornerRadius = 16
            button.addAction(UIAction { [weak self] _ in
                self?.adjustments.filter = filter
                Haptics.play(.selection)
                self?.changed()
            }, for: .touchUpInside)
            filters.addSubview(button)

            return button
        }
        backdrop.contentView.addSubview(filters)
    }

    private func setUpSliders() {
        sliders = Slider.allCases.map { slider in
            let label = UILabel()
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(0.8)
            label.text = strings.label(Self.label(slider))
            let control = UISlider()
            control.minimumValue = slider == .vignette ? 0 : -1
            control.maximumValue = 1
            control.minimumTrackTintColor = .white
            control.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.25)
            control.addAction(UIAction { [weak self, weak control] _ in
                self?.set(slider, Double(control?.value ?? 0))
            }, for: .valueChanged)
            backdrop.contentView.addSubview(label)
            backdrop.contentView.addSubview(control)

            return (slider, label, control)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backdrop.frame = bounds
        filters.frame = CGRect(x: 0, y: 14, width: bounds.width - 90, height: 32)
        resetButton.frame = CGRect(x: bounds.width - 86, y: 14, width: 74, height: 32)
        var x: CGFloat = 14
        for button in filterButtons {
            let width = ceil(button.intrinsicContentSize.width) + 28
            button.frame = CGRect(x: x, y: 0, width: width, height: 32)
            x += width + 8
        }
        filters.contentSize = CGSize(width: x + 6, height: 32)
        var y: CGFloat = 60
        for (_, label, slider) in sliders {
            label.frame = CGRect(x: 16, y: y, width: 96, height: 32)
            slider.frame = CGRect(x: 112, y: y, width: bounds.width - 128, height: 32)
            y += 40
        }
    }

    private func set(_ slider: Slider, _ value: Double) {
        let snapped = abs(value) < 0.04 ? 0 : value
        switch slider {
        case .brightness:
            adjustments.brightness = snapped
        case .contrast:
            adjustments.contrast = snapped
        case .saturation:
            adjustments.saturation = snapped
        case .warmth:
            adjustments.warmth = snapped
        case .vignette:
            adjustments.vignette = snapped
        }
        onChange?(adjustments)
    }

    private func reset() {
        adjustments = StoryAdjustments()
        Haptics.play(.tap)
        changed()
    }

    private func changed() {
        refresh()
        onChange?(adjustments)
    }

    private func refresh() {
        for (index, button) in filterButtons.enumerated() {
            let isSelected = StoryFilter.allCases[index] == adjustments.filter
            button.backgroundColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.12)
            button.tintColor = isSelected ? .black : .white
        }
        for (slider, _, control) in sliders {
            control.value = Float(value(of: slider))
        }
        resetButton.isHidden = adjustments.isIdentity
    }

    private func value(of slider: Slider) -> Double {
        switch slider {
        case .brightness:
            adjustments.brightness
        case .contrast:
            adjustments.contrast
        case .saturation:
            adjustments.saturation
        case .warmth:
            adjustments.warmth
        case .vignette:
            adjustments.vignette
        }
    }

    private static func label(_ slider: Slider) -> StoryLabel {
        switch slider {
        case .brightness:
            .brightness
        case .contrast:
            .contrast
        case .saturation:
            .saturation
        case .warmth:
            .warmth
        case .vignette:
            .vignette
        }
    }

    private static func label(_ filter: StoryFilter) -> StoryLabel {
        switch filter {
        case .original:
            .filterOriginal
        case .vivid:
            .filterVivid
        case .warm:
            .filterWarm
        case .cool:
            .filterCool
        case .fade:
            .filterFade
        case .mono:
            .filterMono
        case .noir:
            .filterNoir
        case .chrome:
            .filterChrome
        }
    }
}
