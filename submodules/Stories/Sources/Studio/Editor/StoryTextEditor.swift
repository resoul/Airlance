import Haptics
import UIKit

public final class StoryTextEditor: UIView {
    public var onDone: (@MainActor (StoryText) -> Void)?

    private let textView = UITextView()
    private let palette = StoryPalette()
    private let doneButton = UIButton(type: .system)
    private let styleButton = UIButton(type: .system)
    private let fonts = UIStackView()
    private var text: StoryText

    public init(text: StoryText, doneTitle: String) {
        self.text = text
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        textView.text = text.text
        textView.tintColor = .white
        textView.textAlignment = .center
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        textView.layer.cornerCurve = .continuous
        palette.select(text.color.uiColor, notify: false)
        palette.onSelect = { [weak self] color in
            self?.text.color = StoryColor(color)
            self?.refresh()
        }
        doneButton.setTitle(doneTitle, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.tintColor = .white
        doneButton.addAction(UIAction { [weak self] _ in
            self?.finish()
        }, for: .touchUpInside)
        styleButton.tintColor = .white
        styleButton.addAction(UIAction { [weak self] _ in
            self?.cycleStyle()
        }, for: .touchUpInside)
        setUpFonts()
        let outside = UITapGestureRecognizer(target: self, action: #selector(tappedOutside(_:)))
        outside.cancelsTouchesInView = false
        addGestureRecognizer(outside)
        for subview in [textView, palette, doneButton, styleButton, fonts] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }
        layOut()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func begin() {
        textView.becomeFirstResponder()
    }

    private func setUpFonts() {
        fonts.axis = .horizontal
        fonts.spacing = 8
        fonts.distribution = .fillEqually
        for font in StoryFont.allCases {
            let button = UIButton(type: .system)
            button.setTitle("Aa", for: .normal)
            button.titleLabel?.font = StoryLook.font(font, size: 17)
            button.tintColor = .white
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 1.5
            button.addAction(UIAction { [weak self] _ in
                self?.text.font = font
                Haptics.play(.selection)
                self?.refresh()
            }, for: .touchUpInside)
            fonts.addArrangedSubview(button)
        }
    }

    private func cycleStyle() {
        let all = StoryTextStyle.allCases
        let index = all.firstIndex(of: text.style) ?? 0
        text.style = all[(index + 1) % all.count]
        Haptics.play(.selection)
        refresh()
    }

    private func refresh() {
        let color = text.color.uiColor
        let size: CGFloat = 32
        textView.font = StoryLook.font(text.font, size: size)
        textView.backgroundColor = .clear
        textView.layer.cornerRadius = 10
        var typing: [NSAttributedString.Key: Any] = [.font: StoryLook.font(text.font, size: size)]
        switch text.style {
        case .shadow:
            typing[.foregroundColor] = color
        case .filled:
            typing[.foregroundColor] = StoryLook.contrast(for: color)
            textView.backgroundColor = color
        case .semi:
            typing[.foregroundColor] = color
            textView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        case .outline:
            typing[.foregroundColor] = StoryLook.contrast(for: color)
            typing[.strokeColor] = color
            typing[.strokeWidth] = -5
        }
        let selection = textView.selectedRange
        textView.attributedText = NSAttributedString(string: textView.text ?? "", attributes: typing)
        textView.typingAttributes = typing
        textView.selectedRange = selection
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let image = UIImage(systemName: Self.symbol(text.style), withConfiguration: configuration)
        styleButton.setImage(image, for: .normal)
        for (index, view) in fonts.arrangedSubviews.enumerated() {
            let isSelected = StoryFont.allCases[index] == text.font
            view.layer.borderColor = (isSelected ? UIColor.white : UIColor.white.withAlphaComponent(0.25)).cgColor
        }
    }

    private static func symbol(_ style: StoryTextStyle) -> String {
        switch style {
        case .shadow:
            "textformat"
        case .filled:
            "a.square.fill"
        case .semi:
            "a.square"
        case .outline:
            "a.circle"
        }
    }

    private func layOut() {
        let keyboard = keyboardLayoutGuide
        let centered = textView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -60)
        centered.priority = .defaultLow
        NSLayoutConstraint.activate([
            doneButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            doneButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            styleButton.centerYAnchor.constraint(equalTo: doneButton.centerYAnchor),
            styleButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            styleButton.widthAnchor.constraint(equalToConstant: 44),
            styleButton.heightAnchor.constraint(equalToConstant: 44),
            palette.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            palette.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            palette.bottomAnchor.constraint(equalTo: keyboard.topAnchor, constant: -12),
            palette.heightAnchor.constraint(equalToConstant: StoryPalette.height),
            fonts.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            fonts.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            fonts.bottomAnchor.constraint(equalTo: palette.topAnchor, constant: -10),
            fonts.heightAnchor.constraint(equalToConstant: 32),
            textView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            textView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            textView.centerXAnchor.constraint(equalTo: centerXAnchor),
            textView.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            textView.bottomAnchor.constraint(lessThanOrEqualTo: fonts.topAnchor, constant: -16),
            textView.topAnchor.constraint(greaterThanOrEqualTo: doneButton.bottomAnchor, constant: 16),
            centered,
        ])
    }

    private func finish() {
        textView.resignFirstResponder()
        text.text = textView.text ?? ""
        onDone?(text)
    }

    @objc
    private func tappedOutside(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        let controls = [textView, palette, fonts, styleButton, doneButton]
        guard !controls.contains(where: { view in
            view.frame.contains(point)
        }) else {
            return
        }

        finish()
    }
}
