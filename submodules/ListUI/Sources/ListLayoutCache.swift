import CoreGraphics

@MainActor
struct ListEntry {
    let reuseIdentifier: String
    let version: Int
    let layoutVersion: Int?

    init(_ item: any ListItem) {
        reuseIdentifier = item.reuseIdentifier
        version = item.version
        layoutVersion = (item as? any AsyncListItem)?.layoutVersion
    }
}

@MainActor
final class ListLayoutCache {
    private struct Entry {
        let layoutVersion: Int
        let width: CGFloat
        let layout: any ListPreparedLayout
    }

    private(set) var generation = 0

    private let limit: Int
    private var entries: [String: Entry] = [:]
    private var order: [String] = []

    init(limit: Int) {
        self.limit = limit
    }

    func layout(for id: String, layoutVersion: Int, width: CGFloat) -> (any ListPreparedLayout)? {
        guard let entry = entries[id], entry.layoutVersion == layoutVersion, entry.width == width else {
            return nil
        }

        touch(id)

        return entry.layout
    }

    func contains(_ id: String, layoutVersion: Int, width: CGFloat) -> Bool {
        guard let entry = entries[id] else {
            return false
        }

        return entry.layoutVersion == layoutVersion && entry.width == width
    }

    func store(_ layout: any ListPreparedLayout, for id: String, layoutVersion: Int, width: CGFloat) {
        entries[id] = Entry(layoutVersion: layoutVersion, width: width, layout: layout)
        touch(id)
        while order.count > limit {
            entries.removeValue(forKey: order.removeFirst())
        }
    }

    func remove(_ id: String) {
        entries.removeValue(forKey: id)
        order.removeAll { other in
            other == id
        }
    }

    func removeAll() {
        entries = [:]
        order = []
        generation += 1
    }

    private func touch(_ id: String) {
        order.removeAll { other in
            other == id
        }
        order.append(id)
    }
}
