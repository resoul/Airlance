import NaturalLanguage
import SwiftUI
import Translation
import UIKit

@MainActor
final class MessageTranslator {
    enum Failure: Error {
        case unavailable
    }

    private var host: UIViewController?
    private var engine: AnyObject?

    static var isSupported: Bool {
        if #available(iOS 18.0, *) {
            return true
        }

        return false
    }

    static func language(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else {
            return nil
        }

        return Locale.Language(identifier: language.rawValue).languageCode?.identifier
    }

    func attach(to parent: UIViewController) {
        guard host == nil, #available(iOS 18.0, *) else {
            return
        }

        let requests = TranslationRequests()
        let controller = UIHostingController(rootView: TranslationHostView(requests: requests))
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        parent.addChild(controller)
        controller.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        parent.view.insertSubview(controller.view, at: 0)
        controller.didMove(toParent: parent)
        host = controller
        engine = requests
    }

    func translate(_ text: String, to target: String) async throws -> String {
        guard #available(iOS 18.0, *), let requests = engine as? TranslationRequests else {
            throw Failure.unavailable
        }

        return try await requests.translate(text, to: Locale.Language(identifier: target))
    }
}

@available(iOS 18.0, *)
@MainActor
private final class TranslationRequests: ObservableObject {
    private struct Pending: Sendable {
        let text: String
        let continuation: CheckedContinuation<String, Error>
    }

    @Published var configuration: TranslationSession.Configuration?
    private var pending: [Pending] = []

    func translate(_ text: String, to target: Locale.Language) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            pending.append(Pending(text: text, continuation: continuation))
            let next = TranslationSession.Configuration(source: nil, target: target)
            if configuration?.target == target {
                configuration?.invalidate()
            } else {
                configuration = next
            }
        }
    }

    nonisolated func run(_ session: TranslationSession) async {
        while let item = await next() {
            do {
                let response = try await session.translate(item.text)
                item.continuation.resume(returning: response.targetText)
            } catch {
                item.continuation.resume(throwing: error)
            }
        }
    }

    private func next() -> Pending? {
        pending.isEmpty ? nil : pending.removeFirst()
    }
}

@available(iOS 18.0, *)
private struct TranslationHostView: View {
    @ObservedObject var requests: TranslationRequests

    var body: some View {
        Color.clear
            .translationTask(requests.configuration, action: requests.run)
    }
}
