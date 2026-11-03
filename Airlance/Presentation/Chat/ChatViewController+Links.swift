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

        if url.scheme == MessageBubbleLayout.hashtagScheme {
            searchHashtag(url)

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
        if let detected = detectedMenu(url) {
            activeLinkMenu = PopupMenu.show(
                detected.items,
                theme: presentation.theme,
                from: anchor,
                in: host,
                header: detected.header
            )

            return
        }

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

    private func detectedMenu(_ url: URL) -> (header: String, items: [PopupMenuItem])? {
        let strings = presentation.strings
        let raw = url.absoluteString
        let start = raw.firstIndex(of: ":").map(raw.index(after:)) ?? raw.startIndex
        let value = String(raw[start...]).removingPercentEncoding ?? ""
        let open: (title: String, symbol: String)
        let header: String
        switch url.scheme?.lowercased() {
        case "tel":
            open = (strings.chatLinkCall, "phone")
            header = value
        case "mailto":
            open = (strings.chatLinkMail, "envelope")
            header = value
        case "calshow":
            let date = Date(timeIntervalSinceReferenceDate: TimeInterval(value) ?? 0)
            open = (strings.chatLinkCalendar, "calendar")
            header = date.formatted(date: .long, time: .shortened)
        default:
            return nil
        }
        let items = [
            PopupMenuItem(title: open.title, symbol: open.symbol) {
                UIApplication.shared.open(url)
            },
            PopupMenuItem(title: strings.chatCopy, symbol: "doc.on.doc") { [weak self] in
                self?.copyText(header)
            },
        ]

        return (header, items)
    }

    private func searchHashtag(_ url: URL) {
        let encoded = String(url.absoluteString.dropFirst(MessageBubbleLayout.hashtagScheme.count + 1))
        let tag = "#" + (encoded.removingPercentEncoding ?? encoded)
        inputBar.dismissKeyboard()
        startSearch()
        searchField.text = tag
        searchField.resignFirstResponder()
        history.setSearch(tag)
        searchBar.update(history.search, strings: presentation.strings)
    }

    private func copyText(_ text: String) {
        UIPasteboard.general.string = text
        Haptics.play(.success)
        showToast(presentation.strings.chatCopied, symbol: "doc.on.doc.fill")
    }

    private func copyLink(_ url: URL) {
        UIPasteboard.general.url = url
        Haptics.play(.success)
        Toast(presentation.strings.linkCopied, symbol: "link").show(theme: presentation.theme, in: view)
    }
}
