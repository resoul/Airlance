public struct ListTransaction: Sendable {
    public let inserted: Set<String>
    public let deleted: Set<String>

    public init(previous: [String], next: [String]) {
        let previousIDs = Set(previous)
        let nextIDs = Set(next)

        inserted = nextIDs.subtracting(previousIDs)
        deleted = previousIDs.subtracting(nextIDs)
    }
}
