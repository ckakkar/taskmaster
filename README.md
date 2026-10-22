# Taskmaster

**A little company. A little mischief.**

A native Mac desktop companion starring Miso, a fluffy red panda with small
paws and a considerable personality. Choose peaceful company, a curious
playmate, or a lovable menace. Pick Miso up, give it a treat, throw a ball,
or let it quietly fall asleep beside your work.

Built with Swift, AppKit, SwiftUI and SpriteKit. macOS 14 or newer.

## Meet Miso

- **Cozy, Playful, Chaos.** Three personalities and a continuous mischief slider
  change roaming, naps, pointer curiosity and little surprises.
- **Pick up and put down.** Drag the panda around your screen, release it, and
  watch it fall and land. Click to pet; double-click to open its room.
- **A panda that notices you.** Miso follows a nearby pointer with its eyes,
  leans its head, blinks, flicks its ears and swishes its tail. Gently move over
  its fur to pet it. Playful and Chaos moods investigate a wiggling cursor;
  Cozy stays peaceful. The companion room responds to your cursor too.
- **Little rituals.** Treats bring happy reactions and crumbs. Petting brings
  hearts. Play creates a ball you can pick up and throw; Miso chases and bats it.
- **A little chaos.** The panda brings silly notes and leaves temporary
  pawprints. Its props belong to the app; your documents stay out of the game.
- **A calm companion room.** Change personality, name, size and sound effects,
  or settle the panda down with one click.
- **A home in the menu bar.** Right-click Miso or use the paw icon for controls,
  hiding, pausing and quitting. Closing the room leaves Miso on your desktop.
- **Considerate by default.** Sound starts off. The overlay passes clicks
  through transparent areas, does not take keyboard focus, follows Reduce
  Motion, and sleeps when the display does. Idle naps are optional.
- **Local.** No account, backend, API key or runtime network connection.

The character uses nine original generated poses, with a soft deformation rig,
animated eyes, breathing, pose transitions, reactions, particles and physics.
This is a first playable version;
window-top perching, additional species and longer animation sequences are
future work.

## Build and run

Requires macOS 14+, Swift 6+, and the Xcode Command Line Tools or Xcode.
There are no third-party package dependencies.

```sh
make run     # build and open build/Taskmaster.app
make check   # behavior tests plus compilation of the native app
make app     # create the release app bundle
make dmg     # package build/Taskmaster.dmg
make clean   # remove generated build products
```

The build uses the Mac's current architecture and ad-hoc signs the local app.
It is not notarized. Distribution signing and automatic updates are not set up.

For debugging without a bundle, `make build` then run
`.build/debug/Taskmaster`. `--quiet` opens only the desktop pet and menu-bar
controls. `--self-check` verifies that all nine character textures load.

## Preferences

Settings are stored in
`~/Library/Application Support/Taskmaster/preferences.json`. To use isolated
state while developing, set `TASKMASTER_STATE_DIR` to a directory in this repo:

```sh
TASKMASTER_STATE_DIR="$PWD/.local" .build/debug/Taskmaster
```

No Accessibility, camera, microphone or screen-recording permission is
required for the implemented features. The app does not read window contents,
type, move files or control other applications.

## Project layout

```text
Sources/CompanionCore/       Deterministic behavior, preferences and toy physics
Sources/Taskmaster/          Desktop overlay, rendering, room and menu bar
Sources/Taskmaster/Resources Original transparent character atlas
Tests/CompanionCoreTests/   Long-session, recovery and interaction tests
Resources/                  Application metadata
scripts/                    Local app and DMG packaging
docs/                       Character art provenance and design decisions
```

`CompanionCore` has no UI dependencies. Behavior tests run without operating
the desktop. On-screen interaction and multiple-display behavior require a
real Mac session; a passing unit test is not a substitute for trying the app.

## Character art

The red panda is original artwork generated for this project using imagegen.
The atlas and exact production prompt are documented in
[docs/CHARACTER-ART.md](docs/CHARACTER-ART.md). Desktop Goose is an inspiration;
its code and assets are not included.
