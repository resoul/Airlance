import Haptics
import Theme
import UIKit

final class ChatInputBar: UIView, UITextViewDelegate {
    var onSend: (@MainActor (ComposedText) -> Void)?
    var onSendMenu: (@MainActor (UILongPressGestureRecognizer) -> Void)?
    var onScheduled: (@MainActor () -> Void)?
    var onMentionQuery: (@MainActor (String?) -> Void)?
    var onAttach: (@MainActor () -> Void)?
    var onHold: (@MainActor (UILongPressGestureRecognizer) -> Void)?
    var includesBottomSafeArea = true
    let replyPanel = ChatReplyPanel()

    private let background = UIView()
    private let separator = UIView()
    let attachButton = UIButton(type: .system)
    let fieldBox = UIView()
    let textView = UITextView()
    let scheduledButton = UIButton(type: .system)
    var composerStyle = ComposerStyle(accent: .systemBlue, spoilerFill: .systemGray5)
    private let placeholder = UILabel()
    let actionIcon = UIImageView()
    private let actionButton = UIButton(type: .custom)
    var strings: AppStrings?
    private var theme: AppTheme?
    var isVideoMode = false
    private var textHeight: CGFloat = 36
    var showsReply = false
    var isEditingMessage = false {
        didSet {
            updateAction(animated: true)
        }
    }

    private var panelHeight: CGFloat {
        showsReply ? ChatReplyPanel.height : 0
    }

    var text: String {
        textView.text ?? ""
    }

    var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var minimumTextHeight: CGFloat {
        max(36, ceil((textView.font?.lineHeight ?? 20) + 16))
    }

    private var maximumTextHeight: CGFloat {
        ceil((textView.font?.lineHeight ?? 20) * 5 + 16)
    }

    override var intrinsicContentSize: CGSize {
        let safeArea = includesBottomSafeArea && !textView.isFirstResponder ? window?.safeAreaInsets.bottom ?? 0 : 0

        return CGSize(width: UIView.noIntrinsicMetric, height: panelHeight + textHeight + 16 + safeArea)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(background)
        background.addSubview(separator)
        replyPanel.alpha = 0
        addSubview(replyPanel)
        let attachImage = UIImage(systemName: "paperclip", withConfiguration: Self.symbol(21))
        attachButton.setImage(attachImage, for: .normal)
        attachButton.addAction(
            UIAction { [weak self] _ in
                self?.onAttach?()
            },
            for: .touchUpInside
        )
        addSubview(attachButton)
        fieldBox.layer.cornerRadius = 18
        fieldBox.layer.cornerCurve = .continuous
        fieldBox.layer.borderWidth = 0.5
        addSubview(fieldBox)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 9, bottom: 8, right: 9)
        textView.showsVerticalScrollIndicator = false
        textView.isScrollEnabled = false
        textView.delegate = self
        fieldBox.addSubview(textView)
        placeholder.isUserInteractionEnabled = false
        fieldBox.addSubview(placeholder)
        setupScheduledButton()
        actionIcon.contentMode = .center
        addSubview(actionIcon)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = 0.18
        hold.allowableMovement = 400
        actionButton.addGestureRecognizer(hold)
        addSubview(actionButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        let theme = presentation.theme
        self.theme = theme
        strings = presentation.strings
        background.backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.separator
        attachButton.tintColor = theme.colors.textSecondary
        attachButton.accessibilityLabel = presentation.strings.chatAttach
        fieldBox.backgroundColor = theme.colors.surface
        fieldBox.layer.borderColor = theme.colors.separator.cgColor
        textView.font = theme.fonts.body
        textView.textColor = theme.colors.textPrimary
        textView.tintColor = theme.colors.accent
        composerStyle = ComposerStyle(
            accent: theme.colors.accent,
            spoilerFill: theme.colors.textSecondary.withAlphaComponent(0.25)
        )
        textView.accessibilityLabel = presentation.strings.chatMessage
        placeholder.text = presentation.strings.chatMessage
        placeholder.font = theme.fonts.body
        placeholder.textColor = theme.colors.textSecondary
        replyPanel.apply(theme)
        updateAction(animated: false)
        textChanged(animated: false)
    }

