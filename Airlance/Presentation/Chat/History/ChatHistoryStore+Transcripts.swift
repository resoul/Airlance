import ChatHistory
import Foundation

extension ChatHistoryStore {
    func transcript(_ messageID: String, in id: String) -> VoiceTranscript? {
        transcripts[id]?[messageID]
    }

    func toggleTranscript(_ messageID: String, in id: String) {
        guard var transcript = transcript(messageID, in: id), transcript.state != .loading else {
            return
        }

        transcript.isShown.toggle()
        setTranscript(transcript, messageID: messageID, in: id)
    }

    func transcribe(_ messageID: String, in id: String, locale: Locale) {
        guard
            transcript(messageID, in: id) == nil,
            let message = message(messageID, in: id),
            case .voice(let voice) = message.content,
            let url = voice.source.url
        else {
            return
        }

        setTranscript(VoiceTranscript(), messageID: messageID, in: id)
        transcriber.transcribe("\(id)/\(messageID)", url: url, locale: locale) { [weak self] transcript in
            self?.setTranscript(transcript, messageID: messageID, in: id)
        }
    }

    private func setTranscript(_ transcript: VoiceTranscript, messageID: String, in id: String) {
        transcripts[id, default: [:]][messageID] = transcript
        changed(id)
    }
}
