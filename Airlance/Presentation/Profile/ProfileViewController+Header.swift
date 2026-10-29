import Haptics
import ToastUI
import UIKit

extension ProfileViewController {
    func containerChanged() {
        let coordinator = container.coordinator
        if !isExpanded, container.isDragging, coordinator.topStretch > 24 {
            setExpanded(true)
        } else if isExpanded, coordinator.headerOffset > geometry.extra * 0.55 {
            setExpanded(false)
        }
        layoutHeader()
        updateMonthPill()
    }

    func updateHeaderHeight() {
        let height = max(0, geometry.contentHeight - geometry.navHeight)
        if abs(container.coordinator.headerHeight - height) > 0.01 {
            container.setHeaderHeight(height)
        }
    }

    func layoutHeader() {
        let coordinator = container.coordinator
        geometry.stretch = coordinator.topStretch
        header.layout(geometry)
        let visibleBottom = coordinator.topStretch - coordinator.headerOffset + geometry.nameBottom + geometry.expansion
        let isUnder = visibleBottom < geometry.navHeight + 20
        navigationBar.setState(filled: isUnder, onPhoto: geometry.openness > 0.5 && !isUnder)
    }

    func stepOpen(_ deltaTime: CFTimeInterval) {
        let target: CGFloat = isExpanded ? 1 : 0
        openSpring.step(toward: target, deltaTime: deltaTime)
        let isSettled = openSpring.isSettled(at: target)
        geometry.progress = isSettled ? target : openSpring.value
        updateHeaderHeight()
        layoutHeader()
        if isSettled {
            openDriver.stop()
        }
    }

    func showPhoto() {
        guard photos.indices.contains(photoIndex) else {
            return
        }

        header.showPhoto(photos[photoIndex], index: photoIndex, count: photos.count, expanded: isExpanded)
    }

    func photoTapped(forward: Bool) {
        guard isExpanded else {
            container.scrollToTop()
            setExpanded(true)

            return
        }

        let next = photoIndex + (forward ? 1 : -1)
        guard photos.indices.contains(next) else {
            header.shakePhoto(forward: forward)

            return
        }

        photoIndex = next
        Haptics.play(.selection)
        showPhoto()
    }

    func perform(_ action: ProfileAction, from button: UIView) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                button.transform = .identity
            }
        }
        Haptics.play(.tap)
        switch action {
        case .chat:
            router.show(.chat(id))
        case .mute:
            isMuted.toggle()
            applyActions(presentation)
            let strings = presentation.strings
            showToast(isMuted ? strings.profileMuted : strings.profileUnmuted, symbol: muteSymbol)
        case .call, .more:
            break
        }
    }

    func applyActions(_ presentation: PresentationData) {
        let strings = presentation.strings
        let theme = presentation.theme
        header.apply(action: .chat, symbol: "bubble.left.fill", title: strings.profileChat, theme: theme)
        header.apply(
            action: .mute,
            symbol: muteSymbol,
            title: isMuted ? strings.profileUnmute : strings.profileMute,
            theme: theme
        )
        header.apply(action: .call, symbol: "phone.fill", title: strings.profileCall, theme: theme)
        header.apply(action: .more, symbol: "ellipsis", title: strings.profileMore, theme: theme)
    }

    func showToast(_ text: String, symbol: String) {
        Toast(text, symbol: symbol, edge: .bottom).show(theme: presentation.theme, in: view)
    }

    func updateMonthPill() {
        guard pager.selectedIndex == 0, mediaPane.verticalOffset > 0 else {
            monthPill.alpha = 0

            return
        }

        let date = Calendar.current.date(byAdding: .month, value: -mediaPane.month, to: Date()) ?? Date()
        monthPill.text = monthFormatter.string(from: date)
        let width = ceil(monthPill.intrinsicContentSize.width) + 22
        let height = ceil(monthPill.font.lineHeight + 8)
        let top = geometry.navHeight + 56
        monthPill.frame = CGRect(x: (view.bounds.width - width) / 2, y: top, width: width, height: height)
        if monthPill.alpha < 1 {
            UIView.animate(withDuration: 0.15) {
                self.monthPill.alpha = 1
            }
        }
        scheduleMonthFade()
    }

    private var muteSymbol: String {
        isMuted ? "bell.slash.fill" : "bell.fill"
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

    private func scheduleMonthFade() {
        monthGeneration += 1
        let generation = monthGeneration
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, self.monthGeneration == generation else {
                return
            }

            UIView.animate(withDuration: 0.35) {
                self.monthPill.alpha = 0
            }
        }
    }
}
