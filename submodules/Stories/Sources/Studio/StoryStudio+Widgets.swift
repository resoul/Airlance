import UIKit

extension StoryStudio {
    func makeDraft(_ media: StoryDraft.Media) -> StoryDraft {
        var draft = StoryDraft(media: media)
        draft.settings.lifetime = context.defaultLifetime

        return draft
    }

    func seeded(_ draft: StoryDraft) -> StoryDraft {
        guard case .addYours(let prompt) = seed else {
            return draft
        }

        var draft = draft
        let widget = StoryWidget(kind: .addYours(prompt: prompt, title: context.strings.label(.widgetAddYours)))
        draft.entities = [StoryEntity(content: .widget(widget), center: CGPoint(x: 0.5, y: 0.3))]

        return draft
    }

    func searchPlaces(_ query: String) {
        placeTask?.cancel()
        let context = context
        placeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else {
                return
            }

            let places = await context.searchPlaces(query)
            guard !Task.isCancelled else {
                return
            }

            self?.editor?.setPlaces(places, for: query)
        }
    }
}
