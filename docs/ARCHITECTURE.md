# Architecture

## Product boundary

Can I Open is a native, non-sandboxed macOS utility for inspecting and changing file-type default applications. It reads app bundle declarations and LaunchServices associations. When the user requests a change, it asks `NSWorkspace` to set a default app and macOS may ask the user to confirm. The app does not currently send data over the network or persist reassignment history across launches.

## Layers

```text
SwiftUI Views
    ↓ user intent / displayed state
AppState (@MainActor)
    ↓ query and mutation requests
FileTypeService ── LaunchServices / NSWorkspace / UTType / app bundles
LaunchServicesMonitor ── detects association database changes
DialogAutoConfirm ── optional Accessibility UI automation
```

### App entry point

`Sources/App.swift` owns the `AppState` lifetime, injects it into the root view, and configures the main window.

### Models and state

- `AppInfo` is an installed app identified by bundle ID and includes the file types it declares.
- `FileTypeInfo` represents a UTI and its extensions, display description, handlers, and default editor/viewer.
- `AppState` owns observable UI state, search/filter results, current selection, operation progress/results, and in-memory reassignment history.
- `ReassignmentHistoryEntry` records a completed batch and the previous editor and viewer handler separately for each type. History is lost on quit. Undo restores non-empty prior roles with LaunchServices' role-specific setter; roles that were previously empty cannot currently be cleared back to empty.

`AppState` is main-actor isolated. Expensive scans should run away from the UI actor; publish the finished snapshot back through `AppState`.

### Services

- `FileTypeService` discovers app bundles, derives supported UTI information, reads LaunchServices handlers, and changes the default app through `NSWorkspace`.
- `LaunchServicesMonitor` watches for association database changes and asks the app to refresh handler state.
- `DialogAutoConfirm` uses Accessibility APIs to press a confirmation button only when the dialog can be tied to the expected target app. It is optional and controlled by the user.

Services should not own view state. Views should not call LaunchServices or Accessibility APIs directly.

## Key data flows

### Initial load

1. The app creates one `AppState` and starts `loadData()` when the main view appears.
2. `FileTypeService` scans known Applications folders and parses app bundle document declarations.
3. It combines app-declared UTIs with a curated set of common system UTIs, then reads extensions, descriptions, and registered handlers.
4. `AppState` resolves bundle IDs to display names, publishes the app/type snapshot, reconciles selection, and starts the monitor.
5. Views derive filtered/sorted presentations from the published state.

### Reassignment

1. The user selects one or more types and chooses a target app, either from File Types or from **Change Defaults…** on an app.
2. The app-centric flow starts with types where the source app is currently the editor or viewer. It preselects types the target app declares as handlers, labels unsupported types, and lets the user explicitly include them if desired. Types merely claimed by the source app are not changed automatically.
3. The UI previews the scope and asks for confirmation before the operation.
4. `AppState` snapshots both current role handlers separately and calls the service sequentially for each UTI. For app-centric changes it verifies the source still owns the type before applying.
5. The service resolves the target bundle ID to an app URL and UTI, then calls `NSWorkspace.setDefaultApplication(at:toOpen:)`.
6. The operation records per-type success/failure, presents a result, and refreshes handler state.
7. A successful batch is stored in session-only history. After an explicit confirmation, Undo attempts to restore each recorded editor/viewer role and reports failures.

The modern API sets the default app for opening a content type. Do not describe it as independently setting an editor or viewer role. The app may display editor/viewer values reported by LaunchServices, but the reassignment action is named “Set Default App.” Undo uses LaunchServices' deprecated role-specific setter because there is no current modern API to restore editor and viewer roles independently. Keep that use isolated to explicit Undo and revisit it if Apple provides a supported replacement.

### Refresh

The file monitor debounces association database updates and refreshes current handlers without repeating a full app-bundle scan. Manual refresh uses the app's refresh action.

## System and privacy boundaries

- App discovery reads bundle metadata from Applications directories.
- Association reads use LaunchServices; writes use `NSWorkspace` and may prompt the person at the OS level.
- Auto-confirm uses Accessibility only after the user enables it and grants permission.
- No account, cloud service, telemetry, or cross-launch operation history is part of the current app.
- Keep bundle IDs and UTIs as identifiers; resolve names/icons only for presentation.

When adding persistence, telemetry, network access, or broader Accessibility automation, reassess privacy, consent, error reporting, and threat model before implementation.
