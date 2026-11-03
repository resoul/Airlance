import AvatarUI
import DatabaseAPI
import EffectsUI
import Foundation
import LiquidUI
import ListUI
import Observers
import ParticlesUI
import UIKit

enum PowerFeature: String, CaseIterable, Codable, Sendable {
    case videoAutoplay
    case liquidEffects
    case particleEffects
    case preload
}

struct PowerSavingSettings: Codable, Equatable, Sendable {
    static let off = 0
    static let always = 100

    var threshold = 15
    var disabled: Set<PowerFeature> = []
}

extension StorageKey where Value == PowerSavingSettings {
    static let powerSaving = StorageKey("power.saving", default: PowerSavingSettings())
}

@MainActor
final class PowerSaving {
    private(set) var settings: PowerSavingSettings
    private let storage: any KeyValueStore
    private let observers = ObserverList<Bool>()
    private var tokens: [any NSObjectProtocol] = []
    private var observation: ObservationToken?

    init(storage: any KeyValueStore) {
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
                    self?.apply()
                }
            }
        }
        observation = storage.observe(.powerSaving) { [weak self] settings in
            self?.settings = settings
            self?.apply()
        }
        apply()
    }

    var isSaving: Bool {
        switch settings.threshold {
        case PowerSavingSettings.off:
            false
        case PowerSavingSettings.always...:
            true
        default:
            ProcessInfo.processInfo.isLowPowerModeEnabled || isBatteryLow
        }
    }

    private var isBatteryLow: Bool {
        let device = UIDevice.current
        guard device.batteryState == .unplugged, device.batteryLevel >= 0 else {
            return false
        }

        return Int((device.batteryLevel * 100).rounded()) <= settings.threshold
    }

    func isEnabled(_ feature: PowerFeature) -> Bool {
        !isSaving && !settings.disabled.contains(feature)
    }

    func update(_ change: @escaping @Sendable (inout PowerSavingSettings) -> Void) {
        let storage = storage
        Task {
            try? await storage.update(.powerSaving) { settings in
                change(&settings)
            }
        }
    }

    func observe(_ onChange: @escaping @MainActor @Sendable (Bool) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(isSaving)

        return token
    }

    private func apply() {
        AvatarPlayback.shared.isAllowed = isEnabled(.videoAutoplay)
        LiquidEffects.isEnabled = isEnabled(.liquidEffects)
        ViewEffectsSettings.isEnabled = isEnabled(.particleEffects)
        ParticleEffects.isEnabled = isEnabled(.particleEffects)
        ListView.prefetchesAhead = isEnabled(.preload)
        observers.notify(isSaving)
    }
}
