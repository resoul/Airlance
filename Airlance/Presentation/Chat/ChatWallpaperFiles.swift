import Theme
import UIKit

@MainActor
enum ChatWallpaperFiles {
    private static var cached: UIImage?
    private static var isLoaded = false

    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        return base.appendingPathComponent("Shared", isDirectory: true).appendingPathComponent("wallpaper.jpg")
    }

    static var image: UIImage? {
        if !isLoaded {
            cached = UIImage(contentsOfFile: url.path)
            isLoaded = true
        }

        return cached
    }

    static func save(_ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            return false
        }

        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? data.write(to: url, options: .atomic)) != nil else {
            return false
        }

        cached = image
        isLoaded = true

        return true
    }
}

extension ChatWallpaper {
    var symbols: [String] {
        switch self {
        case .frost:
            ["snowflake", "cloud.snow.fill", "thermometer.snowflake", "star.fill", "sparkle", "wind"]
        case .love:
            ["heart.fill", "suit.heart.fill", "sparkles", "envelope.fill", "gift.fill", "star.fill"]
        case .holiday:
            ["gift.fill", "star.fill", "bell.fill", "sparkles", "snowflake", "birthday.cake.fill"]
        case .games:
            ["gamecontroller.fill", "dice.fill", "puzzlepiece.fill", "trophy.fill", "star.fill", "bolt.fill"]
        case .school:
            ["pencil", "ruler.fill", "book.fill", "function", "x.squareroot", "graduationcap.fill"]
        case .space:
            ["moon.stars.fill", "sparkles", "star.fill", "globe.americas.fill", "airplane", "sun.max.fill"]
        case .mint:
            ["leaf.fill", "camera.macro", "drop.fill", "sun.max.fill", "ladybug.fill", "tree.fill"]
        case .sunset:
            [
                "sun.horizon.fill", "beach.umbrella.fill", "cup.and.saucer.fill", "music.note", "camera.fill",
                "heart.fill",
            ]
        default:
            [
                "bubble.left.fill", "heart.fill", "star.fill", "paperplane.fill", "camera.fill",
                "music.note", "sparkles", "moon.fill", "leaf.fill", "face.smiling",
            ]
        }
    }
}
