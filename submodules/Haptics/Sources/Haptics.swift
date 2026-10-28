import os
import UIKit

public enum HapticEvent: Sendable {
    case selection
    case tap
    case popup
    case menu
    case threshold
    case reveal
    case success
    case warning
    case error
}

@MainActor
public final class Haptics {
    public static let shared = Haptics()

    private static let logger = Logger(subsystem: "Haptics", category: "Feedback")

    public var isEnabled = true

    private let selection = UISelectionFeedbackGenerator()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
    }

    public static func play(_ event: HapticEvent) {
        shared.play(event)
    }

    public static func prepare(_ event: HapticEvent) {
        shared.prepare(event)
    }

    public func play(_ event: HapticEvent) {
        guard isEnabled else {
            return
        }

        #if targetEnvironment(simulator)
        Self.logger.debug("play \(String(describing: event), privacy: .public)")
        #else
        switch event {
        case .selection:
            selection.selectionChanged()
        case .tap, .popup:
            light.impactOccurred()
        case .menu, .threshold:
            medium.impactOccurred()
        case .reveal:
            soft.impactOccurred()
        case .success:
            notification.notificationOccurred(.success)
        case .warning:
            notification.notificationOccurred(.warning)
        case .error:
            notification.notificationOccurred(.error)
        }
        prepare(event)
        #endif
    }

    public func prepare(_ event: HapticEvent) {
        #if !targetEnvironment(simulator)
        guard isEnabled else {
            return
        }

        switch event {
        case .selection:
            selection.prepare()
        case .tap, .popup:
            light.prepare()
        case .menu, .threshold:
            medium.prepare()
        case .reveal:
            soft.prepare()
        case .success, .warning, .error:
            notification.prepare()
        }
        #endif
    }
}
