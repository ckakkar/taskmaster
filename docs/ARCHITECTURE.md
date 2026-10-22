# Architecture

## Behavior and simulation

`CompanionCore` owns a deterministic state machine, a bounded habitat and a
throwable ball. The UI translates actions into events; the simulation never
touches AppKit, files, the network or other apps. Frame steps are capped to avoid
large physics jumps after a blocked run loop. Display changes rehome the pet.

Personality is continuous from zero to one. Presets choose useful points on
that range. Increasing mischief affects walking speed, target selection, naps
and notes, rather than merely changing a label.

`PetAttention` drives eased gaze, irregular blinks, occasional double blinks,
and ear flicks independently of roaming. Gentle movement over the character
accumulates affection with a cooldown. Nearby cursor motion can trigger a short
anticipation pose and chase above 30% mischief. Teleports and stationary hovers
do not count as strokes or invitations to play; explicit naps remain undisturbed.

## Rendering and input

The desktop is an AppKit nonactivating transparent panel with a SpriteKit
scene. It floats over regular application windows without becoming the key
window. Each frame checks whether the pointer intersects an opaque character
pixel, the ball or a note; elsewhere the panel ignores mouse events.

The renderer receives state snapshots and a bounded stream of transient
events. The companion room renders the same pet state in a second scene.
Sprites are trimmed once at load time and textures are reused. The native
frame loop runs at 60 Hz and stops rendering while the display sleeps. Hidden
desktop and closed preview scenes avoid their per-frame rendering work.

Reviewed source rectangles and eye landmarks live in `MisoAtlas.json`. The
loader trims the largest connected silhouette and transforms those landmarks
into texture coordinates. A fragment shader moves the eyes and closes their
lids. A small warp grid gives the painted head, ears and tail separate movement
without splitting the fur into obvious pieces. Reduce Motion keeps gaze and
blinks but disables warping, bouncing and particles. Short pose crossfades and
speech bubbles that follow the pet avoid jarring transitions. A distance-driven
leg cycle replaces discrete walk-frame switching. Movement accelerates and
brakes in the simulation; analytic springs drive head response, landing squash
and carried inertia independently of frame rate. A short pinch gives direction
changes a readable turn. Each paw stays on the ground for 62% of its cycle;
its local backward movement cancels the body's forward travel. A Hermite return
curve lifts the paw and matches its velocity at touchdown. Distance, rather
than elapsed time, advances the gait, and small contact shadows anchor the feet.
Only the upper body bobs; the complete sprite is never lifted during a walk.
Transient particles are capped at 96 per scene.

The high-five gesture uses a separate generated image, normalized to the atlas
scale, with eye and paw landmarks. A pulsing paw target accepts the gesture.
The follow game has an explicit stop and a one-minute timeout. Snack hunting
has a bounded biscuit, approach, sniff and eating sequence. Explicit actions,
dragging or napping cancel these games rather than leaving hidden props behind.

The first release uses one overlay on the pet's current screen. Dragging to a
different monitor moves that overlay. Spanning several monitors at once and
perching on other applications' window edges are outside this version.

## State and lifecycle

Only preferences persist. Pet interactions and transient props reset on
relaunch. Preferences are sanitized and written atomically. The menu-bar app
remains alive when the companion room closes, with explicit pause, hide and
quit actions. Sounds are opt-in. No login item is installed.

## Validation

Core tests cover long-session bounds, dropping, sleep/wake, pause, monitor
changes, ball lifetime, preference recovery, gaze, blinking, strokes and cursor
curiosity, frame-rate-independent springs, acceleration and braking, high fives,
snack hunts and the bounded follow game. A resource self-check verifies
all ten texture frames. Desktop clicks, menu behavior, transparency and layout
must also be verified in a real Mac UI session.
