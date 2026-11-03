import CoreImage
import UIKit
import Vision

enum StoryCutout {
    static func lift(from image: UIImage) async -> UIImage? {
        guard #available(iOS 17.0, *), let cgImage = image.cgImage else {
            return nil
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return await Task.detached(priority: .userInitiated) { () -> StoryCutoutBox? in
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            guard (try? handler.perform([request])) != nil,
                  let result = request.results?.first,
                  let buffer = try? result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: true
                  ) else {
                return nil
            }

            let image = CIImage(cvPixelBuffer: buffer)
            guard let cutout = StoryImageFilter.context.createCGImage(image, from: image.extent) else {
                return nil
            }

            return StoryCutoutBox(image: UIImage(cgImage: cutout))
        }.value?.image
    }
}

private struct StoryCutoutBox: @unchecked Sendable {
    let image: UIImage
}
