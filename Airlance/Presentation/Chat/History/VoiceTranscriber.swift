import Foundation
import Speech

struct VoiceTranscript: Sendable, Hashable {
    enum State: Sendable, Hashable {
        case loading
        case done
        case failed
    }

    var text = ""
    var state = State.loading
    var isShown = true
}

@MainActor
final class VoiceTranscriber {
    private struct Job {
        let task: SFSpeechRecognitionTask
        let onUpdate: @MainActor (VoiceTranscript) -> Void
        var lastDelivery = Date.distantPast
        var text = ""
    }

    private static let partialInterval: TimeInterval = 0.35

    private var jobs: [String: Job] = [:]

    func transcribe(
        _ key: String,
        url: URL,
        locale: Locale,
        onUpdate: @escaping @MainActor (VoiceTranscript) -> Void
    ) {
        guard
            jobs[key] == nil,
            let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(),
            recognizer.isAvailable
        else {
            onUpdate(VoiceTranscript(state: .failed))

            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = true
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor [weak self] in
                self?.deliver(key, text: text, isFinal: isFinal, failed: failed)
            }
        }
        jobs[key] = Job(task: task, onUpdate: onUpdate)
    }

    func cancelAll() {
        for job in jobs.values {
            job.task.cancel()
        }
        jobs = [:]
    }

    private func deliver(_ key: String, text: String?, isFinal: Bool, failed: Bool) {
        guard var job = jobs[key] else {
            return
        }

        if let text, !text.isEmpty {
            job.text = text
        }
        if isFinal || failed {
            jobs[key] = nil
            let state: VoiceTranscript.State = job.text.isEmpty ? .failed : .done
            job.onUpdate(VoiceTranscript(text: job.text, state: state))

            return
        }

        let now = Date()
        guard now.timeIntervalSince(job.lastDelivery) >= Self.partialInterval, !job.text.isEmpty else {
            jobs[key] = job

            return
        }

        job.lastDelivery = now
        jobs[key] = job
        job.onUpdate(VoiceTranscript(text: job.text, state: .loading))
    }
}
