# Releasing Crate

Crate can be packaged locally from SwiftPM into a `.app` bundle and zip.

## Local Package

```bash
./script/package_app.sh --verify
```

Install into `/Applications`:

```bash
./script/package_app.sh --install --verify
```

## Environment Variables

```bash
CRATE_BUNDLE_ID="com.example.crate" ./script/package_app.sh
CRATE_CODESIGN_IDENTITY="Apple Development: Your Name (...)" ./script/package_app.sh
CRATE_VERSION="0.1.0" CRATE_BUILD="42" ./script/package_app.sh
```

If no signing identity is available, the script falls back to ad-hoc signing.

## Gatekeeper

Local/ad-hoc signing is fine for development and personal use. Public distribution should use Developer ID signing and notarization. Otherwise users may see Gatekeeper warnings when opening the downloaded app.

## Release Checklist

1. Run `./script/verify.sh --package`.
2. Run `./script/build_and_run.sh --verify`.
3. Update `CHANGELOG.md`.
4. Package with `CRATE_VERSION` and `CRATE_BUILD`.
5. Sign/notarize for public distribution.
6. Attach the zip to the GitHub release.
