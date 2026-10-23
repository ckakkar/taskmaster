# Character artwork and provenance

Miso is an original character. Toothless is a fan version of an existing
fictional character, not original character IP or an official game asset.

## Miso

Created on 2026-10-23 with the built-in imagegen tool. No reference artwork
was supplied. The selected PNG is committed at
`Sources/Taskmaster/Resources/MisoAtlas.png` (1254 × 1254, RGBA).

The nine poses are arranged in a 3 × 3 atlas. `MisoAtlas.json` defines reviewed
source rectangles because a few generated poses extend beyond the nominal
cell boundaries. The loader finds each principal silhouette, trims transparent
margins at runtime, and creates SpriteKit textures. The source PNG remains unchanged.
Soft procedural motion, gravity, particles, shadows and toy graphics are
implemented in code.

## Production prompt

> Use case: stylized-concept. Asset type: production animation sprite atlas for a native macOS desktop pet app. Create ONE square image, preferably 1536 by 1536 pixels, with a precisely aligned 3 by 3 grid of NINE equally sized cells on a genuinely transparent background. No visible grid lines. Each cell contains the SAME original adorable fluffy red panda character, full body, in a different useful animation pose. Premium polished 2.5D animated-film character art: soft plush russet-orange fur, cream eyebrow patches and cheeks, tiny dark nose, warm dark brown paws and legs, small round ears, a wonderfully large striped russet and dark-chocolate tail. Charming restrained proportions, expressive readable eyes, rounded silhouette. No clothes or accessories. Soft consistent upper-left studio lighting, beautiful fur texture and soft volume. Three-quarter view facing slightly to the RIGHT in every cell. Maintain exactly the same character design, scale, fur colours, face, and lighting throughout. The character's complete silhouette must stay entirely inside its cell with generous transparent margins, never touch another cell. Consistent ground baseline for grounded poses at approximately 85% down each cell. Equal column widths and row heights. Row 1 left to right: (1) neutral standing on four paws, looking curiously at viewer, tail curled behind; (2) walking right, left forepaw forward and lifted, tail gently extended; (3) walking right, opposite right forepaw forward and lifted, same body and size as previous. Row 2 left to right: (4) sitting upright with paws resting on belly, gentle attentive expression, tail curled beside; (5) asleep curled into a round ball with eyes peacefully closed and tail wrapped around body; (6) being picked up by the scruff, body dangling vertically, four paws relaxed, mildly surprised but comfortable, NO hand or string shown. Row 3 left to right: (7) delighted sitting pose, eyes smiling closed, front paws held near cheeks; (8) playful bow, forepaws down, rear raised, looking excited, tail high; (9) mischievous sitting pose, one front paw raised to mouth, cheeky sideways glance. No text, labels, letters, watermark, captions, props, scenery, cast shadow, ground plane, background colour, rounded tiles, or interface. True alpha transparency around every sprite. This sheet will be sliced directly into nine cells by the app, so the regular 3x3 arrangement is essential.

## High-five gesture

`Sources/Taskmaster/Resources/MisoHighFive.png` (1254 × 1254, RGBA) was created
with the built-in imagegen tool using the original atlas as the character
reference. It adds one pose of Miso, rather than another creature. Its eyes and
raised paw have reviewed landmarks in `MisoAtlas.json`; its scale is normalized
against the sitting pose. Original image files retain their generated alpha.

Exact production prompt:

> Use case: stylized-concept. Asset type: one isolated transparent full-body desktop-pet game sprite. Image 1 is a CHARACTER IDENTITY and MATERIAL REFERENCE ONLY, not a layout to reproduce. Create exactly ONE new pose of the SAME Miso red panda: sitting upright, facing 3/4 toward camera right, raising ONE forepaw high beside its head, palm pads facing viewer, offering a high five. Other forepaw relaxed at chest. Friendly eager open brown eyes, closed smiling mouth. Preserve exact warm orange fluffy fur, cream cheeks and eyebrows, dark cocoa legs, huge striped plush tail curling at left, rounded baby proportions and refined soft 3D illustration style. Full body and full raised paw visible, centered in a square canvas with generous transparent margin. Feet on a single baseline. Soft warm top-left lighting. No floor, no shadows separate from body, no scenery, no text, no props, no other animals, no grid. Real alpha transparency, no checkerboard baked in. This must look like the same character from the reference, not a redesign.

## Current limitations

These are painted poses with procedural animation, not a full skeletal 3D model
or hand-keyed film sequence. A continuous leg deformation, head and tail rig,
eye shader and pose crossfades provide movement at up to 60 fps. Walking deforms the
standing pose with planted feet and lifted swing phases; the original two walk
poses are retained for future art work, but are no longer switched at 5 Hz.

## Toothless companion — October 2026

`Sources/Taskmaster/Resources/ToothlessAtlas.png` is a new transparent 1536×1024
atlas generated with the built-in imagegen tool. Its JSON records ten pose
regions, eyes and raised-paw landmarks. The eye landmarks were re-measured on
23 October 2026 from the green of the irises (the earlier hand-placed ones sat
on the snout and mouth in some poses); each records an `aspect` because the far
eye is seen almost edge-on. The final two cells are unused. Crops
have overlap margins to retain wing and tail tips; the loader extracts the
largest connected silhouette. No official game artwork is bundled. This is
fan-made generated artwork depicting Toothless from *How to Train Your Dragon*,
as requested by the project owner.

The shipped asset lives in the repository. Its original generation output is
retained under the local generated-images directory; the app does not depend
on that directory. Coat variants of Miso are computed by the application and
preserve the original fur shading and transparency.

<details><summary>Toothless production prompt</summary>

```text
Use case: stylized-concept. Asset type: production transparent sprite atlas for a native macOS desktop companion. Create a beautiful premium soft 3D animated-film style BABY TOOTHLESS, the cute black Night Fury dragon from How to Train Your Dragon: huge expressive green eyes, rounded black head, ear fins, tiny wings, four short paws, long curved tail with his recognizable tail fins. The exact same adorable character consistently repeated across TEN separate complete full-body poses. Warm soft light from upper left, exquisitely soft scales, clean readable silhouettes, no floor, no background, no cast shadows, no text, no borders. TRANSPARENT RGBA. Strict evenly spaced FOUR COLUMNS by THREE ROWS grid, landscape canvas; each cell has generous transparent padding and contains exactly ONE complete dragon with no overlap. Camera always the same three-quarter side view facing RIGHT. In row-major order: cell 1 standing on four paws, cell 2 walking with near front paw stepping forward, cell 3 opposite walking step, cell 4 seated sweetly; cell 5 curled up sleeping eyes closed; cell 6 gently held in midair with paws dangling (no human hands); cell 7 delighted grinning with eyes closed; cell 8 playful bow front paws lowered with rear up; cell 9 cheeky plotting grin and narrowed eyes; cell 10 sitting and raising the right-front paw for a high five. Cells 11 and 12 remain fully empty transparent. Consistent body proportions, direction, character details and approximate character size across cells. This is actual game art, not a mockup or UI. Do not add labels, symbols, props, watermark or a checkerboard background.
```

</details>
