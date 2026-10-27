public protocol Route: Hashable, Sendable {
    var segment: RouteSegment { get }
    var anchor: [Self] { get }

    init?(segment: RouteSegment)
}

extension Route {
    public var anchor: [Self] {
        []
    }
}
