public enum RoutePresentation: Hashable, Sendable {
    case stack
    case tab
    case sheet
    case fullScreen

    public var isModal: Bool {
        self == .sheet || self == .fullScreen
    }
}
