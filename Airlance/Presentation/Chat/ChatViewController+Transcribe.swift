import ChatHistory
import Haptics
import UIKit

extension ChatViewController {
    func bindMessageActions() {
        bindTranscripts()
        bindForwardSources()
        expiryObservation = bindExpirations()
        history.onOpenFile = { [weak self] file in
            self?.openFile(file)
        }
        history.onOpenComments = { [weak self] postID in
            self?.openComments(postID)
        }
    }

    private func bindTranscripts() {
        history.onTranscribe = { [weak self] messageID in
            self?.transcribe(messageID)
        }
    }

    private func transcribe(_ messageID: String) {
        let store = dependencies.historyStore
        let chatID = history.chatID
        Haptics.play(.tap)
        guard store.transcript(messageID, in: chatID) == nil else {
            store.toggleTranscript(messageID, in: chatID)

            return
        }

        let flow = dependencies.permissionFlow
        let locale = presentation.strings.pack.locale
        Task { [weak self] in
            guard let self, await flow.authorize(.transcribeVoice, from: self) else {
                return
            }

            store.transcribe(messageID, in: chatID, locale: locale)
        }
    }
}
