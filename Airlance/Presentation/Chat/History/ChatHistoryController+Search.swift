import ChatHistory

struct HistorySearch: Equatable {
    var query: String
    var matches: [SearchMatch]
    var current: Int

    var currentMatch: SearchMatch? {
        matches.indices.contains(current) ? matches[current] : nil
    }
}

extension ChatHistoryController {
    func setSearch(_ query: String?) {
        guard let query else {
            searchRevision += 1
            search = nil
            reapplyItems()

            return
        }

        if search == nil {
            search = HistorySearch(query: query, matches: [], current: -1)
        }
        searchRevision += 1
        let revision = searchRevision
        Task { [weak self] in
            guard let self else {
                return
            }

            let matches = await self.store.search(query, in: self.chatID)
            guard self.searchRevision == revision else {
                return
            }

            self.search = HistorySearch(query: query, matches: matches, current: matches.count - 1)
            self.reapplyItems()
            self.revealCurrentMatch()
            self.onSearchChange?()
        }
    }

    func moveSearch(by step: Int) -> Bool {
        guard var search, search.matches.indices.contains(search.current + step) else {
            return false
        }

        search.current += step
        self.search = search
        reapplyItems()
        revealCurrentMatch()

        return true
    }

    func searchHighlight(for id: String) -> SearchHighlight? {
        guard let search, !search.query.isEmpty else {
            return nil
        }

        return SearchHighlight(query: search.query, isCurrent: search.currentMatch?.messageID == id)
    }

    private func revealCurrentMatch() {
        if let match = search?.currentMatch {
            reveal(match.messageID, quote: match.quote)
        }
    }
}
