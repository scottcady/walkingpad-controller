import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WalkingSession.startTime, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<WalkingSession>

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.spacing.lg) {
            Spacer()

            Image(systemName: "figure.walk")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.textSecondary)

            Text("No Sessions Yet")
                .font(Theme.typography.title)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Complete your first walking session\nto see it here")
                .font(Theme.typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(Theme.spacing.xl)
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            ForEach(sessions) { session in
                SessionRow(
                    date: session.startTime ?? Date(),
                    durationSeconds: Int(session.durationSeconds),
                    distanceKm: session.distanceKm,
                    steps: Int(session.steps),
                    syncedToHealth: session.syncedToHealth
                )
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func deleteSessions(at offsets: IndexSet) {
        withAnimation(Theme.Animation.respecting(reduceMotion: reduceMotion, .default)) {
            offsets.map { sessions[$0] }.forEach(viewContext.delete)
            PersistenceController.shared.save()
        }
    }
}

#Preview {
    HistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
