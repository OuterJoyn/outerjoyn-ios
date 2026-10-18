import SwiftUI
import UIKit

/// Bottom sheet presentation for OuterJoyn SDK widgets.
///
/// Uses UISheetPresentationController (iOS 15+) for system-consistent
/// drag-to-dismiss, detents, and dimming behavior.
public struct OuterJoynSheet: UIViewControllerRepresentable {
    let widget: OuterJoynWidget
    let config: OuterJoynWidgetConfig
    let appearance: OuterJoynAppearance
    let onSuccess: ((Any) -> Void)?
    let onClose: (() -> Void)?
    let onError: ((Error) -> Void)?

    public init(
        widget: OuterJoynWidget,
        config: OuterJoynWidgetConfig,
        appearance: OuterJoynAppearance = OuterJoynAppearance(),
        onSuccess: ((Any) -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.widget = widget
        self.config = config
        self.appearance = appearance
        self.onSuccess = onSuccess
        self.onClose = onClose
        self.onError = onError
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        let webContent = OuterJoynWebContent(
            widget: widget,
            config: config,
            appearance: appearance,
            onSuccess: onSuccess,
            onClose: onClose,
            onError: onError
        )

        let hostingController = UIHostingController(rootView: webContent)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = widget.detents
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = appearance.shapes.cornerRadius + 8
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        return hostingController
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// Widget types supported by the SDK.
public enum OuterJoynWidget: String {
    case pay
    case exchange
    case redeem
    case connect
    case account

    /// Connect fills a full-height sheet edge to edge (the widget's `sheet`
    /// presentation); the others keep their card and a medium detent.
    var fillsSheet: Bool { self == .connect }

    var detents: [UISheetPresentationController.Detent] {
        fillsSheet ? [.large()] : [.medium(), .large()]
    }
}

/// Configuration for presenting a widget.
public struct OuterJoynWidgetConfig {
    /// Session token for API authentication
    public var sessionToken: String
    /// API base URL (default: https://api.outerjoyn.com)
    public var apiBaseUrl: String
    /// Order total in cents (pay widget only)
    public var orderTotalCents: Int?
    /// Merchandise subtotal in cents (pay widget only) — see the breakdown note.
    public var merchandiseSubtotalCents: Int?
    /// Tax in cents (pay widget only) — see the breakdown note.
    public var taxCents: Int?
    /// Shipping in cents (pay widget only) — see the breakdown note.
    public var shippingCents: Int?
    /// Exchange direction (exchange widget only)
    public var direction: String?
    /// Lock target to brand (exchange widget only)
    public var lockTargetToBrand: Bool?
    /// Additional options passed to the widget
    public var extras: [String: Any]

    /// THE ORDER BREAKDOWN (`merchandiseSubtotalCents` / `taxCents` /
    /// `shippingCents`) tells the server how much of the order points may cover
    /// — the "redeemable basis".
    ///
    /// Pass all three on every pay checkout. WHICH of them the server requires
    /// is a per-storefront setting the retailer can change without any app
    /// update, so a checkout that always reports its whole breakdown is correct
    /// under every configuration, while one that reports a subset starts
    /// failing with 422 (`merchandise_subtotal_required` /
    /// `tax_amount_required` / `shipping_amount_required`) the moment that
    /// setting changes — and a shipped mobile binary cannot be hotfixed.
    ///
    /// `0` is a value; omitting a field is not the same thing. Free shipping is
    /// `shippingCents: 0`. `nil` means "this checkout cannot report that
    /// component" and is rejected — deliberately, so an unreported component
    /// can never silently under-report the basis. The corollary: do NOT pass
    /// `0` for a figure you merely don't have, since that asserts the component
    /// IS zero and caps redemption accordingly.
    public init(
        sessionToken: String,
        apiBaseUrl: String = "https://api.outerjoyn.com",
        orderTotalCents: Int? = nil,
        merchandiseSubtotalCents: Int? = nil,
        taxCents: Int? = nil,
        shippingCents: Int? = nil,
        direction: String? = nil,
        lockTargetToBrand: Bool? = nil,
        extras: [String: Any] = [:]
    ) {
        self.sessionToken = sessionToken
        self.apiBaseUrl = apiBaseUrl
        self.orderTotalCents = orderTotalCents
        self.merchandiseSubtotalCents = merchandiseSubtotalCents
        self.taxCents = taxCents
        self.shippingCents = shippingCents
        self.direction = direction
        self.lockTargetToBrand = lockTargetToBrand
        self.extras = extras
    }
}
