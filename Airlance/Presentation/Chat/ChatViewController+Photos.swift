import ChatHistory
import MediaLoader
import UIKit

extension ChatViewController {
    func showPhotos(of message: HistoryMessage, at index: Int, node: MessageBubbleNode) {
        guard case .photos(let photos, _) = message.content else {
            return
        }

        inputBar.dismissKeyboard()
        let tiles = node.tiles
        let pages = photos.enumerated().map { offset, photo in
            PhotoViewerPage(
                thumbnail: tiles.indices.contains(offset) ? tiles[offset].node.image : nil,
                aspectRatio: CGFloat(photo.aspectRatio),
                source: photo.source,
                video: photo.video.flatMap { video in
                    video.source.url
                }
            )
        }
        let sources = photoSources(tiles, node: node, messageID: message.id, space: view.window ?? view)
        guard sources.count == pages.count else {
            return
        }

        let host: UIView = view.window ?? view
        let strings = presentation.strings
        let name = message.isOutgoing ? strings.chatYou : message.authorName
        let viewer = PhotoViewerView(
            pages: pages,
            sources: sources,
            start: index,
            clipArea: view.convert(visibleHistoryFrame, to: host),
            title: name,
            counterText: { current, total in
                guard total == 1 else {
                    return strings.chatPhotoCounter(current, total)
                }

                return photos.first?.video == nil ? strings.chatPhoto : strings.chatVideo
            },
            host: host
        )
        viewer.open()
    }

    private func photoSources(
        _ tiles: [MediaTile],
        node: MessageBubbleNode,
        messageID: String,
        space: UIView
    ) -> [PhotoViewerSource] {
        tiles.map { tile in
            PhotoViewerSource(
                frame: { [weak node, weak space] in
                    guard let node, let space, node.itemID == messageID, node.isOnScreen,
                          tile.node.supernode != nil else {
                        return nil
                    }

                    return tile.node.layer.convert(tile.node.bounds, to: space.layer)
                },
                setHidden: { hidden in
                    tile.setHidden(hidden)
                },
                corners: tile.request.corners
            )
        }
    }
}
