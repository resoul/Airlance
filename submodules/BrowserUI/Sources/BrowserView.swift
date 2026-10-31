import Theme
import UIKit
import WebKit

@MainActor
public final class BrowserView: UIView {
    public var onStateChange: (@MainActor (BrowserState) -> Void)?
    public var onShare: (@MainActor (URL) -> Void)?
    public var onOpenExternal: (@MainActor (URL) -> Void)?

    public private(set) var state: BrowserState

    let webView: WKWebView
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let toolbar = BrowserToolbar()
    private var observations: [NSKeyValueObservation] = []

    public init(url: URL, dataStore: WKWebsiteDataStore) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        state = BrowserState(
            title: "",
            url: url,
            progress: 0,
            isLoading: true,
            canGoBack: false,
            canGoForward: false
        )
        super.init(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        addSubview(webView)
        addSubview(progress)
        addSubview(toolbar)
        bindToolbar()
        observe()
        webView.load(URLRequest(url: url))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func apply(_ theme: AppTheme, strings: BrowserStrings) {
        backgroundColor = theme.colors.background
        webView.backgroundColor = theme.colors.background
        progress.progressTintColor = theme.colors.accent
        progress.trackTintColor = .clear
        toolbar.apply(theme, strings: strings)
    }

    public func reload() {
        webView.reload()
    }

    public func stopLoading() {
        webView.stopLoading()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let toolbarHeight = BrowserToolbar.height + safeAreaInsets.bottom
        toolbar.frame = CGRect(x: 0, y: bounds.height - toolbarHeight, width: bounds.width, height: toolbarHeight)
        webView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: toolbar.frame.minY)
        progress.frame = CGRect(x: 0, y: safeAreaInsets.top, width: bounds.width, height: 2)
    }

    func updateState() {
        let next = BrowserState(
            title: webView.title ?? "",
            url: webView.url ?? state.url,
            progress: webView.estimatedProgress,
            isLoading: webView.isLoading,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )
        guard next != state else {
            return
        }

        state = next
        toolbar.update(next)
        updateProgress()
        onStateChange?(next)
    }

    private func updateProgress() {
        if state.isLoading {
            progress.alpha = 1
            progress.setProgress(Float(max(0.1, state.progress)), animated: true)

            return
        }

        progress.setProgress(1, animated: true)
        UIView.animate(withDuration: 0.25, delay: 0.15) {
            self.progress.alpha = 0
        } completion: { _ in
            if !self.state.isLoading {
                self.progress.setProgress(0, animated: false)
            }
        }
    }

    private func bindToolbar() {
        toolbar.back.addAction(UIAction { [weak self] _ in
            self?.webView.goBack()
        }, for: .touchUpInside)
        toolbar.forward.addAction(UIAction { [weak self] _ in
            self?.webView.goForward()
        }, for: .touchUpInside)
        toolbar.share.addAction(UIAction { [weak self] _ in
            if let url = self?.state.url {
                self?.onShare?(url)
            }
        }, for: .touchUpInside)
        toolbar.external.addAction(UIAction { [weak self] _ in
            if let url = self?.state.url {
                self?.onOpenExternal?(url)
            }
        }, for: .touchUpInside)
        toolbar.update(state)
    }

    private func observe() {
        let changed: @Sendable (WKWebView) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateState()
            }
        }
        observations = [
            webView.observe(\.title) { view, _ in
                changed(view)
            },
            webView.observe(\.url) { view, _ in
                changed(view)
            },
            webView.observe(\.estimatedProgress) { view, _ in
                changed(view)
            },
            webView.observe(\.isLoading) { view, _ in
                changed(view)
            },
            webView.observe(\.canGoBack) { view, _ in
                changed(view)
            },
            webView.observe(\.canGoForward) { view, _ in
                changed(view)
            },
        ]
    }
}
