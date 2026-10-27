# Release and Distribution

## Release flow

Releases are built by [`.github/workflows/release.yml`](../.github/workflows/release.yml) when a `v*` tag is pushed. The workflow:

1. Checks that the tag version matches `VERSION` in the Makefile.
2. Builds the app on native Apple Silicon (`arm64`) and Intel (`x86_64`) GitHub-hosted macOS runners.
3. Verifies each app bundle's code signature and packages it in a drag-to-Applications DMG.
4. Uploads each DMG and its SHA-256 checksum to a draft GitHub Release.
5. Publishes the release only after both architecture builds and uploads succeed.

The release stays as a draft if any build fails. Fix the issue and rerun the failed workflow before publishing it.

## Publishing a version

1. Update `VERSION` in the Makefile and make sure the change is on `main`.
2. Run `make build` and validate the local app as described in [`TESTING.md`](TESTING.md).
3. Create and push the matching version tag from `main`:

   ```sh
   git switch main
   git pull --ff-only
   git tag -a v0.2.0 -m "Can I Open 0.2.0"
   git push origin v0.2.0
   ```

   Replace `0.2.0` with the new `VERSION`. Push the source commit to the repository before pushing its tag. Use a new version tag for every release; published versions are immutable.
4. Watch the GitHub Actions run. The draft release is published automatically after both DMGs and checksums are attached.
5. Verify the release page contains arm64 and x86_64 DMGs and matching `.sha256` files. Confirm the release notes, installation steps, and download links before announcing it.

## Signing and Gatekeeper

Current builds are ad-hoc signed by the Makefile and are not notarized. They are suitable for source builds and early testing, but macOS may require a person to review and explicitly allow the downloaded app under **System Settings > Privacy & Security**. The installer must never instruct users to disable Gatekeeper or remove the quarantine attribute.

For a smooth public download experience, sign with a **Developer ID Application** certificate, enable the hardened runtime as needed, submit the signed app to Apple's notary service, and staple the ticket before packaging the DMG. Never use a developer's unrelated/local code-signing identity for the public release. Store any distribution credentials as narrowly scoped GitHub Actions secrets and do not commit them.

## Asset names

- `Can-I-Open-vX.Y.Z-arm64.dmg` — Apple Silicon Macs
- `Can-I-Open-vX.Y.Z-x86_64.dmg` — Intel Macs
- Matching `.sha256` files — integrity checks for each disk image

The architecture-specific DMGs are built on matching native runners. Do not describe them as universal binaries.
