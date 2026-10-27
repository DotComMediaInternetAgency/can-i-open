import Foundation
import SwiftUI
import CoreServices

enum FileTypeFilter: String, CaseIterable, Identifiable {
    case all = "All types"
    case noDefaultApp = "No default app"
    case multipleHandlers = "Multiple handlers"

    var id: String { rawValue }
}

@MainActor
final class AppState: ObservableObject {
    @Published var fileTypes: [FileTypeInfo] = []
    @Published var installedApps: [AppInfo] = []
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var searchText = ""
    @Published var selectedFileTypes: Set<String> = []
    @Published var fileTypeFilter: FileTypeFilter = .all

    // Reassignment state
    @Published var isReassigning = false
    @Published var reassignProgress: Int = 0
    @Published var reassignTotal: Int = 0
    @Published var reassignErrors: [String] = []
    @Published var activeOperationUsesAutoConfirm = false
    @Published var activeOperationName = "Applying changes"
    @Published var latestOperationResult: OperationResult?
    @Published var reassignmentHistory: [ReassignmentHistoryEntry] = []

    // Auto-confirm state
    @Published var autoConfirmEnabled = false {
        didSet { updateAutoConfirm() }
    }

    private nonisolated let service = FileTypeService()
    private var monitor: LaunchServicesMonitor?
    private let autoConfirm = DialogAutoConfirm()

    // Debounce timer for file monitoring refresh
    private var refreshDebounce: Task<Void, Never>?

    /// Filtered file types based on search text.
    var filteredFileTypes: [FileTypeInfo] {
        fileTypes.filter { fileType in
            let matchesFilter: Bool
            switch fileTypeFilter {
            case .all:
                matchesFilter = true
            case .noDefaultApp:
                matchesFilter = fileType.defaultViewer == nil && fileType.defaultEditor == nil
            case .multipleHandlers:
                matchesFilter = fileType.handlerCount > 1
            }

            guard matchesFilter, !searchText.isEmpty else { return matchesFilter }
            let query = searchText.lowercased()
            return fileType.extensions.contains { $0.lowercased().contains(query) }
                || fileType.description.lowercased().contains(query)
                || fileType.id.lowercased().contains(query)
                || fileType.defaultEditorName.lowercased().contains(query)
                || fileType.defaultViewerName.lowercased().contains(query)
        }
    }

    var appsByClaimCount: [AppInfo] {
        installedApps
            .filter { !$0.claimedTypes.isEmpty }
            .sorted { $0.claimedTypes.count > $1.claimedTypes.count }
    }

