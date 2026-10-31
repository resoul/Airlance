import UIKit
import WebKit

extension BrowserView: WKNavigationDelegate, WKUIDelegate {
    private static let webSchemes: Set<String> = ["http", "https", "about", "data", "blob"]

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
              !Self.webSchemes.contains(scheme) else {
            decisionHandler(.allow)

            return
        }

        decisionHandler(.cancel)
        onOpenExternal?(url)
    }

    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }

        return nil
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        updateState()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
        updateState()
    }
}
