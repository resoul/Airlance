public protocol Route: Hashable, Sendable {
    var segment: RouteSegment { get }
    var anchor: [Self] { get }
    var presentation: RoutePresentation { get }

    init?(segment: RouteSegment)
}

extension Route {
    public var anchor: [Self] {
        []
    }

    public var presentation: RoutePresentation {
        .stack
    }
}
