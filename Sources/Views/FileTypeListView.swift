import SwiftUI

struct FileTypeListView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\FileTypeInfo.displayName)]

    private var sortedFileTypes: [FileTypeInfo] {
        appState.filteredFileTypes.sorted(using: sortOrder)
    }

    private var selectedFileType: FileTypeInfo? {
        appState.fileTypes.first { appState.selectedFileTypes.contains($0.id) }
    }

    var body: some View {
        if sortedFileTypes.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No matching file types")
                    .font(.headline)
                Text("Try a different search or filter.")
                    .foregroundStyle(.secondary)
                Button("Clear Search and Filters") {
                    appState.searchText = ""
                    appState.fileTypeFilter = .all
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
        HSplitView {
            Table(sortedFileTypes, selection: $appState.selectedFileTypes, sortOrder: $sortOrder) {
                TableColumn("Extension", value: \.displayName) { fileType in
                    Text(fileType.displayName)
                        .fontWeight(.medium)
                }
                .width(min: 80, ideal: 105)

                TableColumn("Description", value: \.description) { fileType in
                    Text(fileType.description.isEmpty ? "Unknown type" : fileType.description)
                        .foregroundStyle(fileType.description.isEmpty ? .tertiary : .secondary)
                        .lineLimit(1)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Default App", value: \.defaultAppName) { fileType in
                    AppLabel(
                        name: fileType.defaultAppName,
                        icon: appState.appIcon(for: fileType.defaultAppBundleID)
                    )
                }
                .width(min: 100, ideal: 145)

                TableColumn("Handlers", value: \.handlerCount) { fileType in
                    Text("\(fileType.handlerCount)")
                        .foregroundStyle(.secondary)
                }
                .width(60)
            }
            .frame(minWidth: 460, idealWidth: 660)
            .contextMenu(forSelectionType: String.self) { selection in
                if !selection.isEmpty {
                    ContextMenuContent(selectedUTIs: selection)
                }
            }

            if let selectedFileType {
                FileTypeInspector(fileType: selectedFileType)
                    .environmentObject(appState)
                    .frame(minWidth: 280, idealWidth: 340)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Select a file type")
                        .font(.headline)
                    Text("See its handlers and type identifier.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        }
    }
}

private struct FileTypeInspector: View {
    @EnvironmentObject var appState: AppState
    let fileType: FileTypeInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(fileType.displayName)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)
                    Text(fileType.description.isEmpty ? "Unknown file type" : fileType.description)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Default app") {
                    AppLabel(
                        name: fileType.defaultAppName,
                        icon: appState.appIcon(for: fileType.defaultAppBundleID)
                    )
                }
                LabeledContent("Default editor") {
                    AppLabel(name: fileType.defaultEditorName, icon: appState.appIcon(for: fileType.defaultEditor))
                }
                LabeledContent("Default viewer") {
                    AppLabel(name: fileType.defaultViewerName, icon: appState.appIcon(for: fileType.defaultViewer))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Compatible apps")
                        .font(.headline)
                    if fileType.allHandlers.isEmpty {
                        Text("No registered handlers")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fileType.allHandlers.sorted(by: {
                            appState.appName(for: $0).localizedCaseInsensitiveCompare(appState.appName(for: $1)) == .orderedAscending
                        }), id: \.self) { bundleID in
                            AppLabel(name: appState.appName(for: bundleID), icon: appState.appIcon(for: bundleID))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Type identifier")
                        .font(.headline)
                    Text(fileType.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ContextMenuContent: View {
    let selectedUTIs: Set<String>
    @EnvironmentObject var appState: AppState

    var body: some View {
        Text("\(selectedUTIs.count) file type(s) selected")
            .foregroundStyle(.secondary)
        Divider()

        let handlers = appState.commonHandlers(for: selectedUTIs)
        if handlers.isEmpty {
            Text("No common handlers")
                .foregroundStyle(.secondary)
        } else {
            Menu("Set Default App to…") {
                ForEach(handlers, id: \.self) { bundleID in
                    Button(appState.appName(for: bundleID)) {
                        appState.selectedFileTypes = selectedUTIs
                        appState.reassignSelectedTypes(to: bundleID)
                    }
                }
            }
        }
    }
}
