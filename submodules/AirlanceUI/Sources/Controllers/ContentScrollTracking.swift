import UIKit

@MainActor
public protocol ContentScrollTracking: AnyObject {
    func updateTrackedScrollView()
}

extension UIViewController {
    public func contentScrollViewDidChange() {
        var controller = parent
        while let current = controller {
            if let tracker = current as? ContentScrollTracking {
                tracker.updateTrackedScrollView()

                return
            }

            controller = current.parent
        }
    }
}
