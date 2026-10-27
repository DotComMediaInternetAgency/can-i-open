import Foundation
import CoreServices
import UniformTypeIdentifiers
import AppKit

/// Queries macOS LaunchServices for file type associations and scans installed apps.
final class FileTypeService {

    // MARK: - Query Handlers

    func defaultHandler(for uti: String, role: LSRolesMask) -> String? {
        guard let result = LSCopyDefaultRoleHandlerForContentType(uti as CFString, role) else {
            return nil
        }
        return result.takeRetainedValue() as String
    }

    func allHandlers(for uti: String, role: LSRolesMask = .all) -> [String] {
        guard let result = LSCopyAllRoleHandlersForContentType(uti as CFString, role) else {
            return []
        }
        return result.takeRetainedValue() as? [String] ?? []
    }

    // MARK: - Set Handlers (Modern API)

    /// Set the default application for a UTType using the modern NSWorkspace API.
    /// The completion handler fires AFTER the user confirms the macOS dialog (if any).
    func setDefaultHandler(for uti: String, bundleID: String) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw SetHandlerError.appNotFound(bundleID)
        }
        guard let uttype = UTType(uti) else {
            throw SetHandlerError.invalidUTI(uti)
        }
        try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: uttype)
    }

    /// Restore a recorded editor or viewer role after the user explicitly chooses Undo.
    /// LaunchServices currently has no modern role-specific setter equivalent to NSWorkspace's API.
    func restoreDefaultHandler(for uti: String, bundleID: String, role: LSRolesMask) throws {
        let status = LSSetDefaultRoleHandlerForContentType(
            uti as CFString,
            role,
            bundleID as CFString
        )
        guard status == noErr else {
            throw SetHandlerError.roleRestoreFailed(uti, bundleID, status)
        }
    }

    enum SetHandlerError: LocalizedError {
        case appNotFound(String)
        case invalidUTI(String)
        case roleRestoreFailed(String, String, OSStatus)

        var errorDescription: String? {
            switch self {
            case .appNotFound(let id): return "App not found: \(id)"
            case .invalidUTI(let uti): return "Invalid UTI: \(uti)"
            case .roleRestoreFailed(let uti, let bundleID, let status):
                return "Could not restore \(bundleID) for \(uti) (LaunchServices error \(status))."
            }
        }
    }

    // MARK: - App Scanning

    func scanInstalledApps() -> [AppInfo] {
        let searchDirs: [String] = [
            "/Applications",
            "/System/Applications",
            NSSearchPathForDirectoriesInDomains(.applicationDirectory, .localDomainMask, true).first ?? "",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ].filter { !$0.isEmpty }

        var apps: [String: AppInfo] = [:]

        for dir in searchDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }

            for item in contents where item.hasSuffix(".app") {
                let appPath = "\(dir)/\(item)"
                if let appInfo = parseAppBundle(at: appPath) {
                    if let existing = apps[appInfo.id] {
                        if appInfo.claimedTypes.count > existing.claimedTypes.count {
                            apps[appInfo.id] = appInfo
                        }
                    } else {
                        apps[appInfo.id] = appInfo
                    }
                }
            }
        }

        return apps.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func discoverFileTypes(from apps: [AppInfo]) -> [FileTypeInfo] {
        var utiSet: Set<String> = []
        for app in apps {
            for claim in app.claimedTypes {
                if !claim.uti.isEmpty {
                    utiSet.insert(claim.uti)
                }
            }
        }

        let systemUTIs: [UTType] = [
            .plainText, .html, .json, .xml, .yaml,
            .png, .jpeg, .gif, .tiff, .bmp, .svg, .webP, .heic,
            .pdf, .rtf, .rtfd,
            .mp3, .mpeg4Audio, .wav, .aiff,
            .mpeg4Movie, .quickTimeMovie, .avi,
            .zip, .gzip, .bz2,
            .sourceCode, .swiftSource, .cSource, .cPlusPlusSource,
            .objectiveCSource, .assemblyLanguageSource,
            .shellScript, .pythonScript, .perlScript, .rubyScript,
            .javaScript,
            .propertyList, .xmlPropertyList, .binaryPropertyList,
            .commaSeparatedText, .tabSeparatedText,
        ]
        for uttype in systemUTIs {
            utiSet.insert(uttype.identifier)
        }

        var fileTypes: [FileTypeInfo] = []
        for uti in utiSet {
            let uttype = UTType(uti)
            let extensions: [String]
            if let uttype = uttype {
                extensions = uttype.tags[.filenameExtension] ?? []
            } else {
                extensions = []
            }

            let description = uttype?.localizedDescription ?? ""
            let viewer = defaultHandler(for: uti, role: .viewer)
            let editor = defaultHandler(for: uti, role: .editor)
            let handlers = allHandlers(for: uti)

            if handlers.isEmpty && extensions.isEmpty { continue }

            fileTypes.append(FileTypeInfo(
                id: uti,
                extensions: extensions,
                description: description,
                defaultViewer: viewer,
                defaultEditor: editor,
                allHandlers: handlers
            ))
        }

        return fileTypes.sorted { a, b in
            let aExt = a.extensions.first ?? a.id
            let bExt = b.extensions.first ?? b.id
            return aExt.localizedCaseInsensitiveCompare(bExt) == .orderedAscending
        }
    }

    // MARK: - Private

    private func parseAppBundle(at path: String) -> AppInfo? {
        let plistPath = "\(path)/Contents/Info.plist"
        guard let plist = NSDictionary(contentsOfFile: plistPath) else { return nil }
        guard let bundleID = plist["CFBundleIdentifier"] as? String else { return nil }

        let displayName = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        var claimedTypes: [AppInfo.ClaimedType] = []

        if let docTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]] {
            for docType in docTypes {
                let typeName = docType["CFBundleTypeName"] as? String ?? ""
                let extensions = docType["CFBundleTypeExtensions"] as? [String] ?? []
                let contentTypes = docType["LSItemContentTypes"] as? [String] ?? []

                if !contentTypes.isEmpty {
                    for uti in contentTypes {
                        claimedTypes.append(AppInfo.ClaimedType(
                            uti: uti,
                            extensions: extensions,
                            name: typeName
                        ))
                    }
                } else if !extensions.isEmpty {
                    for ext in extensions {
                        if let uttype = UTType(filenameExtension: ext) {
                            claimedTypes.append(AppInfo.ClaimedType(
                                uti: uttype.identifier,
                                extensions: [ext],
                                name: typeName
                            ))
                        }
                    }
                }
            }
        }

        let icon = NSWorkspace.shared.icon(forFile: path)

        return AppInfo(
            id: bundleID,
            name: displayName,
            path: path,
            claimedTypes: claimedTypes,
            icon: icon
        )
    }
}
