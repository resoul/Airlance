import Foundation

public struct BrowserState: Equatable, Sendable {
    public var title: String
    public var url: URL?
    public var progress: Double
    public var isLoading: Bool
    public var canGoBack: Bool
    public var canGoForward: Bool
}

public struct BrowserStrings: Sendable {
    public let back: String
    public let forward: String
    public let share: String
    public let openExternal: String

    public init(back: String, forward: String, share: String, openExternal: String) {
        self.back = back
        self.forward = forward
        self.share = share
        self.openExternal = openExternal
    }
}
