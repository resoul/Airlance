import Foundation

extension AppStrings {
    func subtitle(for entry: CallEntry) -> String {
        if entry.events.count == 1, let event = entry.events.first {
            return subtitle(for: event)
        }

        var titles: [String] = []
        for event in entry.events {
            let title = event.isMissed ? callsMissedCall : title(for: event.direction)
            if !titles.contains(title) {
                titles.append(title)
            }
        }

        return titles.joined(separator: ", ")
    }

    private func subtitle(for event: CallEvent) -> String {
        guard !event.isMissed else {
            return callsMissedCall
        }

        let title = title(for: event.direction)
        guard let duration = event.duration else {
            return title
        }

        return callsWithDuration(title, max(1, Int((duration / 60).rounded())))
    }

    private func title(for direction: CallDirection) -> String {
        switch direction {
        case .incoming:
            callsIncoming
        case .outgoing:
            callsOutgoing
        }
    }
}
