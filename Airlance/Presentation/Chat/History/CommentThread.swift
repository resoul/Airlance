struct CommentThread: Hashable, Sendable {
    private static let separator = "__"

    let channelID: String
    let postID: String

    var id: String {
        channelID + Self.separator + postID
    }

    init(channelID: String, postID: String) {
        self.channelID = channelID
        self.postID = postID
    }

    init?(id: String) {
        guard let range = id.range(of: Self.separator) else {
            return nil
        }

        channelID = String(id[..<range.lowerBound])
        postID = String(id[range.upperBound...])
        guard !channelID.isEmpty, !postID.isEmpty else {
            return nil
        }
    }
}
