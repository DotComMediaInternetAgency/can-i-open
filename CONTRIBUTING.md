# Contributing

Thanks for helping improve Can I Open. Before making a change, read [`AGENTS.md`](AGENTS.md) and the relevant guides in [`docs/`](docs/README.md).

## Local development

Requirements: macOS 13 or later and a Swift toolchain that can build the package. The recommended commands are:

```sh
make debug
make build
```

See [`docs/TESTING.md`](docs/TESTING.md) for validation expectations and the current test setup.

## Pull requests

Keep changes focused and use a clear imperative summary. Include:

- what user-visible behavior changed and why;
- relevant screenshots for meaningful UI changes;
- validation commands actually run;
- any remaining limitations, especially for Accessibility permission or global file-association behavior;
- documentation updates for changed setup, behavior, architecture, or workflow.

Do not include generated `.build` output, user data, credentials, or unrelated formatting changes. Association-changing validation must use an isolated environment or have explicit approval.
