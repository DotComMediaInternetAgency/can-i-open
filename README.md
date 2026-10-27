# Can I Open

A native macOS app for bulk file type association management.

Tired of apps hijacking your file type associations? **Can I Open** lets you see which apps claim which file types, and reassign them in bulk -- instead of the tedious one-at-a-time method via Finder's Get Info.

## The Problem

When you install apps like VS Code, Xcode, Adobe products, or VLC, they silently claim dozens of file types. Your carefully configured defaults get overwritten, and macOS gives you no way to fix them in bulk. The only built-in option is right-click > Get Info > Open With > Change All -- one file type at a time.

Existing tools that tried to solve this are either dead (RCDefaultApp), abandoned (duti), barely maintained (SwiftDefaultApps), or CLI-only (utiluti).

## Features

**File Types view** -- Browse all file types on your system in a sortable, searchable table. See the current default editor and viewer for each type, how many apps can handle it, and the underlying UTI.

**Apps view** -- Select an installed app to see every file type it claims. Quickly identify which types it currently owns as the default handler and which are handled by other apps.

**Bulk reassign** -- Select multiple file types, pick a target app, and reassign them all. The app shows recommended apps (those that can handle all selected types) at the top of the list.

**Recent changes** -- Review completed reassignment batches and undo them during the current app session when a previous default app was recorded. Changes are not saved after quitting the app. Types with no previous default app cannot be restored by Undo.

**Focused file type details** -- Keep the main table compact, then select a type to see its editor, viewer, compatible apps, and UTI. Filter for types without a default app or with multiple handlers.

**Auto-confirm** -- macOS 26.4+ shows a confirmation dialog for each file type change. Enable auto-confirm (bolt icon) to click through dialogs that mention the target app using the Accessibility API. Requires an Accessibility permission grant.

**Auto-refresh** -- The app monitors the LaunchServices database for changes. When you confirm a dialog or another app changes associations, the view updates automatically.

**Search** -- Filter by file extension, description, app name, or UTI. Search for "audio" to find all audio-related types, or "VS Code" to see everything VS Code handles.

## Requirements

- macOS 13 (Ventura) or later
- Non-sandboxed (distributed directly, not via App Store)
- For auto-confirm: Accessibility permission (System Settings > Privacy & Security > Accessibility)

## Build

```bash
# Clone
git clone https://github.com/DotComMediaInternetAgency/can-i-open.git
cd can-i-open

# Build and run (debug)
make debug

# Build release
make build
```

The app bundle is created at `.build/Can I Open.app`.

You can also open `Package.swift` in Xcode for GUI development.

## Auto-Confirm Setup

On macOS 26.4+, every file type reassignment triggers a macOS confirmation dialog. To automatically click through these:

1. Click the bolt icon in the toolbar
2. If prompted, add `Can I Open` to **System Settings > Privacy & Security > Accessibility**
   - In the file picker, press Cmd+Shift+G and enter the path to the `.app` bundle
3. The bolt icon turns orange when active

**Note for developers:** During development, the Accessibility permission may need to be re-toggled after each rebuild, as the binary hash changes. This is not an issue for release builds with stable code signing.

## How It Works

Can I Open uses macOS system APIs:

- **LaunchServices** (`LSCopyDefaultRoleHandlerForContentType`, `LSCopyAllRoleHandlersForContentType`) to query current file type associations
- **NSWorkspace** (`setDefaultApplication(at:toOpen:)`) to change associations via the modern async API
- **UniformTypeIdentifiers** for type identity and hierarchy
- **App bundle scanning** (`CFBundleDocumentTypes` in Info.plist) to discover which apps claim which types
- **AXUIElement** (Accessibility API) for auto-confirm functionality
- **DispatchSource file monitoring** on the LaunchServices plist for auto-refresh

## Project Structure

```
Sources/
  App.swift                         # SwiftUI app entry point
  Models/
    AppInfo.swift                   # Installed app data model
    AppState.swift                  # Central app state (ObservableObject)
    FileTypeInfo.swift              # File type/UTI data model
    ReassignmentHistoryEntry.swift  # Operation result and session history models
  Services/
    FileTypeService.swift           # LaunchServices API wrapper
    DialogAutoConfirm.swift         # AXUIElement auto-confirm
    LaunchServicesMonitor.swift     # File change monitoring
  Views/
    ContentView.swift               # Main view with toolbar
    FileTypeListView.swift          # Sortable file types table
    AppListView.swift               # App sidebar + detail table
    AppLabel.swift                  # App name + icon component
    ReassignButton.swift            # Reassign sheet
    ReassignmentHistoryView.swift   # Session-only change history and undo
```

## Developer Documentation

Contributor workflow and project standards are documented in [`CONTRIBUTING.md`](CONTRIBUTING.md), [`AGENTS.md`](AGENTS.md), and the [developer documentation index](docs/README.md). The guides cover architecture, UI/accessibility conventions, and build/testing expectations.

## License

MIT License. See [LICENSE](LICENSE).
