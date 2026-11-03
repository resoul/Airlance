import AVFoundation
import Haptics
import UIKit

extension StoryEditorView {
    func setMode(_ next: Mode) {
        guard next != mode else {
            return
        }

        mode = next
        canvas.isDrawing = next == .draw
        Haptics.play(.selection)
        switch next {
        case .adjust:
            showAdjust()
        case .trim:
            showTrim()
        case .sound:
            showSound()
        case .idle, .draw:
            hidePanels()
        }
        updateTools()
    }

    func updateTools() {
        let mode = mode
        let isIdle = mode == .idle
        UIView.animate(withDuration: 0.2) {
            let idleTools = [
                self.textButton, self.drawButton, self.stickerButton, self.adjustButton, self.soundButton,
                self.extraButton,
                self.closeButton, self.audienceButton, self.publishButton, self.subtitleButton,
            ]
            for view in idleTools {
                view.alpha = isIdle ? 1 : 0
            }
            self.undoButton.alpha = mode == .draw ? 1 : 0
            self.palette.alpha = mode == .draw ? 1 : 0
            self.brushBar.alpha = mode == .draw ? 1 : 0
            self.doneButton.alpha = isIdle ? 0 : 1
            self.undoButton.isEnabled = self.canvas.canUndo
        }
        for view in [palette, brushBar, undoButton] {
            view.isUserInteractionEnabled = mode == .draw
        }
        doneButton.isUserInteractionEnabled = !isIdle
    }

    func showStickers() {
        guard stickerPicker == nil else {
            return
        }

        let picker = StoryStickerPicker(frame: bounds, strings: strings)
        picker.onPick = { [weak self] emoji, isReaction in
            if isReaction {
                self?.canvas.addWidget(StoryWidget(kind: .reaction(emoji)), center: CGPoint(x: 0.5, y: 0.6))
            } else {
                self?.canvas.addSticker(StorySticker(source: .emoji(emoji)))
            }
            self?.hideStickers()
        }
        picker.onWidget = { [weak self] type in
            self?.hideStickers()
            self?.showWidgetForm(type)
        }
        picker.onClose = { [weak self] in
            self?.hideStickers()
        }
        addSubview(picker)
        stickerPicker = picker
        picker.layoutIfNeeded()
        picker.show()
    }

    private func hideStickers() {
        stickerPicker?.hide()
        stickerPicker = nil
    }

    func setCutoutLoading(_ isLoading: Bool) {
        extraButton.isEnabled = !isLoading
        extraButton.imageView?.alpha = isLoading ? 0 : 1
        if isLoading {
            extraSpinner.startAnimating()
        } else {
            extraSpinner.stopAnimating()
        }
    }

    private func showAdjust() {
        let panel = StoryAdjustPanel(adjustments: adjustments, strings: strings)
        panel.onChange = { [weak self] adjustments in
            self?.adjustments = adjustments
            self?.applyAdjustments()
        }
        panel.alpha = 0
        addSubview(panel)
        adjustPanel = panel
        setNeedsLayout()
        layoutIfNeeded()
        UIView.animate(withDuration: 0.25) {
            panel.alpha = 1
        }
    }

    private func showTrim() {
        guard trimView == nil, case .video(let url, _) = media else {
            return
        }

        let view = StoryTrimView(url: url, strings: strings)
        view.set(trim: trim, cover: coverTime)
        view.onTrim = { [weak self] trim in
            self?.trim = trim
            self?.restartPlayer()
        }
        view.onCover = { [weak self] time in
            self?.coverTime = time
            self?.player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        }
        view.alpha = 0
        addSubview(view)
        trimView = view
        setNeedsLayout()
        layoutIfNeeded()
        UIView.animate(withDuration: 0.25) {
            view.alpha = 1
        }
    }

    private func hidePanels() {
        for panel in [adjustPanel as UIView?, trimView, soundPanel].compactMap(\.self) {
            UIView.animate(withDuration: 0.2) {
                panel.alpha = 0
            } completion: { _ in
                panel.removeFromSuperview()
            }
        }
        adjustPanel = nil
        trimView = nil
        soundPanel = nil
    }

    func applyAdjustments() {
        adjustTask?.cancel()
        switch media {
        case .photo(let image):
            imageView.image = StoryImageFilter.render(image, adjustments: adjustments, maxSide: 1400)
        case .video(let url, _):
            let adjustments = adjustments
            adjustTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else {
                    return
                }

                let composition = await StoryImageFilter.videoComposition(
                    for: AVURLAsset(url: url),
                    adjustments: adjustments
                )
                guard !Task.isCancelled, let self else {
                    return
                }

                self.videoComposition = composition
                self.restartPlayer()
            }
        }
    }
}
