import UIKit

@MainActor
enum AuthGate {
    static func entry(
        step: AuthStep,
        playsIntro: Bool,
        presentationContext: PresentationContext,
        onContinue: @escaping @MainActor () -> Void,
        onOther: (@MainActor () -> Void)?
    ) -> UIViewController {
        let controller = AuthStepController(step: step, playsIntro: playsIntro, presentationSource: presentationContext)
        controller.onPrimary = { _ in
            onContinue()
        }
        controller.onSecondary = onOther

        return wrapped(controller, presentationContext: presentationContext)
    }

    static func profile(
        presentationContext: PresentationContext,
        onDone: @escaping @MainActor (_ name: String, _ username: String) -> Void
    ) -> UIViewController {
        let controller = AuthStepController(step: .profile, presentationSource: presentationContext)
        controller.onPrimary = { values in
            let trimmed = values.map { value in
                value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            onDone(trimmed.first ?? "", trimmed.dropFirst().first ?? "")
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
