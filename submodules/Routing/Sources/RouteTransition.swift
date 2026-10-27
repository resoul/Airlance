public struct RouteTransition<RouteType: Route>: Sendable {
    public let popCount: Int
    public let push: [RouteType]

    static func between(_ current: [RouteType], _ target: [RouteType]) -> RouteTransition {
        let common = zip(current, target)
            .prefix { current, target in
                current == target
            }
            .count

        return RouteTransition(popCount: current.count - common, push: Array(target[common...]))
    }
}
