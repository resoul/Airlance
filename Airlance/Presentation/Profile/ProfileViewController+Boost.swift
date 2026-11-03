import UIKit

extension ProfileViewController {
    var isBoostable: Bool {
        chat?.kind == .channel && dependencies.onAir.channel(id) != nil
    }

    func presentBoost() {
        BoostViewController.present(
            .channel(id),
            store: dependencies.onAir,
            presentationSource: dependencies.presentationContext,
            from: self
        )
    }
}
