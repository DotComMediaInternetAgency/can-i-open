import SwiftUI

enum ViewMode: String, CaseIterable {
    case fileTypes = "File Types"
    case apps = "Apps"
}
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var viewMode: ViewMode = .fileTypes
    @State private var showingHistory = false

    var body: some View {
        VStack(spacing: 0) {
            if viewMode == .fileTypes && !appState.selectedFileTypes.isEmpty {
                HStack {
                    Label("\(appState.selectedFileTypes.count) selected", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ReassignButton()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider()
            }

            if appState.isReassigning {
                ReassignProgressBanner()
                Divider()
            } else if let result = appState.latestOperationResult {
                OperationResultBanner(result: result)
                Divider()
            }

            if appState.isLoading {
                VStack {
                    ProgressView("Scanning installed apps and file types...")
                        .padding()
                    Spacer()
                }
            } else if let loadError = appState.loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Couldn’t load applications")
                        .font(.headline)
                    Text(loadError)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                    Button("Try Again") { appState.loadData() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewMode {
                case .fileTypes:
                    FileTypeListView()
                case .apps:
                    AppListView()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if viewMode == .fileTypes {
                    FileTypeFilterMenu()
                }

                Button {
                    appState.loadData()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Rescan installed apps and file types")
                .disabled(appState.isLoading || appState.isReassigning)

                Button {
                    showingHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .help("View recent changes and undo a reassignment")

                AutoConfirmToggle()
            }
        }
        .searchable(text: $appState.searchText, placement: .toolbar, prompt: "Search file types or apps")
        .sheet(isPresented: $showingHistory) {
            ReassignmentHistoryView()
        }
    }
}

struct FileTypeFilterMenu: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Menu {
            Picker("Show", selection: $appState.fileTypeFilter) {
                ForEach(FileTypeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
        .help("Filter file types")
    }
}

struct AutoConfirmToggle: View {
    @EnvironmentObject var appState: AppState
    @State private var showPermissionAlert = false

    var body: some View {
        Button {
            if appState.autoConfirmEnabled {
                appState.autoConfirmEnabled = false
            } else if DialogAutoConfirm.testPermission() {
                appState.autoConfirmEnabled = true
            } else {
                showPermissionAlert = true
            }
        } label: {
            Image(systemName: appState.autoConfirmEnabled ? "bolt.fill" : "bolt.slash")
                .foregroundStyle(appState.autoConfirmEnabled ? .orange : .secondary)
        }
        .accessibilityLabel("Auto-confirm dialogs")
        .accessibilityValue(appState.autoConfirmEnabled ? "On" : "Off")
        .help(appState.autoConfirmEnabled
              ? "Auto-confirm is ON -- click to turn off"
              : "Auto-confirm is OFF -- click to enable")
        .alert("Accessibility Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add \"Can I Open\" to System Settings > Privacy & Security > Accessibility, then try again.")
        }
    }
}

struct OperationResultBanner: View {
    let result: OperationResult
    @EnvironmentObject var appState: AppState
    @State private var showingErrors = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(result.errors.isEmpty ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .fontWeight(.medium)
                Text("\(result.successCount) of \(result.totalCount) types changed.")
                    .foregroundStyle(.secondary)
                if !result.errors.isEmpty {
                    DisclosureGroup("Show \(result.errors.count) failed changes", isExpanded: $showingErrors) {
                        ForEach(result.errors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                    .font(.caption)
                }
            }
            Spacer()
            Button("Dismiss") { appState.dismissLatestOperationResult() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(result.errors.isEmpty ? .green.opacity(0.06) : .orange.opacity(0.08))
    }
}

struct ReassignProgressBanner: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(
                value: Double(appState.reassignProgress),
                total: Double(max(appState.reassignTotal, 1))
            )
            .frame(width: 120)

            if appState.activeOperationUsesAutoConfirm {
                Label("Auto-confirming... \(appState.reassignProgress)/\(appState.reassignTotal)",
                      systemImage: "bolt.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else {
                Text("\(appState.activeOperationName)... \(appState.reassignProgress)/\(appState.reassignTotal)")
                    .font(.callout)
            }

            if !appState.reassignErrors.isEmpty {
                Label("\(appState.reassignErrors.count) failed", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.06))
    }
}
