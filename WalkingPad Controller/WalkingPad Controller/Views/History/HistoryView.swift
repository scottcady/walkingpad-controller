import SwiftUI

/// Placeholder view for session history.
/// Full implementation in Phase 7.
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing.lg) {
                Spacer()

                Image(systemName: "clock")
                    .font(.system(size: 64))
                    .foregroundStyle(ColorTokens.textSecondary)

                Text("Session History")
                    .font(Theme.typography.title)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Your walking sessions will appear here")
                    .font(Theme.typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)

                Spacer()
            }
            .padding(Theme.spacing.xl)
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
}
