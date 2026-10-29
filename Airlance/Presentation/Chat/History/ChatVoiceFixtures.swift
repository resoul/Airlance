import ChatHistory
import Foundation

enum ChatVoiceFixtures {
    private static let clips: [MessageVoice] = [
        MessageVoice(source: "bundle-audio:voice-message-1", duration: 7.6, waveform: [
            31, 18, 2, 2, 22, 22, 23, 7, 21, 17, 24, 29, 21, 24, 27, 16, 28, 25, 22, 16,
            2, 15, 21, 23, 16, 25, 25, 23, 23, 23, 27, 22, 18, 5, 12, 23, 16, 25, 12, 2,
        ]),
        MessageVoice(source: "bundle-audio:voice-message-2", duration: 4.8, waveform: [
            23, 23, 22, 22, 13, 22, 26, 26, 16, 23, 27, 12, 18, 7, 2, 2, 31, 14, 16, 17,
            22, 20, 25, 25, 21, 6, 2, 16, 22, 20, 27, 23, 20, 17, 24, 23, 24, 18, 6, 2,
        ]),
        MessageVoice(source: "bundle-audio:voice-message-3", duration: 5.6, waveform: [
            31, 19, 28, 29, 28, 27, 23, 2, 8, 24, 17, 4, 27, 21, 7, 21, 2, 2, 17, 18,
            14, 30, 5, 19, 27, 13, 24, 16, 2, 2, 27, 18, 26, 14, 23, 25, 27, 16, 8, 2,
        ]),
        MessageVoice(source: "bundle-audio:voice-message-4", duration: 3.6, waveform: [
            31, 26, 3, 20, 13, 2, 2, 6, 28, 23, 23, 20, 21, 20, 11, 2, 2, 2, 2, 11,
            25, 12, 24, 24, 17, 23, 22, 19, 9, 20, 2, 23, 23, 16, 19, 15, 14, 6, 2, 2,
        ]),
    ]

    static func voice(pick: Int) -> MessageContent {
        .voice(clips[pick % clips.count])
    }

    static func url(for source: String) -> URL? {
        let prefix = "bundle-audio:"
        if source.hasPrefix(prefix) {
            return Bundle.main.url(forResource: String(source.dropFirst(prefix.count)), withExtension: "m4a")
        }

        return URL(string: source)
    }
}
