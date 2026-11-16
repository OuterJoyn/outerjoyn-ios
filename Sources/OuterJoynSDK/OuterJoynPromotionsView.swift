import SwiftUI
import UIKit
import WebKit

/// How a promotion set lays out its offers. Leave it out to use the set's own.
public enum OuterJoynPromotionsLayout: String {
    case carousel, grid, list, hero, strip, banner
}

/// A promotion set's offers, inline in your screen. It grows to fit its offers.
///
/// - Web pages and app links from offer buttons open outside the view (Safari,
///   or the brand's app).
/// - Link, rewards and other OuterJoyn windows open in the kit's bottom sheet.
///
/// ```swift
/// let offers = OuterJoynPromotionsView(
///     setId: "380551304567336520",
///     layout: .grid,
///     look: ["buttonColor": "#e11d48", "columns": 2],
///     sessionToken: token // nil shows the offers everyone can see
/// )
/// stackView.addArrangedSubview(offers)
/// ```
public final class OuterJoynPromotionsView: UIView {
    /// The height the offers need changed (also applied as the intrinsic height).
    public var onHeightChange: ((CGFloat) -> Void)?
    /// An offer button set to "Run an action on your site" was pressed: its action name.
    public var onOfferEvent: ((String) -> Void)?
    /// The set couldn't be shown (unknown set, bad look setting, no network).
    public var onError: ((Error) -> Void)?

    private let webView: WKWebView
    private let bridge = PromotionsBridge()
    private var contentHeight: CGFloat = 0
    private var pageLoaded = false
    private var html = ""
    private var sessionToken: String?
    private var apiBaseUrl = "https://api.outerjoyn.com"

    /// - Parameters:
    ///   - setId: The promotion set's id (the set designer's **Use on your site** window shows it).
    ///   - layout: Show the set in this layout instead of its own.
    ///   - look: Any saved set setting for this spot only (`accentColor`, `buttonColor`,
    ///     `columns`, `bannerLook`, ...; the list is `GET /api/v1/promotion-sets/design-settings`).
    ///     Values are strings, numbers or booleans.
    ///   - sessionToken: The signed-in customer's session, for joining, linking and rewards.
    ///     `nil` shows the offers everyone can see.
    public init(
        setId: String,
        layout: OuterJoynPromotionsLayout? = nil,
        look: [String: Any] = [:],
        sessionToken: String? = nil,
        apiBaseUrl: String = "https://api.outerjoyn.com"
    ) {
        let config = WKWebViewConfiguration()
        config.userContentController.add(bridge, name: "ojBridge")
        webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: .zero)

