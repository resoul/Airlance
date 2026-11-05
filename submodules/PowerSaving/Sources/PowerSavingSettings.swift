public enum PowerFeature: String, CaseIterable, Codable, Sendable {
    case videoAutoplay
    case liquidEffects
    case particleEffects
    case preload
}

public struct PowerSavingSettings: Codable, Equatable, Sendable {
    public static let off = 0
    public static let always = 100
    public static let standard = 15

    public var threshold = standard
    public var disabled: Set<PowerFeature> = []
    public var lastThreshold: Int?

    public var isOn: Bool {
        threshold != Self.off
    }

    public init() {}

    public mutating func setOn(_ isOn: Bool) {
        guard isOn != self.isOn else {
            return
        }

        if isOn {
            threshold = lastThreshold ?? Self.standard
        } else {
            lastThreshold = threshold
            threshold = Self.off
        }
    }
}
