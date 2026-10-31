import UIKit

open class TabBarController<Presentation: ThemedPresentation>:
    AirlanceViewController<Presentation>,
    ContentScrollTracking {
    public var onSelect: (@MainActor (Int) -> Void)?
    public var menuProvider: (@MainActor (Int) -> [PopupMenuItem]?)? {
        get {
            tabBarView.menuProvider
        }
        set {
            tabBarView.menuProvider = newValue
        }
    }

    public private(set) var viewControllers: [UIViewController] = []
    public private(set) var selectedIndex = 0
    public private(set) var isTabBarHidden = false

    private let tabBarView = TabBarView()
    private weak var trackedScrollView: UIScrollView?
    private var scrollObservation: NSKeyValueObservation?
    private var scrollDistance: CGFloat = 0
    private var follower: TabBarTransitionFollower?

    public var selectedViewController: UIViewController? {
        viewControllers.indices.contains(selectedIndex) ? viewControllers[selectedIndex] : nil
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        tabBarView.onSelect = { [weak self] index in
            self?.onSelect?(index)
        }
        view.addSubview(tabBarView)
        showSelected()
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBarView.bounds = CGRect(origin: .zero, size: view.bounds.size)
        tabBarView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        selectedViewController?.view.frame = view.bounds

        let reserved = isTabBarHidden ? 0 : TabBarLayout.reservedHeight(bottomInset: view.safeAreaInsets.bottom)
        for controller in viewControllers where controller.additionalSafeAreaInsets.bottom != reserved {
            controller.additionalSafeAreaInsets.bottom = reserved
        }
        updateTrackedScrollView()
    }

    override open func apply(_ presentation: Presentation) {
        super.apply(presentation)
        tabBarView.apply(presentation.theme)
    }

    public func setTabs(_ controllers: [UIViewController], items: [TabBarItem], selectedIndex: Int) {
        viewControllers.forEach(remove)
        viewControllers = controllers
        self.selectedIndex = selectedIndex
        tabBarView.setItems(items)
        tabBarView.select(selectedIndex, animated: false)
        if isViewLoaded {
            showSelected()
        }
    }

    public func setItems(_ items: [TabBarItem]) {
        tabBarView.setItems(items)
    }

    public func select(_ index: Int, animated: Bool) {
        guard index != selectedIndex, viewControllers.indices.contains(index) else {
            return
        }

        if let current = selectedViewController {
            remove(current)
        }
        selectedIndex = index
        tabBarView.select(index, animated: animated)
        showSelected()
    }

    public func setTabBarHidden(
        _ hidden: Bool,
        animated: Bool,
        alongside coordinator: (any UIViewControllerTransitionCoordinator)? = nil
    ) {
        guard hidden != isTabBarHidden, follower == nil else {
            return
        }

        if animated, let coordinator, follow(coordinator, hiding: hidden) {
            return
        }

        isTabBarHidden = hidden
        let changes = { [weak self] in
            self?.applyTabBarVisibility()
        }
        guard animated else {
            changes()

            return
        }

        if let coordinator {
            coordinator.animate(alongsideTransition: { _ in
                changes()
            }, completion: { [weak self] context in
                if context.isCancelled {
                    self?.setTabBarHidden(!hidden, animated: false)
                }
            })
        } else {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                changes()
            }
        }
    }

    private func follow(_ coordinator: any UIViewControllerTransitionCoordinator, hiding: Bool) -> Bool {
        guard
            let cover = coordinator.view(forKey: hiding ? .to : .from),
            let base = coordinator.view(forKey: hiding ? .from : .to)
        else {
            return false
        }

        let follower = TabBarTransitionFollower(bar: tabBarView, cover: cover, base: base, space: view)
        self.follower = follower
        tabBarView.transform = .identity
        follower.start()
        coordinator.animate(alongsideTransition: nil) { [weak self] context in
            guard let self else {
                return
            }

            follower.stop()
            self.follower = nil
            self.isTabBarHidden = context.isCancelled ? !hiding : hiding
            self.applyTabBarVisibility()
        }

        return true
    }

    public func setTabBarCompact(_ compact: Bool, animated: Bool) {
        tabBarView.setCompact(compact, animated: animated)
    }

    public func scrollSelectedToTop() {
        guard let scrollView = trackedScrollView else {
            return
        }

        let top = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(top, animated: true)
        setTabBarCompact(false, animated: true)
    }

    public func updateTrackedScrollView() {
        let scrollView = selectedViewController.flatMap(Self.scrollView(in:))
        guard scrollView !== trackedScrollView else {
            return
        }

        trackedScrollView = scrollView
        scrollDistance = 0
        setTabBarCompact(false, animated: true)
        let options: NSKeyValueObservingOptions = [.old, .new]
        scrollObservation = scrollView?.observe(\.contentOffset, options: options) { [weak self] scrollView, change in
            guard let old = change.oldValue, let new = change.newValue else {
                return
            }

            MainActor.assumeIsolated {
                self?.scrolled(scrollView, from: old.y, to: new.y)
            }
        }
    }

    private func applyTabBarVisibility() {
        let height = TabBarLayout.reservedHeight(bottomInset: view.safeAreaInsets.bottom)
        tabBarView.transform = isTabBarHidden ? CGAffineTransform(translationX: 0, y: height + 24) : .identity
        tabBarView.alpha = isTabBarHidden ? 0 : 1
        tabBarView.isUserInteractionEnabled = !isTabBarHidden
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func showSelected() {
        guard let controller = selectedViewController else {
            return
        }

        addChild(controller)
        controller.view.frame = view.bounds
        view.insertSubview(controller.view, belowSubview: tabBarView)
        controller.didMove(toParent: self)
        updateTrackedScrollView()
    }

    private func remove(_ controller: UIViewController) {
        guard controller.parent === self else {
            return
        }

        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }

    private func scrolled(_ scrollView: UIScrollView, from old: CGFloat, to new: CGFloat) {
        guard scrollView.isTracking || scrollView.isDecelerating else {
            return
        }

        let top = -scrollView.adjustedContentInset.top
        let bottom = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height
        guard new > top + 8 else {
            scrollDistance = 0
            setTabBarCompact(false, animated: true)

            return
        }

        guard new < bottom else {
            return
        }

        let delta = new - old
        if delta * scrollDistance < 0 {
            scrollDistance = 0
        }
        scrollDistance += delta
        if scrollDistance > 24 {
            setTabBarCompact(true, animated: true)
        } else if scrollDistance < -16 {
            setTabBarCompact(false, animated: true)
        }
    }

    private static func scrollView(in controller: UIViewController) -> UIScrollView? {
        if let navigation = controller as? UINavigationController {
            return navigation.topViewController.flatMap(scrollView(in:))
        }

        return controller.contentScrollView(for: .bottom) ?? controller.viewIfLoaded as? UIScrollView
    }
}
