import UIKit

public struct TabBarItem {
    public let image: UIImage?
    public let selectedImage: UIImage?
    public let title: String

    public init(image: UIImage?, selectedImage: UIImage? = nil, title: String) {
        self.image = image
        self.selectedImage = selectedImage
        self.title = title
    }
}
