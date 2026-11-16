# OuterJoyn SDK for iOS (beta)

Let customers link their loyalty accounts, pay with points and more, from your iOS app. Each widget opens in a native bottom sheet. Partner logins run in Apple's secure sign-in sheet.

> **Beta.** The API may change before 2.0. Tell us what you hit: support@outerjoyn.com.

Requires iOS 16+.

## Install

In Xcode: **File → Add Package Dependencies…**, paste `https://github.com/OuterJoyn/outerjoyn-ios`, and add the `OuterJoynSDK` library to your app target.

Or in `Package.swift`:

```swift
.package(url: "https://github.com/OuterJoyn/outerjoyn-ios", from: "1.1.0")
```

## Link an account

1. **On your server**, start a short-lived session for the signed-in customer with your secret API key (never put the key in the app):

   ```http
   POST https://api.outerjoyn.com/api/sdk/sessions
   x-api-key: <your secret key>
   content-type: application/json

   { "partner_member_id": "<your id for the customer>", "scopes": ["link"] }
   ```

   Send the returned `token` to the app.

2. **In the app**, open the link sheet:

   ```swift
   import OuterJoynSDK

   OuterJoynSDK.shared.present(
       .connect,
       config: OuterJoynWidgetConfig(
           sessionToken: token,
           partners: ["<partner program id>"] // optional: only these partners; one skips the program list
       ),
       from: self,
       onSuccess: { result in
           // linked
       }
   )
   ```

   SwiftUI:

   ```swift
   Button("Link your account") { showLink = true }
       .outerJoynSheet(isPresented: $showLink, widget: .connect,
                       config: OuterJoynWidgetConfig(sessionToken: token))
   ```

3. **Treat the server as the source of truth**: subscribe to the `account_link.completed` webhook.

No URL scheme or entitlement is needed for partner logins; the secure sign-in sheet handles the return to your app.

## Offers

Show a promotion set's offers inline. The view grows to fit its offers. Buttons that go to a web page open Safari, "Open in the app" buttons open the brand's app, and link or rewards buttons open the kit's sheet.

```swift
// SwiftUI
OuterJoynPromotions(
    setId: "<promotion set id>",
    layout: .grid,                                      // optional: instead of the set's own
    look: ["buttonColor": "#e11d48", "columns": 2],     // optional: any saved set setting, for this spot only
    sessionToken: token                                 // optional: nil shows the offers everyone can see
)

// UIKit
let offers = OuterJoynPromotionsView(setId: "<promotion set id>", sessionToken: token)
offers.onOfferEvent = { action in /* a "Run an action on your site" button */ }
stackView.addArrangedSubview(offers)
```

`look` takes any setting from `GET /api/v1/promotion-sets/design-settings` (`accentColor`, `buttonColor`, `columns`, `bannerLook`, ...). Layouts: `carousel`, `grid`, `list`, `hero`, `strip`, `banner`.

## Open in the app

An offer button can open a brand's app. When the button is tapped the kit opens the app if it is installed, or the button's web page in Safari if not. Nothing to set up in your app.

## Look

```swift
var appearance = OuterJoynAppearance()
appearance.colors.primary = .purple
OuterJoynSDK.shared.configure(appearance: appearance)
```

## Docs

https://docs.outerjoyn.com/guides/retailer/ACCOUNT-LINKING-EMBED

## License

MIT — see [LICENSE](LICENSE).
