import SwiftUI

struct SettingsView: View {
    @State private var bridgeURLText: String = ""
    @State private var validationError: String?
    @State private var showingSaveConfirmation = false
    @State private var connectionManager = ConnectionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let settings = SettingsService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Connection Type", selection: $connectionManager.connectionMode) {
                        ForEach(ConnectionMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Connection Mode")
                } footer: {
                    Text(connectionManager.connectionMode.description)
                }

                if connectionManager.connectionMode == .bridge {
                    Section {
                        TextField("http://192.168.1.100:8000", text: $bridgeURLText)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: bridgeURLText) { _, newValue in
                            // Clear validation error when user types
                            if validationError != nil {
                                validationError = nil
                            }
                        }

                    if let error = validationError {
                        Text(error)
                            .font(Theme.typography.caption)
                            .foregroundStyle(ColorTokens.error)
                    }
                } header: {
                    Text("Bridge URL")
                } footer: {
                    Text("Enter the URL of your WalkingPad bridge server running on your Mac. Include the port number (e.g., http://192.168.1.100:8000).")
                }

                    Section {
                        Button {
                            saveURL()
                        } label: {
                            HStack {
                                Text("Save")
                                Spacer()
                                if showingSaveConfirmation {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ColorTokens.success)
                                }
                            }
                        }
                        .disabled(bridgeURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    Section {
                        Text("No configuration needed for Bluetooth mode")
                            .font(Theme.typography.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                    } header: {
                        Text("Bluetooth Connection")
                    } footer: {
                        Text("Your iPhone will connect directly to the WalkingPad via Bluetooth.")
                    }
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadSavedURL()
            }
        }
    }

    // MARK: - Private Methods

    private func loadSavedURL() {
        bridgeURLText = settings.bridgeURL ?? ""
    }

    private func saveURL() {
        let trimmed = bridgeURLText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Allow saving empty string to clear the URL
        if trimmed.isEmpty {
            settings.bridgeURL = nil
            showSaveConfirmation()
            return
        }

        // Validate non-empty URL
        if let error = settings.validateBridgeURL(trimmed) {
            validationError = error
            return
        }

        // Normalize and save
        let normalized = settings.normalizeBridgeURL(trimmed)
        settings.bridgeURL = normalized
        bridgeURLText = normalized

        showSaveConfirmation()
    }

    private func showSaveConfirmation() {
        withAnimation(Theme.Animation.respecting(reduceMotion: reduceMotion, Theme.Animation.quick)) {
            showingSaveConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [reduceMotion] in
            withAnimation(Theme.Animation.respecting(reduceMotion: reduceMotion, Theme.Animation.quick)) {
                showingSaveConfirmation = false
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
