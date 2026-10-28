public struct RouteTransition<RouteType: Route>: Sendable {
    public let dismissCount: Int
    public let update: RouteLayerUpdate<RouteType>?
    public let present: [RouteLayer<RouteType>]
    public let layers: [RouteLayer<RouteType>]

    static func between(_ current: [RouteType], _ target: [RouteType]) -> RouteTransition {
        let currentLayers = RouteLayer.layers(of: current)
        let targetLayers = RouteLayer.layers(of: target)
        let equal = zip(currentLayers, targetLayers)
            .prefix { current, target in
                current == target
            }
            .count

        guard
            equal < min(currentLayers.count, targetLayers.count),
            currentLayers[equal].opens(like: targetLayers[equal])
        else {
            return RouteTransition(
                dismissCount: currentLayers.count - equal,
                update: nil,
                present: Array(targetLayers[equal...]),
                layers: targetLayers
            )
        }

        return RouteTransition(
            dismissCount: currentLayers.count - equal - 1,
            update: RouteLayerUpdate(index: equal, current: currentLayers[equal], target: targetLayers[equal]),
            present: Array(targetLayers[(equal + 1)...]),
            layers: targetLayers
        )
    }
}

public struct RouteLayerUpdate<RouteType: Route>: Sendable {
    public let index: Int
    public let popCount: Int
    public let push: [RouteType]

    init(index: Int, current: RouteLayer<RouteType>, target: RouteLayer<RouteType>) {
        let common = zip(current.routes, target.routes)
            .prefix { current, target in
                current == target
            }
            .count

        self.index = index
        popCount = current.routes.count - common
        push = Array(target.routes[common...])
    }
}
