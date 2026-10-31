import ChatHistory
import UIKit

extension ChatViewController {
    func bindMentions() {
        mentions.isHidden = true
        mentions.onPick = { [weak self] person in
            self?.inputBar.insertMention(name: person.name, userID: person.id)
        }
        view.addSubview(mentions)
        inputBar.onMentionQuery = { [weak self] query in
            self?.showMentions(query)
        }
    }

    func layoutMentions() {
        let height = mentions.contentHeight
        mentions.frame = CGRect(x: 0, y: bottomBarTop - height, width: view.bounds.width, height: height)
    }

    private var mentionCandidates: [MessageCommenter] {
        let kind = thread == nil ? dependencies.chatsStore.chat(id)?.kind : .group
        guard kind == .group else {
            return []
        }

        return ChatChannelFixtures.commenters
    }

    private func showMentions(_ query: String?) {
        let people = query.map { query in
            mentionCandidates.filter { person in
                query.isEmpty || person.name.range(of: query, options: [.caseInsensitive, .anchored]) != nil
            }
        } ?? []
        mentions.apply(presentation)
        mentions.setPeople(people)
        let isHidden = people.isEmpty
        guard mentions.isHidden != isHidden || !isHidden else {
            return
        }

        mentions.isHidden = false
        layoutMentions()
        UIView.animate(withDuration: 0.2) {
            self.mentions.alpha = isHidden ? 0 : 1
        } completion: { _ in
            self.mentions.isHidden = isHidden
        }
    }
}
