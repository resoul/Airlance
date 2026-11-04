import Haptics
import UIKit

final class ChannelReactionsController: UIViewController {
    private static let columns = 8
    private static let palette = Reactions.quick + Reactions.more

    var onSave: (@MainActor (ChannelReactionRule, Int?) -> Void)?
    var onUpgrade: (@MainActor () -> Void)?

    private let presentation: PresentationData
    private let limit: @MainActor () -> Int
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let modes: UISegmentedControl
    private let hintLabel = UILabel()
    private let upgradeButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let perPostLabel = UILabel()
    private let perPostSlider = UISlider()
    private var cells: [UIButton] = []
    private var selected: Set<String>

    static func height(for width: CGFloat) -> CGFloat {
        let rows = (palette.count + columns - 1) / columns

        return 150 + CGFloat(rows) * (width - 32) / CGFloat(columns) + 72 + 44 + 8 + 50 + 20
    }

    init(
        rule: ChannelReactionRule,
        perPost: Int?,
        presentation: PresentationData,
        limit: @escaping @MainActor () -> Int
    ) {
        self.presentation = presentation
        perPostSlider.minimumValue = 1
        perPostSlider.maximumValue = Float(ChannelSettingsStore.maxReactionsPerPost)
        perPostSlider.value = Float(perPost ?? ChannelSettingsStore.maxReactionsPerPost)
        self.limit = limit
        let strings = presentation.strings
        modes = UISegmentedControl(items: [
            strings.channelReactionsAll,
            strings.channelReactionsSome,
            strings.channelReactionsNone,
        ])
        switch rule {
        case .all:
            modes.selectedSegmentIndex = 0
            selected = []
        case .some(let emojis):
            modes.selectedSegmentIndex = 1
            selected = Set(emojis)
        case .none:
            modes.selectedSegmentIndex = 2
            selected = []
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupControls()
        setupPerPost()
        cells = Self.palette.map { emoji in
            let cell = UIButton(type: .custom)
            cell.setTitle(emoji, for: .normal)
            cell.titleLabel?.font = .systemFont(ofSize: 26)
            cell.addAction(
                UIAction { [weak self] _ in
                    self?.toggle(emoji)
                },
                for: .touchUpInside
            )
            view.addSubview(cell)

            return cell
        }
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        closeButton.frame = CGRect(x: 16, y: 14, width: 44, height: 44)
        titleLabel.frame = CGRect(x: 68, y: 14, width: width - 136, height: 44)
        modes.frame = CGRect(x: 16, y: 72, width: width - 32, height: 36)
        hintLabel.frame = CGRect(x: 20, y: 114, width: width - 40, height: 30)
        let side = (width - 32) / CGFloat(Self.columns)
        for (index, cell) in cells.enumerated() {
            cell.frame = CGRect(
                x: 16 + CGFloat(index % Self.columns) * side,
                y: 150 + CGFloat(index / Self.columns) * side,
                width: side,
                height: side
            ).insetBy(dx: 2, dy: 2)
            cell.layer.cornerRadius = cell.frame.width / 2
        }
        saveButton.frame = CGRect(x: 16, y: view.bounds.height - 70, width: width - 32, height: 50)
        upgradeButton.frame = CGRect(x: 16, y: saveButton.frame.minY - 52, width: width - 32, height: 44)
        perPostLabel.frame = CGRect(x: 20, y: upgradeButton.frame.minY - 66, width: width - 40, height: 22)
        perPostSlider.frame = CGRect(x: 20, y: perPostLabel.frame.maxY + 4, width: width - 40, height: 34)
    }

    private func setupHeader() {
        let theme = presentation.theme
        titleLabel.text = presentation.strings.channelReactionsTitle
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = theme.colors.textPrimary
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        closeButton.tintColor = theme.colors.textPrimary
        closeButton.backgroundColor = theme.colors.textSecondary.withAlphaComponent(0.14)
        closeButton.layer.cornerRadius = 22
        closeButton.accessibilityLabel = presentation.strings.chatCancel
        closeButton.addAction(
            UIAction { [weak self] _ in
                self?.floatingSheet?.close()
            },
            for: .touchUpInside
        )
        view.addSubview(closeButton)
    }

    private func setupControls() {
        let theme = presentation.theme
        let strings = presentation.strings
        modes.addAction(
            UIAction { [weak self] _ in
                Haptics.play(.selection)
                self?.render()
            },
            for: .valueChanged
        )
        view.addSubview(modes)
        hintLabel.font = theme.fonts.caption
        hintLabel.textColor = theme.colors.textSecondary
        hintLabel.numberOfLines = 2
        view.addSubview(hintLabel)
        upgradeButton.setTitle(strings.channelReactionsUpgrade, for: .normal)
        upgradeButton.titleLabel?.font = theme.fonts.body
        upgradeButton.tintColor = theme.colors.accent
        upgradeButton.addAction(
            UIAction { [weak self] _ in
                self?.onUpgrade?()
            },
            for: .touchUpInside
        )
        view.addSubview(upgradeButton)
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = theme.colors.accent
        configuration.baseForegroundColor = theme.colors.onAccent
        configuration.background.cornerRadius = 25
        configuration.title = strings.channelReactionsSave
        saveButton.configuration = configuration
        saveButton.addAction(
            UIAction { [weak self] _ in
                self?.save()
            },
            for: .touchUpInside
        )
        view.addSubview(saveButton)
    }

    private func setupPerPost() {
        let theme = presentation.theme
        perPostLabel.font = theme.fonts.subheadline
        perPostLabel.textColor = theme.colors.textPrimary
        perPostSlider.tintColor = theme.colors.accent
        perPostSlider.addAction(
            UIAction { [weak self] _ in
                self?.perPostChanged()
            },
            for: .valueChanged
        )
        view.addSubview(perPostLabel)
        view.addSubview(perPostSlider)
    }

    private var isPicking: Bool {
        modes.selectedSegmentIndex == 1
    }

    private func toggle(_ emoji: String) {
        guard isPicking else {
            return
        }

        if selected.contains(emoji) {
            selected.remove(emoji)
        } else if selected.count < limit() {
            selected.insert(emoji)
        } else {
            Haptics.play(.warning)
            floatingSheet?.showHint(presentation.strings.channelReactionsLimit)

            return
        }
        Haptics.play(.selection)
        render()
    }

    private func render() {
        let strings = presentation.strings
        let accent = presentation.theme.colors.accent
        for (index, cell) in cells.enumerated() {
            let isOn = selected.contains(Self.palette[index])
            cell.backgroundColor = isPicking && isOn ? accent.withAlphaComponent(0.24) : .clear
            cell.alpha = isPicking ? (isOn ? 1 : 0.45) : (modes.selectedSegmentIndex == 0 ? 1 : 0.2)
            cell.isUserInteractionEnabled = isPicking
        }
        switch modes.selectedSegmentIndex {
        case 0:
            hintLabel.text = strings.channelReactionsAllHint
        case 1:
            hintLabel.text = strings.channelReactionsCounter(String(selected.count), String(limit()))
        default:
            hintLabel.text = strings.channelReactionsNoneHint
        }
        perPostLabel.text = strings.channelReactionsPerPost(String(perPost))
        upgradeButton.isHidden = onUpgrade == nil || !isPicking || limit() >= Self.palette.count
    }

    private var perPost: Int {
        Int(perPostSlider.value.rounded())
    }

    private func perPostChanged() {
        let value = perPost
        perPostSlider.value = Float(value)
        if perPostLabel.text != presentation.strings.channelReactionsPerPost(String(value)) {
            Haptics.play(.selection)
            render()
        }
    }

    private func save() {
        let rule: ChannelReactionRule
        switch modes.selectedSegmentIndex {
        case 0:
            rule = .all
        case 1 where !selected.isEmpty:
            rule = .some(Self.palette.filter(selected.contains))
        default:
            rule = .none
        }
        let value = perPost == ChannelSettingsStore.maxReactionsPerPost ? nil : perPost
        floatingSheet?.close { [onSave] in
            onSave?(rule, value)
        }
    }
}
