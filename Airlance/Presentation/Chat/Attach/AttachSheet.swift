import ChatHistory
import DeviceContacts
import Haptics
import Photos
import UIKit

final class AttachSheet: UIView, UITextFieldDelegate {
    enum Tab: Int, CaseIterable {
        case gallery
        case location
        case poll
        case sound
        case contact
        case file
    }

    var onSendMedia: (@MainActor ([PHAsset], String) -> Void)?
    var onCamera: (@MainActor (CGRect?) -> Void)?
    var onClosed: (@MainActor () -> Void)?
    var onFile: (@MainActor () -> Void)?
    var onLocation: (@MainActor (AttachLocationView.Pick) -> Void)?
    var onPoll: (@MainActor () -> Void)?
    var onSoundFile: (@MainActor (MessageFile) -> Void)?
    var onPickSoundFiles: (@MainActor () -> Void)?
    var onContact: (@MainActor (DeviceContact) -> Void)?
    var onManage: (@MainActor () -> Void)?
    var authorize: (@MainActor (Tab) async -> Bool)?
    var isLimited: (@MainActor () -> Bool)?
    var galleryTitle: String?

    let presentation: PresentationData
    let tabs: [Tab]
    let sheet = UIView()
    let gallery = AttachGallery()
    let location: AttachLocationView
    let sound: AttachSoundView
    let contacts: AttachContactsView
    let placeholder = AttachPlaceholder()
    let tabBar: AttachTabBar
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
    private let closeButton = UIButton(type: .system)

    init(tabs: [Tab], presentation: PresentationData, contacts store: DeviceContactsStore, host: UIView) {
        self.tabs = tabs
        self.presentation = presentation
        location = AttachLocationView(presentation: presentation)
        sound = AttachSoundView(presentation: presentation)
        contacts = AttachContactsView(store: store, presentation: presentation)
        tabBar = Self.makeTabBar(tabs, presentation: presentation)
        super.init(frame: host.bounds)
        host.addSubview(self)
        dim.backgroundColor = UIColor(white: 0, alpha: 0.35)
        dim.alpha = 0
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        addSubview(dim)
        sheet.backgroundColor = presentation.theme.colors.surface
        sheet.layer.cornerRadius = 28
        sheet.layer.cornerCurve = .continuous
        sheet.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        addSubview(sheet)
        grabber.backgroundColor = presentation.theme.colors.separator
        grabber.layer.cornerRadius = 2.5
        sheet.addSubview(grabber)
        titleLabel.font = HistoryStyle.bold(presentation.theme.fonts.body)
        titleLabel.textColor = presentation.theme.colors.textPrimary
        titleLabel.textAlignment = .center
        sheet.addSubview(titleLabel)
        gallery.apply(presentation)
        placeholder.apply(presentation)
        bindContent()
        for view in [gallery, location, sound, contacts, placeholder] as [UIView] {
            sheet.addSubview(view)
        }
        setupCloseButton()
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
        tabBar.isHidden = tabs.count < 2
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
        gallery.onCamera = { [weak self] frame in
            self?.cameraTapped(from: frame)
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
        sound.onSend = { [weak self] file in
            self?.close {
                self?.onSoundFile?(file)
            }
        }
        sound.onPickFiles = { [weak self] in
            self?.close {
                self?.onPickSoundFiles?()
            }
        }
        contacts.onPick = { [weak self] contact in
            self?.close {
                self?.onContact?(contact)
            }
        }
    }

    private func setupCloseButton() {
        let colors = presentation.theme.colors
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        closeButton.tintColor = colors.textPrimary
        closeButton.backgroundColor = colors.textSecondary.withAlphaComponent(0.14)
        closeButton.layer.cornerRadius = 20
        closeButton.accessibilityLabel = presentation.strings.chatCancel
        closeButton.addAction(
            UIAction { [weak self] _ in
                self?.close(nil)
            },
            for: .touchUpInside
        )
        sheet.addSubview(closeButton)
    }

    private func layoutSheet(in host: UIView) {
        dim.frame = bounds
        sheetHeight = bounds.height * 0.82
        let width = bounds.width
        sheet.frame = CGRect(x: 0, y: bounds.height, width: width, height: sheetHeight + 40)
        grabber.frame = CGRect(x: (width - 36) / 2, y: 6, width: 36, height: 5)
        closeButton.frame = CGRect(x: 14, y: 14, width: 40, height: 40)
        titleLabel.frame = CGRect(x: 62, y: 16, width: width - 124, height: 36)
        let top: CGFloat = 62
        let tabsHeight = AttachTabBar.height + 12 + host.safeAreaInsets.bottom
        let full = CGRect(x: 0, y: top, width: width, height: sheetHeight - top)
        for view in [gallery, sound, contacts] as [UIView] {
            view.frame = full
        }
        gallery.bottomInset = tabsHeight
        sound.bottomInset = tabsHeight
        contacts.bottomInset = tabsHeight
        for view in [location, placeholder] as [UIView] {
            view.frame = CGRect(x: 0, y: top, width: width, height: sheetHeight - top - tabsHeight)
        }
        tabBar.frame = CGRect(x: 12, y: sheetHeight - tabsHeight + 6, width: width - 24, height: AttachTabBar.height)
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
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let height = max(0, bounds.height - convert(frame, from: nil).minY)
        sound.keyboardInset = height
        contacts.keyboardInset = height
        guard caption.isFirstResponder || sheet.transform != .identity else {
            return
        }

        let overlap = max(0, height - safeAreaInsets.bottom)
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
        sound.stopPreview()
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.sheet.frame.origin.y = self.bounds.height
            self.sheet.transform = .identity
            self.dim.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
            self.onClosed?()
        }
    }
}
