# Build and Testing

## Current project setup

The app is a Swift Package executable with no separate test target currently defined in `Package.swift`. The Makefile assembles the Swift executable into a macOS app bundle, copies the app icon, writes `Info.plist`, and applies an ad-hoc signature. Do not claim a unit/integration test suite exists until one is added.

## Validation commands

Run from the repository root:

```sh
# Check whitespace and patch formatting
git diff --check

# Build and launch the debug app bundle
make debug

# Build the release app bundle
make build

# Remove Swift package build output and the generated app bundle
make clean
```

`make debug` opens `.build/Can I Open.app`. `make build` creates `.build/Can I Open.app` without launching it. The Makefile prefers the installed macOS 26.5 SDK only when using standalone Command Line Tools and that SDK is present; otherwise it uses the selected toolchain's default SDK.

Use `swift test` only after a test target exists or for a focused package test run that is known to apply. Do not report it as meaningful validation while the package contains no tests.

## Expected checks by change

| Change | Required validation |
| --- | --- |
| Swift source, models, services, or views | `git diff --check`, `make build`; run relevant tests if available |
| Makefile, package manifest, app bundle metadata | `git diff --check`, `make build`; inspect the generated bundle's Info.plist and signature when packaging changes |
| UI interaction or layout | Build, then inspect affected screen at minimum window size; check keyboard/accessibility semantics for changed controls |
| LaunchServices writes or undo behavior | Unit-test extracted pure decision logic where possible; manual system-level checks only with an isolated test account or explicit user approval because these operations mutate global macOS settings. Verify a type with distinct editor/viewer apps and one with a missing role; never change real defaults without approval. |
| Auto-confirm / Accessibility | Build and inspect permission-denied, disabled, target-mismatch, and successful-dialog paths without clicking unrelated system dialogs |
| Documentation only | `git diff --check`; verify referenced paths, commands, and links |

## Testing principles

- Add tests alongside new pure logic and regression fixes. Keep LaunchServices and Accessibility boundaries behind services so decision logic can be tested without changing real user defaults.
- Prefer deterministic unit tests for filtering, selection reconciliation, operation summaries, history/undo eligibility, and other pure transformations.
- Keep any system integration check explicit and isolated. Never casually change the machine's real file associations during development validation.
- Test failure and partial-success behavior as well as the happy path. For user-facing flows include loading, empty, filtered-empty, permission-denied, and recovery states where relevant.
- Record exactly which checks ran and any environment limitations in the handoff or change description.
