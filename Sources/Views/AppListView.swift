import SwiftUI

struct AppListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedAppID: String?

    var filteredApps: [AppInfo] {
        let apps = appState.appsByClaimCount
        guard !appState.searchText.isEmpty else { return apps }
        let query = appState.searchText.lowercased()
        return apps.filter { app in
            app.name.lowercased().contains(query)
            || app.id.lowercased().contains(query)
            || app.claimedTypes.contains { claim in
                claim.extensions.contains { $0.lowercased().contains(query) }
                || claim.name.lowercased().contains(query)
            }
        }
    }

    var selectedApp: AppInfo? {
        guard let id = selectedAppID else { return nil }
        return appState.installedApps.first { $0.id == id }
    }

    var body: some View {
        HSplitView {
            List(filteredApps, selection: $selectedAppID) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .fontWeight(.medium)
                        Text("\(Set(app.claimedTypes.map(\.uti)).count) types claimed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .tag(app.id)
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 350)

            if let app = selectedApp {
                AppDetailView(app: app)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select an app to see its claimed file types")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// A claimed type row for the detail table and app-to-app reassignment review.
struct ClaimedTypeRow: Identifiable {
    let id: String  // UTI
    let extensions: String
    let typeName: String
    let isDefaultEditor: Bool
    let isDefaultViewer: Bool
    let currentEditorName: String
    let currentViewerName: String

    var isCurrentDefault: Bool { isDefaultEditor || isDefaultViewer }
}

struct AppDetailView: View {
    let app: AppInfo
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator<ClaimedTypeRow>(\.extensions)]
    @State private var showingChangeDefaults = false

    var claimedTypeRows: [ClaimedTypeRow] {
        let claimsByUTI = Dictionary(grouping: app.claimedTypes, by: \.uti)
        return claimsByUTI.keys.sorted().map { uti in
            let claims = claimsByUTI[uti] ?? []
            let fileType = appState.fileTypes.first { $0.id == uti }
            let extensions = Set(claims.flatMap(\.extensions))
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .map { ".\($0)" }
                .joined(separator: ", ")
            let typeName = claims.first(where: { !$0.name.isEmpty })?.name ?? ""

            return ClaimedTypeRow(
                id: uti,
                extensions: extensions,
                typeName: typeName,
                isDefaultEditor: fileType?.defaultEditor == app.id,
                isDefaultViewer: fileType?.defaultViewer == app.id,
                currentEditorName: fileType?.defaultEditorName ?? "None",
                currentViewerName: fileType?.defaultViewerName ?? "None"
            )
        }
        .sorted(using: sortOrder)
    }

    private var defaultEditorCount: Int {
        claimedTypeRows.filter(\.isDefaultEditor).count
    }

    private var currentDefaultCount: Int {
        claimedTypeRows.filter(\.isCurrentDefault).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(app.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(claimedTypeRows.count) types claimed · \(currentDefaultCount) currently default · \(defaultEditorCount) default editor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingChangeDefaults = true
                } label: {
                    Label("Change Defaults…", systemImage: "arrow.left.arrow.right")
                }
                .disabled(currentDefaultCount == 0 || appState.isReassigning)
                .help("Choose another app for the types currently opened by \(app.name)")
            }
            .padding()

            Divider()

            Table(claimedTypeRows, sortOrder: $sortOrder) {
                TableColumn("Extension", value: \.extensions) { item in
                    Text(item.extensions.isEmpty ? item.id : item.extensions)
                        .fontWeight(.medium)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Type Name", value: \.typeName) { item in
                    Text(item.typeName.isEmpty ? "Unknown type" : item.typeName)
                        .foregroundStyle(item.typeName.isEmpty ? .tertiary : .secondary)
                }
                .width(min: 100, ideal: 160)

                TableColumn("Default Editor", value: \.currentEditorName) { item in
                    if item.isDefaultEditor {
                        Label("This app", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text(item.currentEditorName)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 100, ideal: 140)

                TableColumn("Default Viewer", value: \.currentViewerName) { item in
                    if item.isDefaultViewer {
                        Label("This app", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text(item.currentViewerName)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 100, ideal: 140)

                TableColumn("UTI", value: \.id) { item in
                    Text(item.id)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .width(min: 120, ideal: 200)
            }
        }
        .sheet(isPresented: $showingChangeDefaults) {
            ChangeAppDefaultsSheet(sourceApp: app, claimedRows: claimedTypeRows)
        }
    }
}

private struct ChangeAppDefaultsSheet: View {
    let sourceApp: AppInfo
    let claimedRows: [ClaimedTypeRow]

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var appSearchText = ""
    @State private var selectedTargetID: String?
    @State private var selectedUTIs: Set<String> = []
    @State private var showingConfirmation = false

    private var currentDefaultRows: [ClaimedTypeRow] {
        claimedRows.filter(\.isCurrentDefault)
    }

    private var targetApps: [AppInfo] {
        appState.installedApps
            .filter { $0.id != sourceApp.id }
            .filter { app in
                appSearchText.isEmpty
                    || app.name.localizedCaseInsensitiveContains(appSearchText)
                    || app.id.localizedCaseInsensitiveContains(appSearchText)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedTarget: AppInfo? {
        guard let selectedTargetID else { return nil }
        return appState.installedApps.first { $0.id == selectedTargetID }
    }

    private var supportedCurrentDefaults: Set<String> {
        supportedCurrentDefaults(for: selectedTargetID)
    }

    private var selectedUnsupportedCount: Int {
        selectedUTIs.subtracting(supportedCurrentDefaults).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Change defaults from \(sourceApp.name)")
                    .font(.title2.weight(.semibold))
                Text("Only types currently opened by \(sourceApp.name) are included. Other types it claims won’t be changed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextField("Search for a target app", text: $appSearchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search target apps")

            List(targetApps, selection: $selectedTargetID) { app in
                AppPickerRow(app: app)
                    .tag(app.id)
            }
            .listStyle(.bordered)
            .frame(height: 140)
            .onChange(of: selectedTargetID) { targetID in
                selectedUTIs = supportedCurrentDefaults(for: targetID)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current defaults (\(currentDefaultRows.count))")
                        .font(.headline)
                    Text("Select the types you want to open with the target app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Supported Types") {
                        selectedUTIs = supportedCurrentDefaults
                    }
                    .disabled(supportedCurrentDefaults.isEmpty)
                    Button("All Current Defaults") {
                        selectedUTIs = Set(currentDefaultRows.map(\.id))
                    }
                    Button("Clear Selection") {
                        selectedUTIs.removeAll()
                    }
                    .disabled(selectedUTIs.isEmpty)
                } label: {
                    Label("Select", systemImage: "checklist")
                }
                .disabled(selectedTargetID == nil)
                .help("Choose supported types, all current defaults, or clear the selection")
            }

            if currentDefaultRows.isEmpty {
                emptyState(
                    title: "No Current Defaults",
                    message: "\(sourceApp.name) claims file types, but none are currently assigned to it."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTarget == nil {
                emptyState(
                    title: "Choose a Target App",
                    message: "Select the app that should open these file types."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(currentDefaultRows) { row in
                        let targetSupportsType = supportedCurrentDefaults.contains(row.id)
                        Toggle(isOn: selectionBinding(for: row.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(row.extensions.isEmpty ? row.id : row.extensions)
                                        .fontWeight(.medium)
                                    if !targetSupportsType {
                                        Label("Not listed as a handler", systemImage: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Text(typeDetail(for: row))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .help(targetSupportsType
                              ? "This app is registered to handle this type."
                              : "This target app is not registered for this type. macOS may refuse the change or the app may not open it.")
                    }
                }
                .listStyle(.inset)
            }

            HStack(spacing: 8) {
                Image(systemName: appState.autoConfirmEnabled ? "bolt.fill" : "info.circle")
                    .foregroundStyle(appState.autoConfirmEnabled ? .orange : .secondary)
                Text(appState.autoConfirmEnabled
                     ? "Auto-confirm is on. macOS may still request consent for each type."
                     : "macOS may ask you to confirm each type change. Auto-confirm is optional.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("\(selectedUTIs.count) selected · \(selectedUTIs.count - selectedUnsupportedCount) supported · \(selectedUnsupportedCount) unsupported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Review Changes…") { showingConfirmation = true }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedTarget == nil || selectedUTIs.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 720, height: 700)
        .confirmationDialog("Change file type defaults?", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Change \(selectedUTIs.count) Defaults") {
                guard let selectedTarget else { return }
                appState.reassignTypes(
                    Array(selectedUTIs),
                    from: sourceApp.id,
                    to: selectedTarget.id
                )
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }

    private var confirmationMessage: String {
        var message = "\(selectedUTIs.count) selected file types currently opened by \(sourceApp.name) will be assigned to \(selectedTarget?.name ?? "the target app"). macOS may ask you to confirm the changes."
        if selectedUnsupportedCount > 0 {
            message += " \(selectedUnsupportedCount) selected type(s) are not listed as supported by the target; macOS may refuse those changes or the app may not open those files."
        }
        return message
    }

    private func supportedCurrentDefaults(for targetID: String?) -> Set<String> {
        guard let targetID else { return [] }
        return Set(currentDefaultRows.compactMap { row in
            guard let fileType = appState.fileTypes.first(where: { $0.id == row.id }),
                  fileType.allHandlers.contains(targetID) else { return nil }
            return row.id
        })
    }

    private func selectionBinding(for uti: String) -> Binding<Bool> {
        Binding(
            get: { selectedUTIs.contains(uti) },
            set: { isSelected in
                if isSelected {
                    selectedUTIs.insert(uti)
                } else {
                    selectedUTIs.remove(uti)
                }
            }
        )
    }

    private func typeDetail(for row: ClaimedTypeRow) -> String {
        let roles = [
            row.isDefaultEditor ? "editor" : nil,
            row.isDefaultViewer ? "viewer" : nil
        ].compactMap { $0 }.joined(separator: " and ")
        let name = row.typeName.isEmpty ? "Unknown type" : row.typeName
        return "\(name) · current default for \(roles)"
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
