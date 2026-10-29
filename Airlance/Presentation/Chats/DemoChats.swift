enum DemoChats {
    static let ids = ["anna", "boris", "vika"]

    static func next(after id: String) -> String {
        let index = ids.firstIndex(of: id).map { index in
            index + 1
        } ?? 0

        return ids[index % ids.count]
    }
}
