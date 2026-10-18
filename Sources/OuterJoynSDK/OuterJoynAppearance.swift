import SwiftUI

/// Stripe-inspired appearance configuration for OuterJoyn SDK widgets.
///
/// Maps 1:1 to CSS custom properties injected into the WebView content.
/// Set on the SDK via `OuterJoynSDK.configure(appearance:)`.
public struct OuterJoynAppearance {
    public var colors = Colors()
    public var typography = Typography()
    public var shapes = Shapes()

    public init() {}

    public struct Colors {
        /// Primary brand color (slider fills, CTA buttons)
        public var primary: Color = .init(hex: "#6B21A8")
        /// Accent color (highlights, secondary actions)
        public var accent: Color = .init(hex: "#A855F7")
        /// Widget background
        public var background: Color = Color(.systemBackground)
        /// Card/surface background
        public var surface: Color = Color(.secondarySystemBackground)
        /// Primary text color
        public var text: Color = Color(.label)
        /// Secondary/muted text
        public var textMuted: Color = Color(.secondaryLabel)
        /// Border color
        public var border: Color = Color(.separator)
        /// Success state (checkmarks, applied badges)
        public var success: Color = .init(hex: "#16A34A")
        /// Error state
        public var error: Color = .init(hex: "#DC2626")
        /// Slider track fill (per-program — overridden by brand_color)
        public var sliderFill: Color = .init(hex: "#6B21A8")
        /// Slider track background
        public var sliderTrack: Color = Color(.systemGray5)

        public init() {}
    }

    public struct Typography {
        /// Body text font
        public var body: Font = .body
        /// Headline font
        public var headline: Font = .headline
        /// Caption font
        public var caption: Font = .caption
        /// Custom font family name (nil = system font)
        public var fontFamily: String? = nil

        public init() {}
    }

    public struct Shapes {
        /// Corner radius for cards and buttons
        public var cornerRadius: CGFloat = 12
        /// Border width
        public var borderWidth: CGFloat = 1
        /// Shadow radius
        public var shadowRadius: CGFloat = 4

        public init() {}
    }

    /// Convert appearance to CSS custom properties for WebView injection.
    func toCSSVariables() -> String {
        var vars: [String] = []
        vars.append("--oj-primary: \(colors.primary.hex)")
        vars.append("--oj-accent: \(colors.accent.hex)")
        vars.append("--oj-bg: \(colors.background.hex)")
        vars.append("--oj-surface: \(colors.surface.hex)")
        vars.append("--oj-text: \(colors.text.hex)")
        vars.append("--oj-text-muted: \(colors.textMuted.hex)")
        vars.append("--oj-border: \(colors.border.hex)")
        vars.append("--oj-success: \(colors.success.hex)")
        vars.append("--oj-error: \(colors.error.hex)")
        vars.append("--oj-radius: \(Int(shapes.cornerRadius))px")
        if let font = typography.fontFamily {
            vars.append("--oj-font-family: '\(font)', system-ui, sans-serif")
        }
        return vars.map { "\($0);" }.joined(separator: "\n")
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    var hex: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        let uiColor = UIColor(self)
        let resolved = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
