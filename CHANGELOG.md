# Changelog

## 1.4.1 (beta)

- The appearance you pass to `OuterJoynSDK.shared.configure(appearance:)` or `OuterJoynSheet(appearance:)` now styles the hosted widgets (the link window included), not only the native views around them.
- The widgets follow the phone's light or dark mode when the brand's OuterJoyn Design > Appearance is System. Set `appearance.followDeviceColorScheme = false` to keep the brand's look.

## 1.4.0 (beta)

- "Open in the app" offer buttons open the brand's app when it is installed (a scheme link, or an https link only as a universal link), else the button's web page in Safari. No `LSApplicationQueriesSchemes` entry needed.

## 1.3.0 (beta)

- `OuterJoynWidgetConfig(partners:)` shows only the partner programs you name in the link sheet. One opens straight on its sign-in; several are the whole list. An id your store can't link ends on an error with code `partner_not_linkable`.

## 1.2.0 (beta)

- When a brand needs a confirmation code to link an account, the link sheet asks for it and finishes the link.

## 1.1.2 (beta)

- README marks the SDK as beta.

## 1.1.1

- The link sheet's page sizes to the sheet itself, so the link window fills it on every WebKit version.

## 1.1.0

- Partner logins run in Apple's secure sign-in sheet; the result returns to the link sheet. No URL scheme or entitlement needed.
- The link sheet opens full height and fills it edge to edge.
- The widget's close button dismisses the sheet; a swiped-away sheet can be opened again.
- Removed `OuterJoynAuth`, `configure(apiBaseUrl:)` and `configure(callbackScheme:)`.
