import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: Theme.spacing.lg) {
            Image(systemName: "figure.walk")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.accent)

            Text("WalkingPad Controller")
                .font(Theme.typography.title)

            Text("Phase 1 Complete")
                .font(Theme.typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(Theme.spacing.xl)
    }
}

#Preview {
    ContentView()
}
