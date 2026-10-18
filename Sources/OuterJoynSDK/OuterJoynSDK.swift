import SwiftUI
import UIKit

/// OuterJoyn SDK — Native iOS integration for loyalty point widgets.
///
/// Presents loyalty widgets (Pay, Exchange, Redeem, Connect) in a native
/// bottom sheet with web content loaded from the OuterJoyn CDN.
///
/// ## Usage
/// ```swift
/// // Configure appearance
/// var appearance = OuterJoynAppearance()
/// appearance.colors.primary = .purple
/// OuterJoynSDK.shared.configure(appearance: appearance)
///
/// // Present a widget
/// OuterJoynSDK.shared.present(
///     .pay,
///     config: OuterJoynWidgetConfig(
///         sessionToken: "ojsdk_live_...",
///         orderTotalCents: 4999
///     ),
///     from: viewController
/// )
/// ```
public final class OuterJoynSDK {

    /// Shared singleton instance
    public static let shared = OuterJoynSDK()

    /// SDK version
    public static let version = "1.1.1"

    /// Current appearance configuration
    public private(set) var appearance = OuterJoynAppearance()

    /// Whether a widget is currently presented
    public private(set) var isPresenting = false

    private weak var presentedViewController: UIViewController?
    private var onDismiss: (() -> Void)?
    private lazy var dismissObserver = SheetDismissObserver { [weak self] in self?.didDismiss() }

    private init() {}

    // MARK: - Configuration

    /// Configure the SDK appearance. Call before presenting any widgets.
    public func configure(appearance: OuterJoynAppearance) {
        self.appearance = appearance
    }

    // MARK: - Presentation

    /// Present a widget in a bottom sheet.
    ///
    /// Uses UISheetPresentationController. Connect opens full height (its
    /// consent step is long); the other widgets also offer a medium detent.
    /// The widget content is loaded from sdk.outerjoyn.com CDN.
    ///
    /// - Parameters:
    ///   - widget: Which widget to present
    ///   - config: Widget configuration (session token, options)
    ///   - viewController: The presenting view controller
    ///   - onSuccess: Called when the widget action completes successfully
    ///   - onError: Called on error
    ///   - onDismiss: Called when the sheet is dismissed
    public func present(
        _ widget: OuterJoynWidget,
        config: OuterJoynWidgetConfig,
        from viewController: UIViewController,
        onSuccess: ((Any) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        guard !isPresenting else {
            print("[OuterJoynSDK] Widget already presenting. Dismiss first.")
            return
        }

        let webContent = OuterJoynWebContent(
            widget: widget,
            config: config,
            appearance: appearance,
            onSuccess: { result in
                onSuccess?(result)
                self.dismiss()
            },
            onClose: { self.dismiss() },
            onError: onError
        )

        let hostingController = UIHostingController(rootView: webContent)
        hostingController.modalPresentationStyle = .pageSheet
        hostingController.presentationController?.delegate = dismissObserver

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = widget.detents
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = appearance.shapes.cornerRadius + 8
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        isPresenting = true
        presentedViewController = hostingController
        self.onDismiss = onDismiss

        viewController.present(hostingController, animated: true) {
            // Sheet presented
        }
    }

    /// Dismiss the currently presented widget.
    public func dismiss() {
        presentedViewController?.dismiss(animated: true) {
            self.didDismiss()
        }
    }

    /// Runs for both a programmatic dismiss and a swipe-down, so a swiped-away
    /// sheet does not leave `isPresenting` stuck and refuse the next present.
    private func didDismiss() {
        guard isPresenting else { return }
        isPresenting = false
        presentedViewController = nil
        let callback = onDismiss
        onDismiss = nil
        callback?()
    }

    // MARK: - SwiftUI Modifier

    /// SwiftUI view modifier for presenting OuterJoyn widgets.
    ///
    /// ```swift
    /// Button("Pay with Points") { showPay = true }
    ///     .outerJoynSheet(
    ///         isPresented: $showPay,
    ///         widget: .pay,
    ///         config: config
    ///     )
    /// ```
    public struct SheetModifier: ViewModifier {
        @Binding var isPresented: Bool
        let widget: OuterJoynWidget
        let config: OuterJoynWidgetConfig
        let onSuccess: ((Any) -> Void)?
        let onDismiss: (() -> Void)?

        public func body(content: Content) -> some View {
            content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                OuterJoynWebContent(
                    widget: widget,
                    config: config,
                    appearance: OuterJoynSDK.shared.appearance,
                    onSuccess: { result in
                        onSuccess?(result)
                        isPresented = false
                    },
                    onClose: { isPresented = false },
                    onError: nil
                )
                .presentationDetents(widget.fillsSheet ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Present an OuterJoyn widget as a sheet.
    public func outerJoynSheet(
        isPresented: Binding<Bool>,
        widget: OuterJoynWidget,
        config: OuterJoynWidgetConfig,
        onSuccess: ((Any) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(OuterJoynSDK.SheetModifier(
            isPresented: isPresented,
            widget: widget,
            config: config,
            onSuccess: onSuccess,
            onDismiss: onDismiss
        ))
    }
}

private final class SheetDismissObserver: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