    func loadData() {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil

        Task {
            let apps = await Task.detached {
                self.service.scanInstalledApps()
            }.value

            var types = await Task.detached {
                self.service.discoverFileTypes(from: apps)
            }.value

            let appLookup = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0.name) })
            for i in types.indices {
                types[i].defaultEditorName = types[i].defaultEditor.flatMap { appLookup[$0] }
                    ?? types[i].defaultEditor?.components(separatedBy: ".").last?.capitalized
                    ?? "None"
                types[i].defaultViewerName = types[i].defaultViewer.flatMap { appLookup[$0] }
                    ?? types[i].defaultViewer?.components(separatedBy: ".").last?.capitalized
                    ?? "None"
            }

            self.installedApps = apps
            self.fileTypes = types
            self.selectedFileTypes.formIntersection(Set(types.map(\.id)))
            if apps.isEmpty {
                self.loadError = "No installed applications were found. Check that the Applications folders are accessible, then refresh."
            }
            self.isLoading = false

            // Start monitoring for changes
            startMonitoring()
        }
    }

    /// Refresh only the handler assignments (faster than full reload).
    func refreshHandlers() {
        Task {
            var updatedTypes = self.fileTypes
            let appLookup = Dictionary(uniqueKeysWithValues: installedApps.map { ($0.id, $0.name) })

            await Task.detached {
                for i in updatedTypes.indices {
                    let uti = updatedTypes[i].id
                    updatedTypes[i].defaultViewer = self.service.defaultHandler(for: uti, role: .viewer)
                    updatedTypes[i].defaultEditor = self.service.defaultHandler(for: uti, role: .editor)
                    updatedTypes[i].allHandlers = self.service.allHandlers(for: uti)

                    updatedTypes[i].defaultEditorName = updatedTypes[i].defaultEditor.flatMap { appLookup[$0] }
                        ?? updatedTypes[i].defaultEditor?.components(separatedBy: ".").last?.capitalized
                        ?? "None"
                    updatedTypes[i].defaultViewerName = updatedTypes[i].defaultViewer.flatMap { appLookup[$0] }
                        ?? updatedTypes[i].defaultViewer?.components(separatedBy: ".").last?.capitalized
                        ?? "None"
                }
            }.value

            self.fileTypes = updatedTypes
        }
    }

    func appName(for bundleID: String?) -> String {
        guard let bundleID else { return "None" }
        if let app = installedApps.first(where: { $0.id == bundleID }) {
            return app.name
        }
        return bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
    }

    func appIcon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        return installedApps.first(where: { $0.id == bundleID })?.icon
    }

    func commonHandlers(for utis: Set<String>) -> [String] {
        let types = utis.compactMap { uti in
            fileTypes.first { $0.id == uti }
        }
        guard let first = types.first else { return [] }
        var common = Set(first.allHandlers)
        for type in types.dropFirst() {
            common.formIntersection(type.allHandlers)
        }
        return common.sorted { a, b in
            appName(for: a).localizedCaseInsensitiveCompare(appName(for: b)) == .orderedAscending
        }
    }

    /// Reassign selected file types using the modern async NSWorkspace API.
    /// Each call awaits the user's dialog response before proceeding to the next.
    func reassignSelectedTypes(to targetBundleID: String) {
        reassignTypes(Array(selectedFileTypes), to: targetBundleID)
    }

    /// Reassign a specific batch. When a source app is supplied, only types it still owns as
    /// a viewer or editor are changed, protecting against stale review state.
    func reassignTypes(_ requestedUTIs: [String], from sourceBundleID: String? = nil, to targetBundleID: String) {
        let uniqueUTIs = Array(Set(requestedUTIs)).sorted()
        let utis = uniqueUTIs.filter { uti in
            guard let sourceBundleID else { return true }
            guard let fileType = fileTypes.first(where: { $0.id == uti }) else { return false }
            return fileType.defaultViewer == sourceBundleID || fileType.defaultEditor == sourceBundleID
        }
        let skippedUTIs = Set(uniqueUTIs).subtracting(utis)

        guard !isReassigning else { return }
        guard targetBundleID != sourceBundleID else { return }
        guard !utis.isEmpty else {
            latestOperationResult = OperationResult(
                title: "No changes made",
                successCount: 0,
                totalCount: uniqueUTIs.count,
                errors: ["The selected app is no longer the current default for these file types. Refresh and review the list again."]
            )
            return
        }

        isReassigning = true
        activeOperationName = "Setting defaults to \(appName(for: targetBundleID))"
        reassignProgress = 0
        reassignTotal = uniqueUTIs.count
        reassignErrors = []
        latestOperationResult = nil

        let staleTypeCount = uniqueUTIs.count - utis.count
        if staleTypeCount > 0 {
            reassignErrors.append("\(staleTypeCount) type(s) were skipped because \(appName(for: sourceBundleID)) is no longer the current default.")
        }

        let previousAssignments = Dictionary(uniqueKeysWithValues: utis.map { uti in
            let fileType = fileTypes.first { $0.id == uti }
            return (uti, FileTypeHandlerAssignment(
                editorBundleID: fileType?.defaultEditor,
                viewerBundleID: fileType?.defaultViewer
            ))
        })

        if autoConfirmEnabled {
            autoConfirm.start(expectedAppName: appName(for: targetBundleID))
        }
        activeOperationUsesAutoConfirm = autoConfirmEnabled

        Task {
            var succeededTypes: [String] = []
            var failedTypes = skippedUTIs.sorted()
            for uti in utis {
                do {
                    try await service.setDefaultHandler(for: uti, bundleID: targetBundleID)
                    succeededTypes.append(uti)
                } catch {
                    reassignErrors.append("\(uti): \(error.localizedDescription)")
                    failedTypes.append(uti)
                }
                reassignProgress += 1
            }
            reassignProgress += staleTypeCount

            autoConfirm.stop()
            activeOperationUsesAutoConfirm = false
            isReassigning = false

            if !succeededTypes.isEmpty {
                let successfulAssignments = previousAssignments.filter { succeededTypes.contains($0.key) }
                reassignmentHistory.insert(
                    ReassignmentHistoryEntry(
                        date: Date(),
                        targetBundleID: targetBundleID,
                        sourceBundleID: sourceBundleID,
                        succeededTypes: succeededTypes,
                        failedTypes: failedTypes,
                        previousAssignments: successfulAssignments
                    ),
                    at: 0
                )
            }

            latestOperationResult = OperationResult(
                title: "Reassignment finished",
                successCount: succeededTypes.count,
                totalCount: uniqueUTIs.count,
                errors: reassignErrors
            )

            try? await Task.sleep(for: .milliseconds(500))
            refreshHandlers()
        }
    }

    func undoReassignment(id: UUID) {
        guard !isReassigning,
              let index = reassignmentHistory.firstIndex(where: { $0.id == id }),
              !reassignmentHistory[index].isUndone,
              reassignmentHistory[index].restorableTypeCount > 0 else { return }

        let entry = reassignmentHistory[index]
        let assignmentsToRestore = entry.previousAssignments.filter { $0.value.hasPreviousHandler }
        isReassigning = true
        activeOperationName = "Restoring previous editor and viewer defaults"
        reassignProgress = 0
        reassignTotal = assignmentsToRestore.count
        reassignErrors = []
        activeOperationUsesAutoConfirm = false
        latestOperationResult = nil

        Task {
            var restoredCount = 0
            for uti in assignmentsToRestore.keys.sorted() {
                guard let assignment = assignmentsToRestore[uti] else { continue }
                var typeFailed = false

                if let editorBundleID = assignment.editorBundleID {
                    do {
                        try service.restoreDefaultHandler(for: uti, bundleID: editorBundleID, role: .editor)
                    } catch {
                        reassignErrors.append("\(uti) (editor): \(error.localizedDescription)")
                        typeFailed = true
                    }
                }
                if let viewerBundleID = assignment.viewerBundleID {
                    do {
                        try service.restoreDefaultHandler(for: uti, bundleID: viewerBundleID, role: .viewer)
                    } catch {
                        reassignErrors.append("\(uti) (viewer): \(error.localizedDescription)")
                        typeFailed = true
                    }
                }

                if !typeFailed { restoredCount += 1 }
                reassignProgress += 1
            }

            autoConfirm.stop()
            activeOperationUsesAutoConfirm = false
            isReassigning = false
            if reassignErrors.isEmpty {
                reassignmentHistory[index].isUndone = true
            }
            latestOperationResult = OperationResult(
                title: "Undo finished",
                successCount: restoredCount,
                totalCount: assignmentsToRestore.count,
                errors: reassignErrors
            )
            try? await Task.sleep(for: .milliseconds(500))
            refreshHandlers()
        }
    }

    func dismissLatestOperationResult() {
        latestOperationResult = nil
    }

    // MARK: - File Monitoring

    private func startMonitoring() {
        monitor?.stop()
        monitor = LaunchServicesMonitor { [weak self] in
            // Debounce: wait 1s after last change before refreshing
            self?.refreshDebounce?.cancel()
            self?.refreshDebounce = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.refreshHandlers()
            }
        }
        monitor?.start()
    }

    // MARK: - Auto-Confirm

    private func updateAutoConfirm() {
        if !autoConfirmEnabled {
            autoConfirm.stop()
        }
    }
}
