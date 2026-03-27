import SwiftUI

enum Theme {
    // MARK: - Colors
    static let colors = ColorTokens.self

    // MARK: - Spacing
    static let spacing = SpacingTokens.self

    // MARK: - Typography
    static let typography = TypographyTokens.self

    // MARK: - Radius
    static let radius = RadiusTokens.self

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)

        /// Returns the animation if reduceMotion is disabled, nil otherwise
        static func respecting(reduceMotion: Bool, _ animation: SwiftUI.Animation) -> SwiftUI.Animation? {
            reduceMotion ? nil : animation
        }
    }

    // MARK: - Shadows
    enum Shadow {
        static let small = SwiftUI.Color.black.opacity(0.1)
        static let medium = SwiftUI.Color.black.opacity(0.15)
        static let large = SwiftUI.Color.black.opacity(0.2)
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.spacing.md)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius.md))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
