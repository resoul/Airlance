import UIKit

public enum StudioMedia {
    case photo(UIImage)
    case video(URL, poster: UIImage?)

    public var preview: UIImage? {
        switch self {
        case .photo(let image):
            image
        case .video(_, let poster):
            poster
        }
    }
}
