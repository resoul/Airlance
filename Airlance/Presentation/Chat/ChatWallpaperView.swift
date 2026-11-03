import Theme
import UIKit

final class ChatWallpaperView: UIView {
    private static let tileSize = CGSize(width: 180, height: 180)
    @MainActor private static var tiles: [ThemeWallpaper: UIImage] = [:]

    private let gradient = CAGradientLayer()
    private let pattern = UIView()
    private let photo = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)
        photo.contentMode = .scaleAspectFill
        photo.clipsToBounds = true
        addSubview(photo)
        addSubview(pattern)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ wallpaper: ThemeWallpaper?) {
        isHidden = wallpaper == nil
        guard let wallpaper else {
            return
        }

        gradient.colors = wallpaper.colors.map(\.cgColor)
        photo.isHidden = wallpaper.kind != .photo
        photo.image = wallpaper.kind == .photo ? ChatWallpaperFiles.image : nil
        pattern.isHidden = wallpaper.kind == .photo || wallpaper.kind == .color
        if !pattern.isHidden {
            pattern.backgroundColor = UIColor(patternImage: Self.tile(for: wallpaper))
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
        photo.frame = bounds
        pattern.frame = bounds
    }

    private static func tile(for wallpaper: ThemeWallpaper) -> UIImage {
        if let tile = tiles[wallpaper] {
            return tile
        }

        let tile = UIGraphicsImageRenderer(size: tileSize).image { _ in
            var random = SeededRandom(seed: ChatHistoryFixtures.seed(wallpaper.kind.rawValue))
            let symbols = wallpaper.kind.symbols
            let columns = 3
            let cell = tileSize.width / CGFloat(columns)
            for index in 0..<columns * columns {
                let name = symbols[Int(random.next() % UInt64(symbols.count))]
                let size = 16 + CGFloat(random.next() % 10)
                let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
                guard let image = UIImage(systemName: name, withConfiguration: configuration) else {
                    continue
                }

                let jitter = CGPoint(x: CGFloat(random.next() % 20) - 10, y: CGFloat(random.next() % 20) - 10)
                let center = CGPoint(
                    x: (CGFloat(index % columns) + 0.5) * cell + jitter.x,
                    y: (CGFloat(index / columns) + 0.5) * cell + jitter.y
                )
                let rect = CGRect(
                    origin: CGPoint(x: center.x - image.size.width / 2, y: center.y - image.size.height / 2),
                    size: image.size
                )
                image.withTintColor(wallpaper.pattern, renderingMode: .alwaysOriginal).draw(in: rect)
            }
        }
        tiles[wallpaper] = tile

        return tile
    }
}
