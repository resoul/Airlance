import UIKit

struct AuthProfileFields: Sendable {
    let firstName: String
    let lastName: String
    let username: String

    init(values: [String]) {
        firstName = values.first ?? ""
        lastName = values.dropFirst().first ?? ""
        username = values.dropFirst(2).first ?? ""
    }
}

@MainActor
enum AuthGate {
    static func entry(
        step: AuthStep,
        playsIntro: Bool,
        presentationContext: PresentationContext,
        onContinue: @escaping @MainActor (_ onEnd: @escaping @MainActor () -> Void) -> Void,
        onOther: (@MainActor () -> Void)?
    ) -> UIViewController {
        let controller = AuthStepController(step: step, playsIntro: playsIntro, presentationSource: presentationContext)
        controller.onPrimary = { [weak controller] _ in
            controller?.setLogoPaused(true)
            onContinue {
                controller?.setLogoPaused(false)
            }
        }
        controller.onSecondary = onOther

        return wrapped(controller, presentationContext: presentationContext)
    }

    static func profile(
        presentationContext: PresentationContext,
        onDone: @escaping @MainActor (_ fields: AuthProfileFields) async -> String?
    ) -> UIViewController {
        let controller = AuthStepController(step: .profile, presentationSource: presentationContext)
        controller.onPrimary = { [weak controller] values in
            let trimmed = values.map { value in
                value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            controller?.setBusy(true)
            Task {
                let failure = await onDone(AuthProfileFields(values: trimmed))
                controller?.setBusy(false)
                if let failure {
                    controller?.showFailure(failure)
                }
            }
        }

        return wrapped(controller, presentationContext: presentationContext)
    }

    private static func wrapped(
        _ controller: UIViewController,
        presentationContext: PresentationContext
    ) -> UIViewController {
        let navigation = ScreenNavigationController(presentationSource: presentationContext)
        navigation.viewControllers = [controller]
        navigation.isNavigationBarHidden = true

        return navigation
    }
}
