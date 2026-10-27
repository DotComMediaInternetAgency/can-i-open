# Development Workflow and Coding Standards

## Scope and source of truth

`AGENTS.md` contains the short rules every code contributor must follow. This page explains how to apply them. `CLAUDE.md` contains the broader Mycelium product-development workflow; its required review of corrections, guardrails, active diamonds, and domain context remains in effect.

When a change reveals a missing or ambiguous rule, update this page or the relevant page in `docs/`, then link to it from `docs/README.md`. Do not copy the same detailed rule into multiple documents; link to its canonical location.

## Before changing code

- Identify the user outcome and keep the change to the smallest complete slice.
- Inspect nearby code and existing patterns before introducing a new abstraction or dependency.
- Check whether a behavior change affects global file associations, Accessibility permissions, persistence, privacy, or the minimum supported macOS version.
- For changes to user-visible behavior, describe the expected behavior and failure/empty states before implementation.
- Read the correction log and required Mycelium context listed in `AGENTS.md` and `CLAUDE.md`.

## Swift and SwiftUI conventions

- Follow Swift API Design Guidelines: names should communicate purpose, types should express domain concepts, and Boolean properties should read naturally as conditions.
- Use `struct` for value models and SwiftUI views. Use reference types only where identity or shared mutable state is needed.
- Keep types and members narrowly scoped. Prefer `private` for implementation details and avoid broad global state.
- Keep async work off the main actor when it performs filesystem scanning or other expensive work. Return results to the main-actor-owned UI state before publishing changes.
- Keep views declarative. Move discovery, association mutation, and other operating-system behavior into services or app state.
- Keep user-facing names distinct from system identifiers. Display names to people; retain bundle IDs and UTIs for stable identity.
- Avoid force unwraps and silent error swallowing for operations a user depends on. Handle failures and give the user a useful next step.
- Avoid adding third-party packages unless the platform SDK cannot reasonably provide the needed capability.

## File and component boundaries

- `Sources/App.swift`: app lifecycle, shared state creation, and window setup.
- `Sources/Models/`: app and file-type data plus app-level observable state.
- `Sources/Services/`: LaunchServices queries, app discovery, association writes, dialog assistance, and system change monitoring.
- `Sources/Views/`: presentation and user interaction only.
- `Resources/`: app assets packaged by `Makefile`.

Use the existing structure for small changes. Add a file when a type has a clear responsibility and placing it in an existing file would obscure that responsibility. Update `docs/ARCHITECTURE.md` when responsibilities or important data flow change.

## Build and local installation

- Use `make debug` for a debug build assembled into `.build/Can I Open.app` and launched for interactive development.
- Use `make build` for a release build assembled into the same app bundle without launching it.
- To replace the local `/Applications` installation for manual verification, quit Can I Open first, then copy the built bundle with `ditto ".build/Can I Open.app" "/Applications/Can I Open.app"`. This requires write access to `/Applications`. Verify the installed signature and version as described in `docs/TESTING.md`.
- Do not treat a successful build as an install. Report the actual bundle path that was built or installed.

## Change safety

Changing a default app changes macOS behavior outside this process. Every association write must be traceable to a user action and clearly identify the selected target and affected types. Preserve prior handlers when a workflow offers undo. Report successes and failures accurately, including partial completion. Never use tests or previews that mutate real associations without an explicit, isolated test strategy.

Use `NSWorkspace.setDefaultApplication(at:toOpen:)` for new assignments. Undo may use the deprecated role-specific LaunchServices setter only after the user confirms restoration, because the modern setter cannot independently restore editor and viewer roles. An absent prior role cannot currently be cleared back to empty.

Accessibility automation must remain optional and narrowly scoped. Request only the permission needed, target only a dialog that can be positively associated with the selected app, and leave ambiguous dialogs for the user.

## Documentation and review

Update the relevant documentation when changing:

- setup, build commands, supported macOS versions, or packaging;
- app behavior, data retention, permissions, or system integration;
- architecture boundaries or state/data flow;
- UI patterns or accessibility behavior.

Before handing off, inspect `git diff --check` and `git diff`, run the relevant validation from `docs/TESTING.md`, and summarize behavior changes, validation, and any known limitations.
