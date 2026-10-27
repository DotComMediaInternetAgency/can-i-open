import Foundation

struct ReassignmentHistoryEntry: Identifiable {
    let id = UUID()
    let date: Date
    let targetBundleID: String
    let succeededTypes: [String]
    let failedTypes: [String]
    let previousHandlers: [String: String]
    let typesWithoutPreviousHandler: Int
    var isUndone = false
}

struct OperationResult: Identifiable {
    let id = UUID()
    let title: String
    let successCount: Int
    let totalCount: Int
    let errors: [String]
}
