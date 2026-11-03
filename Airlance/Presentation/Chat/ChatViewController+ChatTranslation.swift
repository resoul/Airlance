import ChatHistory
import Haptics
import UIKit

extension ChatViewController {
    var translationTarget: String {
        presentation.strings.pack.locale.language.languageCode?.identifier ?? "en"
    }

    func placeTranslationBar() {
        translationBar.isHidden = true
        translationBar.addAction(
            UIAction { [weak self] _ in
                self?.toggleChatTranslation()
            },
            for: .touchUpInside
        )
        translationBar.onClose = { [weak self] in
            self?.dismissChatTranslation()
        }
        view.addSubview(translationBar)
    }

    func applyTranslationBar(_ presentation: PresentationData) {
        translationBar.apply(presentation.theme, closeLabel: presentation.strings.chatCancel)
        updateChatTranslation()
    }

    func updateChatTranslation() {
        let settings = dependencies.translation
        let language = settings.translatesChats && MessageTranslator.isSupported && !isTranslationDismissed
            ? dominantLanguage()
            : nil
        chatLanguage = language
        let wasHidden = translationBar.isHidden
        translationBar.isHidden = language == nil
        if let language {
            let locale = presentation.strings.pack.locale
            let name = (locale.localizedString(forLanguageCode: language) ?? language).capitalized(with: locale)
            let strings = presentation.strings
            translationBar.setTitle(isChatTranslated ? strings.chatTranslateOriginal : strings.chatTranslateFrom(name))
            if isChatTranslated {
                translateChat()
            }
        }
        if wasHidden != translationBar.isHidden {
            view.setNeedsLayout()
        }
    }

    private func dominantLanguage() -> String? {
        var counts: [String: Int] = [:]
        var total = 0
        for message in history.window.itemMessages.suffix(40) {
            guard case .text(let text) = message.content, text.count > 3 else {
                continue
            }

            let language = cachedLanguage(message.id, text: text)
            total += 1
            if let language {
                counts[language, default: 0] += 1
            }
        }
        let target = translationTarget
        guard let (language, count) = counts.max(by: { left, right in
            left.value < right.value
        }), count >= 3, count * 2 >= total, language != target, !dependencies.translation.skips(language) else {
            return nil
        }

        return language
    }

    private func cachedLanguage(_ id: String, text: String) -> String? {
        if let cached = messageLanguages[id] {
            return cached
        }

        let language = MessageTranslator.language(of: text)
        messageLanguages[id] = language

        return language
    }

    private func toggleChatTranslation() {
        Haptics.play(.selection)
        isChatTranslated.toggle()
        if isChatTranslated {
            translateChat()
        } else {
            chatTranslationTask?.cancel()
            history.clearTranslations()
        }
        updateChatTranslation()
    }

    private func dismissChatTranslation() {
        isTranslationDismissed = true
        if isChatTranslated {
            isChatTranslated = false
            history.clearTranslations()
        }
        updateChatTranslation()
    }

    private func translateChat() {
        guard chatTranslationTask == nil, let language = chatLanguage else {
            return
        }

        let pending = history.window.itemMessages.compactMap { message -> (String, String)? in
            guard case .text(let text) = message.content, history.translations[message.id] == nil,
                  messageLanguages[message.id] == language else {
                return nil
            }

            return (message.id, text)
        }
        guard !pending.isEmpty else {
            return
        }

        runChatTranslation(pending, language: language)
    }

    private func runChatTranslation(_ pending: [(String, String)], language: String) {
        let target = translationTarget
        let locale = presentation.strings.pack.locale
        let name = (locale.localizedString(forLanguageCode: language) ?? language).capitalized(with: locale)
        let note = presentation.strings.chatTranslateNote(name)
        chatTranslationTask = Task { [weak self] in
            var results: [String: MessageTranslation] = [:]
            for (id, text) in pending {
                guard let self, !Task.isCancelled else {
                    return
                }

                if let result = try? await self.translator.translate(text, to: target) {
                    results[id] = MessageTranslation(original: text, text: result, note: note)
                }
            }
            guard let self, !Task.isCancelled else {
                return
            }

            self.chatTranslationTask = nil
            if self.isChatTranslated {
                self.history.setTranslations(results)
            }
        }
    }
}
