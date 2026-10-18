# Changelog

## 1.1.0

- Partner logins run in Apple's secure sign-in sheet; the result returns to the link sheet. No URL scheme or entitlement needed.
- The link sheet opens full height and fills it edge to edge.
- The widget's close button dismisses the sheet; a swiped-away sheet can be opened again.
- Removed `OuterJoynAuth`, `configure(apiBaseUrl:)` and `configure(callbackScheme:)`.
