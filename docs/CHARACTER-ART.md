# Miso character art

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

## Current limitations

This is a pose atlas, not a hand-keyed full animation sequence. The two walking
poses are combined with procedural bobbing. A later art pass can add properly
registered walk cycles, blinks, anticipation and transitional poses without
changing the behavior engine.
