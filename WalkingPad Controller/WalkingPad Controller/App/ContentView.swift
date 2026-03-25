import SwiftUI

struct ContentView: View {
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing.lg) {
                Spacer()

                Image(systemName: "figure.walk")
                    .font(.system(size: 64))
                    .foregroundStyle(ColorTokens.accent)

                Text("WalkingPad Controller")
                    .font(Theme.typography.title)

                if let bridgeURL = SettingsService.shared.bridgeURL {
                    VStack(spacing: Theme.spacing.xs) {
                        Text("Bridge configured")
                            .font(Theme.typography.subheadline)
                            .foregroundStyle(ColorTokens.success)
                        Text(bridgeURL)
                            .font(Theme.typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                } else {
                    Text("Configure bridge URL in Settings")
                        .font(Theme.typography.subheadline)
                        .foregroundStyle(ColorTokens.warning)
                }

                Spacer()
            }
            .padding(Theme.spacing.xl)
            .navigationTitle("Control")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
