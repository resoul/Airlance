import AVFoundation
import UIKit

public enum SubtitleLayers {
    public static func make(_ subtitles: Subtitles, size: CGSize) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: size)
        for phrase in subtitles.phrases {
            for (index, word) in phrase.words.enumerated() {
                let end = phrase.words.indices.contains(index + 1) ? phrase.words[index + 1].start : phrase.end + 0.3
                let layer = state(phrase, word: index, subtitles: subtitles, size: size)
                show(layer, from: word.start, to: end)
                container.addSublayer(layer)
            }
        }

        return container
    }

    private static func state(_ phrase: SubtitlePhrase, word: Int, subtitles: Subtitles, size: CGSize) -> CALayer {
        let text = SubtitleText.attributed(phrase, highlight: word, style: subtitles.style, width: size.width)
        var frame = SubtitleText.frame(for: text, position: subtitles.position, in: size)
        frame.origin.y = size.height - frame.maxY
        let plate = CALayer()
        plate.frame = frame
        plate.backgroundColor = SubtitleText.plateColor(subtitles.style)?.cgColor
        plate.cornerRadius = size.width * 0.026
        let label = CATextLayer()
        label.string = text
        label.isWrapped = true
        label.alignmentMode = .center
        label.contentsScale = 1
        let fitted = text.boundingRect(
            with: CGSize(width: frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        label.frame = CGRect(x: 0, y: (frame.height - fitted.height) / 2, width: frame.width, height: fitted.height)
        plate.addSublayer(label)
        plate.opacity = 0

        return plate
    }

    private static func show(_ layer: CALayer, from start: TimeInterval, to end: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 1
        animation.beginTime = start > 0 ? start : AVCoreAnimationBeginTimeAtZero
        animation.duration = max(end - start, 0.05)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .removed
        layer.add(animation, forKey: "visible")
    }
}
