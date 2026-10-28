public struct RouteLayer<RouteType: Route>: Hashable, Sendable {
    public let presentation: RoutePresentation
    public private(set) var routes: [RouteType]

    static func layers(of stack: [RouteType]) -> [RouteLayer] {
        var layers = [RouteLayer(presentation: .stack, routes: [])]
        for route in stack {
            if route.presentation.isModal {
                layers.append(RouteLayer(presentation: route.presentation, routes: [route]))
            } else {
                layers[layers.count - 1].routes.append(route)
            }
        }

        return layers
    }

    func opens(like other: RouteLayer) -> Bool {
        presentation == other.presentation && (presentation == .stack || routes.first == other.routes.first)
    }
}
