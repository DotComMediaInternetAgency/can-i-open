import SwiftUI

struct ReassignmentHistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Changes")
                        .font(.title2.weight(.semibold))
                    Text("History is kept in memory until you quit the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            if appState.reassignmentHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No Changes Yet")
                        .font(.headline)
                    Text("Completed reassignments will appear here.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.reassignmentHistory) { entry in
                    HistoryEntryRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
        .frame(width: 600, height: 480)
    }
}

private struct HistoryEntryRow: View {
    @EnvironmentObject var appState: AppState
    let entry: ReassignmentHistoryEntry

    private var targetName: String { appState.appName(for: entry.targetBundleID) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.isUndone ? "arrow.uturn.backward.circle" : "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(entry.isUndone ? Color.secondary : Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text("Set default app to \(targetName)")
                    .fontWeight(.medium)
                Text("\(entry.succeededTypes.count) changed · \(entry.failedTypes.count) failed · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if entry.typesWithoutPreviousHandler > 0 {
                    Text("\(entry.typesWithoutPreviousHandler) type(s) had no previous default and can’t be restored by Undo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !entry.failedTypes.isEmpty {
                    Text("Failed: \(entry.failedTypes.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 8)

            if entry.isUndone {
                Label("Undone", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if entry.previousHandlers.isEmpty {
                Text("Can’t undo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Undo") {
                    appState.undoReassignment(id: entry.id)
                }
                .disabled(appState.isReassigning)
            }
        }
        .padding(.vertical, 5)
    }
}
