import AVFoundation
import Haptics
import UIKit

extension StoryEditorView {
    var storyLength: TimeInterval {
        guard case .video = media else {
            return StorySound.photoDuration
        }

        return trim?.duration ?? videoDuration
    }

    func showSound() {
        let panel = StorySoundPanel(sound: sound, strings: strings, isVideo: player != nil, length: storyLength)
        panel.onChange = { [weak self] sound in
            self?.changeSound(sound)
        }
        panel.onPickTrack = { [weak self] in
            self?.onPickTrack?()
        }
        panel.onRecord = { [weak self] isHolding in
            self?.holdRecord(isHolding)
        }
        panel.alpha = 0
        addSubview(panel)
        soundPanel = panel
        loadWaveform()
        setNeedsLayout()
        layoutIfNeeded()
        UIView.animate(withDuration: 0.25) {
            panel.alpha = 1
        }
    }

    func layoutSoundPanel() {
        guard let soundPanel else {
            return
        }

        let height = soundPanel.preferredHeight
        soundPanel.frame = CGRect(
            x: 8,
            y: bounds.height - max(safeAreaInsets.bottom, 8) - height,
            width: bounds.width - 16,
            height: height
        )
    }

    func setTrack(_ track: StoryTrack) {
        if let old = sound.track, old.url != track.url {
            try? FileManager.default.removeItem(at: old.url)
        }
        sound.track = track
        soundPanel?.set(sound: sound)
        applySound()
        restartSound()
        loadWaveform(suggests: true)
        setNeedsLayout()
    }

    func changeSound(_ next: StorySound) {
        let restarts = next.track?.start != sound.track?.start || next.track?.url != sound.track?.url
            || next.voice?.url != sound.voice?.url
        sound = next
        applySound()
        if restarts {
            restartSound()
        }
        setNeedsLayout()
    }

    private func loadWaveform(suggests: Bool = false) {
        guard let track = sound.track else {
            return
        }

        let count = 64
        let length = storyLength
        Task { [weak self] in
            let samples = await StoryWaveform.samples(of: track.url, count: count)
            guard let self, self.sound.track?.url == track.url else {
                return
            }

            if suggests, track.duration > length {
                let window = Int((length / track.duration * Double(count)).rounded())
                let index = StoryWaveform.loudest(samples, window: window)
                self.sound.track?.start = min(Double(index) / Double(count) * track.duration, track.duration - length)
                self.soundPanel?.set(sound: self.sound)
                self.restartSound()
            }
            self.soundPanel?.setWaveform(samples)
        }
    }
}

extension StoryEditorView {
    func coverImage(width: CGFloat) -> UIImage? {
        guard bounds.width > 0, let base = imageView.image ?? media.preview else {
            return nil
        }

        let size = CGSize(width: width, height: (width * bounds.height / bounds.width).rounded())
        let overlay = canvas.render(width: width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let scale = max(size.width / base.size.width, size.height / base.size.height)
            let drawn = CGSize(width: base.size.width * scale, height: base.size.height * scale)
            base.draw(in: CGRect(
                x: (size.width - drawn.width) / 2,
                y: (size.height - drawn.height) / 2,
                width: drawn.width,
                height: drawn.height
            ))
            overlay?.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
