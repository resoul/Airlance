@MainActor
public protocol RouteNavigator<RouteType>: AnyObject {
    associatedtype RouteType: Route

    func apply(_ transition: RouteTransition<RouteType>, animated: Bool)
}
