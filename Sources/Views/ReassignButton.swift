import SwiftUI
import CoreServices

struct ReassignButton: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAppPicker = false

    var body: some View {
        Button {
            showingAppPicker = true
        } label: {
            Label("Set Default App…", systemImage: "arrow.right.circle")
        }
        .disabled(appState.isReassigning)
        .sheet(isPresented: $showingAppPicker) {
            ReassignSheet()
        }
    }
}

struct AppPickerEntry: Identifiable {
    let id: String
    let app: AppInfo
    let isRecommended: Bool
}

struct ReassignSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedAppID: String?
    @State private var searchText = ""
    @State private var showingConfirmation = false

    var recommendedAppIDs: Set<String> {
        Set(appState.commonHandlers(for: appState.selectedFileTypes))
    }

    var recommendedApps: [AppPickerEntry] {
        let rec = recommendedAppIDs
        return appState.installedApps
            .filter { rec.contains($0.id) }
            .filter { matchesSearch($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { AppPickerEntry(id: $0.id, app: $0, isRecommended: true) }
    }

    var otherApps: [AppPickerEntry] {
        let rec = recommendedAppIDs
        return appState.installedApps
            .filter { !rec.contains($0.id) }
            .filter { matchesSearch($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { AppPickerEntry(id: $0.id, app: $0, isRecommended: false) }
    }

    private func matchesSearch(_ app: AppInfo) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return app.name.lowercased().contains(query) || app.id.lowercased().contains(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a default app for \(appState.selectedFileTypes.count) file type(s)")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(appState.selectedFileTypes).sorted(), id: \.self) { uti in
                        if let ft = appState.fileTypes.first(where: { $0.id == uti }) {
                            Text(ft.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .frame(maxHeight: 30)

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            List(selection: $selectedAppID) {
                if !recommendedApps.isEmpty {
                    Section {
                        ForEach(recommendedApps) { entry in
                            AppPickerRow(app: entry.app)
                                .tag(entry.id)
                        }
                    } header: {
                        Label("Recommended", systemImage: "star.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }

                    Section {
                        ForEach(otherApps) { entry in
                            AppPickerRow(app: entry.app)
                                .tag(entry.id)
                        }
                    } header: {
                        Text("Other apps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(otherApps, id: \.id) { entry in
                        AppPickerRow(app: entry.app)
                            .tag(entry.id)
                    }
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 300)

            if let selectedAppID, let selectedApp = appState.installedApps.first(where: { $0.id == selectedAppID }) {
                Label("These types will open with \(selectedApp.name)", systemImage: "arrow.right.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }

            // Status hint
            if appState.autoConfirmEnabled {
                Label("Auto-confirm is on -- dialogs will be confirmed automatically",
                      systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Label("macOS will show a confirmation dialog for each file type",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Review Changes…") { showingConfirmation = true }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedAppID == nil)
            }
        }
        .padding()
        .frame(width: 520, height: 540)
        .confirmationDialog("Set the default app?", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Set Default App") {
                guard let targetApp = selectedAppID else { return }
                appState.reassignSelectedTypes(to: targetApp)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(appState.selectedFileTypes.count) selected file types will use \(selectedAppName). macOS may ask you to confirm the change.")
        }
    }

    private var selectedAppName: String {
        selectedAppID.map { appState.appName(for: $0) } ?? "the selected app"
    }
}

struct AppPickerRow: View {
    let app: AppInfo

    var body: some View {
        HStack(spacing: 8) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            VStack(alignment: .leading) {
                Text(app.name)
                Text(app.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
