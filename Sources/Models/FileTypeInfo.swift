import Foundation
import UniformTypeIdentifiers

/// A file type (UTI) and its current handler assignments.
struct FileTypeInfo: Identifiable, Hashable {
    let id: String  // UTI identifier (e.g. "public.plain-text")
    let extensions: [String]
    let description: String
    var defaultViewer: String?  // bundle ID
    var defaultEditor: String?  // bundle ID
    var allHandlers: [String]   // all bundle IDs that can handle this type

    // Resolved names for display and sorting (populated by AppState)
    var defaultEditorName: String = "None"
    var defaultViewerName: String = "None"

    var displayName: String {
        if !extensions.isEmpty {
            return extensions.map { ".\($0)" }.joined(separator: ", ")
        }
        return description.isEmpty ? id : description
    }

    var handlerCount: Int { allHandlers.count }

    var defaultAppName: String {
        defaultViewer != nil ? defaultViewerName : defaultEditorName
    }

    var defaultAppBundleID: String? {
        defaultViewer ?? defaultEditor
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileTypeInfo, rhs: FileTypeInfo) -> Bool {
        lhs.id == rhs.id
    }
}
