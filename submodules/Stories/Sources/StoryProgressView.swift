import UIKit

@MainActor
final class StoryProgressView: UIView {
    private static let gap: CGFloat = 3
    private static let height: CGFloat = 2.5

    private var tracks: [UIView] = []
    private var fills: [UIView] = []
    private var index = 0
    private var progress: CGFloat = 0

    func setCount(_ count: Int) {
        for view in tracks {
            view.removeFromSuperview()
        }
        tracks = (0..<count).map { _ in
            let track = UIView()
            track.backgroundColor = UIColor(white: 1, alpha: 0.3)
            track.layer.cornerRadius = Self.height / 2
            track.clipsToBounds = true
            addSubview(track)

            return track
        }
        fills = tracks.map { track in
            let fill = UIView()
            fill.backgroundColor = .white
            track.addSubview(fill)

            return fill
        }
        setNeedsLayout()
    }

    func set(index: Int, progress: CGFloat) {
        self.index = index
        self.progress = min(max(progress, 0), 1)
        layoutFills()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let count = CGFloat(max(tracks.count, 1))
        let width = (bounds.width - Self.gap * (count - 1)) / count
        for (offset, track) in tracks.enumerated() {
            track.frame = CGRect(
                x: CGFloat(offset) * (width + Self.gap),
                y: (bounds.height - Self.height) / 2,
                width: width,
                height: Self.height
            )
        }
        layoutFills()
    }

    private func layoutFills() {
        for (offset, fill) in fills.enumerated() {
            let value: CGFloat = offset < index ? 1 : offset > index ? 0 : progress
            let track = tracks[offset].bounds
            fill.frame = CGRect(x: 0, y: 0, width: track.width * value, height: track.height)
        }
    }
}
