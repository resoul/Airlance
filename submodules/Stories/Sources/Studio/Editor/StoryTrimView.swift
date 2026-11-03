import AVFoundation
import Haptics
import UIKit

final class StoryTrimView: UIView {
    static let height: CGFloat = 76

    private static let frames = 10
    private static let handle: CGFloat = 16
    private static let minimum: TimeInterval = 1

    var onTrim: (@MainActor (StoryTrim) -> Void)?
    var onCover: (@MainActor (TimeInterval) -> Void)?

    private let strip = UIStackView()
    private let selection = UIView()
    private let leftHandle = UIView()
    private let rightHandle = UIView()
    private let coverMarker = UIView()
    private let caption = UILabel()
    private let strings: StoryStudioStrings
    private var duration: TimeInterval = 0
    private(set) var trim = StoryTrim(start: 0, end: 0)
    private(set) var cover: TimeInterval = 0
    private var dragging: UIView?

    init(url: URL, strings: StoryStudioStrings) {
        self.strings = strings
        super.init(frame: .zero)
        strip.axis = .horizontal
        strip.distribution = .fillEqually
        strip.clipsToBounds = true
        strip.layer.cornerRadius = 8
        selection.layer.borderColor = UIColor.white.cgColor
        selection.layer.borderWidth = 3
        selection.layer.cornerRadius = 8
        selection.isUserInteractionEnabled = false
        for handle in [leftHandle, rightHandle] {
            handle.backgroundColor = .white
            handle.layer.cornerRadius = 4
        }
        coverMarker.backgroundColor = .systemYellow
        coverMarker.layer.cornerRadius = 2
        caption.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        caption.textColor = UIColor.white.withAlphaComponent(0.85)
        for view in [strip, selection, leftHandle, rightHandle, coverMarker, caption] {
            addSubview(view)
        }
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        load(url)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func set(trim: StoryTrim?, cover: TimeInterval) {
        if let trim {
            self.trim = trim
        }
        self.cover = cover
        setNeedsLayout()
    }

    private var stripFrame: CGRect {
        CGRect(x: Self.handle, y: 22, width: bounds.width - Self.handle * 2, height: 46)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frame = stripFrame
        strip.frame = frame
        guard duration > 0 else {
            return
        }

        let start = x(for: trim.start)
        let end = x(for: trim.end)
        selection.frame = CGRect(x: start - 2, y: frame.minY - 2, width: end - start + 4, height: frame.height + 4)
        leftHandle.frame = CGRect(x: start - Self.handle + 4, y: frame.minY, width: 8, height: frame.height)
        rightHandle.frame = CGRect(x: end - 4, y: frame.minY, width: 8, height: frame.height)
        let coverX = x(for: cover)
        coverMarker.frame = CGRect(x: coverX - 2, y: frame.minY - 6, width: 4, height: frame.height + 12)
        caption.frame = CGRect(x: frame.minX, y: 0, width: frame.width, height: 18)
        caption.text = "\(strings.label(.trim)) \(Self.time(trim.start))–\(Self.time(trim.end))   "
            + "\(strings.label(.cover)) \(Self.time(cover))"
    }

    private func x(for time: TimeInterval) -> CGFloat {
        let frame = stripFrame

        return frame.minX + frame.width * CGFloat(time / max(duration, 0.01))
    }

    private func time(at x: CGFloat) -> TimeInterval {
        let frame = stripFrame

        return min(max(Double((x - frame.minX) / max(frame.width, 1)) * duration, 0), duration)
    }

    private func load(_ url: URL) {
        let asset = AVURLAsset(url: url)
        Task { [weak self] in
            let length = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
            guard length > 0 else {
                return
            }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 160)
            var images: [UIImage] = []
            for index in 0..<Self.frames {
                let seconds = length * (Double(index) + 0.5) / Double(Self.frames)
                let time = CMTime(seconds: seconds, preferredTimescale: 600)
                if let image = try? await generator.image(at: time).image {
                    images.append(UIImage(cgImage: image))
                }
            }
            self?.loaded(images, duration: length)
        }
    }

    private func loaded(_ images: [UIImage], duration: TimeInterval) {
        self.duration = duration
        if trim.end <= 0 {
            trim = StoryTrim(start: 0, end: duration)
        }
        for image in images {
            let view = UIImageView(image: image)
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            strip.addArrangedSubview(view)
        }
        setNeedsLayout()
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            let left = abs(point.x - x(for: trim.start))
            let right = abs(point.x - x(for: trim.end))
            dragging = min(left, right) < 36 ? (left < right ? leftHandle : rightHandle) : nil
            Haptics.prepare(.selection)
        case .changed:
            let value = time(at: point.x)
            if dragging === leftHandle {
                trim.start = min(value, trim.end - Self.minimum)
            } else if dragging === rightHandle {
                trim.end = max(value, trim.start + Self.minimum)
            }
            cover = min(max(cover, trim.start), trim.end)
            setNeedsLayout()
        default:
            if dragging != nil {
                Haptics.play(.selection)
                onTrim?(trim)
            }
            dragging = nil
        }
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        let value = time(at: gesture.location(in: self).x)
        cover = min(max(value, trim.start), trim.end)
        Haptics.play(.selection)
        setNeedsLayout()
        onCover?(cover)
    }

    private static func time(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())

        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
