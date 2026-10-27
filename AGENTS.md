# Can I Open — Developer Instructions

These instructions apply to all code changes in this repository. Read them before editing. The project-specific standards below are the source of truth for implementation; `CLAUDE.md` supplies the broader Mycelium workflow and should be followed where it does not conflict with these app-specific rules.

## Start Here

1. Read `docs/DEVELOPMENT.md` for the change workflow and coding conventions.
2. Read the relevant sections of `docs/ARCHITECTURE.md` and `docs/USER_INTERFACE.md` before changing app behavior or UI.
3. Read `docs/TESTING.md` and run the applicable validation after changing code.
4. Review `.claude/memory/corrections.md`, `.claude/harness/guardrails.md`, and `.claude/diamonds/active.yml` as required by `CLAUDE.md`.
5. Keep documentation and behavior aligned. Update `README.md` or the relevant `docs/` page when user-visible behavior, setup, architecture, or development workflow changes.

## Project Rules

- Build a native macOS app using Swift, SwiftUI, AppKit, LaunchServices, and UniformTypeIdentifiers. Preserve the macOS 13 deployment target unless a deliberate, documented decision changes it.
- Keep presentation in `Sources/Views`, app/domain state in `Sources/Models`, and operating-system integration in `Sources/Services`. Avoid moving code across these boundaries without a clear reason.
- Use the existing `AppState` as the shared observable state owner. Put reusable association and discovery behavior in `FileTypeService`, not in view bodies.
- Do not use `@EnvironmentObject` inside SwiftUI `Table` or `List` row/cell subviews. Resolve values in the parent and pass concrete values into row views.
- Keep all user-visible text clear, consistent, and action-oriented. Use native macOS controls and established app patterns before adding custom styling.
- Keep the native About panel and its centered credits consistent: distinguish the original author/project from the fork maintainer and retain clickable links to both repositories.
- Association changes affect macOS-wide user settings. Explain the target and scope before applying changes, preserve prior editor and viewer assignments separately for Undo, report partial failures, and never add automatic writes or destructive behavior without explicit user action.
- Use the deprecated role-specific LaunchServices setter only for an explicitly confirmed Undo restoration; use the modern `NSWorkspace` API for new default-app assignments. Document that roles previously empty cannot be cleared back to empty.
- App-to-app bulk reassignment should start only with types currently defaulted to the source app. Preselect types the target app declares as handlers, flag unsupported types, and recheck source ownership before writing to avoid stale changes. Roles that had no previous app cannot currently be restored to an empty state.
- Auto-confirm is opt-in and permission-dependent. Keep it scoped to the expected app/dialog, fail closed when the target cannot be verified, and explain when macOS may still ask the user.
- Do not add telemetry, network requests, or persistence of user/system data without an explicit product decision and privacy review. Reassignment history is currently in memory only.
- Do not add dependencies or architectural abstractions without a concrete need.

## Validation

For a code change, run `git diff --check` and the applicable commands in `docs/TESTING.md`. At minimum, run `make build` for changes that affect compilation or app packaging. Do not claim a test or manual check that was not performed. If validation cannot run, state the reason and remaining risk.

Before finishing, review the diff for unintended changes, verify documentation links and commands, and report the changes and validation performed.
