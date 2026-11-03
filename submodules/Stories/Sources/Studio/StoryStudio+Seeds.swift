import CoreImage
import Haptics
import UIKit

public enum StorySeed: Sendable {
    case addYours(String)
    case repost(StoryDraft.Media, StoryMentionPeer)
    case edit(StoryDraft)
}

extension StoryStudio {
    public func start() {
        switch seed {
        case .edit(let draft):
            isEditingPublished = true
            open(draft.rebased())
        case .repost(let media, let peer):
            repost(media, author: peer)
        case .addYours, nil:
            break
        }
    }

    private func repost(_ media: StoryDraft.Media, author: StoryMentionPeer) {
        let mention = StoryEntity(
            content: .widget(StoryWidget(kind: .mention(author), style: .dark)),
            center: CGPoint(x: 0.5, y: 0.8)
        )
        switch media {
        case .photo(let url):
            guard let image = UIImage(contentsOfFile: url.path), let card = Self.card(image),
                  let background = Self.backdrop(image) else {
                Haptics.play(.error)

                return
            }

            let backgroundURL = context.makeFileURL(extension: "jpg")
            let cardURL = context.makeFileURL(extension: "png")
            try? background.jpegData(compressionQuality: 0.9)?.write(to: backgroundURL)
            try? card.pngData()?.write(to: cardURL)
            var draft = StoryDraft(media: .photo(backgroundURL))
            let sticker = StorySticker(source: .image(cardURL), width: 0.7)
            draft.entities = [StoryEntity(content: .sticker(sticker), center: CGPoint(x: 0.5, y: 0.44)), mention]
            edit(.photo(background), draft: draft)
        case .video(let url):
            let copy = context.makeFileURL(extension: url.pathExtension.isEmpty ? "mp4" : url.pathExtension)
            guard (try? FileManager.default.copyItem(at: url, to: copy)) != nil else {
                Haptics.play(.error)

                return
            }

            var draft = StoryDraft(media: .video(copy))
            draft.entities = [mention]
            open(draft)
        }
    }

    private static func card(_ image: UIImage) -> UIImage? {
        guard image.size.width > 0 else {
            return nil
        }

        let width: CGFloat = 900
        let size = CGSize(width: width, height: (width * image.size.height / image.size.width).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: width * 0.05).addClip()
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func backdrop(_ image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image) else {
            return nil
        }

        let blurred = input.clampedToExtent()
            .applyingGaussianBlur(sigma: 40)
            .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.15])
            .cropped(to: input.extent)
        guard let cgImage = StoryImageFilter.context.createCGImage(blurred, from: input.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
