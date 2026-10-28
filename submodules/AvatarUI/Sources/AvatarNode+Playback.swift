@preconcurrency import AsyncDisplayKit
import UIKit

extension AvatarNode: AvatarPlaybackParticipant {
    var wantsPlayback: Bool {
        guard isInHierarchy, isOnScreen, presentation.playbackPriority > 0 else {
            return false
        }

        return descriptor?.video != nil && videoNode?.failed != true
    }

    var playbackPriority: Int {
        presentation.playbackPriority
    }

    func setPlaybackAllowed(_ allowed: Bool) {
        guard allowed != isPlaybackAllowed else {
            return
        }

        isPlaybackAllowed = allowed
        guard allowed, let video = descriptor?.video else {
            videoNode?.setAllowed(false)
            videoNode?.isHidden = true

            return
        }

        let node = videoNode ?? makeVideoNode()
        node.setSource(key: video.key, url: video.source(for: presentation), start: video.startTimestamp)
        node.setAllowed(true)
    }

    func resetVideo() {
        isPlaybackAllowed = false
        videoNode?.reset()
        videoNode?.removeFromSupernode()
        videoNode = nil
    }

    private func makeVideoNode() -> AvatarVideoNode {
        let node = AvatarVideoNode()
        node.isHidden = true
        node.onReady = { [weak self, weak node] ready in
            guard let self, let node, self.videoNode === node else {
                return
            }

            node.isHidden = !ready || !self.isPlaybackAllowed
        }
        node.onFailure = {
            AvatarPlayback.shared.update()
        }
        videoNode = node
        insertSubnode(node, aboveSubnode: imageNode)
        node.frame = contentFrame

        return node
    }
}
