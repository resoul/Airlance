import Observers

@MainActor
public final class Router<RouteType: Route> {
    public private(set) var stack: [RouteType] = []

    private let observers = ObserverList<RoutePath>()
    private weak var navigator: (any RouteNavigator<RouteType>)?

    public var path: RoutePath {
        RoutePath(stack.map(\.segment))
    }

    public var layers: [RouteLayer<RouteType>] {
        RouteLayer.layers(of: stack)
    }

    public init() {}

    public func attach(_ navigator: any RouteNavigator<RouteType>) {
        self.navigator = navigator
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (RoutePath) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(path)

        return token
    }

    public func open(_ route: RouteType, animated: Bool = true) {
        navigate(to: stack + [route], animated: animated)
    }

    public func show(_ route: RouteType, animated: Bool = true) {
        guard let index = stack.lastIndex(of: route) else {
            navigate(to: route.anchor + [route], animated: animated)

            return
        }

        navigate(to: Array(stack[...index]), animated: animated)
    }

    public func back(animated: Bool = true) {
        navigate(to: Array(stack.dropLast()), animated: animated)
    }

    public func dismiss(animated: Bool = true) {
        let start = stack.lastIndex { route in
            route.presentation != .stack
        }
        guard let start else {
            return
        }

        navigate(to: Array(stack[..<start]), animated: animated)
    }

    public func navigate(to target: [RouteType], animated: Bool = true) {
        guard target != stack else {
            return
        }

        let transition = RouteTransition.between(stack, target)
        stack = target
        navigator?.apply(transition, animated: animated)
        observers.notify(path)
    }

    @discardableResult
    public func navigate(to path: RoutePath, animated: Bool = true) -> Bool {
        var target: [RouteType] = []
        for segment in path.segments {
            guard let route = RouteType(segment: segment) else {
                return false
            }

            target.append(route)
        }

        navigate(to: target, animated: animated)

        return true
    }

    public func sync(_ stack: [RouteType]) {
        guard stack != self.stack else {
            return
        }

        self.stack = stack
        observers.notify(path)
    }
}
