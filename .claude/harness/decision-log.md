# Decision Log

Record of significant decisions made during product development. Decisions are immutable once logged -- if a decision is reversed, log a new entry that references the original.

## Format

```
### [DATE] - [SHORT TITLE]
- **Diamond**: [ID, scale, phase]
- **Decision**: What was decided.
- **Alternatives considered**: What other options were evaluated and why they were rejected.
- **Theory**: Which framework/theory informed this decision (e.g., "Cynefin - Complex domain", "Cagan - Four Risks").
- **Evidence**: What data or research supports this decision.
- **Confidence**: [0.0-1.0] How confident are we, and what would change this.
- **Reversibility**: [easily reversible | costly to reverse | irreversible]
```

## Decisions

### 2026-04-07 - Complete L0 Purpose and spawn L2 Opportunity
- **Diamond**: l0-purpose, L0, discover->complete (fast-tracked)
- **Decision**: Progress L0 Purpose to complete in a single session. Skip L1 Strategy (solo_hobby project). Spawn L2 Opportunity diamond to begin scoping what to build.
- **Alternatives considered**: (1) Progress L0 phase-by-phase over multiple sessions -- rejected, purpose is clear and validated. (2) Run L1 Strategy diamond -- rejected per canvas-guidance.yml, solo_hobby projects skip strategic portfolio management.
- **Theory**: Torres (evidence-based progression), canvas-guidance.yml (solo_hobby skip L1)
- **Evidence**: Founder interview + web research validating pain across Apple Forums, MacRumors, GitHub (duti ~1800 stars, utiluti new in 2025). API feasibility confirmed (LaunchServices non-deprecated). No modern GUI solution exists.
- **Confidence**: 0.8 -- adapted from 0.9 threshold for solo_hobby. Would increase with external user testing.
- **Reversibility**: easily reversible

### 2026-04-07 - MVP scope: Dashboard + App view + Bulk reassign
- **Diamond**: l2-opportunity-file-associations, L2, define
- **Decision**: MVP (v0.1) includes three ideas: association dashboard, app-centric view, and bulk reassign. Snapshot/restore shelved for v0.2.
- **Alternatives considered**: (1) Dashboard-only MVP (read-only) -- rejected, the write side is the primary value proposition even with dialog constraint. (2) Include snapshot/restore in v0.1 -- rejected, restore depends on solving bulk-write UX first; premature.
- **Theory**: Gilad (ICE scoring, evidence-guided), YAGNI (defer snapshot until bulk-write UX is proven)
- **Evidence**: ICE scores: Dashboard 8.0, App view 7.3, Bulk reassign 6.7, Snapshot 5.7. Read-side APIs spike-validated. Write-side works with dialog constraint.
- **Confidence**: 0.6 -- ideas scored, APIs tested, but no user-facing prototype yet.
- **Reversibility**: easily reversible

### 2026-04-07 - Direct distribution over App Store
- **Diamond**: l2-opportunity-file-associations, L2, discover
- **Decision**: Target direct distribution (non-sandboxed) as primary distribution method. App Store version as a future possibility with reduced features.
- **Alternatives considered**: (1) App Store first -- rejected, sandbox restricts app enumeration and lsregister access, limiting core functionality. (2) Both simultaneously -- rejected, premature complexity for solo hobby.
- **Theory**: Cagan (feasibility risk), YAGNI
- **Evidence**: API research shows sandboxed apps cannot enumerate installed apps or use lsregister for full type discovery. Direct distribution with notarization provides full API access.
- **Confidence**: 0.7 -- needs hands-on testing to confirm sandbox limitations.
- **Reversibility**: easily reversible


### 2026-10-27 - Use a single default-app reassignment action
- **Diamond**: l2-opportunity-file-associations, L3, deliver
- **Decision**: Present one “Set Default App” action. Keep editor and viewer handler details visible in the inspector, while the write action changes the default app association.
- **Alternatives considered**: Keep separate editor/viewer write controls; rejected because the supported modern `NSWorkspace` API sets a default app per content type without an editor/viewer role parameter.
- **Theory**: Four Risks - reduce usability and technical risks by matching the control label to the API behavior.
- **Evidence**: Apple `NSWorkspace.setDefaultApplication(at:toOpen:)` documentation describes a default app for opening files of a content type.
- **Confidence**: 0.9
- **Reversibility**: easily reversible
