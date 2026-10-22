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
The check reports **55 passing tests** and **20 validated transparent frames**.
The release bundle's `--self-check`, strict code-signature verification and
DMG packaging also pass. The packaged resources contain no removed character art.
GitHub Actions retains `macos-15` as the older-toolchain check; it runs lint,
compilation, tests and `--self-check`. Check output is recorded in commit
messages, not a generated document in this repository.

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
Toothless. Screenshots in `docs/media/` come from this running build.

The owner tested cursor borrowing with a physical mouse and reported that
**pulling away releases it** on their Mac. This is user-tested hardware behavior,
not a simulated input result. Click and Esc remain the documented controls.

Early focus cancellation after petting, repeated stash recovery, the keep-card
extension, physical display wake and monitor changes were covered by tests,
not certified through an end-to-end hardware session.

## Remaining limits

- Animation feel still needs sustained human observation. These are painted
  poses with procedural deformation, rather than skeletal 3D animation.
- No controlled sitting/walking/flying/room-open Activity Monitor baseline
  was taken. One earlier `ps` sample was about 19.8% CPU and 174 MiB RSS;
  its state was uncontrolled, so it is not an idle or battery benchmark.
- Multi-monitor hardware, sleep/wake and cursor release on other Macs need
  hands-on checks. Unit tests cover their simulation boundaries only.
- Recovering corrupt meme JSON retains images but cannot reconstruct lost
  titles or enabled flags. Animated imports use only their first frame.
- Local app builds are ad-hoc signed. Notarization, distribution signing and
  automatic updates are not configured.

Use `TASKMASTER_STATE_DIR` for isolated QA. Do not replace the owner's normal
Application Support preferences or meme stash with test fixtures.
