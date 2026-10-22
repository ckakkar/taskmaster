# Repository Guidelines

## Structure and boundaries

- `Sources/CompanionCore/`: deterministic behavior, preferences, games, physics and scheduling. **Never import AppKit, SwiftUI, SpriteKit or other UI code here.**
- `Sources/Taskmaster/`: native macOS application, transparent overlay, rendering, customization and image library.
- `Sources/Taskmaster/Resources/`: character images and artwork metadata.
- `Tests/CompanionCoreTests/`: Swift Testing behavior and regression tests.
- `Tests/TaskmasterTests/`: native rendering, meme recovery and image-import tests.
- `Resources/`, `scripts/`: app metadata, icon generation and local packaging.
- `docs/`: architecture, art provenance, screenshots and handoff notes.

## Build and verification

Run from the repository root on macOS 14+ with Swift 6+:

```sh
make check # tests, native compilation and character resource self-check
make lint  # check Swift formatting
make run   # build and open build/Taskmaster.app
make app   # release app bundle
make dmg   # drag-and-drop installer
```

`--self-check` validates character textures and landmarks without starting the companion. Use `TASKMASTER_STATE_DIR="$PWD/.local" .build/debug/Taskmaster` for isolated development state. Never commit this directory or personal preferences/images.

## Style and tests

Use Swift naming conventions, descriptive feature names and the checked-in swift-format configuration. Keep simulation independent of wall-clock APIs: pass time and input explicitly. Group feature-specific engine behavior in extensions. Run `make format` after Swift edits.

Tests use `@Test` and describe observable behavior. Add regression coverage for bug fixes, including cancellation, legacy preferences and malformed input. Verify visible changes in the running Mac app; distinguish native checks from simulation tests in the handoff.

## Commits and pull requests

Use short, imperative subjects, for example `Fix focus cancellation`. Keep commits focused. PRs should explain behavior, link issues, include screenshots for visual changes, and report exact validation commands and limitations. Keep generated builds, caches, credentials and user state out of Git.
