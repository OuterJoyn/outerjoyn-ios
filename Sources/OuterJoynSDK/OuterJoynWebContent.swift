import SwiftUI
import WebKit

/// WebView that loads OuterJoyn SDK widget content from CDN.
///
/// Injects CSS custom properties from OuterJoynAppearance into the WebView
/// so the widget renders with the native app's theme.
///
/// Bridges postMessage events from the widget back to native callbacks.
public struct OuterJoynWebContent: View {
    let widget: OuterJoynWidget
    let config: OuterJoynWidgetConfig
    let appearance: OuterJoynAppearance
    let onSuccess: ((Any) -> Void)?
    let onClose: (() -> Void)?
    let onError: ((Error) -> Void)?

    @State private var isLoading = true

    public var body: some View {
        ZStack {
            WebViewWrapper(
                html: generateHTML(),
                onMessage: handleMessage,
                onFinishLoading: { isLoading = false }
            )
            // The page draws to the sheet's bottom edge and keeps its own
            // content clear of the home indicator (viewport-fit=cover).
            .ignoresSafeArea(edges: .bottom)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(appearance.typography.caption)
                        .foregroundColor(appearance.colors.textMuted)
                }
            }
        }
    }

    private func generateHTML() -> String {
        let cssVars = appearance.toCSSVariables()
        let widgetName = widget.rawValue
        var optionsDict: [String: Any] = [
            "sessionToken": config.sessionToken,
            "apiBaseUrl": config.apiBaseUrl,
        ]
        if let orderTotal = config.orderTotalCents {
            optionsDict["orderTotal"] = orderTotal
        }
        // The redeemable basis. `if let` is load-bearing: a 0 must reach the
        // widget (it reports "nothing charged for this component"), while nil
        // must stay OFF the wire entirely — the gateway rejects an absent
        // component but accepts an explicit 0. Set before the extras merge so
        // an integrator's own extras still override, as with every field above.
        if let merch = config.merchandiseSubtotalCents {
            optionsDict["merchandiseSubtotalCents"] = merch
        }
        if let tax = config.taxCents {
            optionsDict["taxCents"] = tax
        }
        if let shipping = config.shippingCents {
            optionsDict["shippingCents"] = shipping
        }
        if let direction = config.direction {
            optionsDict["direction"] = direction
        }
        if let lock = config.lockTargetToBrand {
            optionsDict["lockTargetToBrand"] = lock
        }
        if widget.fillsSheet {
            optionsDict["presentation"] = "sheet"
        }
        for (key, value) in config.extras {
            optionsDict[key] = value
        }

        // Serialize options to JSON, escaping </script> for HTML safety
        let optionsData = try? JSONSerialization.data(withJSONObject: optionsDict)
        let optionsJson = (String(data: optionsData ?? Data(), encoding: .utf8) ?? "{}")
            .replacingOccurrences(of: "</script>", with: "<\\/script>")

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
          <style>
            :root { \(cssVars) }
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, sans-serif; background: transparent; }
            #oj-widget { min-height: 100vh; }
          </style>
        </head>
        <body>
          <div id="oj-widget"></div>
          <script src="https://sdk.outerjoyn.com/v1/outerjoyn.js"></script>
          <script>
            (function() {
              var opts = \(optionsJson);
              opts.container = '#oj-widget';
              opts.onSuccess = function(result) {
                window.webkit.messageHandlers.ojBridge.postMessage(
                  JSON.stringify({ type: 'success', payload: result })
                );
              };
              opts.onClose = function() {
                window.webkit.messageHandlers.ojBridge.postMessage(
                  JSON.stringify({ type: 'close' })
                );
              };
              opts.onError = function(err) {
                window.webkit.messageHandlers.ojBridge.postMessage(
                  JSON.stringify({ type: 'error', payload: { message: err.message || String(err) } })
                );
              };

              var _tryCount = 0;
              function tryOpen() {
                if (window.OuterJoyn && window.OuterJoyn.\(widgetName)) {
                  window.OuterJoyn.\(widgetName).open(opts);
                } else if (++_tryCount < 10) {
                  setTimeout(tryOpen, 200);
                } else {
                  opts.onError({ message: 'OuterJoyn SDK failed to load after 2s' });
                }
              }
              tryOpen();
            })();
          </script>
        </body>
        </html>
        """
    }

    private func handleMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "success":
            onSuccess?(json["payload"] ?? [:])
        case "error":
            let msg = (json["payload"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            onError?(NSError(domain: "OuterJoynSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: msg]))
        case "close":
            onClose?()
        default:
            break
        }
    }
}

// MARK: - WKWebView Wrapper

struct WebViewWrapper: UIViewRepresentable {
    let html: String
    let onMessage: (String) -> Void
    let onFinishLoading: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMessage: onMessage, onFinishLoading: onFinishLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "ojBridge")
        config.userContentController.add(context.coordinator, name: OuterJoynLoginSheet.handlerName)
        config.userContentController.addUserScript(OuterJoynLoginSheet.userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.loginSheet = OuterJoynLoginSheet(webView: webView)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.loadHTMLString(html, baseURL: URL(string: "https://sdk.outerjoyn.com"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "ojBridge")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: OuterJoynLoginSheet.handlerName)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onMessage: (String) -> Void
        let onFinishLoading: () -> Void
        var loginSheet: OuterJoynLoginSheet?

        init(onMessage: @escaping (String) -> Void, onFinishLoading: @escaping () -> Void) {
            self.onMessage = onMessage
            self.onFinishLoading = onFinishLoading
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? String else { return }
            if message.name == OuterJoynLoginSheet.handlerName {
                loginSheet?.handle(body)
            } else {
                onMessage(body)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onFinishLoading()
        }
    }
}
