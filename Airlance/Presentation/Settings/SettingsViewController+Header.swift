import Haptics
import LiquidUI
import UIKit

extension SettingsViewController {
    private static let expandPull: CGFloat = 24

    private var scrollPosition: CGFloat {
        listView.scrollView.contentOffset.y + listView.contentInsets.top
    }

    func scrollChanged() {
        if !isExpanded, !photos.isEmpty, listView.scrollView.isTracking, scrollPosition < -Self.expandPull {
            setExpanded(true)
        } else if isExpanded, scrollPosition > geometry.extra * 0.55 {
            setExpanded(false)
        }
        layoutHeader()
    }

    func layoutHeader() {
        geometry.stretch = max(0, -scrollPosition)
        if abs(listView.headerHeight - geometry.height) > 0.01 {
            listView.headerHeight = geometry.height
        }
        header.layout(geometry)
        applyNavigationBar(filled: header.nameBottom - scrollPosition < 0)
    }

    func applyNavigationBar(filled: Bool) {
        let isFirstCall = navigationItem.standardAppearance == nil
        guard filled != isNavigationBarFilled || isFirstCall else {
            return
        }

        isNavigationBarFilled = filled
        let clear = UINavigationBarAppearance()
        clear.configureWithTransparentBackground()
        navigationItem.standardAppearance = clear
        if filled, let bar = navigationController?.navigationBar {
            navigationItem.standardAppearance = bar.standardAppearance
        }
        navigationItem.scrollEdgeAppearance = navigationItem.standardAppearance
        navigationItem.compactAppearance = navigationItem.standardAppearance
        navigationItem.title = filled ? myProfile.profile.fullName : nil
    }

    func applyBarTint() {
        let tint: UIColor? = geometry.openness > 0.5 ? .white : nil
        for item in navigationItem.rightBarButtonItems ?? [] {
            item.tintColor = tint
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    func reloadPhotos() {
        let profile = myProfile.profile
        photos = myProfile.gallery(for: profile)
        if photos.isEmpty, isExpanded {
            setExpanded(false)
        }
        photoIndex = min(photoIndex, max(0, photos.count - 1))
        showPhoto()
    }

    func stepOpen(_ deltaTime: CFTimeInterval) {
        let target: CGFloat = isExpanded ? 1 : 0
        openSpring.step(toward: target, deltaTime: deltaTime)
        let isSettled = openSpring.isSettled(at: target)
        setProgress(isSettled ? target : openSpring.value)
        if isSettled {
            openDriver.stop()
        }
    }

    func finishOpening() {
        guard openDriver.isRunning else {
            return
        }

        openDriver.stop()
        openSpring = Spring(isExpanded ? 1 : 0, stiffness: 15, dampingRatio: 0.78)
        setProgress(isExpanded ? 1 : 0)
    }

    func collapseForEditing() {
        openDriver.stop()
        isExpanded = false
        photoIndex = 0
        openSpring = Spring(0, stiffness: 15, dampingRatio: 0.78)
        showPhoto()
        setProgress(0)
        listView.scrollView.setContentOffset(CGPoint(x: 0, y: -listView.contentInsets.top), animated: false)
    }

    func photoTapped(at position: CGFloat) {
        guard !photos.isEmpty else {
            return
        }

        guard isExpanded else {
            listView.scrollView.setContentOffset(CGPoint(x: 0, y: -listView.contentInsets.top), animated: true)
            setExpanded(true)

            return
        }

        if !myProfile.profile.photos.isEmpty, (1.0 / 3...2.0 / 3).contains(position) {
            openViewer()

            return
        }

        let forward = position > 0.5
        let next = photoIndex + (forward ? 1 : -1)
        guard photos.indices.contains(next) else {
            header.shakePhoto(forward: forward)

            return
        }

        photoIndex = next
        Haptics.play(.selection)
        showPhoto()
    }

    func photoSwiped(forward: Bool) {
        guard isExpanded else {
            return
        }

        if photos.indices.contains(photoIndex + (forward ? 1 : -1)) {
            header.slidePhoto(forward: forward)
        }
        photoTapped(at: forward ? 1 : 0)
    }

    private func openViewer() {
        let viewer = ProfilePhotoViewerController(store: myProfile, index: photoIndex, presentation: presentation)
        viewer.onChoose = { [weak self] in
            self?.collapseForEditing()
            self?.router.open(.settingsPage(.editProfile))
        }
        present(viewer, animated: true)
    }

    private func showPhoto() {
        let profile = myProfile.profile
        let shown = photos.indices.contains(photoIndex) ? photos[photoIndex] : myProfile.avatar(for: profile)
        header.showPhoto(shown, index: photoIndex, count: photos.count, expanded: isExpanded)
    }

    private func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else {
            return
        }

        isExpanded = expanded
        Haptics.play(expanded ? .threshold : .tap)
        if !expanded {
            photoIndex = 0
        }
        showPhoto()
        openDriver.start()
    }

    private func setProgress(_ progress: CGFloat) {
        let wasOnPhoto = geometry.openness > 0.5
        let oldHeight = geometry.height
        geometry.progress = progress
        let shrink = oldHeight - geometry.height
        if shrink > 0, scrollPosition > 0 {
            let scrollView = listView.scrollView
            let top = -listView.contentInsets.top
            listView.headerHeight = geometry.height
            scrollView.contentOffset.y = max(top, scrollView.contentOffset.y - shrink)
        }
        layoutHeader()
        if wasOnPhoto != (geometry.openness > 0.5) {
            applyBarTint()
        }
    }
}
