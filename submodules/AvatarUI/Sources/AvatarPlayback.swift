import Foundation
import UIKit

@MainActor
protocol AvatarPlaybackParticipant: AnyObject {
    var wantsPlayback: Bool { get }
    var playbackPriority: Int { get }

    func setPlaybackAllowed(_ allowed: Bool)
}

@MainActor
public final class AvatarPlayback {
    public static let shared = AvatarPlayback()

    public var respectsLowPowerMode = true {
        didSet {
            update()
        }
    }
    public var respectsReduceMotion = true {
        didSet {
            update()
        }
    }

    private var participants: [ObjectIdentifier: Entry] = [:]
    private var nextOrder = 0
    private var isActive = true
    private var isUpdateScheduled = false
    private var observers: [any NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIApplication.willResignActiveNotification,
            UIApplication.didBecomeActiveNotification,
            .NSProcessInfoPowerStateDidChange,
            UIAccessibility.reduceMotionStatusDidChangeNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let name = notification.name
                MainActor.assumeIsolated {
                    self?.changed(name)
                }
            }
        }
    }

    func register(_ participant: any AvatarPlaybackParticipant) {
        let id = ObjectIdentifier(participant)
        guard participants[id] == nil else {
            return
        }

        nextOrder += 1
        participants[id] = Entry(value: participant, order: nextOrder)
    }

    func unregister(_ participant: any AvatarPlaybackParticipant) {
        guard participants.removeValue(forKey: ObjectIdentifier(participant)) != nil else {
            return
        }

        participant.setPlaybackAllowed(false)
        update()
    }

    func update() {
        guard !isUpdateScheduled else {
            return
        }

        isUpdateScheduled = true
        Task { @MainActor in
            self.isUpdateScheduled = false
            self.performUpdate()
        }
    }

    private func performUpdate() {
        participants = participants.filter { _, entry in
            entry.value != nil
        }
        let winner = isEnabled ? candidate() : nil
        for entry in participants.values where entry.value !== winner {
            entry.value?.setPlaybackAllowed(false)
        }
        winner?.setPlaybackAllowed(true)
    }

    private var isEnabled: Bool {
        let lowPower = respectsLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled
        let reduceMotion = respectsReduceMotion && UIAccessibility.isReduceMotionEnabled

        return isActive && !lowPower && !reduceMotion
    }

    private func candidate() -> (any AvatarPlaybackParticipant)? {
        let wanting = participants.values.compactMap { entry -> (value: any AvatarPlaybackParticipant, order: Int)? in
            guard let value = entry.value, value.wantsPlayback else {
                return nil
            }

            return (value, entry.order)
        }
        let best = wanting.min { lhs, rhs in
            if lhs.value.playbackPriority != rhs.value.playbackPriority {
                return lhs.value.playbackPriority > rhs.value.playbackPriority
            }

            return lhs.order < rhs.order
        }

        return best?.value
    }

    private func changed(_ name: Notification.Name) {
        if name == UIApplication.willResignActiveNotification {
            isActive = false
        } else if name == UIApplication.didBecomeActiveNotification {
            isActive = true
        }
        update()
    }
}

@MainActor
private final class Entry {
    weak var value: (any AvatarPlaybackParticipant)?
    let order: Int

    init(value: any AvatarPlaybackParticipant, order: Int) {
        self.value = value
        self.order = order
    }
}
