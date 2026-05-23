# Contributing

Thanks for wanting to help with Crate.

Crate is a native macOS app, so the bar is not just "it compiles." Changes should preserve interaction quality, browsing performance, and the local-first library model.

## Setup

```bash
git clone <repo-url> crate
cd crate
./script/verify.sh
./script/build_and_run.sh
```

## Development Guidelines

- Keep Crate local-first. Do not add network calls, telemetry, cloud sync, or AI services without a very explicit design discussion.
- Keep imported assets out of the repo. Crate copies user-owned assets into a managed library outside source control.
- Prefer native macOS and SwiftUI APIs.
- Keep files small and named by responsibility.
- Avoid broad refactors in feature PRs.
- Add or update CLI support when a workflow should also be available to agents or scripts.
- Preserve the app's visual polish. Generic utility-app sludge is not the goal.

## Verification

Run:

```bash
./script/verify.sh
```

This includes `swift build`, `swift test`, CLI help, and the sample-pack smoke test.

For app launch verification:

```bash
./script/build_and_run.sh --verify
```

For packaging verification:

```bash
./script/package_app.sh --verify
```

## Pull Request Shape

Good PRs should include:

- What changed
- Why it changed
- How it was verified
- Screenshots or screen recordings for visible UI changes
- Notes about any library/database migration behavior

## Asset Licensing

Do not submit third-party asset packs, generated libraries, imported files, thumbnails, or exports. Crate is the browser; the user's assets stay theirs.
