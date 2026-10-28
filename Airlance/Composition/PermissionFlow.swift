import AirlanceUI
import Permissions
import PermissionsAPI
import UIKit

@MainActor
final class PermissionFlow {
    private let store: PermissionStore
    private let presentationContext: PresentationContext

    init(store: PermissionStore, presentationContext: PresentationContext) {
        self.store = store
        self.presentationContext = presentationContext
    }

    func isAuthorized(_ purpose: PermissionPurpose) -> Bool {
        purpose.permissions.allSatisfy { permission in
            store.status(permission)?.allowsUse == true
        }
    }

    func authorize(_ purpose: PermissionPurpose, from presenter: UIViewController) async -> Bool {
        for permission in purpose.permissions {
            let result = await store.request(permission)
            guard result.status.allowsUse else {
                if !result.wasPrompted {
                    explain(permission, status: result.status, from: presenter)
                }

                return false
            }
        }

        return true
    }

    private func explain(_ permission: Permission, status: PermissionStatus, from presenter: UIViewController) {
        guard presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else {
            return
        }

        let presentation = presentationContext.presentation
        let strings = presentation.strings
        let restricted = status == .restricted
        let store = store
        let actions = restricted
            ? [PopupAlertAction(title: strings.permissionAlertOk, style: .cancel)]
            : [
                PopupAlertAction(title: strings.permissionAlertSettings) {
                    store.openSettings(for: permission)
                },
                PopupAlertAction(title: strings.permissionAlertNotNow, style: .cancel),
            ]
        PopupAlert.show(
            title: strings.permissionAlertTitle,
            message: restricted ? strings.permissionAlertRestricted : strings.refusal(for: permission),
            actions: actions,
            theme: presentation.theme,
            in: presenter.view
        )
    }
}
