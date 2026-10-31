import ChatHistory
import Foundation

extension ChatHistoryStore {
    func threadHistory(_ id: String) -> ChatHistoryFixtures.History? {
        guard
            let thread = CommentThread(id: id),
            let chat = chatsStore.chat(thread.channelID),
            let post = post(thread)
        else {
            return nil
        }

        let history = ChatChannelFixtures.thread(for: post, in: chat)
        histories[id] = history

        return history
    }

    func post(_ thread: CommentThread) -> HistoryMessage? {
        history(for: thread.channelID)?.messages.first { message in
            message.id == thread.postID
        }
    }

    func channelPost(_ message: HistoryMessage, in id: String) -> HistoryMessage {
        guard let chat = chatsStore.chat(id), chat.kind == .channel else {
            return message
        }

        var post = HistoryMessage(
            id: message.id,
            authorID: chat.id,
            authorName: chat.name,
            isOutgoing: false,
            date: message.date,
            content: message.content,
            reply: message.reply,
            forward: message.forward,
            link: message.link
        )
        post.views = 1
        if ChatChannelFixtures.hasDiscussion(chat) {
            post.comments = MessageComments(total: 0, recent: [])
        }

        return post
    }

    func countComment(_ message: HistoryMessage, in id: String) {
        guard let thread = CommentThread(id: id) else {
            return
        }

        let me = MessageCommenter(id: message.authorID, name: ProfileFixture.current.name)
        update(thread.postID, in: thread.channelID) { post in
            var comments = post.comments ?? MessageComments(total: 0, recent: [])
            comments.total += 1
            comments.recent = Array(([me] + comments.recent.filter { commenter in
                commenter.id != me.id
            }).prefix(3))
            post.comments = comments
        }
    }
}
