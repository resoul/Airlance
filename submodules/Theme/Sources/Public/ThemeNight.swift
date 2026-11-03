import Foundation

public enum NightSchedule: String, Codable, Sendable, CaseIterable {
    case system
    case off
    case scheduled
    case automatic
}

public enum NightStyle: String, Codable, Sendable, CaseIterable {
    case night
    case tinted
}

public struct ThemeClock: Equatable, Sendable {
    public let minute: Int
    public let brightness: Double

    public init(minute: Int, brightness: Double) {
        self.minute = minute
        self.brightness = brightness
    }
}

public struct NightSettings: Codable, Equatable, Sendable {
    public static let `default` = NightSettings()

    public var schedule = NightSchedule.system
    public var style = NightStyle.night
    public var from = 22 * 60
    public var to = 7 * 60
    public var brightness = 0.25

    public init(schedule: NightSchedule = .system) {
        self.schedule = schedule
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.default
        schedule = (try? container.decodeIfPresent(NightSchedule.self, forKey: .schedule)) ?? fallback.schedule
        style = (try? container.decodeIfPresent(NightStyle.self, forKey: .style)) ?? fallback.style
        from = (try? container.decodeIfPresent(Int.self, forKey: .from)) ?? fallback.from
        to = (try? container.decodeIfPresent(Int.self, forKey: .to)) ?? fallback.to
        brightness = (try? container.decodeIfPresent(Double.self, forKey: .brightness)) ?? fallback.brightness
    }

    public var usesClock: Bool {
        schedule == .scheduled || schedule == .automatic
    }

    public func isNight(clock: ThemeClock) -> Bool {
        switch schedule {
        case .scheduled:
            from <= to ? (from..<to).contains(clock.minute) : clock.minute >= from || clock.minute < to
        case .automatic:
            clock.brightness <= brightness
        case .system, .off:
            false
        }
    }
}
