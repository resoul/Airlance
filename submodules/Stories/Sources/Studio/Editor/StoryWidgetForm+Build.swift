import UIKit

extension StoryWidgetForm {
    static let pollOptions = 4

    var placeholders: [String] {
        switch type {
        case .mention:
            [strings.label(.mentionPlaceholder)]
        case .location:
            [strings.label(.locationPlaceholder)]
        case .link:
            [strings.label(.linkPlaceholder), strings.label(.linkTitlePlaceholder)]
        case .poll:
            [strings.label(.pollQuestionPlaceholder)] + (1...Self.pollOptions).map { number in
                strings.label(.pollOptionPlaceholder) + " \(number)"
            }
        case .question:
            [strings.label(.questionDefault)]
        case .addYours:
            [strings.label(.addYoursPlaceholder)]
        case .reaction:
            []
        }
    }

    func configure(_ field: UITextField, index: Int) {
        field.autocapitalizationType = .sentences
        switch type {
        case .link where index == 0:
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        case .mention:
            field.autocapitalizationType = .words
            field.autocorrectionType = .no
        default:
            break
        }
    }

    func textChanged() {
        let query = text(0)
        if let selected, selected.title != query {
            self.selected = nil
        }
        switch type {
        case .mention:
            let matches = peers.filter { peer in
                query.isEmpty || peer.name.localizedCaseInsensitiveContains(query)
            }
            setSuggestions(Array(matches.prefix(12)).map(Suggestion.peer))
        case .location:
            onSearch?(query)
        default:
            break
        }
        refresh()
    }

    func setPlaces(_ places: [StoryPlace], for query: String) {
        guard query == text(0) else {
            return
        }

        setSuggestions(places.map(Suggestion.place))
    }

    func widget(strict: Bool) -> StoryWidget? {
        kind(strict: strict).map { kind in
            StoryWidget(kind: kind)
        }
    }

    private func text(_ index: Int) -> String {
        guard fields.indices.contains(index) else {
            return ""
        }

        return (fields[index].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func kind(strict: Bool) -> StoryWidget.Kind? {
        switch type {
        case .mention:
            return mention(strict: strict).map(StoryWidget.Kind.mention)
        case .location:
            return place(strict: strict).map(StoryWidget.Kind.location)
        case .link:
            return link(strict: strict)
        case .poll:
            return poll(strict: strict).map(StoryWidget.Kind.poll)
        case .question:
            let prompt = text(0).isEmpty ? strings.label(.questionDefault) : text(0)

            return .question(prompt: prompt, hint: strings.label(.questionHint))
        case .addYours:
            let prompt = text(0)
            guard !prompt.isEmpty || !strict else {
                return nil
            }

            let shown = prompt.isEmpty ? strings.label(.addYoursPlaceholder) : prompt

            return .addYours(prompt: shown, title: strings.label(.widgetAddYours))
        case .reaction:
            return nil
        }
    }

    private func mention(strict: Bool) -> StoryMentionPeer? {
        if case .peer(let peer) = selected {
            return peer
        }

        if let exact = peers.first(where: { peer in
            peer.name.compare(text(0), options: .caseInsensitive) == .orderedSame
        }) {
            return exact
        }

        guard !strict else {
            return nil
        }

        return StoryMentionPeer(id: "", name: text(0).isEmpty ? strings.label(.mentionPlaceholder) : text(0))
    }

    private func place(strict: Bool) -> StoryPlace? {
        if case .place(let place) = selected {
            return place
        }

        guard !text(0).isEmpty else {
            return strict ? nil : StoryPlace(title: strings.label(.locationPlaceholder))
        }

        return StoryPlace(title: text(0))
    }

    private func link(strict: Bool) -> StoryWidget.Kind? {
        let title = text(1).isEmpty ? nil : text(1)
        guard let url = Self.url(from: text(0)) else {
            return strict ? nil : .link(URL(fileURLWithPath: "/"), title: title ?? strings.label(.linkPlaceholder))
        }

        return .link(url, title: title)
    }

    private func poll(strict: Bool) -> StoryPoll? {
        let options = (1...Self.pollOptions).map(text).filter { option in
            !option.isEmpty
        }
        guard !strict else {
            return text(0).isEmpty || options.count < 2 ? nil : StoryPoll(question: text(0), options: options)
        }

        let question = text(0).isEmpty ? strings.label(.pollQuestionPlaceholder) : text(0)
        let shown = options.count < 2 ? [
            strings.label(.pollOptionPlaceholder) + " 1",
            strings.label(.pollOptionPlaceholder) + " 2",
        ] : options

        return StoryPoll(question: question, options: shown)
    }

    static func url(from text: String) -> URL? {
        guard !text.isEmpty, !text.contains(" ") else {
            return nil
        }

        let full = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: full),
              let host = url.host,
              host.contains("."),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        return url
    }
}
