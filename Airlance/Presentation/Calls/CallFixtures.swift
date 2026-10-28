import Foundation

enum CallFixtures {
    private struct Row {
        let peer: String
        let name: String
        let daysAgo: Double
        let events: [CallEvent]
    }

    private static let missed = CallEvent(direction: .incoming, duration: nil, isMissed: true)

    private static func incoming(_ minutes: Double?) -> CallEvent {
        CallEvent(direction: .incoming, duration: seconds(minutes), isMissed: false)
    }

    private static func outgoing(_ minutes: Double?) -> CallEvent {
        CallEvent(direction: .outgoing, duration: seconds(minutes), isMissed: false)
    }

    private static func seconds(_ minutes: Double?) -> TimeInterval? {
        minutes.map { minutes in
            minutes * 60
        }
    }

    static func make(now: Date) -> [CallEntry] {
        let rows = [
            Row(peer: "anna", name: "Анна", daysAgo: 0.1, events: [incoming(3)]),
            Row(peer: "boris", name: "Борис", daysAgo: 1, events: [incoming(10)]),
            Row(peer: "vika", name: "Віка", daysAgo: 1.2, events: [outgoing(4)]),
            Row(peer: "anna", name: "Анна", daysAgo: 1.4, events: [outgoing(5)]),
            Row(peer: "vika", name: "Віка", daysAgo: 1.6, events: [outgoing(nil), incoming(2)]),
            Row(peer: "olena", name: "Олена", daysAgo: 2, events: [missed]),
            Row(peer: "boris", name: "Борис", daysAgo: 10, events: [outgoing(8)]),
            Row(peer: "max", name: "Max", daysAgo: 21, events: [missed, missed]),
            Row(peer: "boris", name: "Борис", daysAgo: 28, events: [incoming(10)]),
            Row(peer: "lucia", name: "Lucía", daysAgo: 42, events: [incoming(18)]),
            Row(peer: "vika", name: "Віка", daysAgo: 47, events: [incoming(7)]),
            Row(peer: "boris", name: "Борис", daysAgo: 47.2, events: [outgoing(1)]),
            Row(peer: "anna", name: "Анна", daysAgo: 47.4, events: [incoming(9)]),
            Row(peer: "olena", name: "Олена", daysAgo: 60, events: [missed]),
            Row(peer: "boris", name: "Борис", daysAgo: 70, events: [incoming(nil)]),
            Row(peer: "dmytro", name: "Дмитро", daysAgo: 95, events: [missed]),
            Row(peer: "lucia", name: "Lucía", daysAgo: 120, events: [outgoing(12)]),
            Row(peer: "max", name: "Max", daysAgo: 400, events: [missed]),
            Row(peer: "anna", name: "Анна", daysAgo: 430, events: [outgoing(2)]),
            Row(peer: "olena", name: "Олена", daysAgo: 470, events: [missed]),
        ]

        return rows.enumerated().map { index, row in
            CallEntry(
                id: "call-\(index)",
                peerID: row.peer,
                name: row.name,
                events: row.events,
                date: now.addingTimeInterval(-row.daysAgo * 86_400)
            )
        }
    }
}
