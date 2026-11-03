import UIKit

extension StoryEditorView {
    func setUpTools() {
        let isVideo = player != nil
        style(closeButton, symbol: "xmark", label: strings.cancel)
        style(textButton, symbol: "textformat", label: strings.text)
        style(drawButton, symbol: "scribble.variable", label: strings.draw)
        style(stickerButton, symbol: "face.smiling", label: strings.label(.sticker))
        style(adjustButton, symbol: "slider.horizontal.3", label: strings.label(.adjust))
        style(soundButton, symbol: "music.note", label: strings.label(.sound))
        style(
            extraButton,
            symbol: isVideo ? "timeline.selection" : "person.crop.rectangle.badge.plus",
            label: strings.label(isVideo ? .trim : .cutout)
        )
        style(undoButton, symbol: "arrow.uturn.backward", label: strings.undo)
        bindTools(isVideo: isVideo)
        doneButton.setTitle(strings.done, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.tintColor = .white
        doneButton.addAction(UIAction { [weak self] _ in
            self?.setMode(.idle)
        }, for: .touchUpInside)
        extraSpinner.color = .white
        extraSpinner.hidesWhenStopped = true
        extraButton.addSubview(extraSpinner)
        setUpPublish()
        let tools = [
            closeButton, textButton, drawButton, stickerButton, adjustButton, soundButton, extraButton, undoButton,
            doneButton,
            audienceButton, publishButton,
        ]
        for view in tools + [palette, brushBar] {
            addSubview(view)
        }
    }

    private func bindTools(isVideo: Bool) {
        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)
        textButton.addAction(UIAction { [weak self] _ in
            self?.editText(nil)
        }, for: .touchUpInside)
        drawButton.addAction(UIAction { [weak self] _ in
            self?.setMode(.draw)
        }, for: .touchUpInside)
        stickerButton.addAction(UIAction { [weak self] _ in
            self?.showStickers()
        }, for: .touchUpInside)
        adjustButton.addAction(UIAction { [weak self] _ in
            self?.setMode(.adjust)
        }, for: .touchUpInside)
        soundButton.addAction(UIAction { [weak self] _ in
            self?.setMode(.sound)
        }, for: .touchUpInside)
        extraButton.addAction(UIAction { [weak self] _ in
            if isVideo {
                self?.setMode(.trim)
            } else {
                self?.onCutout?()
            }
        }, for: .touchUpInside)
        undoButton.addAction(UIAction { [weak self] _ in
            self?.canvas.undo()
        }, for: .touchUpInside)
    }

    func layoutTools() {
        let safe = safeAreaInsets
        let width = bounds.width
        let top = max(safe.top, 16) + 6
        closeButton.frame = CGRect(x: 16, y: top, width: 44, height: 44)
        undoButton.frame = closeButton.frame
        doneButton.frame = CGRect(x: width - 100, y: top, width: 84, height: 44)
        let column = [textButton, drawButton, stickerButton, adjustButton, soundButton, extraButton]
        for (index, button) in column.enumerated() {
            button.frame = CGRect(x: width - 60, y: top + 56 + CGFloat(index) * 54, width: 44, height: 44)
        }
        for button in column + [closeButton, undoButton] {
            button.layer.cornerRadius = 22
        }
        extraSpinner.center = CGPoint(x: 22, y: 22)
        let bottom = bounds.height - max(safe.bottom, 16) - 8
        palette.frame = CGRect(x: 12, y: bottom - StoryPalette.height, width: width - 24, height: StoryPalette.height)
        brushBar.frame = CGRect(x: 24, y: palette.frame.minY - StoryBrushBar.height - 14, width: width - 48, height: 44)
        let audienceWidth = min(audienceButton.intrinsicContentSize.width + 28, width / 2 - 24)
        audienceButton.frame = CGRect(x: 16, y: bottom - 44, width: audienceWidth, height: 44)
        let font = publishButton.titleLabel?.font ?? .systemFont(ofSize: 16, weight: .semibold)
        let publishWidth = ceil((strings.publish as NSString).size(withAttributes: [.font: font]).width) + 36
        publishButton.frame = CGRect(x: width - 16 - publishWidth, y: bottom - 44, width: publishWidth, height: 44)
        for button in [audienceButton, publishButton] {
            button.layer.cornerRadius = 22
        }
        spinner.center = CGPoint(x: publishButton.bounds.midX, y: publishButton.bounds.midY)
        adjustPanel?.frame = CGRect(
            x: 8,
            y: bounds.height - max(safe.bottom, 8) - StoryAdjustPanel.height,
            width: width - 16,
            height: StoryAdjustPanel.height
        )
        trimView?.frame = CGRect(
            x: 12,
            y: bottom - StoryTrimView.height,
            width: width - 24,
            height: StoryTrimView.height
        )
        layoutSoundPanel()
        layoutSubtitleButton()
    }

    private func setUpPublish() {
        publishButton.setTitle(strings.publish, for: .normal)
        publishButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        publishButton.tintColor = .black
        publishButton.backgroundColor = .white
        publishButton.addAction(UIAction { [weak self] _ in
            guard let self else {
                return
            }

            self.onPublish?(self.audience)
        }, for: .touchUpInside)
        spinner.color = .black
        spinner.hidesWhenStopped = true
        publishButton.addSubview(spinner)
        audienceButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        audienceButton.tintColor = .white
        audienceButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        audienceButton.addAction(UIAction { [weak self] _ in
            self?.showPublishSheet()
        }, for: .touchUpInside)
        setAudience(audience)
    }

    func setAudience(_ audience: StoryAudience) {
        self.audience = audience
        let configuration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        audienceButton.setImage(UIImage(systemName: audience.symbol, withConfiguration: configuration), for: .normal)
        audienceButton.setTitle(" " + audience.title(strings), for: .normal)
        audienceButton.accessibilityLabel = strings.audience
        audienceButton.accessibilityValue = audience.title(strings)
        setNeedsLayout()
    }

    private func style(_ button: UIButton, symbol: String, label: String) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        button.accessibilityLabel = label
    }
}

extension StoryAudience {
    var symbol: String {
        switch self {
        case .everyone:
            "globe"
        case .contacts:
            "person.2.fill"
        case .closeFriends:
            "star.fill"
        case .selected:
            "person.crop.circle.badge.checkmark"
        }
    }

    func title(_ strings: StoryStudioStrings) -> String {
        strings.audiences[self] ?? rawValue
    }
}
