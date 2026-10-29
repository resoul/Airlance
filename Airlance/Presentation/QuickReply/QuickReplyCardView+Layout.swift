import LiquidUI
import UIKit

extension QuickReplyCardView {
    func buildViews() {
        isUserInteractionEnabled = true
        canvas.color = .black
        canvas.gloss = 0.4
        canvas.rimWidth = 10
        addSubview(canvas)
        dim.backgroundColor = .black
        dim.alpha = 0
        addSubview(dim)
        content.backgroundColor = LiquidCanvasView.isSupported ? .clear : .black
        content.layer.cornerRadius = 28
        content.layer.cornerCurve = .continuous
        content.clipsToBounds = true
        addSubview(content)
        historyClip.clipsToBounds = true
        historyClip.alpha = 0
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        divider.alpha = 0
        for child in [historyClip, divider, avatar, name, message, field, send, close, hint, grabber] {
            content.addSubview(child)
        }
        avatar.isUserInteractionEnabled = false
        buildHeader()
        buildComposer()
        addGestures()
        updateControls()
    }

    private func buildHeader() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = texts.title
        let chevron = UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        configuration.image = UIImage(systemName: "chevron.right", withConfiguration: chevron)
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 5
        configuration.contentInsets = .zero
        configuration.baseForegroundColor = .white
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = .systemFont(ofSize: 15, weight: .semibold)

