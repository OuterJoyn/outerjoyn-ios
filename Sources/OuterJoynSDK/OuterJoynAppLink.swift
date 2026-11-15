import UIKit

/// Opens a brand's app from an "Open in the app" offer button.
///
/// The widget posts `{ type: "open_app_link", payload: { appUrl, fallbackUrl } }`.
/// The app opens when it is installed: a scheme link through `open`, an https
/// link only as a universal link. Otherwise the fallback page opens in Safari.
/// No `LSApplicationQueriesSchemes` entry is needed, since nothing asks
/// `canOpenURL` first.
enum OuterJoynAppLink {
    static func open(appUrl: String, fallbackUrl: String) {
        guard let fallback = URL(string: fallbackUrl), fallback.scheme == "https" else { return }
        guard let app = URL(string: appUrl), let scheme = app.scheme?.lowercased(), scheme != "http" else {
            UIApplication.shared.open(fallback)
            return
        }
        let options: [UIApplication.OpenExternalURLOptionsKey: Any] =
            scheme == "https" ? [.universalLinksOnly: true] : [:]
        UIApplication.shared.open(app, options: options) { opened in
            if !opened { UIApplication.shared.open(fallback) }
        }
    }
}
