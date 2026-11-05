import DatabaseAPI
import Foundation
import Observers
import UIKit

extension StorageKey where Value == PowerSavingSettings {
    static let powerSaving = StorageKey("power.saving", default: PowerSavingSettings())
}

@MainActor
public final class PowerSavingStore {
    public private(set) var settings: PowerSavingSettings

    private let storage: any KeyValueStore
    private let observers = ObserverList<Bool>()
    private var tokens: [any NSObjectProtocol] = []
    private var observation: ObservationToken?

    public init(storage: any KeyValueStore) {
        self.storage = storage
        settings = storage.value(for: .powerSaving)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIDevice.batteryLevelDidChangeNotification,
            UIDevice.batteryStateDidChangeNotification,
            .NSProcessInfoPowerStateDidChange,
        ]
        tokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.changed()
                }
            }
        }
        observation = storage.observe(.powerSaving) { [weak self] settings in
            self?.settings = settings
            self?.changed()
        }
    }

    public var isSaving: Bool {
        switch settings.threshold {
        case PowerSavingSettings.off:
            false
        case PowerSavingSettings.always...:
            true
        default:
            ProcessInfo.processInfo.isLowPowerModeEnabled || isBatteryLow
        }
    }

    public func isEnabled(_ feature: PowerFeature) -> Bool {
        guard settings.isOn else {
            return true
        }

        return !isSaving && !settings.disabled.contains(feature)
    }

    public func update(_ change: @escaping @Sendable (inout PowerSavingSettings) -> Void) {
        let storage = storage
        Task {
            try? await storage.update(.powerSaving) { settings in
                change(&settings)
            }
        }
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (Bool) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(isSaving)

        return token
    }

    private var isBatteryLow: Bool {
        let device = UIDevice.current
        guard device.batteryState == .unplugged, device.batteryLevel >= 0 else {
            return false
        }

        return Int((device.batteryLevel * 100).rounded()) <= settings.threshold
    }

    private func changed() {
        observers.notify(isSaving)
    }
}
