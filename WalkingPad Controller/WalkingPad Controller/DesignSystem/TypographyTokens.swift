import SwiftUI

enum TypographyTokens {
    // MARK: - Large Title
    static let largeTitle = Font.largeTitle
    static let largeTitleBold = Font.largeTitle.bold()

    // MARK: - Title
    static let title = Font.title
    static let titleBold = Font.title.bold()

    static let title2 = Font.title2
    static let title2Bold = Font.title2.bold()

    static let title3 = Font.title3
    static let title3Bold = Font.title3.bold()

    // MARK: - Headline
    static let headline = Font.headline

    // MARK: - Body
    static let body = Font.body
    static let bodyBold = Font.body.bold()

    // MARK: - Callout
    static let callout = Font.callout
    static let calloutBold = Font.callout.bold()

    // MARK: - Subheadline
    static let subheadline = Font.subheadline
    static let subheadlineBold = Font.subheadline.bold()

    // MARK: - Footnote
    static let footnote = Font.footnote
    static let footnoteBold = Font.footnote.bold()

    // MARK: - Caption
    static let caption = Font.caption
    static let captionBold = Font.caption.bold()

    static let caption2 = Font.caption2
    static let caption2Bold = Font.caption2.bold()

    // MARK: - Monospaced (for metrics display)
    static let metricsLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let metricsMedium = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let metricsSmall = Font.system(size: 24, weight: .medium, design: .rounded)
}
