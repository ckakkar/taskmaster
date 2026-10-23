# Handoff — 23 October 2026

## Current scope

Miso and Toothless are the two shipped companions, with ten poses each.
Robin was removed at the owner's request after a native preview; no Robin
artwork, selector or grappling feature is shipped. Saved unknown character
values fall back to Miso while retaining the user's other preferences.

Focus, custom sayings, the local meme stash, manual HTTPS imports, scheduled
deliveries, Miso's coats and accessories, muddy trails and opt-in cursor
borrowing are implemented. Flight resizing preserves the trip and its deadline.
Airborne pets pass desktop clicks through, automatic flights have a three-minute
cooldown, and same-display wake preserves an active delivery.

## Automated verification

`make format`, `make lint` and `make check` pass locally with Swift 6.4.
The check reports **64 passing tests** and **20 validated transparent frames**.
The release bundle's `--self-check`, strict code-signature verification and
DMG packaging also pass. The packaged resources contain no removed character art.
GitHub Actions retains `macos-15` as the older-toolchain check; it runs lint,
compilation, tests and `--self-check`. Check output is recorded in commit
messages, not a generated document in this repository.
The complete file split also passed on Swift 6.1.2 in
[CI run 39867425783](https://github.com/ckakkar/taskmaster/actions/runs/39867425783).

Regression coverage includes:

- Ending focus after petting; finite idle timers resume.
- Every preference saving and reloading; unrelated edits keep the meme deadline.
- Corrupt stash recovery, immediate index saving and no repeated backup copies.
- Off-main-thread image conversion, main-actor responsiveness, and declared
  versus streamed download size limits.
- Flight bounds, pause, landing before ground activities, dragging, resizing,
  display remapping, cooldown and unavailable-character fallback.
- Same-display wake preserving a meme; moving displays cancelling it.
- Coat textures, all shipped poses, eye/paw landmarks and unclipped flight previews.
- Debug workload validation, isolated defaults and states held for over 60 seconds.
- The eye shader compiling and rendering through SpriteKit: blinks with fur-coloured
  lids, pupils that follow the gaze, and no change outside the eyes, for both
  companions (skipped on machines without a Metal device, such as some CI runners).
- Frame-rate and overlay-size decisions for calm, moving, held, flying and ball states.

## Performance baseline

Measured on an **Apple M2, 8 CPU cores, 16 GiB RAM**, macOS **27.0.1**.
The LG display ran at 5120×2880, scaled to 2560×1440 points, 2× backing scale,
60 Hz. Reduce Motion was off. These are **unoptimized debug-build** numbers,
not release-build or battery benchmarks.

Each row uses a fresh process, 10-second warm-up, then a 60-second window.
CPU is the change in `ps` cumulative user+system CPU time divided by elapsed
wall time; **100% means one CPU core**. Memory is mean `ps` RSS from 61
one-second boundary samples, in MiB; it is not physical footprint or GPU memory.
The renderer and 60 Hz loop were unchanged. No builds or profilers ran during
the samples. Normal Mac background apps remained running.

Defaults were fixed at size 100%, mischief 25%, Cinnamon coat, no accessory,
sound off and no automatic memes or cursor borrowing. Random activity decisions
and away-time naps were bypassed to hold the requested state. Walking uses the
normal ground physics; flying uses continuous normal aerial routes. Miso does
not support flight. The regular companion was quit and its settings were untouched.

| Companion | State | CPU, room closed | Mean RSS, closed | CPU, room open | Mean RSS, open |
| --- | --- | ---: | ---: | ---: | ---: |
| Miso | Sitting | 13.27% | 140.65 MiB | 12.37% | 170.27 MiB |
| Miso | Walking | 15.83% | 141.90 MiB | 16.97% | 168.31 MiB |
| Miso | Sleeping | 12.08% | 141.14 MiB | 16.67% | 168.61 MiB |
| Miso | Flying | Not supported | — | Not supported | — |
| Toothless | Sitting | 14.53% | 157.86 MiB | 16.25% | 182.17 MiB |
| Toothless | Walking | 17.70% | 154.48 MiB | 19.05% | 184.94 MiB |
| Toothless | Sleeping | 15.65% | 154.73 MiB | 17.80% | 182.35 MiB |
| Toothless | Flying | 15.35% | 154.52 MiB | 18.08% | 173.23 MiB |

The measured source revision is `2e45e76`, before the mechanical UI file split;
all 35 moved method/section bodies were compared and matched, ignoring whitespace.
Raw counters, process handshakes and metadata were kept in
`.local/performance-2026-10-23/` and later removed in a cleanup; the tables here
are the record. To repeat:

```sh
make build
python3 scripts/measure-performance.py --output .local/performance
python3 scripts/profile-performance.py --results .local/performance/results.json
```

The launch switches are debug-only. Add `--quiet` to omit the room, for example
`.build/debug/Taskmaster --debug-avatar miso --debug-state walking --quiet`.
Without `TASKMASTER_STATE_DIR`, a debug workload uses a temporary directory;
ordinary launches retain the normal state location.

### Worst-case profile

The highest-CPU case was **Toothless walking, room open** (19.05% CPU,
184.94 MiB mean RSS). A separate **30-second, 1 ms `sample` recording** used
that workload and the exact same benchmark binary (SHA-256 match recorded in
`worst-profile/profile.json`).

**No Time Profiler trace was captured.** Only Command Line Tools are installed;
`xcrun --find xctrace` reports “unable to find utility xctrace.” The profiler
runner tries Xcode first and labels the `sample` fallback explicitly. A full
Xcode installation is still needed for the requested Instruments trace.

These are the top ten entries in `sample`'s “top of stack, same collapsed”
summary. Counts include waiting threads across the process; they are **not
CPU percentages or Time Profiler weights**. Long generic symbols are shortened.

| Function | Image | Leaf observations |
| --- | --- | ---: |
| `__workq_kernreturn` | `libsystem_kernel.dylib` | 120,673 |
| `__psynch_cvwait` | `libsystem_kernel.dylib` | 31,737 |
| `mach_msg2_trap` | `libsystem_kernel.dylib` | 30,779 |
| `start_wqthread` | `libsystem_pthread.dylib` | 5,620 |
| `iokit_user_client_trap` | `IOKit` | 114 |
| `cerror_nocancel` | `libsystem_kernel.dylib` | 105 |
| `_os_nospin_lock_lock` | `libsystem_platform.dylib` | 95 |
| `getCache(…)` | `libswiftCore.dylib` | 89 |
| `swift::TargetContextDescriptor::getGenericContext()` | `libswiftCore.dylib` | 89 |
| `_swift_isClassOrObjCExistentialType` | `libswiftCore.dylib` | 60 |

Within the application workload call graph, `PetScene.render` appeared in
1,705 observations and `PetAnimation.update` in 1,615. Those counts are
inclusive and overlap. No optimization was applied. The separate profile
reported physical footprint as `393.1M`; that differs from the RSS metric above.
The raw call graph and log were not kept.

**Renderer issue at the time (now fixed):** every scenario logged eye-shader
compilation errors, so the table above measures sprites drawn without the eye
shader. See the rendering pass below.

## Rendering pass — eyes, frame pacing and overlay size

**Eyes.** The eye shader had never compiled on this Mac: SpriteKit's Metal
translation only exposes uniforms and `u_texture` inside `main()`, and the eye
code lived in a helper function, so SpriteKit silently drew the plain sprite.
`EyeShader` now handles both eyes in a loop inside `main()`. Once visible, the
original lids (one row of fur stretched over the eye) streaked badly, so lids
are now blended from the fur ringing each eye — the upper lid from above, the
lower lid from below — with a shaded edge and a lash line. Toothless's eye
landmarks were re-measured from his irises; several sat on his snout or mouth.
The regression test renders through SpriteKit and fails against the old shader.

**Per-frame work.** `panel.ignoresMouseEvents` was assigned every frame; each
assignment is a window-server round trip and also forced Core Animation fence
transactions, which were the largest main-thread cost in `sample`. It is now
assigned only when it changes. `childNode(withName:)`, which parses a search
pattern, no longer runs every frame.

**Frame pacing and overlay size.** See `FramePacing` and `OverlayExtent` in
[ARCHITECTURE.md](ARCHITECTURE.md): 60 fps while anything moves, is held or is
near the pointer, otherwise 30 fps (20 asleep); the panel covers a floor strip
(597 of 1,440 points on this display) and grows to full screen only while
something can be above it.

**Measured.** Same Mac and display as above. Optimized builds with the debug
workloads (`make measure`'s build), 5-second warm-up and 20-second window, the
owner's regular companion still running (it was not quit this time), and the
old and new builds alternated case by case so background activity affects both.
Repeated runs of one case varied by about ±1.5 points.

| Case | Before (`c25825c`) | After |
| --- | ---: | ---: |
| Miso sitting, room closed | 9.45% | 5.30% |
| Miso walking, room closed | 11.40% | 9.45% |
| Miso sleeping, room closed | 9.35% | 3.60% |
| Toothless flying, room closed | 12.40% | 9.30% |
| Miso sitting, room open, pointer over the room | 16.85% | 14.30% |

Mean RSS was unchanged at about 140 MiB (room closed). The room-open row stays
at 60 fps by design while the pointer is over the room.

GPU: `ioreg` "Device Utilization %", averaged over 30 half-second readings,
with and without one test pet. This is a coarse, system-wide counter and
another app raised the idle baseline to 18–20% during the comparison, so treat
the numbers as relative. The original build added about 31 points sitting and
29 walking; the new build added about 12 and 8.

## First release — 0.1.25

The release workflow published Taskmaster 0.1.25 on 23 October 2026 with
`Taskmaster.dmg`, `Taskmaster.zip` and `appcast.xml`. The downloaded assets were
checked: the app is universal, signed by "Taskmaster Self-Signed", carries the
update key and feed URL, and passes `--self-check` from the mounted disk image;
the archive's EdDSA signature verifies against the update key and its length
matches the appcast. It was installed into `/Applications` on the owner's Mac,
replacing the older local build.

## Checked in the running Mac app

The room, customization pages, custom name, Miso/Toothless selection, voice
preview, coat changes and accessory placement were inspected. Dusk visibly
changed Miso's fur. A local image and a direct HTTPS image were imported;
copies persisted without changing the originals. Meme fetching, on-screen
display and retrieval were observed. Focus started and its countdown advanced.
The final Toothless flight was observed in the room, including its airborne
pose, blue spark trail, movement and Land gently control. The initial preview
clipped at its edges; after fixing the layout, the complete dragon stayed
visible in the reviewed capture. The final selector contains only Miso and
Toothless. Screenshots in `docs/media/` were captured before the file-only
refactor, with the same view bodies.

After the split, the release app was rebuilt and all five customization sections
and the room preferences popover were opened again. The normal custom name,
65% size, Chaos settings and existing meme stash were retained; benchmark
defaults did not leak into them. The app was returned to desktop-only operation.
Release launch with `--debug-state sitting` exits with status 2, as intended.

In the rendering pass, the eye fix was checked with SpriteKit renders of every
pose at magnified and on-screen scale, and the overlay's real window bounds were
read back from the window server for sitting (a 597-point strip) and flying
(full screen) test pets. Blinking and cursor-following were **not** watched on
the desktop yet, the release `.app` bundle was not rebuilt (the owner's copy was
running from it), and multi-display strip resizing was not tried.

The owner tested cursor borrowing with a physical mouse and reported that
**pulling away releases it** on their Mac. This is user-tested hardware behavior,
not a simulated input result. Click and Esc remain the documented controls.

Early focus cancellation after petting, repeated stash recovery, the keep-card
extension, physical display wake and monitor changes were covered by tests,
not certified through an end-to-end hardware session.

## Remaining limits

- Animation feel still needs sustained human observation. These are painted
  poses with procedural deformation, rather than skeletal 3D animation.
- Blink appearance is tuned from magnified renders; it still needs a look at
  real size on the desktop, especially Miso's paler lower lids.
- Performance numbers are single passes on one Mac and one 5K display with
  default benchmark settings; other displays and settings can differ. GPU
  readings are coarse and were taken with other GPU activity present.
- Multi-monitor hardware, sleep/wake and cursor release on other Macs need
  hands-on checks. Unit tests cover their simulation boundaries only.
- Recovering corrupt meme JSON retains images but cannot reconstruct lost
  titles or enabled flags. Animated imports use only their first frame.
- Releases, the disk image and Sparkle updates follow Luna's setup
  ([RELEASING.md](RELEASING.md)). The app isn't notarized (no Apple Developer
  ID), so first launch needs **Open Anyway**. Installing an update through
  Sparkle's window (0.1.25 to the next release) still needs a person to click
  Install to confirm the whole path.

Use `TASKMASTER_STATE_DIR` for isolated QA. Do not replace the owner's normal
Application Support preferences or meme stash with test fixtures.
