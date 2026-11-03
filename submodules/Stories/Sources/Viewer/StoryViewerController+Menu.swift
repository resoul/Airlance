import Haptics
import UIKit

extension StoryViewerController {
    func bindMenu(_ page: StoryPageView) {
        page.moreButton.addAction(UIAction { [weak self] _ in
            self?.showMenu()
        }, for: .touchUpInside)
    }

    private func showMenu() {
        guard let page, let item = page.item, answerView == nil else {
            return
        }

        dismissTooltip()
        Haptics.play(.tap)
        isInteracting = true
        page.media.setPaused(true)
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if page.author.peer.isSelf {
            sheet.addAction(action(.editStory, style: .default, .edit(item: item.id)))
            sheet.addAction(action(.deleteStory, style: .destructive, .delete(item: item.id)))
        } else if let media = page.media.repostMedia {
            let peer = StoryMentionPeer(id: page.author.peer.id, name: page.author.peer.title)
            sheet.addAction(action(.repostStory, style: .default, .repost(media, peer: peer)))
        }
        sheet.addAction(UIAlertAction(title: label(.cancelMenu), style: .cancel) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resumeAfterMenu()
            }
        })
        sheet.popoverPresentationController?.sourceView = page.moreButton
        present(sheet, animated: true)
    }

    private func action(
        _ title: StoryLabel,
        style: UIAlertAction.Style,
        _ interaction: StoryInteraction
    ) -> UIAlertAction {
        UIAlertAction(title: label(title), style: style) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resumeAfterMenu()
                self?.onInteraction?(interaction)
            }
        }
    }

    private func resumeAfterMenu() {
        isInteracting = false
        page?.media.setPaused(isHeld)
    }
}
