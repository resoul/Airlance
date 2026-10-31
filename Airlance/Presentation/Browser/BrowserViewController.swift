import BrowserUI
import UIKit

struct BrowserDependencies {
    let presentationContext: PresentationContext
    let dataStoreID: String
}

final class BrowserViewController: ScreenViewController {
    private let browser: BrowserView
    private let titleLabel = UILabel()
    private let hostLabel = UILabel()
    private lazy var reloadItem = UIBarButtonItem(
        image: UIImage(systemName: "arrow.clockwise"),
        primaryAction: UIAction { [weak self] _ in
            self?.reloadOrStop()
        }
    )

    init(url: URL, dependencies: BrowserDependencies) {
        browser = BrowserView(url: url, dataStore: BrowserDataStore.store(for: dependencies.dataStoreID))
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func loadView() {
        view = browser
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = UIStackView(arrangedSubviews: [titleLabel, hostLabel])
        stack.axis = .vertical
        stack.alignment = .center
        for label in [titleLabel, hostLabel] {
            label.lineBreakMode = .byTruncatingTail
        }
        navigationItem.titleView = stack
        navigationItem.rightBarButtonItem = reloadItem
        browser.onStateChange = { [weak self] state in
            self?.show(state)
        }
        browser.onShare = { [weak self] url in
            self?.share(url)
        }
        browser.onOpenExternal = { url in
            UIApplication.shared.open(url)
        }
        show(browser.state)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let strings = presentation.strings
        let theme = presentation.theme
        browser.apply(theme, strings: BrowserStrings(
            back: strings.browserBack,
            forward: strings.browserForward,
            share: strings.browserShare,
            openExternal: strings.browserOpenInSafari
        ))
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = theme.colors.textPrimary
        hostLabel.font = theme.fonts.caption
        hostLabel.textColor = theme.colors.textSecondary
    }

    private func show(_ state: BrowserState) {
        let host = state.url?.host() ?? ""
        titleLabel.text = state.title.isEmpty ? host : state.title
        hostLabel.text = host
        hostLabel.isHidden = state.title.isEmpty
        reloadItem.image = UIImage(systemName: state.isLoading ? "xmark" : "arrow.clockwise")
        navigationItem.titleView?.sizeToFit()
    }

    private func reloadOrStop() {
        if browser.state.isLoading {
            browser.stopLoading()
        } else {
            browser.reload()
        }
    }

    private func share(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = view
        present(controller, animated: true)
    }
}
