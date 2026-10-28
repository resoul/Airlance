enum StoryFixtures {
    static func make() -> [StorySummary] {
        [
            StorySummary(peerID: "me", name: "Олена Коваль", total: 2, unseen: 0, isSelf: true),
            StorySummary(peerID: "anna", name: "Анна", total: 3, unseen: 2),
            StorySummary(peerID: "vika", name: "Віка", total: 1, unseen: 1),
            StorySummary(peerID: "max", name: "Max", total: 2, unseen: 2),
            StorySummary(peerID: "lucia", name: "Lucía", total: 5, unseen: 1),
            StorySummary(peerID: "taras", name: "Тарас", total: 1, unseen: 1),
            StorySummary(peerID: "sofia", name: "Софія", total: 4, unseen: 3),
            StorySummary(peerID: "boris", name: "Борис", total: 4, unseen: 0),
            StorySummary(peerID: "ira", name: "Ірина", total: 2, unseen: 0),
        ]
    }
}
