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
