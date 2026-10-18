import AuthenticationServices
import UIKit
import WebKit

/// Runs a partner's login in the system's secure sign-in sheet.
///
/// The link widget opens a partner login with `window.open`. An embedded web
/// view drops that pop-up, and partners (Google among them) refuse logins in
/// embedded views anyway, so the kit replaces `window.open` with a bridge: the
/// login runs in `ASWebAuthenticationSession`, the API redirects to
/// `outerjoyn://connect/callback` when it is done, and the result is posted back
/// into the widget as the same message a web pop-up would send.
final class OuterJoynLoginSheet: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let handlerName = "ojLogin"

    /// The API only redirects native logins to pre-registered schemes
    /// (ALLOWED_MOBILE_SCHEMES in sdkConnectOAuth.ts). The session catches the
    /// redirect itself, so the host app does not register this scheme.
    private static let callbackScheme = "outerjoyn"
    private static let callbackURL = "outerjoyn://connect/callback"
    private static let partnerLoginPath = "/api/v1/connect/oauth/authorize"

    /// Installed at document start so it is in place before the widget loads.
    static let userScript = WKUserScript(
        source: """
        (function () {
          var popups = {};
          window.__ojLoginFinished = function (id) {
            if (popups[id]) { popups[id].closed = true; delete popups[id]; }
          };
          window.open = function (url) {
            var id = String(Date.now()) + String(Math.random()).slice(2);
            var popup = { closed: false, focus: function () {}, close: function () {} };
            popups[id] = popup;
            window.webkit.messageHandlers.\(handlerName).postMessage(
              JSON.stringify({ id: id, url: new URL(String(url), location.href).toString() })
            );
            return popup;
          };
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    private weak var webView: WKWebView?
    private var session: ASWebAuthenticationSession?

    init(webView: WKWebView) {
        self.webView = webView
    }

    func handle(_ body: String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String,
              let urlString = json["url"] as? String,
              var components = URLComponents(string: urlString),
              components.scheme == "https" else {
            return
        }

        guard components.path == Self.partnerLoginPath else {
            // Any other link the widget opens (terms, privacy) belongs in Safari.
            if let url = components.url { UIApplication.shared.open(url) }
            finish(id, afterDelivery: false)
            return
        }

        var query = components.queryItems ?? []
        query.removeAll { $0.name == "platform" || $0.name == "redirect_uri" }
        query.append(URLQueryItem(name: "platform", value: "mobile"))
        query.append(URLQueryItem(name: "redirect_uri", value: Self.callbackURL))
        components.queryItems = query
        guard let loginURL = components.url else { return }

        let session = ASWebAuthenticationSession(url: loginURL, callbackURLScheme: Self.callbackScheme) { [weak self] callbackURL, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.session = nil
                if let callbackURL {
                    self.deliver(callbackURL)
                    self.finish(id, afterDelivery: true)
                } else {
                    // Cancelled or failed before the API answered: closing the
                    // pop-up puts the widget back on its confirm step.
                    self.finish(id, afterDelivery: false)
                }
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        session.start()
    }

    private func deliver(_ callbackURL: URL) {
        // The API builds the query with URLSearchParams (form encoding: a space
        // is "+"), which URLComponents does not decode, so decode it here.
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.percentEncodedQueryItems ?? []
        var params: [String: String] = [:]
        for item in items {
            let raw = (item.value ?? "").replacingOccurrences(of: "+", with: "%20")
            params[item.name] = raw.removingPercentEncoding ?? raw
        }

        let message: [String: Any]
        if params["status"] == "success", let linkId = params["member_partner_link_id"] {
            var payload: [String: Any] = ["member_partner_link_id": linkId]
            if let institution = params["institution_id"] { payload["institution_id"] = institution }
            if let consumerRef = params["consumer_ref"] { payload["consumer_ref"] = consumerRef }
            message = ["type": "outerjoyn:connect:complete", "payload": payload]
        } else {
            message = [
                "type": "outerjoyn:connect:error",
                "payload": [
                    "error": params["error"] ?? "unknown_error",
                    "message": params["error_description"] ?? "Linking did not finish.",
                ],
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.postMessage(\(json), '*');")
    }

    /// The widget treats a closed pop-up with no result as a cancel, so after a
    /// result it is closed only once the posted message has had time to land.
    private func finish(_ id: String, afterDelivery: Bool) {
        let script = "window.__ojLoginFinished(\(String(reflecting: id)));"
        if afterDelivery {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.webView?.evaluateJavaScript(script)
            }
        } else {
            webView?.evaluateJavaScript(script)
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        webView?.window ?? ASPresentationAnchor()
    }
}
