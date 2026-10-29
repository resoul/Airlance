import LiquidUI
import UIKit

extension MessageBubbleNode {
    func setVoice(progress: CGFloat, isPlaying: Bool) {
        guard let (parts, origin) = voiceLayout else {
            return
        }

        parts.play.image = VoiceBody.playImage(isPlaying, color: parts.iconColor)
        let isIdle = !isPlaying && progress <= 0
        let current = isIdle ? parts.duration : parts.duration * Double(progress)
        parts.length.attributedText = NSAttributedString(
            string: VoiceBadge.text(current),
            attributes: [.font: parts.lengthFont, .foregroundColor: parts.lengthColor]
        )
        guard !isIdle, LiquidWaveView.isSupported else {
            removeVoice()

            return
        }

        let wave = waveView ?? LiquidWaveView()
        if waveView == nil {
            waveView = wave
            view.addSubview(wave)
        }
        wave.frame = parts.waveFrame.offsetBy(dx: origin.x, dy: origin.y)
        wave.playedColor = parts.played
        wave.restColor = parts.rest
        if wave.amplitudes != parts.amplitudes {
            wave.amplitudes = parts.amplitudes
        }
        wave.progress = progress
        if wave.isPlaying != isPlaying {
            wave.isPlaying = isPlaying
        }
        parts.wave.isHidden = true
    }

    func removeVoice() {
        waveView?.removeFromSuperview()
        waveView = nil
        voiceLayout?.parts.wave.isHidden = false
    }
}
