import ListUI

@MainActor
final class ChatScrollPositions {
    private var anchors: [String: ListAnchor] = [:]

    func anchor(for chatID: String) -> ListAnchor? {
        anchors[chatID]
    }

    func set(_ anchor: ListAnchor?, for chatID: String) {
        anchors[chatID] = anchor
    }
}
