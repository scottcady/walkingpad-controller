import Foundation

enum RadiusTokens {
    /// 4pt - Subtle rounding
    static let xs: CGFloat = 4

    /// 8pt - Light rounding
    static let sm: CGFloat = 8

    /// 12pt - Standard rounding
    static let md: CGFloat = 12

    /// 16pt - Pronounced rounding
    static let lg: CGFloat = 16

    /// 24pt - Heavy rounding
    static let xl: CGFloat = 24

    /// Full circle (use with equal width/height)
    static let full: CGFloat = .infinity
}
