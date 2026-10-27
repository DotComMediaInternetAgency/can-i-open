import Foundation

struct FileTypeHandlerAssignment {
    let editorBundleID: String?
    let viewerBundleID: String?

    var hasPreviousHandler: Bool {
        editorBundleID != nil || viewerBundleID != nil
    }

    var missingRoleCount: Int {
        (editorBundleID == nil ? 1 : 0) + (viewerBundleID == nil ? 1 : 0)
    }
}

struct ReassignmentHistoryEntry: Identifiable {
    let id = UUID()
    let date: Date
    let targetBundleID: String
    let sourceBundleID: String?
    let succeededTypes: [String]
    let failedTypes: [String]
    let previousAssignments: [String: FileTypeHandlerAssignment]
    var isUndone = false

    var restorableTypeCount: Int {
        previousAssignments.values.filter(\.hasPreviousHandler).count
    }

    var missingPreviousRoleCount: Int {
        previousAssignments.values.reduce(0) { $0 + $1.missingRoleCount }
    }
}

struct OperationResult: Identifiable {
    let id = UUID()
    let title: String
    let successCount: Int
    let totalCount: Int
    let errors: [String]
}
