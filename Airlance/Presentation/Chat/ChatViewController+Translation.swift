import ChatHistory
import UIKit

extension ChatViewController {
    func translateItems(for message: HistoryMessage) -> [MenuItem] {
        let strings = presentation.strings
        if let translation = history.translations[message.id], message.content == .text(translation.original) {
            let original = MenuItem(
                title: strings.chatTranslateOriginal,
                symbol: "character.bubble",
                isDestructive: false,
                action: .run { [weak self] in
                    self?.history.setTranslation(nil, messageID: message.id)
                }
            )

            return [original]
        }

        guard case .text(let text) = message.content, MessageTranslator.isSupported,
              let source = MessageTranslator.language(of: text), source != targetLanguage else {
            return []
        }

        let translate = MenuItem(
            title: strings.chatTranslate,
            symbol: "translate",
            isDestructive: false,
            action: .run { [weak self] in
                self?.translate(message.id, text: text, source: source)
            }
        )

        return [translate]
    }

    private var targetLanguage: String {
        presentation.strings.pack.locale.language.languageCode?.identifier ?? "en"
    }

    private func translate(_ messageID: String, text: String, source: String) {
        let target = targetLanguage
        let locale = presentation.strings.pack.locale
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let result = try await self.translator.translate(text, to: target)
                guard self.history.message(messageID)?.content == .text(text) else {
                    return
                }

                let language = locale.localizedString(forLanguageCode: source) ?? source
                let note = self.presentation.strings.chatTranslateNote(language.capitalized(with: locale))
                let translation = MessageTranslation(original: text, text: result, note: note)
                self.history.setTranslation(translation, messageID: messageID)
            } catch {
                self.showToast(self.presentation.strings.chatTranslateFailed, symbol: "exclamationmark.triangle")
            }
        }
    }
}
