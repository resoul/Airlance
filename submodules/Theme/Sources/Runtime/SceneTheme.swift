import Observers
import UIKit

@MainActor
public final class SceneTheme {
    public private(set) var theme: AppTheme

    private let observers = ObserverList<AppTheme>()
    private var settings: ThemeSettings
    private var systemTraits: SystemTraits
    private var settingsObservation: ObservationToken?
    private var clockTimer: Timer?
    private var brightnessObserver: (any NSObjectProtocol)?

    public init(store: ThemeStore, systemTraits: SystemTraits) {
        settings = store.settings
        self.systemTraits = systemTraits
        theme = ThemeFactory.makeTheme(ThemeInputs(settings: store.settings, system: systemTraits, clock: Self.clock))
        settingsObservation = store.observeSettings { [weak self] settings in
            self?.apply(settings: settings)
        }
        brightnessObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clockTicked()
            }
        }
        updateClock()
    }

    private static var clock: ThemeClock {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        return ThemeClock(minute: minute, brightness: Double(UIScreen.main.brightness))
    }

    private func updateClock() {
        guard settings.night.usesClock else {
            clockTimer?.invalidate()
            clockTimer = nil

            return
        }

        guard clockTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clockTicked()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    private func clockTicked() {
        guard settings.night.usesClock else {
            return
        }

        rebuild()
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (AppTheme) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(theme)

        return token
    }

    public func updateSystemTraits(_ traits: SystemTraits) {
        guard traits != systemTraits else {
            return
        }

        systemTraits = traits
        rebuild()
    }

    private func apply(settings: ThemeSettings) {
        guard settings != self.settings else {
            return
        }

        self.settings = settings
        updateClock()
        rebuild()
    }

    private func rebuild() {
        let inputs = ThemeInputs(settings: settings, system: systemTraits, clock: Self.clock)
        guard inputs != theme.inputs else {
            return
        }

        theme = ThemeFactory.makeTheme(inputs)
        observers.notify(theme)
    }
}
