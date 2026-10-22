<div align="center">
  <img src="Sources/Taskmaster/Resources/MisoHighFive.png" alt="Miso offers a tiny high five" width="180">

# Taskmaster

**A little company. A little mischief. A desktop with a heartbeat.**

A native Mac companion that notices your cursor, brings you memes,
keeps you company while you work, and occasionally commits a very small crime.

[![macOS](https://img.shields.io/badge/macOS-14%2B-333333?logo=apple)](#get-started)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](#under-the-fur)
[![Check](https://github.com/ckakkar/taskmaster/actions/workflows/check.yml/badge.svg)](https://github.com/ckakkar/taskmaster/actions/workflows/check.yml)

[Meet the companions](#meet-your-desk-mates) · [Make it yours](#your-kind-of-company) · [Build & run](#get-started) · [Handoff](docs/HANDOFF.md)

</div>

![The companion room, running on macOS](docs/media/room.jpg)

## Meet your desk mates

| Companion | Personality you can see | Their little specialty |
| --- | --- | --- |
| **Miso** | A fluffy red panda with curious eyes, a swishing tail, and questionable intentions. | Muddy zoomies, pawprint trails, and an optional cursor heist. Four coat tones and a tiny wardrobe. |
| **Toothless** | A miniature Night Fury with bright green eyes, ear fins, wings, and an unmistakable silhouette. | Full-screen **2D flight**, wing movement, blue spark trails, a glowing plasma toy, and airborne cursor following. |

Each has ten authored poses: standing, two walk steps, sitting, sleeping,
being carried, delight, a play bow, scheming, and a high five. Their shared
behavior includes petting, treats, naps, dragging, games, notes and deliveries.
Toothless lands gently before a ground activity or a quiet focus session.

Airborne companions pass clicks through to your windows. Use **Land gently**
before picking one up. Automatic flights are rare and have a three-minute
breather between starts; Cozy keeps them off. Explicit flights are always
available from the room. Toothless is a fan version of the existing character; Miso is an original
design. Both use painted sprite art.

## Your kind of company

### Peaceful, playful, or a lovable menace

Choose **Cozy**, **Playful**, or **Chaos**, then fine-tune the mischief slider.
A nearby cursor gets a glance, a head tilt, or an invitation to play. Gentle
strokes earn hearts; a raised paw is waiting for your high five.

Chaos can leave temporary pawprints, deliver silly notes, and borrow your
cursor for a quick getaway. Cursor heists start **off**. Enable them in
**Make it yours → Little crimes**; click or press Esc to end one.
They last at most 1½ seconds and pause during focus. Wipe the evidence with one click.

### A familiar face, with your sense of humor

Pick a companion, choose a name and size, and write your own sayings.
Use `{name}` wherever their name should appear. Mix in the original quips,
add a cozy or chaotic pack, or choose silence. Bubble colors and reading time
are adjustable too. Miso's coat, bandana, bow and bell can be styled separately.

![Choose a companion and customize its appearance](docs/media/wardrobe.jpg)

### Special delivery, from somewhere off-screen

Add your own images or paste a direct HTTPS image link. Your companion walks
out of view, pulls a card onto the desktop, leaves it for a while, and takes
it back. Keep a card for another 30 seconds, send it home early, or let occasional
deliveries happen on a schedule. Three original starter cards are included.

The stash holds up to 100 cards. Imports are copied, resized to at most 1600 pixels,
and stored locally; originals stay untouched. Files and downloads are limited
to 25 MB. Animated images use their first frame.

### A little focus, together

Start a 1–90 minute session. Your companion settles nearby while you work,
then offers a gentle stretch reminder. The countdown uses real time, including
when the pet is tucked away. Completed sessions are saved; an active timer
resets when the app quits.

## Get started

Requires **macOS 14+**, **Swift 6+**, and Xcode or the Xcode Command Line Tools.
There are no third-party package dependencies.

```sh
git clone https://github.com/ckakkar/taskmaster.git
cd taskmaster
make run
```

This creates and opens `build/Taskmaster.app`. Use `make dmg` for a drag-and-drop
installer. Local builds are ad-hoc signed; distribution signing, notarization
and automatic updates are not configured.

| Command | What it does |
| --- | --- |
| `make run` | Build the release app and open the companion room. |
| `make check` | Run behavior and image-import tests, compile the native app, and validate every shipped pose. |
| `make lint` / `make format` | Check or apply the repository's Swift formatting. |
| `make app` / `make dmg` | Create the app bundle or installer under `build/`. |
| `make clean` | Remove generated build products. |

**Your way back home:** the paw in the menu bar opens the room, settings,
games, pause, hide and quit. Right-click the companion for the same controls.
Closing the room leaves your desk mate running. With the app focused,
`⌘,` opens the room and `⌘;` opens customization. Launch with `--quiet`
to show just the desktop companion and menu bar.

## At home on your Mac

No account, analytics, cloud backend, camera or microphone. Images and
preferences live in `~/Library/Application Support/Taskmaster/`. Network requests
happen when you explicitly import an HTTPS image; automatic deliveries use
only your local stash. The app never types, reads your screen contents,
or changes your documents. The optional cursor game moves the pointer briefly.

The transparent overlay passes clicks through empty space. Sound starts off.
Reduce Motion disables warping, bounce effects, particles and cursor grabs.
The renderer sleeps with your display. One overlay follows the companion's
current display; drag the pet to another monitor to move it there.

For isolated development state:

```sh
make build
TASKMASTER_STATE_DIR="$PWD/.local" .build/debug/Taskmaster
.build/debug/Taskmaster --self-check
```

## Under the fur

**SwiftUI** for the room and customization. **AppKit** for the menu bar and
transparent nonactivating window. **SpriteKit** for character rendering.
A deterministic **CompanionCore** handles behavior, physics, scheduling and
2D movement without importing UI code.

```text
Sources/CompanionCore/       Behavior, games, preferences, scheduling, physics
Sources/Taskmaster/          Native app, rendering, wardrobe, meme library
Sources/Taskmaster/Resources Character artwork and pose/eye/neck metadata
Tests/CompanionCoreTests/   Simulation and regression tests
Tests/TaskmasterTests/      Image import, recovery and streaming limits
Resources/                  App metadata
scripts/                    Build, icon and installer tools
docs/                       Architecture, art provenance and handoff
```

The motion rig combines planted footsteps, eased acceleration, spring-based
landings, eye tracking, blinks, ear flicks and pose transitions. Sprite textures
are reused, transient effects are capped, and image conversion runs off the
main thread. Animation feel and battery use still deserve testing on real Macs.

Read [Architecture](docs/ARCHITECTURE.md), [Artwork & provenance](docs/CHARACTER-ART.md),
and [Repository guidelines](AGENTS.md) before contributing. Include relevant
tests, screenshots for visual changes, and an honest account of what you tried
in the running app. Current verification and known limitations are recorded
in the [handoff](docs/HANDOFF.md).

## Repeatable performance checks

Debug builds can hold a state for profiling without changing your normal setup:

```sh
make build
.build/debug/Taskmaster --debug-avatar toothless --debug-state flying --quiet
# Quit that instance before starting the full measurement matrix.
python3 scripts/measure-performance.py
python3 scripts/profile-performance.py
```

States are `sitting`, `walking`, `sleeping`, and `flying` (Toothless only).
Omit `--quiet` to include the room. Release builds reject debug flags.
The measurement script runs each supported combination for 60 seconds after
a 10-second warm-up and stores raw results under `.local/performance/`.
Profiling prefers Xcode's Time Profiler; without full Xcode it records a labeled
`sample` fallback. Results, machine details and limits are in the
[performance handoff](docs/HANDOFF.md#performance-baseline).
That run also exposed eye-shader compilation errors on this Mac; the handoff
records them for the next animation pass.

---

<div align="center"><sub>Small paws. Big opinions. Made for the little moments between your work.</sub></div>
