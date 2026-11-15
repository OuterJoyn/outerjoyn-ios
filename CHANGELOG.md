# Changelog

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
