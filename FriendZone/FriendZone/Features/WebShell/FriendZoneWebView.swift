import SwiftUI
import UIKit
import WebKit

struct FriendZoneWebView: UIViewRepresentable {
    let path: String
    let reloadKey: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(baseHost: AppConfig.baseURL.host)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(FriendZoneTheme.background)

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.refreshWebView), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        context.coordinator.webView = webView

        loadInitialURL(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastReloadKey != reloadKey {
            context.coordinator.lastReloadKey = reloadKey
            webView.reload()
            return
        }

        guard let currentURL = webView.url else {
            loadInitialURL(in: webView)
            return
        }

        let expectedURL = AppConfig.url(for: path)
        if currentURL.path != expectedURL.path {
            webView.load(URLRequest(url: expectedURL))
        }
    }

    private func loadInitialURL(in webView: WKWebView) {
        webView.load(URLRequest(url: AppConfig.url(for: path)))
    }
}

final class Coordinator: NSObject, WKNavigationDelegate {
    weak var webView: WKWebView?
    let baseHost: String?
    var lastReloadKey: UUID?

    init(baseHost: String?) {
        self.baseHost = baseHost
    }

    @objc func refreshWebView() {
        webView?.reload()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        syncCookies(from: webView)
        webView.scrollView.refreshControl?.endRefreshing()
    }

    private func syncCookies(from webView: WKWebView) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            let sharedStore = HTTPCookieStorage.shared
            for cookie in cookies {
                sharedStore.setCookie(cookie)
            }
        }
    }


    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let host = url.host else {
            decisionHandler(.allow)
            return
        }

        let isInAppURL = (host == baseHost)
        if isInAppURL {
            decisionHandler(.allow)
            return
        }

        UIApplication.shared.open(url)
        decisionHandler(.cancel)
    }
}
