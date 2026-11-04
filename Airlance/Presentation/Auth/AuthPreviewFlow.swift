import Haptics
import UIKit

enum AuthPreviewScenario: String, CaseIterable {
    case newUser
    case returning
    case sessionEnded
}

@MainActor
final class AuthPreviewFlow {
    private static let host = "auth.airlance.org"

    private let presentationContext: PresentationContext
    private let scenario: AuthPreviewScenario
    private weak var root: UINavigationController?
    private weak var sheet: UINavigationController?
    private weak var first: AuthStepController?

    init(scenario: AuthPreviewScenario, presentationContext: PresentationContext) {
        self.scenario = scenario
        self.presentationContext = presentationContext
    }

    func start(from presenter: UIViewController) {
        let navigation = makeRoot(playsIntro: false)
        first?.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak self] _ in
                self?.close()
            }
        )
        navigation.modalPresentationStyle = .fullScreen
        presenter.present(navigation, animated: true)
    }

    private func makeRoot(playsIntro: Bool) -> UINavigationController {
        let step: AuthStep = scenario == .sessionEnded ? .sessionEnded(canSwitch: false) : .welcome
        let controller = make(step, playsIntro: playsIntro)
        let navigation = ScreenNavigationController(presentationSource: presentationContext)
        navigation.viewControllers = [controller]
        first = controller
        root = navigation

        return navigation
    }

    private func make(_ step: AuthStep, playsIntro: Bool = false) -> AuthStepController {
        let controller = AuthStepController(
            step: step,
            playsIntro: playsIntro,
            presentationSource: presentationContext
        )
        controller.onPrimary = { values in
            self.primary(step, values: values)
        }
        controller.onSecondary = {
            self.secondary(step)
        }

        return controller
    }

    private func primary(_ step: AuthStep, values: [String]) {
        switch step {
        case .welcome, .sessionEnded:
            openSheet()
        case .entry:
            push(.code(email: values.first ?? ""))
        case .code:
            push(scenario == .newUser ? .createPasskey : .usePasskey)
        case .createPasskey:
            push(.recoveryCodes)
        case .recovery:
            push(.replacePasskey)
        case .recoveryCodes:
            openProfile()
        case .usePasskey, .replacePasskey, .profile:
            finish()
        }
    }

    private func secondary(_ step: AuthStep) {
        switch step {
        case .entry:
            finish()
        case .usePasskey:
            push(.recovery)
        default:
            break
        }
    }

    private func openSheet() {
        let entry = make(.entry)
        entry.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: presentationContext.presentation.strings.chatCancel,
            primaryAction: UIAction { [weak self] _ in
                self?.cancelSheet()
            }
        )
        entry.navigationItem.title = Self.host
        let navigation = ScreenNavigationController(presentationSource: presentationContext)
        navigation.viewControllers = [entry]
        navigation.modalPresentationStyle = .pageSheet
        navigation.isModalInPresentation = true
        sheet = navigation
        first?.setLogoPaused(true)
        root?.present(navigation, animated: true)
    }

    private func cancelSheet() {
        first?.setLogoPaused(false)
        sheet?.dismiss(animated: true)
    }

    private func push(_ step: AuthStep) {
        let controller = make(step)
        controller.navigationItem.title = Self.host
        sheet?.pushViewController(controller, animated: true)
    }

    private func openProfile() {
        let profile = make(.profile)
        profile.navigationItem.hidesBackButton = true
        root?.interactivePopGestureRecognizer?.isEnabled = false
        root?.pushViewController(profile, animated: false)
        sheet?.dismiss(animated: true)
    }

    private func finish() {
        Haptics.play(.success)
        close()
    }

    private func close() {
        root?.presentingViewController?.dismiss(animated: true)
    }
}
