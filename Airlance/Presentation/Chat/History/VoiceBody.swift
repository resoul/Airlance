@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct VoiceParts {
    let play: ASImageNode
    let wave: ASImageNode
    let length: ASTextNode
    let iconColor: UIColor
    let waveFrame: CGRect
    let amplitudes: [Float]
    let played: UIColor
    let rest: UIColor
    let duration: TimeInterval
    let lengthColor: UIColor
    let lengthFont: UIFont
}

struct VoiceBody {
    private static let playSize: CGFloat = 42
    private static let height: CGFloat = 60

    let voice: MessageVoice
    let input: MessageBubbleInput
    let scale: CGFloat
    let maxBubble: CGFloat

    func make(style: HistoryStyle) -> BubbleBody {
        let padding = MessageBubbleLayout.padding
        let message = input.message
        let outgoing = message.isOutgoing
        let width = min(maxBubble, 250)
        let header = BubbleHeader(input, style: style, maxWidth: width - padding.left - padding.right, scale: scale)
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: .zero, content: content)
        var top: CGFloat = 0
        if !header.isEmpty {
            let origin = CGPoint(x: padding.left, y: padding.top)
            body.add(header.place(in: content, at: origin, width: width - padding.left - padding.right))
            top = padding.top + header.size.height - 2
        }
        body.voice = parts(in: content, top: top, width: width, style: style)
        let buttonFrame = CGRect(x: width - 44, y: top + 12, width: 34, height: 24)
        content.addSubnode(transcribeButton(frame: buttonFrame, style: style))
        body.actions.append(BubbleAction(frame: buttonFrame.insetBy(dx: -6, dy: -8), kind: .transcribe))
        let meta = MessageMeta(input, delivery: outgoing ? message.delivery : nil, style: style)
        var height = top + Self.height
        if let transcript = input.transcript, transcript.isShown {
            height = addTranscript(transcript, to: &body, top: top + 48, width: width, meta: meta, style: style)
        } else {
            meta.place(in: content, bottomRight: CGPoint(x: width - 11, y: height - 7))
        }
        let size = CGSize(width: ceil(width), height: ceil(height))
        content.frame = CGRect(origin: .zero, size: size)
        body.size = size
        body.actions.append(BubbleAction(frame: CGRect(x: 0, y: top, width: width - 50, height: 46), kind: .voice))

