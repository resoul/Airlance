import Foundation

public struct RoutePath: Hashable, Sendable, CustomStringConvertible {
    public static let rootName = "app"

    public let segments: [RouteSegment]

    public init(_ segments: [RouteSegment]) {
        self.segments = segments
    }

    public init?(_ string: String) {
        self.init(components: string.split(separator: ".", omittingEmptySubsequences: false))
    }

    public init?(url: URL) {
        guard let host = url.host else {
            return nil
        }

        let path = url.path.split(separator: "/")
        self.init(components: [Substring(host)] + path)
    }

    public init?(pathComponents: [String]) {
        self.init(components: pathComponents.map { component in
            Substring(component)
        })
    }

    private init?(components: [Substring]) {
        guard components.first == Substring(Self.rootName) else {
            return nil
        }

        var segments: [RouteSegment] = []
        for component in components.dropFirst() {
            guard let segment = RouteSegment(parsing: component) else {
                return nil
            }

            segments.append(segment)
        }

        self.init(segments)
    }

    public var description: String {
        ([Self.rootName] + segments.map(\.description)).joined(separator: ".")
    }
}