            return result
        }
        name.configuration = configuration
        name.contentHorizontalAlignment = .leading
        name.addAction(
            UIAction { [weak self] _ in
                self?.openChat()
            },
            for: .touchUpInside
        )
        message.text = texts.message
        message.font = .systemFont(ofSize: 13)
        message.textColor = UIColor.white.withAlphaComponent(0.78)
        message.numberOfLines = 2
        let xmark = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        close.setImage(UIImage(systemName: "xmark", withConfiguration: xmark), for: .normal)
        close.tintColor = UIColor.white.withAlphaComponent(0.6)
        close.accessibilityLabel = texts.closeLabel
        close.addAction(
            UIAction { [weak self] _ in
                self?.dismiss()
            },
            for: .touchUpInside
        )
    }

    private func buildComposer() {
        field.text = texts.draft
        field.attributedPlaceholder = NSAttributedString(
            string: texts.placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        )
        field.font = .systemFont(ofSize: 16)
        field.textColor = .white
        field.tintColor = .white
        field.keyboardAppearance = .dark
        field.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        field.layer.cornerRadius = 20
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.returnKeyType = .send
        field.enablesReturnKeyAutomatically = true
        field.delegate = self
        field.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        let arrow = UIImage.SymbolConfiguration(pointSize: 36)
        send.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: arrow), for: .normal)
        send.tintColor = .white
        send.addAction(
            UIAction { [weak self] _ in
                self?.sendReply()
            },
            for: .touchUpInside
        )
        hint.font = .systemFont(ofSize: 12, weight: .medium)
        hint.textColor = UIColor.white.withAlphaComponent(0.65)
        hint.textAlignment = .center
        grabber.backgroundColor = UIColor.white.withAlphaComponent(0.35)
        grabber.layer.cornerRadius = 2
    }

    func updateControls() {
        field.isHidden = !isReplying
        send.isHidden = !isReplying
        hint.isHidden = !isReplying
        send.isEnabled = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        historyClip.isUserInteractionEnabled = mode == .expanded
        hint.text = isArmed ? texts.releaseHint : texts.pullHint
    }

    func layoutCard(height: CGFloat) {
        let width = content.bounds.width
        let progress = expansion
        let headerHeight = Self.bannerHeight - (Self.bannerHeight - Self.chatHeaderHeight) * progress
        avatar.frame = CGRect(x: 16, y: 17 - 4 * progress, width: 40, height: 40)
        name.frame = CGRect(x: 68, y: 14 + 9 * progress, width: width - 112, height: 20)
        message.frame = CGRect(x: 68, y: 36, width: width - 92, height: 34)
        message.alpha = max(0, 1 - progress * 2.5)
        close.frame = CGRect(x: width - 40, y: 5 + 8 * progress, width: 36, height: 34)
        let replyGap = Self.replyHeight - Self.bannerHeight
        let fieldGap = replyGap - (replyGap - (Self.chatComposerHeight - 6)) * progress
        let fieldY = max(headerHeight, height - fieldGap)
        field.frame = CGRect(x: 16, y: fieldY, width: width - 80, height: 42)
        send.frame = CGRect(x: width - 58, y: fieldY - 1, width: 44, height: 44)
        hint.frame = CGRect(x: 12, y: fieldY + 55, width: width - 24, height: 18)
        hint.alpha = max(0, 1 - progress * 3)
        grabber.frame = CGRect(x: (width - 32) / 2, y: height - 12, width: 32, height: 4)
        grabber.alpha = isReplying ? max(0, 1 - progress * 3) : 0
        divider.frame = CGRect(x: 0, y: headerHeight - 0.5, width: width, height: 0.5)
        divider.alpha = Self.smoothstep(0.1, 0.5, progress)
        let clipHeight = max(0, fieldY - 6 - headerHeight)
        historyClip.frame = CGRect(x: 0, y: headerHeight, width: width, height: clipHeight)
        historyClip.alpha = historyView == nil ? 0 : Self.smoothstep(0, 0.2, progress)
        let finalHeight = max(1, chatHeight - Self.chatHeaderHeight - Self.chatComposerHeight)
        let historyFrame = CGRect(x: 0, y: (clipHeight - finalHeight) / 2, width: width, height: finalHeight)
        if historyView?.frame != historyFrame {
            historyView?.frame = historyFrame
        }
        if isReplying, progress > 0.001 {
            dim.alpha = 0.15 + 0.15 * progress
        }
    }

    func step(_ deltaTime: CFTimeInterval) {
        phaseTime += deltaTime
        if dragExpansion == nil {
            expansionSpring.step(toward: mode == .expanded ? 1 : 0, deltaTime: deltaTime)
        }
        var target = restingCenter
        var size = CGPoint(x: cardWidth / 2, y: cardHeight / 2)
        var neck: CGFloat = 0
        switch mode {
        case .entering:
            neck = 22 * max(0, 1 - CGFloat(phaseTime) / 0.4)
            content.alpha = min(1, max(0, CGFloat(phaseTime - 0.1) / 0.2))
            if phaseTime > 0.65 {
                mode = .banner
            }
        case .dismissing:
            target = islandMouth
            size = CGPoint(x: 7, y: 7)
            neck = hypot(centerSpring.position.x - target.x, centerSpring.position.y - target.y) < 65 ? 18 : 0
            if phaseTime > 0.65 {
                finish()

                return
            }
        case .banner, .reply, .expanded:
            break
        }
        target.y += drag
        if !isReplying {
            size.y += max(0, drag) * 0.12
        }
        move(to: target, size: size, deltaTime: deltaTime)
        draw(neck: neck)
        if isSettled(at: target, size: size) {
            canvas.stopFrames()
        }
    }

    func snap() {
        if mode == .entering {
            mode = .banner
            content.alpha = 1
        }
        if dragExpansion == nil {
            expansionSpring.reset(to: mode == .expanded ? 1 : 0)
        }
        var target = restingCenter
        target.y += drag
        centerSpring.position = target
        halfSpring.position = CGPoint(x: cardWidth / 2, y: cardHeight / 2)
        draw(neck: 0)
        canvas.render()
    }

    private func move(to target: CGPoint, size: CGPoint, deltaTime: CFTimeInterval) {
        guard isReplying, !isExpansionSettled else {
            centerSpring.step(toward: target, deltaTime: deltaTime)
            halfSpring.step(toward: size, deltaTime: deltaTime)

            return
        }

        centerSpring.position = target
        halfSpring.position = size
    }

    private func isSettled(at target: CGPoint, size: CGPoint) -> Bool {
        guard mode != .entering, mode != .dismissing, drag == 0, isExpansionSettled, !isKeyboardMoving else {
            return false
        }

        let position = centerSpring.position
        let current = halfSpring.position

        return hypot(position.x - target.x, position.y - target.y) < 0.2
            && hypot(current.x - size.x, current.y - size.y) < 0.2
            && centerSpring.speed < 1
            && halfSpring.speed < 1
    }

    private func draw(neck: CGFloat) {
        let size = halfSpring.position
        let halfSize = CGSize(width: max(1, size.x), height: max(1, size.y))
        let position = centerSpring.position
        let frame = CGRect(
            x: position.x - halfSize.width,
            y: position.y - halfSize.height,
            width: halfSize.width * 2,
            height: halfSize.height * 2
        )
        canvas.blobs = [
            LiquidBlob(frame: island, cornerRadius: island.height / 2, blend: 0),
            LiquidBlob(frame: frame, cornerRadius: min(28, halfSize.height), blend: neck),
        ]
        content.center = position
        if mode == .entering || mode == .dismissing {
            content.bounds = CGRect(origin: .zero, size: scaleBase)
            content.transform = CGAffineTransform(
                scaleX: max(0.01, frame.width / scaleBase.width),
                y: max(0.01, frame.height / scaleBase.height)
            )
        } else {
            content.transform = .identity
            content.bounds = CGRect(origin: .zero, size: frame.size)
        }
        layoutCard(height: content.bounds.height)
    }

    private static func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let t = max(0, min(1, (value - edge0) / (edge1 - edge0)))

        return t * t * (3 - 2 * t)
    }
}
