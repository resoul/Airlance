import ChatHistory
import MusicPlayer
import UIKit

extension ChatHistoryController {
    func bindVoice() {
        audioObservation = AudioPlayer.shared.observe { [weak self] state in
            self?.audioChanged(state)
        }
    }

    func toggleVoice(_ messageID: String) {
        let tracks = chatMessages.compactMap { message -> AudioTrack? in
            guard case .voice(let voice) = message.content, let url = voice.source.url else {
                return nil
            }

            let date = message.date.formatted(date: .abbreviated, time: .shortened)

            var track = AudioTrack(id: message.id, groupID: chatID, url: url, kind: .voice, title: message.authorName)
            track.artist = date

            return track
        }
        AudioPlayer.shared.play(tracks, startAt: messageID)
    }

    func playMusic(_ messageID: String) {
        let tracks = chatMessages.compactMap { message -> AudioTrack? in
            guard
                case .file(let file, _) = message.content,
                file.isAudio,
                file.isDownloaded,
                let url = file.source.url
            else {
                return nil
            }

            let title = (file.name as NSString).deletingPathExtension

            return AudioTrack(id: message.id, groupID: chatID, url: url, kind: .music, title: title)
        }
        AudioPlayer.shared.play(tracks, startAt: messageID)
    }

    private var chatMessages: [HistoryMessage] {
        store.history(for: chatID)?.messages ?? window.data.messages
    }

    private func audioChanged(_ state: PlaybackState) {
        let track = state.track
        let current = track?.groupID == chatID && track?.kind == .voice ? track?.id : nil
        if let previous = playingVoiceID, previous != current {
            voiceNode(previous)?.setVoice(progress: 0, isPlaying: false)
        }
        if let current, current != playingVoiceID, message(current)?.isListened == false {
            markListened(current)
        }
        playingVoiceID = current
        guard let current else {
            return
        }

        voiceNode(current)?.setVoice(progress: CGFloat(state.progress), isPlaying: state.isPlaying)
    }

    private func voiceNode(_ id: String) -> MessageBubbleNode? {
        listView.node(for: id) as? MessageBubbleNode
    }
}

extension MessageFile {
    static let audioExtensions: Set<String> = ["mp3", "m4a", "m4b", "aac", "wav", "aif", "aiff", "caf", "flac"]

    var isAudio: Bool {
        Self.audioExtensions.contains(fileExtension)
    }
}
