# Releases

There is nothing to do by hand: every push to `main` that passes **Check** is released by
`.github/workflows/release.yml` as version `<major.minor>.<commits on main>`. The major.minor is
`CFBundleShortVersionString` in `Resources/Info.plist`; bump it there for a bigger step. Each release carries:

- a universal `Taskmaster.dmg`, whose window (`scripts/dmg-background.swift`, `scripts/dmg-settings.py`, laid out
  by [dmgbuild](https://github.com/dmgbuild/dmgbuild) in `.build/dmg-venv`) shows Taskmaster and Applications on
  a desk, with a trail of pawprints between them;
- `Taskmaster.zip`, the archive Sparkle installs;
- `appcast.xml`, the update feed, signed with the update key.

The release notes are the commit subjects since the previous release, so write them for people who use the app.
Installed copies check `releases/latest/download/appcast.xml` about 20 seconds after they open and then every
hour. An update found in the background puts a dot on the menu bar paw, an **Update to Taskmaster …** item at the
top of its menu and a note in the companion room; Sparkle's window, with the notes and **Install**, opens when you
click one (or by itself if the dot is ignored for a day). Users can switch automatic checks off in the room's
settings. Run the workflow by hand (Actions › Release › Run workflow) to rebuild the current commit if a release
failed.

To try the installer locally, `make dmg` builds the same universal app and disk image into `build/`.

## Keys

Run `scripts/release-keys.sh` once on the maintainer's Mac. It creates both keys and prints the `gh secret set`
commands.

- **Update key (Sparkle EdDSA).**
  - The public half is `Resources/SparklePublicKey.txt` (committed), which `scripts/build-app.sh` writes into the
    app. Without it the app's updater stays off, and **Check for Updates…** doesn't appear.
  - The private half is the `SPARKLE_PRIVATE_KEY` repository secret, with a backup in
    `~/.taskmaster/sparkle-private.key` and in the login keychain.
  - Keep that backup: without it no future update can be signed, and installed copies would need a manual
    reinstall.
  - Local builds carry the public key too and check for updates, but their build number (commits on your branch)
    is never behind a release of the same commit.
- **Signing certificate ("Taskmaster Self-Signed").**
  - Repository secrets `TASKMASTER_CERT_P12` (base64) and `TASKMASTER_CERT_PASSWORD`, with a backup in
    `~/.taskmaster/`.
  - Signing every release with the same certificate keeps the app's identity the same across updates, so
    anything macOS has granted it carries over. An ad-hoc signature changes with every build.
  - Import the `.p12` into your login keychain and `scripts/build-app.sh` uses it for local builds too.

## Apple code signing (optional)

Without an Apple Developer ID the app isn't notarized, so people click **Open Anyway** once (System Settings ›
Privacy & Security); the disk image's window says so. To sign with a Developer ID and notarize, add these
repository secrets; the release workflow picks them up when set:

- `APPLE_CERTIFICATE` (base64 .p12)
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY`
- `APPLE_ID`
- `APPLE_PASSWORD` (app-specific)
- `APPLE_TEAM_ID`
