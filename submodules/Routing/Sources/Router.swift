import Observers

@MainActor
public final class Router<RouteType: Route> {
    public private(set) var stack: [RouteType] {
        didSet {
            rememberTabStack()
        }
    }

    private let observers = ObserverList<RoutePath>()
    private weak var navigator: (any RouteNavigator<RouteType>)?
    private var tabStacks: [RouteType: [RouteType]] = [:]

    public var path: RoutePath {
        RoutePath(stack.map(\.segment))
    }

    public var layers: [RouteLayer<RouteType>] {
        RouteLayer.layers(of: stack)
    }

    public var tab: RouteType? {
        stack.first { route in
            route.presentation == .tab
        }
    }

    public init(root: [RouteType] = []) {
        stack = root
        rememberTabStack()
    }

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

    public func selectTab(_ tab: RouteType, animated: Bool = true) {
        guard tab != self.tab else {
            navigate(to: [tab], animated: animated)

            return
        }

        navigate(to: tabStacks[tab] ?? [tab], animated: animated)
    }

    public func back(animated: Bool = true) {
        navigate(to: Array(stack.dropLast()), animated: animated)
    }

    public func dismiss(animated: Bool = true) {
        let start = stack.lastIndex { route in
            route.presentation.isModal
        }
        guard let start else {
            return
        }

        navigate(to: Array(stack[..<start]), animated: animated)
    }

    public func navigate(to target: [RouteType], animated: Bool = true) {
        let target = normalized(target)
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

    private func normalized(_ target: [RouteType]) -> [RouteType] {
        guard let tab else {
            return target
        }

        guard let first = target.first else {
            return [tab]
        }

        guard first.presentation != .tab else {
            return target
        }

        let anchor = first.anchor
        if anchor.first?.presentation == .tab {
            return anchor + target
        }

        return [tab] + target
    }

    private func rememberTabStack() {
        guard let tab = stack.first, tab.presentation == .tab else {
            return
        }

        tabStacks[tab] = layers.first?.routes ?? [tab]
    }
}
