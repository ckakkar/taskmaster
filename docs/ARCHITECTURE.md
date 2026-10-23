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
unless an opaque character pixel or interactive prop is hit; the panel's
`ignoresMouseEvents` is only assigned when it changes, because every assignment
is a window-server round trip. Pawprints never intercept input. The companion
room and wardrobe use additional live scenes.

Drawing and compositing a full-screen transparent layer costs GPU time on every
frame, so the panel covers only a strip along the floor (`OverlayExtent`: the
floor plus 260 + 230 × size points, enough for the tallest grounded pose,
speech, notes and meme cards). It grows to the whole screen while the pet is
carried, falling or flying, or the ball is held or will rise near the strip's
top, and shrinks 1.5 seconds after that ends. The panel's bottom-left corner
never moves, so scene coordinates stay the same at either size.

`PetAtlas` trims each source rectangle to its largest connected silhouette.
JSON metadata describes eyes, paws and neck placement, including high-five
landmarks. Each shipped companion has ten frames. Miso is an original
character; Toothless is a fan interpretation. Coat variants recolor warm
fur while preserving cream markings and alpha, then cache textures. Miso's
accessories attach to pose-specific neck coordinates and hide behind occluding
paws or sleeping poses. Other characters keep their illustrated appearance.

A small warp grid animates head, ears, tail, wings and legs. `EyeShader` shifts
the painted pupils toward the pointer and blinks by sliding fur-coloured lids
over each eye: the upper lid's colour blends the fur in a ring above the eye and
the lower lid's the ring below, so lids match the coat without streaks, and a
lash line marks the lid edge. SpriteKit's Metal translation only exposes uniforms
and `u_texture` inside `main()`, so both eyes are handled in a loop there. Eye
landmarks are ovals: `radius` is vertical and the optional `aspect` is width ÷
height (Toothless's far eye is seen almost edge-on). Distance-driven gait keeps each foot planted during 62% of the cycle,
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

The frame loop (`FramePacing`) runs at 60 fps while anything moves or is held,
or the pointer is near the pet or over the room; calm moments drop to 30 fps
and sleep to 20 fps, but only after a second of calm, so landings and pose
blends finish smoothly. Cursor petting and curiosity measure pointer movement
per frame and were tuned at 60 fps, which is why a nearby pointer always keeps
it. The loop suspends with display sleep. Hidden desktop and closed preview
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
and cancels when the limit is exceeded. The only periodic request is the update check below.
An NSCache bounds decoded images. Originals are never moved or removed.

A damaged index is copied to a uniquely named recovery file. The library
rebuilds entries from its UUID-named PNG copies, so images remain discoverable;
original titles and disabled flags cannot be reconstructed from corrupt JSON.
The rebuilt index is saved immediately so later launches do not duplicate backups.
Removing a card trashes only the library copy. Starter definitions and bubble
colors each have a single source of truth.

The menu-bar app survives closure of its ordinary windows, with explicit hide,
pause and quit actions. No login item is installed. Sound is opt-in.

## Updates and packaging

`Updater` wraps Sparkle's standard updater, as in Luna. It starts only when the
bundle's `SUPublicEDKey` is filled in (by `scripts/build-app.sh`, from
`Resources/SparklePublicKey.txt`), so tests, the debug binary and builds without
a key never check. Sparkle reads `appcast.xml` from the latest GitHub release
about 20 seconds after launch and then hourly, and verifies each download's
EdDSA signature. A background find is announced gently: a dot on the menu bar
paw (`MenuBarGlyph`), a menu item and a note in the room; Sparkle's window
opens when one is clicked, or by itself after a day. The release pipeline,
disk image and keys are described in [RELEASING.md](RELEASING.md).

## Verification

`make check` runs Swift Testing suites for simulation, scheduling, preference
round trips, recovery, asynchronous import and streamed download limits, then
runs `--self-check` without creating the app or windows. The resource check
validates every shipped character frame and its landmarks. `make lint` enforces
swift-format. GitHub Actions runs both on macOS.

Debug-only `DebugLaunch` and `PetEngine+Debug` hold reproducible sitting,
walking, sleeping and Toothless flying workloads. They preserve ordinary
movement/rendering but bypass random activity decisions. Measurements use fresh
isolated preferences, a fixed seed and the normal adaptive frame loop.
`make measure` runs them on an optimized build compiled with `-DDEBUG` into
`.build/perf`, apart from release output. Release builds
contain no workload hook and reject debug launch flags. The `ps` runner measures
cumulative CPU-time deltas and mean RSS; the separate profiler runner chooses
the highest-CPU result so tracing does not contaminate the baseline.

Unit tests do not certify animation feel, physical cursor release, power use,
or multi-display input. Record those separately in [HANDOFF.md](HANDOFF.md).
