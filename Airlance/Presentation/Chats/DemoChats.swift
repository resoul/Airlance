enum DemoChats {
    static let ids = [1, 2, 3]

    static func next(after id: Int) -> Int {
        id % ids.count + 1
    }
}
