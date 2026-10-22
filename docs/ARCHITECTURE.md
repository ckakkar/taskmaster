# Architecture

## Simulation boundary

`CompanionCore` imports Foundation only. Time, cursor position, user idle time
and actions enter a deterministic state machine; events and state snapshots
leave it. It never accesses AppKit, files, the network or other applications.
Steps are capped at 0.1 seconds. Seeded randomness supports long-session tests.

`PetEngine.swift` coordinates state transitions. Feature extensions own cursor
games, speech, toys, deliveries and aerial movement. `AvatarKind` supplies
character identity and gait geometry. Miso stays on the ground; Toothless uses
`AerialRoute` for eased 2D travel, bounded by the current display's habitat.
Ground activities queue a smooth landing first.
Dragging cancels flight. Pausing freezes simulation time. Resizing and monitor
changes preserve flight age and its deadline while remapping the route. Automatic
flights have a low decision probability and a minimum three-minute cooldown.
Airborne desktop characters pass clicks through; the room provides Land gently.

`CompanionSchedule` owns wall-clock focus and automatic meme scheduling. Quiet
affection does not end focus; games do. Completion emits one break reminder and
defers a coincident meme. Only automatic-delivery enablement and interval edits
restart the meme deadline. Hidden, paused, sleeping, busy or airborne pets wait
for a suitable delivery opportunity. Ending focus restores finite decision timers.

## Rendering and input

`PetScene.swift` owns node setup and shared scene storage. Feature extensions
separate the frame renderer (`+Rendering`), particles/pawprints/notes/speech
(`+Effects`), meme card placement (`+Memes`) and hit-testing (`+HitTesting`).
Their method bodies and animation constants are unchanged by the file split.
The room's header, introduction, controls and footer live in separate extensions;
each customization editor, shared controls and `PetPreview` has its own file.

An AppKit nonactivating transparent panel contains a SpriteKit scene. It floats
over normal windows without taking keyboard focus. Mouse input passes through
unless an opaque character pixel or interactive prop is hit. Pawprints never
intercept input. The companion room and wardrobe use additional live scenes.

`PetAtlas` trims each source rectangle to its largest connected silhouette.
JSON metadata describes eyes, paws and neck placement, including high-five
landmarks. Each shipped companion has ten frames. Miso is an original
character; Toothless is a fan interpretation. Coat variants recolor warm
fur while preserving cream markings and alpha, then cache textures. Miso's
accessories attach to pose-specific neck coordinates and hide behind occluding
paws or sleeping poses. Other characters keep their illustrated appearance.

A small warp grid animates head, ears, tail, wings and legs; a shader animates
eyes. Distance-driven gait keeps each foot planted during 62% of the cycle,
with Hermite swing curves and contact shadows. Springs handle landing and
carried inertia. Each character profile defines its foot positions and phases.
Flight banks gently as the dragon follows a 2D route.
Transient particles are capped at 96 and pawprints at 60 per scene.

Cursor heists are opt-in and Chaos-only. The simulation times approach and
escape. The desktop adapter performs the pointer movement and ends it for
clicks, Esc, physical pull-away, pause, focus, Reduce Motion or a 1.5-second
wall-clock deadline. No event tap or Accessibility permission is requested.
The user tested physical pull-away on their Mac and confirmed it releases the
cursor. Click and Esc remain the documented controls; other Macs need the same
hardware check.

The 60 Hz loop suspends with display sleep. Hidden desktop and closed preview
scenes avoid their per-frame rendering. One overlay occupies the current
screen; moving to another display rehomes the simulation and cancels delivery. Waking
the same display preserves delivery and retains the current screen when present.
Size changes preserve an active delivery's route instead of teleporting the pet.

## Images, persistence and lifecycle

Preferences, custom quips, completed focus count and the meme index persist
under Application Support/Taskmaster, or `TASKMASTER_STATE_DIR`. Active focus,
position, interactions and transient props reset at relaunch. Preferences use
backward-compatible defaults, sanitization, debounced saves and atomic writes.

`MemeLibrary` stores metadata on the main actor. `MemeImageImport` performs
ImageIO conversion in a detached task; files are limited to 25 MB and normalized
to PNG with a maximum dimension of 1600 pixels. URLSession streams manual HTTPS
imports into a temporary file, checks both Content-Length and actual bytes,
and cancels when the limit is exceeded. No periodic network fetches occur.
An NSCache bounds decoded images. Originals are never moved or removed.

A damaged index is copied to a uniquely named recovery file. The library
rebuilds entries from its UUID-named PNG copies, so images remain discoverable;
original titles and disabled flags cannot be reconstructed from corrupt JSON.
The rebuilt index is saved immediately so later launches do not duplicate backups.
Removing a card trashes only the library copy. Starter definitions and bubble
colors each have a single source of truth.

The menu-bar app survives closure of its ordinary windows, with explicit hide,
pause and quit actions. No login item is installed. Sound is opt-in.

## Verification

`make check` runs Swift Testing suites for simulation, scheduling, preference
round trips, recovery, asynchronous import and streamed download limits, then
runs `--self-check` without creating the app or windows. The resource check
validates every shipped character frame and its landmarks. `make lint` enforces
swift-format. GitHub Actions runs both on macOS.

Debug-only `DebugLaunch` and `PetEngine+Debug` hold reproducible sitting,
walking, sleeping and Toothless flying workloads. They preserve ordinary
movement/rendering but bypass random activity decisions. Measurements use fresh
isolated preferences, a fixed seed and the normal 60 Hz loop. Release builds
contain no workload hook and reject debug launch flags. The `ps` runner measures
cumulative CPU-time deltas and mean RSS; the separate profiler runner chooses
the highest-CPU result so tracing does not contaminate the baseline.

Unit tests do not certify animation feel, physical cursor release, power use,
or multi-display input. Record those separately in [HANDOFF.md](HANDOFF.md).
