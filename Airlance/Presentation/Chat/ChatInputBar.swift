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

    let attachButton = UIButton(type: .system)
    let fieldBox = UIView()
    let textView = UITextView()
    let scheduledButton = UIButton(type: .system)
    var composerStyle = ComposerStyle(accent: .systemBlue, spoilerFill: .systemGray5)
    private let placeholder = UILabel()
    let actionIcon = UIImageView()
    let actionCircle = UIView()
    private let actionButton = UIButton(type: .custom)
    var strings: AppStrings?
    private var theme: AppTheme?
    var isVideoMode = false
    private var textHeight: CGFloat = 44
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
        max(Self.controlSize, ceil((textView.font?.lineHeight ?? 20) + 24))
    }

    private var maximumTextHeight: CGFloat {
        ceil((textView.font?.lineHeight ?? 20) * 5 + 24)
    }

    override var intrinsicContentSize: CGSize {
        let safeArea = window?.safeAreaInsets.bottom ?? 0
        let floats = includesBottomSafeArea && !textView.isFirstResponder
        let bottom = floats ? Self.floatingGap(safeArea: safeArea) : 8

        return CGSize(width: UIView.noIntrinsicMetric, height: panelHeight + 8 + textHeight + bottom)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        addSubview(fieldBox)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 9, bottom: 12, right: 9)
        textView.showsVerticalScrollIndicator = false
        textView.isScrollEnabled = false
        textView.delegate = self
        fieldBox.addSubview(textView)
        placeholder.isUserInteractionEnabled = false
        fieldBox.addSubview(placeholder)
        setupScheduledButton()
        actionIcon.contentMode = .center
        actionCircle.isUserInteractionEnabled = false
        addSubview(actionCircle)
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
        applyFloating(theme)
        attachButton.tintColor = theme.colors.textSecondary
        attachButton.accessibilityLabel = presentation.strings.chatAttach
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
        let side = Self.controlSize
        let gap: CGFloat = 8
        replyPanel.frame = CGRect(x: gap, y: 0, width: width - gap * 2, height: ChatReplyPanel.height - 4)
        let fieldX = gap * 2 + side
        fieldBox.frame = CGRect(x: fieldX, y: panelHeight + 8, width: width - fieldX * 2, height: textHeight)
        let rowBottom = fieldBox.frame.maxY
        attachButton.frame = CGRect(x: gap, y: rowBottom - side, width: side, height: side)
        layoutField()
        let placeholderHeight = ceil(placeholder.font?.lineHeight ?? 20)
        placeholder.frame = CGRect(
            x: 14,
            y: (minimumTextHeight - placeholderHeight) / 2,
            width: fieldBox.bounds.width - 28,
            height: placeholderHeight
        )
        actionIcon.frame = CGRect(x: width - gap - side, y: rowBottom - side, width: side, height: side)
        actionCircle.frame = actionIcon.frame
        actionButton.frame = actionIcon.frame.insetBy(dx: -4, dy: -4)
        layoutFloating()
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
        let sendSymbol = isEditingMessage ? "checkmark" : "arrow.up"
        let symbol = sends ? sendSymbol : (isVideoMode ? "video" : "mic")
        let configuration = sends ? UIImage.SymbolConfiguration(pointSize: 18, weight: .bold) : Self.symbol(22)
        let image = UIImage(systemName: symbol, withConfiguration: configuration)
        actionIcon.tintColor = sends ? .white : theme.colors.textSecondary
        setActionFilled(sends, theme: theme, animated: animated)
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

    static func symbol(_ size: CGFloat) -> UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
    }
}
