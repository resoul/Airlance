import AirlanceUI
import Stories
import UIKit

extension PhotoEditorView {
    func setUpTools() {
        style(closeButton, symbol: "xmark", label: strings.chatCancel)
        style(cropButton, symbol: "crop.rotate", label: strings.photoEditorCrop)
        style(textButton, symbol: "textformat", label: strings.storiesText)
        style(drawButton, symbol: "scribble.variable", label: strings.storiesDraw)
        style(undoButton, symbol: "arrow.uturn.backward", label: strings.storiesUndo)
        style(rotateButton, symbol: "rotate.left", label: strings.photoEditorRotate)
        bindButtons()
        setUpRatios()
        let tools = [closeButton, cropButton, textButton, drawButton, undoButton, doneButton, rotateButton, applyButton]
        for view in tools + [palette, ratioControl] {
            addSubview(view)
        }
    }

    private func bindButtons() {
        closeButton.addAction(UIAction { [weak self] _ in
            self?.closeTapped()
        }, for: .touchUpInside)
        cropButton.addAction(UIAction { [weak self] _ in
            self?.apply(.crop)
        }, for: .touchUpInside)
        textButton.addAction(UIAction { [weak self] _ in
            self?.editText(nil)
        }, for: .touchUpInside)
        drawButton.addAction(UIAction { [weak self] _ in
            self?.apply(.draw)
        }, for: .touchUpInside)
        undoButton.addAction(UIAction { [weak self] _ in
            self?.canvas.undo()
        }, for: .touchUpInside)
        rotateButton.addAction(UIAction { [weak self] _ in
            self?.rotate()
        }, for: .touchUpInside)
        doneButton.setTitle(strings.storiesDone, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.tintColor = .white
        doneButton.addAction(UIAction { [weak self] _ in
            self?.doneTapped()
        }, for: .touchUpInside)
        applyButton.setTitle(strings.storiesDone, for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        applyButton.tintColor = .black
        applyButton.backgroundColor = .white
        applyButton.addAction(UIAction { [weak self] _ in
            guard let self else {
                return
            }

            self.onDone?(self.flattened())
        }, for: .touchUpInside)
    }

    private func setUpRatios() {
        ratioControl.apply(style: LiquidSegmentedStyle(
            font: .systemFont(ofSize: 14, weight: .semibold),
            text: .white,
            selectedText: .black,
            background: UIColor.white.withAlphaComponent(0.15),
            accent: .white
        ))
        ratioControl.setTitles([strings.photoEditorFree, "1:1", "3:4", "9:16"])
        ratioControl.select(0, animated: false)
        ratioControl.onSelect = { [weak self] index in
            self?.ratioIndex = index
            self?.ratioControl.select(index, animated: true)
            self?.cropView.reset(ratio: Self.ratios[index])
        }
    }

    func layoutTools() {
        let safe = safeAreaInsets
        let width = bounds.width
        let top = max(safe.top, 16) + 6
        closeButton.frame = CGRect(x: 16, y: top, width: 44, height: 44)
        undoButton.frame = closeButton.frame
        drawButton.frame = CGRect(x: width - 60, y: top, width: 44, height: 44)
        textButton.frame = CGRect(x: width - 112, y: top, width: 44, height: 44)
        cropButton.frame = CGRect(x: width - 164, y: top, width: 44, height: 44)
        doneButton.frame = CGRect(x: width - 100, y: top, width: 84, height: 44)
        let bottom = bounds.height - max(safe.bottom, 16) - 8
        palette.frame = CGRect(x: 12, y: bottom - StoryPalette.height, width: width - 24, height: StoryPalette.height)
        let ratioSize = ratioControl.intrinsicContentSize
        ratioControl.frame = CGRect(
            x: 16,
            y: bottom - ratioSize.height - 4,
            width: min(ratioSize.width, width - 92),
            height: ratioSize.height
        )
        rotateButton.frame = CGRect(x: width - 60, y: ratioControl.frame.midY - 22, width: 44, height: 44)
        let applyWidth = ceil((strings.storiesDone as NSString).size(withAttributes: [
            .font: applyButton.titleLabel?.font ?? UIFont.systemFont(ofSize: 16),
        ]).width) + 40
        applyButton.frame = CGRect(x: width - 16 - applyWidth, y: bottom - 44, width: applyWidth, height: 44)
        for button in [closeButton, undoButton, drawButton, textButton, cropButton, rotateButton, applyButton] {
            button.layer.cornerRadius = 22
        }
    }

    func updateTools() {
        let mode = mode
        let isIdle = mode == .idle
        UIView.animate(withDuration: 0.2) {
            for view in [self.cropButton, self.textButton, self.drawButton, self.applyButton] {
                view.alpha = isIdle ? 1 : 0
            }
            self.closeButton.alpha = mode == .draw ? 0 : 1
            self.undoButton.alpha = mode == .draw ? 1 : 0
            self.palette.alpha = mode == .draw ? 1 : 0
            self.doneButton.alpha = isIdle ? 0 : 1
            self.ratioControl.alpha = mode == .crop ? 1 : 0
            self.rotateButton.alpha = mode == .crop ? 1 : 0
            self.undoButton.isEnabled = self.canvas.canUndo
        }
        for view in [cropButton, textButton, drawButton, applyButton] {
            view.isUserInteractionEnabled = isIdle
        }
        undoButton.isUserInteractionEnabled = mode == .draw
        palette.isUserInteractionEnabled = mode == .draw
        ratioControl.isUserInteractionEnabled = mode == .crop
        rotateButton.isUserInteractionEnabled = mode == .crop
        doneButton.isUserInteractionEnabled = !isIdle
    }

    private func closeTapped() {
        if mode == .crop {
            apply(.idle)
        } else {
            onCancel?()
        }
    }

    private func doneTapped() {
        switch mode {
        case .crop:
            applyCrop()
        case .draw:
            apply(.idle)
        case .idle:
            break
        }
    }

    private func style(_ button: UIButton, symbol: String, label: String) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.accessibilityLabel = label
    }
}
