import Theme
import UIKit

struct PinnedMessageItem: Equatable {
    let id: String
    let text: String
}

final class PinnedMessageBar: UIControl {
    static let height: CGFloat = 46

    var onUnpin: (@MainActor () -> Void)?

    private let separator = UIView()
    private let track = UIView()
    private let marker = UIView()
    private let title = UILabel()
    private let clip = UIView()
    private var text = UILabel()
    private let unpin = UIButton(type: .system)
    private var segments: [UIView] = []
    private var items: [PinnedMessageItem] = []
    private var titleText: (Int, Int) -> String = { _, _ in
        ""
    }
    private var textFont = UIFont.systemFont(ofSize: 14)
    private var textColor = UIColor.label
    private var accent = UIColor.systemBlue
    private(set) var current = 0

    var currentItem: PinnedMessageItem? {
        items.indices.contains(current) ? items[current] : nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        track.isUserInteractionEnabled = false
        marker.layer.cornerRadius = 1
        track.addSubview(marker)
        addSubview(track)
        title.isUserInteractionEnabled = false
        addSubview(title)
        clip.clipsToBounds = true
        clip.isUserInteractionEnabled = false
        clip.addSubview(text)
        addSubview(clip)
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        unpin.setImage(UIImage(systemName: "pin.slash", withConfiguration: configuration), for: .normal)
        unpin.addAction(
            UIAction { [weak self] _ in
                self?.onUnpin?()
            },
            for: .touchUpInside
        )
        addSubview(unpin)
        addSubview(separator)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme, title: @escaping (Int, Int) -> String, unpinLabel: String) {
        titleText = title
        accent = theme.colors.accent
        textFont = theme.fonts.subheadline
        textColor = theme.colors.textPrimary
        backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.separator
        marker.backgroundColor = accent
        self.title.font = HistoryStyle(theme: theme).nameFont
        self.title.textColor = accent
        text.font = textFont
        text.textColor = textColor
        unpin.tintColor = theme.colors.textSecondary
        unpin.accessibilityLabel = unpinLabel
        rebuildSegments()
        updateTitle()
    }

    func setItems(_ items: [PinnedMessageItem], showing index: Int) {
        let changed = items.map(\.id) != self.items.map(\.id)
        self.items = items
        if changed {
            rebuildSegments()
        }
        show(index, animated: !changed)
        if changed {
            text.text = currentItem?.text
        }
    }

    func show(_ index: Int, animated: Bool) {
        guard items.indices.contains(index) else {
            return
        }

        let up = index < current
        let changed = index != current
        current = index
        updateTitle()
        guard animated, changed, !UIAccessibility.isReduceMotionEnabled else {
            text.text = items[index].text
            setNeedsLayout()

            return
        }

        slide(to: items[index].text, up: up)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
            self.marker.frame = self.segments[index].frame
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = bounds.height
        separator.frame = CGRect(x: 0, y: height - 0.5, width: bounds.width, height: 0.5)
        track.frame = CGRect(x: 12, y: 7, width: 2, height: height - 14)
        let gap: CGFloat = 2
        let count = CGFloat(max(segments.count, 1))
        let segmentHeight = (track.bounds.height - gap * (count - 1)) / count
        for (index, segment) in segments.enumerated() {
            segment.frame = CGRect(x: 0, y: CGFloat(index) * (segmentHeight + gap), width: 2, height: segmentHeight)
        }
        if segments.indices.contains(current) {
            marker.frame = segments[current].frame
        }
        let titleHeight = ceil(title.font?.lineHeight ?? 17)
        let textHeight = ceil(textFont.lineHeight)
        let top = (height - titleHeight - textHeight) / 2
        title.frame = CGRect(x: 24, y: top, width: bounds.width - 76, height: titleHeight)
        clip.frame = CGRect(x: 24, y: top + titleHeight, width: bounds.width - 76, height: textHeight)
        text.frame = clip.bounds
        unpin.frame = CGRect(x: bounds.width - 48, y: (height - 44) / 2, width: 44, height: 44)
    }

    private func rebuildSegments() {
        for segment in segments {
            segment.removeFromSuperview()
        }
        segments = items.map { _ in
            let segment = UIView()
            segment.backgroundColor = accent.withAlphaComponent(0.3)
            segment.layer.cornerRadius = 1
            track.insertSubview(segment, belowSubview: marker)

            return segment
        }
        marker.isHidden = items.isEmpty
        setNeedsLayout()
    }

    private func updateTitle() {
        title.text = titleText(current + 1, items.count)
    }

    private func slide(to string: String, up: Bool) {
        let old = text
        let new = UILabel()
        new.font = textFont
        new.textColor = textColor
        new.text = string
        let offset = clip.bounds.height
        new.frame = clip.bounds.offsetBy(dx: 0, dy: up ? -offset : offset)
        clip.addSubview(new)
        text = new
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            old.frame = self.clip.bounds.offsetBy(dx: 0, dy: up ? offset : -offset)
            old.alpha = 0
            new.frame = self.clip.bounds
        } completion: { _ in
            old.removeFromSuperview()
        }
    }
}
