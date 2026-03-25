import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ControlView()
                .tabItem {
                    Label("Control", systemImage: "figure.walk")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
