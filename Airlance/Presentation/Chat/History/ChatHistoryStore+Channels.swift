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
        if chatsStore.channelSettings.settings(id).signsMessages {
            post.signature = chatsStore.channelSettings.signatureName()
        }
        post.comments = MessageComments(total: 0, recent: [])

        return post
    }

    func countComment(_ message: HistoryMessage, in id: String) {
        if let thread = CommentThread(id: id) {
            bumpComments(thread, author: message.authorID)
            mirrorToGroup(message, thread: thread)
        } else {
            mirrorToThread(message, group: id)
        }
    }

    func discussionHistory(_ group: ChatSummary) -> ChatHistoryFixtures.History? {
        guard
            let channelID = ChatChannelFixtures.channel(discussedIn: group.id),
            let channel = chatsStore.chat(channelID),
            let posts = history(for: channelID)?.messages
        else {
            return nil
        }

        return ChatChannelFixtures.discussion(
            posts: posts,
            threads: { post in
                comments(in: CommentThread(channelID: channelID, postID: post.id))
            },
            group: group.id,
            channel: channel
        )
    }

    func discussionGroup(of thread: CommentThread) -> String? {
        ChatChannelFixtures.discussionGroup(of: thread.channelID)
    }

    private func comments(in thread: CommentThread) -> [HistoryMessage] {
        history(for: thread.id)?.messages.filter { message in
            ChatChannelFixtures.isComment(message, in: thread)
        } ?? []
    }

    private func bumpComments(_ thread: CommentThread, author: String) {
        let me = MessageCommenter(id: author, name: ProfileFixture.current.name)
        update(thread.postID, in: thread.channelID) { post in
            var comments = post.comments ?? MessageComments(total: 0, recent: [])
            comments.total += 1
            comments.recent = Array(([me] + comments.recent.filter { commenter in
                commenter.id != me.id
            }).prefix(3))
            post.comments = comments
        }
    }

    private func mirrorToGroup(_ message: HistoryMessage, thread: CommentThread) {
        guard let group = discussionGroup(of: thread), histories[group] != nil else {
            return
        }

        let postID = ChatChannelFixtures.discussionPostID(thread.postID, group: group)
        guard let post = histories[group]?.messages.first(where: { message in
            message.id == postID
        }) else {
            return
        }

        append(ChatChannelFixtures.discussionComment(message, post: post), to: group)
    }

    private func mirrorToThread(_ message: HistoryMessage, group: String) {
        guard let channelID = ChatChannelFixtures.channel(discussedIn: group), let reply = message.reply else {
            return
        }

        let prefix = ChatChannelFixtures.discussionPostID("", group: group)
        guard reply.messageID.hasPrefix(prefix) else {
            return
        }

        let thread = CommentThread(channelID: channelID, postID: String(reply.messageID.dropFirst(prefix.count)))
        bumpComments(thread, author: message.authorID)
        if histories[thread.id] != nil {
            var comment = message
            comment.reply = nil
            append(comment, to: thread.id)
        }
    }
}
