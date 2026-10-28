import Foundation

enum CallDirection: Sendable {
    case incoming
    case outgoing
}

struct CallEvent: Sendable, Equatable {
    let direction: CallDirection
    let duration: TimeInterval?
    let isMissed: Bool
}

struct CallEntry: Identifiable, Sendable, Equatable {
    let id: String
    let peerID: String
    let name: String
    let events: [CallEvent]
    let date: Date

    var isMissed: Bool {
        events.contains { event in
            event.isMissed
        }
    }

    var isOutgoing: Bool {
        events.first?.direction == .outgoing
    }
}
