import Foundation

struct AccountContent {
    static let empty = AccountContent(
        chats: [],
        previews: [],
        onAirChannels: [],
        onAirPosts: [],
        calls: [],
        stories: []
    )

    let chats: [ChatSummary]
    let previews: [ChatSummary]
    let onAirChannels: [OnAirChannel]
    let onAirPosts: [OnAirPost]
    let calls: [CallEntry]
    let stories: [StorySummary]

    static func forAccount(_ record: AccountRecord, now: Date) -> AccountContent {
        record.isDemo ? demo(now: now, variant: record.fixtureVariant) : empty
    }

    private static func demo(now: Date, variant: Int) -> AccountContent {
        AccountContent(
            chats: ChatFixtures.make(now: now, variant: variant),
            previews: demoPreviews(now: now),
            onAirChannels: OnAirFixtures.channels(),
            onAirPosts: OnAirFixtures.posts(now: now),
            calls: CallFixtures.make(now: now),
            stories: StoryFixtures.make()
        )
    }

    private static func demoPreviews(now: Date) -> [ChatSummary] {
        let previews = ChatFixtures.previews(now: now)
        let onAirPreviews = OnAirFixtures.summaries(now: now).filter { summary in
            !previews.contains { preview in
                preview.id == summary.id
            }
        }

        return previews + onAirPreviews
    }
}
