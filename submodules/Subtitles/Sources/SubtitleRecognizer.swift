import Foundation
import Speech

@MainActor
public final class SubtitleRecognizer {
    public static let languages = [
        "uk-UA", "en-US", "es-ES", "ru-RU", "it-IT", "ro-RO", "fr-FR", "de-DE",
    ]

    public static func language(for locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier ?? "uk"

        return languages.first { identifier in
            identifier.hasPrefix(code + "-")
        } ?? languages[0]
    }

    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<Subtitles?, Never>?

    public init() {
    }

    public func recognize(_ url: URL, locale: Locale) async -> Subtitles? {
        cancel()
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            return nil
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = true

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let words = result.map(Self.words(from:))
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor [weak self] in
                    self?.deliver(words, isFinal: isFinal, failed: failed)
                }
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        finish(nil)
    }

    private func deliver(_ words: [SubtitleWord]?, isFinal: Bool, failed: Bool) {
        if failed {
            finish(nil)
        } else if isFinal {
            let subtitles = words.map(Subtitles.init(words:))
            finish(subtitles?.isEmpty == false ? subtitles : nil)
        }
    }

    private func finish(_ subtitles: Subtitles?) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: subtitles)
    }

    nonisolated private static func words(from result: SFSpeechRecognitionResult) -> [SubtitleWord] {
        result.bestTranscription.segments.map { segment in
            SubtitleWord(
                text: segment.substring,
                start: segment.timestamp,
                end: segment.timestamp + max(segment.duration, 0.1)
            )
        }
    }
}