        return body
    }

    private func parts(in content: ASDisplayNode, top: CGFloat, width: CGFloat, style: HistoryStyle) -> VoiceParts {
        let outgoing = input.message.isOutgoing
        let tint = style.tint(outgoing: outgoing)
        let rest = tint.withAlphaComponent(0.35)
        let amplitudes = voice.waveform.map { value in
            Float(value) / 31
        }
        let waveFrame = CGRect(x: 58, y: top + 8, width: width - 108, height: 28)
        let wave = Self.waveNode(amplitudes, frame: waveFrame, color: rest, scale: scale)
        content.addSubnode(wave)
        let iconColor = outgoing ? style.outgoingBubble : UIColor.white
        let play = Self.playNode(tint: tint, icon: iconColor)
        play.frame = CGRect(x: 9, y: top + 9, width: Self.playSize, height: Self.playSize)
        content.addSubnode(play)
        let length = lengthNode(VoiceBadge.text(voice.duration), color: tint, style: style)
        length.frame.origin = CGPoint(x: 60, y: top + 38)
        content.addSubnode(length)
        if !outgoing, !input.message.isListened {
            content.addSubnode(Self.unlistenedDot(after: length.frame, color: tint))
        }

        return VoiceParts(
            play: play,
            wave: wave,
            length: length,
            iconColor: iconColor,
            waveFrame: waveFrame,
            amplitudes: amplitudes,
            played: tint,
            rest: rest,
            duration: voice.duration,
            lengthColor: tint,
            lengthFont: style.metaFont
        )
    }

    private func addTranscript(
        _ transcript: VoiceTranscriptText,
        to body: inout BubbleBody,
        top: CGFloat,
        width: CGFloat,
        meta: MessageMeta,
        style: HistoryStyle
    ) -> CGFloat {
        let padding = MessageBubbleLayout.padding
        let textWidth = width - padding.left - padding.right
        let text = MessageBubbleLayout.text(
            transcript.text,
            outgoing: input.message.isOutgoing,
            metaWidth: meta.size.width,
            style: style,
            width: textWidth
        )
        if transcript.isPending {
            text.alpha = 0.6
        }
        text.place(in: body.content, at: CGPoint(x: padding.left, y: top), width: textWidth)
        body.text = text
        meta.place(in: body.content, bottomRight: CGPoint(x: width - padding.right, y: text.frame.maxY))

        return text.frame.maxY + padding.bottom
    }

    private func transcribeButton(frame: CGRect, style: HistoryStyle) -> ASImageNode {
        let tint = style.tint(outgoing: input.message.isOutgoing)
        let transcript = input.transcript
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.frame = frame
        node.cornerRadius = 7
        node.backgroundColor = tint.withAlphaComponent(0.15)
        node.contentMode = .center
        let symbol = transcript?.isShown == true ? "chevron.up" : "text.bubble"
        let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        if transcript == nil {
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            node.image = UIGraphicsImageRenderer(size: frame.size, format: format).image { _ in
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: tint,
                ]
                let size = ("Aa" as NSString).size(withAttributes: attributes)
                let origin = CGPoint(x: (frame.width - size.width) / 2, y: (frame.height - size.height) / 2)
                ("Aa" as NSString).draw(at: origin, withAttributes: attributes)
            }
        } else {
            node.image = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(tint, renderingMode: .alwaysOriginal)
        }

        return node
    }

    private func lengthNode(_ text: String, color: UIColor, style: HistoryStyle) -> ASTextNode {
        let node = ASTextNode()
        node.isLayerBacked = true
        node.maximumNumberOfLines = 1
        let attributes: [NSAttributedString.Key: Any] = [.font: style.metaFont, .foregroundColor: color]
        node.attributedText = NSAttributedString(string: text, attributes: attributes)
        node.frame = CGRect(origin: .zero, size: MessageBubbleLayout.measure(node, width: 80))

        return node
    }

    static func playImage(_ playing: Bool, color: UIColor) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)

        return UIImage(systemName: playing ? "pause.fill" : "play.fill", withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }

    private static func playNode(tint: UIColor, icon: UIColor) -> ASImageNode {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.backgroundColor = tint
        node.cornerRadius = playSize / 2
        node.contentMode = .center
        node.image = playImage(false, color: icon)

        return node
    }

    private static func unlistenedDot(after frame: CGRect, color: UIColor) -> ASDisplayNode {
        let dot = ASDisplayNode()
        dot.isLayerBacked = true
        dot.backgroundColor = color
        dot.cornerRadius = 3
        dot.frame = CGRect(x: frame.maxX + 4, y: frame.midY - 3, width: 6, height: 6)

        return dot
    }

    private static func waveNode(_ amplitudes: [Float], frame: CGRect, color: UIColor, scale: CGFloat) -> ASImageNode {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.frame = frame
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        node.image = UIGraphicsImageRenderer(size: frame.size, format: format).image { _ in
            color.setFill()
            VoiceWavePath.make(amplitudes, size: frame.size).fill()
        }

        return node
    }
}

enum VoiceBadge {
    static func text(_ duration: TimeInterval) -> String {
        VideoBadge.text(duration)
    }
}

enum VoiceWavePath {
    static func make(_ amplitudes: [Float], size: CGSize) -> UIBezierPath {
        let margin: CGFloat = 4
        let mid = size.height / 2
        let steps = max(2, Int(size.width - margin * 2))
        var top: [CGPoint] = []
        for step in 0...steps {
            let x = CGFloat(step) / CGFloat(steps)
            let amplitude = max(CGFloat(sample(amplitudes, at: x)), 0.12)
            let half = max(amplitude * size.height * 0.42, 1.4)
            top.append(CGPoint(x: margin + x * (size.width - margin * 2), y: mid - half))
        }
        let path = UIBezierPath()
        path.move(to: top[0])
        for point in top.dropFirst() {
            path.addLine(to: point)
        }
        for point in top.reversed() {
            path.addLine(to: CGPoint(x: point.x, y: mid * 2 - point.y))
        }
        path.close()

        return path
    }

    private static func sample(_ values: [Float], at x: CGFloat) -> Float {
        guard values.count > 1 else {
            return values.first ?? 0
        }

        let f = Float(min(max(x, 0), 1)) * Float(values.count - 1)
        let i = Int(f)
        let t = f - Float(i)
        let last = values.count - 1
        let a = values[max(i - 1, 0)]
        let b = values[i]
        let c = values[min(i + 1, last)]
        let d = values[min(i + 2, last)]
        let cubic = (-a + 3 * b - 3 * c + d) * t * t * t

        return 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + cubic)
    }
}
