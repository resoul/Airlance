import AirlanceUI
import Haptics
import ToastUI
import UIKit

extension ChatViewController {
    func openLink(_ url: URL) {
        if url.scheme == MessageBubbleLayout.mentionScheme {
            inputBar.dismissKeyboard()
            router.open(.profile(String(url.absoluteString.dropFirst(MessageBubbleLayout.mentionScheme.count + 1))))

            return
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            UIApplication.shared.open(url)

            return
        }

        inputBar.dismissKeyboard()
        router.open(.browser(url))
    }

    func showLinkMenu(_ url: URL, node: MessageBubbleNode, point: CGPoint) {
        guard let host = view.window else {
            return
        }

        inputBar.dismissKeyboard()
        let strings = presentation.strings
        let anchor = node.view.convert(CGRect(origin: point, size: .zero), to: host).insetBy(dx: -1, dy: -12)
        let items = [
            PopupMenuItem(title: strings.linkOpen, symbol: "safari") { [weak self] in
                self?.openLink(url)
            },
            PopupMenuItem(title: strings.browserOpenInSafari, symbol: "arrow.up.forward.app") {
                UIApplication.shared.open(url)
            },
            PopupMenuItem(title: strings.linkCopy, symbol: "doc.on.doc") { [weak self] in
                self?.copyLink(url)
            },
        ]
        activeLinkMenu = PopupMenu.show(
            items,
            theme: presentation.theme,
            from: anchor,
            in: host,
            header: url.absoluteString
        )
    }

    func trackLinkMenu(_ gesture: UILongPressGestureRecognizer) -> Bool {
        guard let menu = activeLinkMenu else {
            return false
        }

        switch gesture.state {
        case .changed, .ended:
            menu.track(menu.location(of: gesture), ended: gesture.state == .ended)
        default:
            menu.track(nil, ended: true)
        }
        if gesture.state != .changed {
            activeLinkMenu = nil
        }

        return true
    }

    private func copyLink(_ url: URL) {
        UIPasteboard.general.url = url
        Haptics.play(.success)
        Toast(presentation.strings.linkCopied, symbol: "link").show(theme: presentation.theme, in: view)
    }
}
