import UIKit

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
        onDone: @escaping @MainActor (_ name: String, _ username: String) async -> String?
    ) -> UIViewController {
        let controller = AuthStepController(step: .profile, presentationSource: presentationContext)
        controller.onPrimary = { [weak controller] values in
            let trimmed = values.map { value in
                value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            controller?.setBusy(true)
            Task {
                let failure = await onDone(trimmed.first ?? "", trimmed.dropFirst().first ?? "")
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