        bridge.view = self
        webView.navigationDelegate = bridge
        webView.uiDelegate = bridge
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        show(setId: setId, layout: layout, look: look, sessionToken: sessionToken, apiBaseUrl: apiBaseUrl)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(setId:layout:look:sessionToken:)") }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "ojBridge")
    }

    /// Show another set, layout, look or session. Nothing reloads when nothing changed.
    public func show(
        setId: String,
        layout: OuterJoynPromotionsLayout? = nil,
        look: [String: Any] = [:],
        sessionToken: String? = nil,
        apiBaseUrl: String = "https://api.outerjoyn.com"
    ) {
        let next = Self.html(setId: setId, layout: layout, look: look, sessionToken: sessionToken, apiBaseUrl: apiBaseUrl)
        guard next != html else { return }
        html = next
        self.sessionToken = sessionToken
        self.apiBaseUrl = apiBaseUrl
        pageLoaded = false
        webView.loadHTMLString(next, baseURL: URL(string: "https://sdk.outerjoyn.com"))
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }

    // MARK: - Messages from the page

    fileprivate func handle(_ body: String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        let payload = json["payload"] as? [String: Any] ?? [:]

        switch type {
        case "height":
            guard let h = payload["height"] as? Double, CGFloat(h) != contentHeight else { return }
            contentHeight = CGFloat(h)
            invalidateIntrinsicContentSize()
            onHeightChange?(contentHeight)
        case "open_url":
            if let s = payload["url"] as? String, let url = URL(string: s) { openOutside(url) }
        case "open_app_link":
            if let appUrl = payload["appUrl"] as? String, let fallbackUrl = payload["fallbackUrl"] as? String {
                OuterJoynAppLink.open(appUrl: appUrl, fallbackUrl: fallbackUrl)
            }
        case "open_widget":
            guard let name = payload["widget"] as? String, let widget = OuterJoynWidget(rawValue: name) else { return }
            openWidget(widget, partners: payload["partners"] as? [String])
        case "offer_event":
            if let id = payload["eventId"] as? String { onOfferEvent?(id) }
        case "error":
            let msg = payload["message"] as? String ?? "The offers could not be shown."
            onError?(NSError(domain: "OuterJoynSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: msg]))
        default:
            break
        }
    }

    fileprivate func openOutside(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme != "javascript", scheme != "data", scheme != "about" else { return }
        UIApplication.shared.open(url)
    }

    private func openWidget(_ widget: OuterJoynWidget, partners: [String]?) {
        guard let token = sessionToken else {
            onError?(NSError(domain: "OuterJoynSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "This offer needs a sessionToken."]))
            return
        }
        guard let presenter = presentingController() else { return }
        OuterJoynSDK.shared.present(
            widget,
            config: OuterJoynWidgetConfig(sessionToken: token, apiBaseUrl: apiBaseUrl, partners: partners),
            from: presenter,
            onSuccess: { [weak self] _ in self?.reload() },
            onError: { [weak self] err in self?.onError?(err) }
        )
    }

    /// Redraws the set, e.g. after a link changed which offers the customer has.
    public func reload() {
        webView.evaluateJavaScript("window.ojRenderPromotions && window.ojRenderPromotions()")
    }

    private func presentingController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder, !(r is UIViewController) { responder = r.next }
        var top = responder as? UIViewController ?? window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    fileprivate func allowsNavigation(_ action: WKNavigationAction) -> Bool {
        // The page itself and anything inside frames load here; a page the
        // shopper goes to opens outside the view.
        guard pageLoaded, action.targetFrame?.isMainFrame != false, let url = action.request.url else { return true }
        openOutside(url)
        return false
    }

    fileprivate func didFinishLoading() { pageLoaded = true }

    // MARK: - Page

    static func html(
        setId: String,
        layout: OuterJoynPromotionsLayout?,
        look: [String: Any],
        sessionToken: String?,
        apiBaseUrl: String
    ) -> String {
        precondition(JSONSerialization.isValidJSONObject(look), "OuterJoynPromotionsView look: values must be strings, numbers or booleans")
        var options: [String: Any] = ["arrayId": setId, "theme": look]
        if let layout { options["layout"] = layout.rawValue }
        var configure: [String: Any] = ["apiBaseUrl": apiBaseUrl]
        if let sessionToken { configure["sessionToken"] = sessionToken }
        return PromotionsPage.html(options: options, configure: configure, post: "window.webkit.messageHandlers.ojBridge.postMessage(m)")
    }
}

/// The page both kits' promotions views load (kept the same as Android's).
enum PromotionsPage {
    static func json(_ value: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "</", with: "<\\/")
    }

    static func html(options: [String: Any], configure: [String: Any], post: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            * { box-sizing: border-box; }
            html, body { margin: 0; padding: 0; background: transparent; font-family: -apple-system, system-ui, sans-serif; }
            #oj-promos { display: flow-root; }
          </style>
        </head>
        <body>
          <div id="oj-promos"></div>
          <script src="https://sdk.outerjoyn.com/v1/outerjoyn.js"></script>
          <script>
            (function() {
              function send(type, payload) { var m = JSON.stringify({ type: type, payload: payload || {} }); \(post); }
              var opts = \(json(options));
              var configure = \(json(configure));
              var box = document.getElementById('oj-promos');

              // The page's height, so the app sizes the view to the offers.
              // An open details window counts too, so it is never cut off.
              var last = -1;
              function measure() {
                var h = box.getBoundingClientRect().height;
                document.querySelectorAll('[role="dialog"]').forEach(function(d) {
                  var c = d.firstElementChild || d;
                  h = Math.max(h, c.scrollHeight + 32);
                });
                h = Math.ceil(h);
                if (h !== last) { last = h; send('height', { height: h }); }
              }
              new ResizeObserver(measure).observe(box);
              new MutationObserver(measure).observe(document.body, { childList: true, subtree: true, attributes: true });

              // Pages and app links leave the view; OuterJoyn windows open in the kit's sheet.
              window.open = function(url) { send('open_url', { url: String(url) }); return null; };
              window.addEventListener('outerjoyn:offer', function(e) { send('offer_event', { eventId: e.detail && e.detail.eventId }); });

              var tries = 0;
              function start() {
                var oj = window.OuterJoyn;
                if (!oj || !oj.promotions) {
                  if (++tries < 25) return setTimeout(start, 200);
                  return send('error', { message: 'The OuterJoyn SDK did not load.' });
                }
                ['connect', 'redeem', 'pay', 'account', 'exchange'].forEach(function(name) {
                  var w = oj[name];
                  if (w && typeof w.open === 'function') {
                    w.open = function(o) { send('open_widget', { widget: name, partners: (o && o.partners) || null }); };
                  }
                });
                oj.promotions.configure(configure);
                window.ojRenderPromotions = function() {
                  oj.promotions.render(Object.assign({}, opts, {
                    container: box,
                    onError: function(err) { send('error', { message: (err && err.message) || String(err) }); }
                  }));
                };
                window.ojRenderPromotions();
              }
              start();
            })();
          </script>
        </body>
        </html>
        """
    }
}

private final class PromotionsBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    weak var view: OuterJoynPromotionsView?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        view?.handle(body)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(view?.allowsNavigation(navigationAction) ?? true ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        view?.didFinishLoading()
    }

    // A target="_blank" link.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { view?.openOutside(url) }
        return nil
    }
}

// MARK: - SwiftUI

/// SwiftUI: a promotion set's offers, as tall as its offers need.
///
/// ```swift
/// OuterJoynPromotions(setId: "380551304567336520", layout: .grid, look: ["buttonColor": "#e11d48"])
/// ```
public struct OuterJoynPromotions: View {
    let setId: String
    let layout: OuterJoynPromotionsLayout?
    let look: [String: Any]
    let sessionToken: String?
    let apiBaseUrl: String
    let onOfferEvent: ((String) -> Void)?
    let onError: ((Error) -> Void)?

    @State private var height: CGFloat = 0

    public init(
        setId: String,
        layout: OuterJoynPromotionsLayout? = nil,
        look: [String: Any] = [:],
        sessionToken: String? = nil,
        apiBaseUrl: String = "https://api.outerjoyn.com",
        onOfferEvent: ((String) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.setId = setId
        self.layout = layout
        self.look = look
        self.sessionToken = sessionToken
        self.apiBaseUrl = apiBaseUrl
        self.onOfferEvent = onOfferEvent
        self.onError = onError
    }

    public var body: some View {
        Representable(owner: self, height: $height).frame(height: height)
    }

    private struct Representable: UIViewRepresentable {
        let owner: OuterJoynPromotions
        @Binding var height: CGFloat

        func makeUIView(context: Context) -> OuterJoynPromotionsView {
            OuterJoynPromotionsView(setId: owner.setId, layout: owner.layout, look: owner.look,
                                    sessionToken: owner.sessionToken, apiBaseUrl: owner.apiBaseUrl)
        }

        func updateUIView(_ view: OuterJoynPromotionsView, context: Context) {
            view.onHeightChange = { h in DispatchQueue.main.async { height = h } }
            view.onOfferEvent = owner.onOfferEvent
            view.onError = owner.onError
            view.show(setId: owner.setId, layout: owner.layout, look: owner.look,
                      sessionToken: owner.sessionToken, apiBaseUrl: owner.apiBaseUrl)
        }
    }
}