    func clear() {
        setText("", animated: true)
    }

    func setText(_ text: String, animated: Bool) {
        textView.text = text
        textChanged(animated: animated)
    }

    func focus() {
        textView.becomeFirstResponder()
    }

    func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let top = panelHeight
        let rowBottom = top + textHeight + 16
        background.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height + 40)
        replyPanel.frame = CGRect(x: 0, y: 0, width: width, height: ChatReplyPanel.height)
        separator.frame = CGRect(x: 0, y: 0, width: width, height: 0.5)
        attachButton.frame = CGRect(x: 4, y: rowBottom - 48, width: 44, height: 44)
        fieldBox.frame = CGRect(x: 50, y: top + 8, width: width - 100, height: textHeight)
        layoutField()
        let placeholderHeight = ceil(placeholder.font?.lineHeight ?? 20)
        placeholder.frame = CGRect(
            x: 14,
            y: (minimumTextHeight - placeholderHeight) / 2,
            width: fieldBox.bounds.width - 28,
            height: placeholderHeight
        )
        actionIcon.frame = CGRect(x: width - 48, y: rowBottom - 48, width: 44, height: 44)
        actionButton.frame = actionIcon.frame.insetBy(dx: -4, dy: -4)
    }

    func textViewDidChange(_ textView: UITextView) {
        textChanged(animated: true)
        reportMention()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        reportMention()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        animateLayout()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        animateLayout()
    }

    private func textChanged(animated: Bool) {
        placeholder.isHidden = !text.isEmpty
        updateAction(animated: animated)
        let width = max(fieldBox.bounds.width, 100)
        let fitting = ceil(textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        let height = min(max(minimumTextHeight, fitting), maximumTextHeight)
        textView.isScrollEnabled = fitting > maximumTextHeight
        if textView.isScrollEnabled {
            textView.scrollRangeToVisible(textView.selectedRange)
        }
        guard height != textHeight else {
            return
        }

        textHeight = height
        if animated {
            animateLayout()
        } else {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    func animateLayout(_ changes: (@MainActor () -> Void)? = nil) {
        invalidateIntrinsicContentSize()
        UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0) {
            changes?()
            self.layoutIfNeeded()
            self.superview?.layoutIfNeeded()
        }
    }

    private func updateAction(animated: Bool) {
        guard let theme, let strings else {
            return
        }

        let sends = hasText || isEditingMessage
        let sendSymbol = isEditingMessage ? "checkmark.circle.fill" : "arrow.up.circle.fill"
        let symbol = sends ? sendSymbol : (isVideoMode ? "video" : "mic")
        let image = UIImage(systemName: symbol, withConfiguration: Self.symbol(sends ? 30 : 22))
        actionIcon.tintColor = sends ? theme.colors.accent : theme.colors.textSecondary
        actionButton.accessibilityLabel = sends
            ? (isEditingMessage ? strings.chatEdit : strings.chatSend)
            : (isVideoMode ? strings.chatVideoMessage : strings.chatVoiceMessage)
        guard actionIcon.image != image else {
            return
        }

        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            actionIcon.image = image

            return
        }

        UIView.transition(with: actionIcon, duration: 0.2, options: .transitionCrossDissolve) {
            self.actionIcon.image = image
        }
        actionIcon.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
            self.actionIcon.transform = .identity
        }
    }

    @objc
    private func actionTapped() {
        guard !hasText, !isEditingMessage else {
            Haptics.play(.tap)
            onSend?(ComposedText(attributed: textView.attributedText))

            return
        }

        isVideoMode.toggle()
        Haptics.play(.selection)
        updateAction(animated: true)
    }

    private static func symbol(_ size: CGFloat) -> UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
    }
}
