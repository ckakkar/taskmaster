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
frame loop runs at 30 Hz and stops rendering while the display sleeps.

Reviewed source rectangles and eye landmarks live in `MisoAtlas.json`. The
loader trims the largest connected silhouette and transforms those landmarks
into texture coordinates. A fragment shader moves the eyes and closes their
lids. A small warp grid gives the painted head, ears and tail separate movement
without splitting the fur into obvious pieces. Reduce Motion keeps gaze and
blinks but disables warping, bouncing and particles. Short pose crossfades and
speech bubbles that follow the pet avoid jarring transitions.

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
curiosity. A resource self-check verifies
all nine texture frames. Desktop clicks, menu behavior, transparency and layout
must also be verified in a real Mac UI session.
