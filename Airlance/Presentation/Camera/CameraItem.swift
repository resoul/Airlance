import MediaLoader
import UIKit

enum CameraItem {
    case photo(UIImage)
    case video(URL, poster: UIImage?)

    var preview: UIImage? {
        switch self {
        case .photo(let image):
            image
        case .video(_, let poster):
            poster
        }
    }

    static func video(at url: URL) async -> CameraItem {
        let poster = await VideoFrames.first(of: url, maxSize: CGSize(width: 1080, height: 1080))

        return .video(url, poster: poster)
    }
}
