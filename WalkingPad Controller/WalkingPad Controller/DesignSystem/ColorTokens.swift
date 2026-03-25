import SwiftUI

enum ColorTokens {
    // MARK: - Primary
    static let primary = Color("Primary", bundle: nil)
    static let primaryVariant = Color("PrimaryVariant", bundle: nil)

    // MARK: - Background
    static let background = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
    static let backgroundTertiary = Color(uiColor: .tertiarySystemBackground)

    // MARK: - Surface
    static let surface = Color(uiColor: .systemBackground)
    static let surfaceElevated = Color(uiColor: .secondarySystemBackground)

    // MARK: - Text
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    // MARK: - Semantic
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    // MARK: - Interactive
    static let accent = Color.accentColor
    static let disabled = Color(uiColor: .systemGray3)

    // MARK: - Dividers & Borders
    static let divider = Color(uiColor: .separator)
    static let border = Color(uiColor: .opaqueSeparator)
}
