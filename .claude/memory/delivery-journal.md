# Delivery Journal

Chronological log of implementation work, technical decisions, and engineering learnings.

## Format

```
### [DATE] - [TITLE]
- **Diamond**: [ID and phase]
- **Type**: [implementation | refactor | bugfix | infrastructure | learning]
- **Summary**: What was delivered and key decisions made.
- **Technical details**: Stack, patterns used, trade-offs.
- **Testing**: What was tested and coverage achieved.
- **Metrics impact**: Effect on DORA metrics or system health.
- **Lessons**: What to carry forward.
```

## Entries


### 2026-10-27 - Modernize association workflow and add undo history
- **Diamond**: l2-opportunity-file-associations, L3 deliver
- **Type**: implementation
- **Summary**: Added toolbar-based navigation and search, association filters, a clearer default-app inspector, scoped dialog auto-confirm, operation summaries, and session-only reassignment history with undo.
- **Technical details**: Reassignment history snapshots previous default handlers. Undo restores only associations that had a prior default; the history UI explains that unset defaults cannot be restored. Used the modern single default-app API semantics in the UI.
- **Testing**: `git diff --check` and release `make build` succeeded. Installed app signature verified and launched for an accessibility-tree UI check. Automated tests were not run.
- **Metrics impact**: Improves feedback and reversibility for bulk reassignment; no runtime metrics collected.
- **Lessons**: Preserve truthful operation labels when platform APIs don't expose the role implied by older UI labels.

### 2026-10-27 - Add bulk defaults from the Apps view
- **Diamond**: l3-solution-mvp, deliver
- **Type**: implementation
- **Summary**: Added a Change Defaults workflow to selected app details. It scopes candidates to types where the source app is currently a default, preselects target-supported types, labels unsupported types, and requires review before applying the batch.
- **Technical details**: The batch reuses `AppState` reassignment and revalidates source ownership before writing to avoid stale review. History now records editor and viewer handlers separately. Explicit Undo restores non-empty roles through LaunchServices' deprecated role setter because NSWorkspace's modern default-app API is not role-specific. Empty prior roles cannot be reset to empty.
- **Testing**: `git diff --check` and release `make build` succeeded. Verified the installed Apps flow with the Accessibility tree, including selecting all unsupported Music defaults and reviewing the warning; cancelled before applying. No automated tests or system association mutations were run. The build emitted two Command Line Tools linker search-path warnings.
- **Metrics impact**: Reduces per-type selection effort; no usage metrics collected.
- **Lessons**: App document claims and current defaults are different sets; bulk defaults should start from current ownership and make unsupported target types visible.
