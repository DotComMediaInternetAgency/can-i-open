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
    @State private var showingUndoConfirmation = false
    let entry: ReassignmentHistoryEntry

    private var targetName: String { appState.appName(for: entry.targetBundleID) }

    private var operationTitle: String {
        if let sourceBundleID = entry.sourceBundleID {
            return "Change defaults from \(appState.appName(for: sourceBundleID)) to \(targetName)"
        }
        return "Set default app to \(targetName)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.isUndone ? "arrow.uturn.backward.circle" : "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(entry.isUndone ? Color.secondary : Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(operationTitle)
                    .fontWeight(.medium)
                Text("\(entry.succeededTypes.count) changed · \(entry.failedTypes.count) failed · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if entry.missingPreviousRoleCount > 0 {
                    Text("\(entry.missingPreviousRoleCount) editor/viewer role(s) had no previous app and can’t be restored to an empty state by Undo.")
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
                Label(entry.missingPreviousRoleCount > 0 ? "Restored with limits" : "Undone", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if entry.restorableTypeCount == 0 {
                Text("Can’t undo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Undo") {
                    showingUndoConfirmation = true
                }
                .disabled(appState.isReassigning)
            }
        }
        .padding(.vertical, 5)
        .confirmationDialog("Restore previous defaults?", isPresented: $showingUndoConfirmation, titleVisibility: .visible) {
            Button("Restore Previous Defaults") {
                appState.undoReassignment(id: entry.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restore the recorded editor and viewer defaults for up to \(entry.restorableTypeCount) file types.\(undoLimitMessage)")
        }
    }

    private var undoLimitMessage: String {
        guard entry.missingPreviousRoleCount > 0 else { return "" }
        return " \(entry.missingPreviousRoleCount) role(s) had no previous app and can’t be cleared back to empty."
    }
}
