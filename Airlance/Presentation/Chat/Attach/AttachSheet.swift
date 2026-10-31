import Haptics
import Photos
import UIKit

final class AttachSheet: UIView, UITextFieldDelegate {
    enum Tab: Int, CaseIterable {
        case gallery
        case file
        case location
        case poll
    }

    var onSendMedia: (@MainActor ([PHAsset], String) -> Void)?
    var onCamera: (@MainActor () -> Void)?
    var onFile: (@MainActor () -> Void)?
    var onLocation: (@MainActor (AttachLocationView.Pick) -> Void)?
    var onPoll: (@MainActor () -> Void)?
    var onManage: (@MainActor () -> Void)?
    var authorize: (@MainActor (Tab) async -> Bool)?
    var isLimited: (@MainActor () -> Bool)?

    let presentation: PresentationData
    let tabs: [Tab]
    let sheet = UIView()
    let gallery = AttachGallery()
    let location: AttachLocationView
    let placeholder = AttachPlaceholder()
    let tabBar = UIStackView()
    let sendBar = UIView()
    let caption = UITextField()
    let sendButton = UIButton(type: .system)
    let countLabel = UILabel()
    var selected = Tab.gallery
    var refused: Set<Tab> = []
    var libraryShown = false
    var sheetHeight: CGFloat = 0
    private let dim = UIView()
    private let grabber = UIView()
    private let titleLabel = UILabel()

    init(tabs: [Tab], presentation: PresentationData, host: UIView) {
        self.tabs = tabs
        self.presentation = presentation
        location = AttachLocationView(presentation: presentation)
        super.init(frame: host.bounds)
        host.addSubview(self)
        dim.backgroundColor = UIColor(white: 0, alpha: 0.35)
        dim.alpha = 0
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        addSubview(dim)
        sheet.backgroundColor = presentation.theme.colors.surface
        sheet.layer.cornerRadius = 16
        sheet.layer.cornerCurve = .continuous
        sheet.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        addSubview(sheet)
        grabber.backgroundColor = presentation.theme.colors.separator
        grabber.layer.cornerRadius = 2.5
        sheet.addSubview(grabber)
        titleLabel.font = HistoryStyle.bold(presentation.theme.fonts.body)
        titleLabel.textColor = presentation.theme.colors.textPrimary
        sheet.addSubview(titleLabel)
        gallery.apply(presentation)
        placeholder.apply(presentation)
        bindContent()
        for view in [gallery, location, placeholder] as [UIView] {
            sheet.addSubview(view)
        }
        setupTabs()
        setupSendBar()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        layoutSheet(in: host)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        select(.gallery)
        UIView.animate(withDuration: 0.3) {
            self.dim.alpha = 1
        }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.sheet.frame.origin.y = self.bounds.height - self.sheetHeight
        }
    }

    private func bindContent() {
        gallery.onSelectionChange = { [weak self] count in
            self?.selectionChanged(count)
        }
        gallery.onCamera = { [weak self] in
            self?.cameraTapped()
        }
        gallery.onManage = { [weak self] in
            self?.onManage?()
        }
        location.onPick = { [weak self] pick in
            self?.close {
                self?.onLocation?(pick)
            }
        }
        placeholder.onAction = { [weak self] in
            self?.placeholderTapped()
        }
    }

    private func layoutSheet(in host: UIView) {
        dim.frame = bounds
        sheetHeight = bounds.height * 0.64
        let width = bounds.width
        sheet.frame = CGRect(x: 0, y: bounds.height, width: width, height: sheetHeight + 40)
        grabber.frame = CGRect(x: (width - 36) / 2, y: 6, width: 36, height: 5)
        titleLabel.frame = CGRect(x: 16, y: 16, width: width - 32, height: 24)
        let tabsHeight: CGFloat = 64 + host.safeAreaInsets.bottom
        let content = CGRect(x: 0, y: 50, width: width, height: sheetHeight - 50 - tabsHeight)
        for view in [gallery, location, placeholder] as [UIView] {
            view.frame = content
        }
        tabBar.frame = CGRect(x: 8, y: sheetHeight - tabsHeight + 6, width: width - 16, height: 52)
        sendBar.frame = CGRect(x: 0, y: sheetHeight - tabsHeight, width: width, height: tabsHeight)
        caption.superview?.frame = CGRect(x: 12, y: 10, width: width - 80, height: 38)
        caption.frame = CGRect(x: 14, y: 0, width: width - 108, height: 38)
        sendButton.frame = CGRect(x: width - 58, y: 6, width: 46, height: 46)
        countLabel.frame = CGRect(x: width - 30, y: 0, width: 22, height: 22)
    }

    func setTitle(_ text: String) {
        titleLabel.text = text
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }

    @objc
    private func keyboardWillChange(_ notification: Notification) {
        guard caption.isFirstResponder || sheet.transform != .identity,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let overlap = max(0, bounds.height - convert(frame, from: nil).minY - safeAreaInsets.bottom)
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.sheet.transform = CGAffineTransform(translationX: 0, y: -overlap)
        }
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            endEditing(true)
        }
        let offset = gesture.translation(in: self).y
        let rest = bounds.height - sheetHeight
        switch gesture.state {
        case .changed:
            sheet.frame.origin.y = rest + (offset > 0 ? offset : offset * 0.2)
            dim.alpha = 1 - max(0, offset) / sheetHeight
        case .ended, .cancelled:
            if offset > 120 || gesture.velocity(in: self).y > 800 {
                close(nil)
            } else {
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
                    self.sheet.frame.origin.y = rest
                    self.dim.alpha = 1
                }
            }
        default:
            break
        }
    }

    @objc
    private func dimTapped() {
        close(nil)
    }

    func close(_ completion: (@MainActor () -> Void)?) {
        endEditing(true)
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.sheet.frame.origin.y = self.bounds.height
            self.sheet.transform = .identity
            self.dim.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}
