import AirlanceUI
import ListUI
import Stories
import UIKit

extension ChatsViewController {
    func listDidScroll(_ list: ListView) {
        guard list === pager.currentList else {
            return
        }

        expansion.didScroll(offset: list.contentOffset)
        alignLists(to: list)
        updateExpansion()
    }

    func keepStoriesOnPageChange() {
        guard let list = pager.currentList else {
            return
        }

        expansion.keep(fraction: header.expansion, at: list.contentOffset)
    }

    func alignLists(to current: ListView) {
        let topZone = -expansion.baseInset + 0.5
        guard current.contentOffset <= topZone else {
            return
        }

        let offset = max(current.contentOffset, -expansion.topInset)
        for list in pager.lists where list !== current && list.contentOffset <= topZone {
            list.scrollView.contentOffset.y = offset
        }
    }

    func targetOffset(for list: ListView, proposed target: CGFloat) -> CGFloat {
        guard list === pager.currentList else {
            return target
        }

        return expansion.targetOffset(from: list.contentOffset, proposed: target)
    }

    func expandStories() {
        expansion.expand()
        pager.currentList?.scrollView.setContentOffset(CGPoint(x: 0, y: -expansion.topInset), animated: true)
    }

    func updateExpansion() {
        let offset = pager.currentList?.contentOffset ?? -expansion.topInset
        header.setExpansion(expansion.fraction(offset: offset))
        tabs.frame = CGRect(x: 0, y: header.visibleHeight, width: view.bounds.width, height: LiquidTabsView.height)
    }

    func updateInsets(top: CGFloat) {
        let previous = pager.contentInsets.top
        let atTop = pager.lists.map { list in
            list.contentOffset <= -previous + 1
        }
        pager.contentInsets = UIEdgeInsets(top: top, left: 0, bottom: view.safeAreaInsets.bottom, right: 0)
        for (list, wasAtTop) in zip(pager.lists, atTop) where wasAtTop && list !== pager.currentList {
            list.scrollView.contentOffset.y = -top
        }
    }

    func renderStories() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let peers = dependencies.storiesStore.ordered.map { story in
            StoryPeers.peer(story, strings: strings)
        }
        header.setPeers(peers)
        expansion.isEnabled = !peers.isEmpty
    }
}
