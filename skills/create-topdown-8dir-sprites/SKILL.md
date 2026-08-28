---
name: create-topdown-8dir-sprites
description: Create consistent top-down eight-direction pixel character sets from generated or supplied raster art, including separate view generation, Perfect Pixel recovery, 1:1 placement on fixed canvases, shared palette, binary alpha, previews, metadata, and audit evidence. Use for eight-view top-down character poses or animation baselines; do not use for four-direction-only, isometric, 3D, or skeletal-rig work.
---

# Create Top-Down 8-Direction Sprites

Produce an auditable eight-view character set ordered `N, NE, E, SE, S, SW, W, NW`. Preserve identity and readable direction changes without sacrificing recovered pixel detail.

## Non-Negotiable Invariants

- Treat the final dimensions as a canvas contract, not a command to shrink the character to an arbitrary height.
- Generate or approve each direction separately. Do not ask an image model for one eight-view sheet and then accept identity drift hidden inside it.
- Use the same approved identity anchor, costume, proportions, camera elevation, lighting, and pose across all views. Use adjacent approved views as additional references when the image tool supports them.
- Convert each approved high-detail direction separately into a high-resolution pseudo-pixel source.
- Let Perfect Pixel recovery define the final logical pixels. Use `majority` sampling, disable automatic refinement, and calibrate an integer grid per direction when necessary.
- After recovery, forbid all non-integer resampling. Only crop transparent bounds, center, integer-translate, and pad with transparency.
- Apply one shared palette across all eight frames, then enforce binary alpha.
- Preserve raw generated sources. A checkerboard-looking background is not evidence of real transparency; inspect the image mode and alpha values.

## Workflow

1. Write an asset contract before generation. Read [references/pipeline-contract.md](references/pipeline-contract.md) for the required fields, direction semantics, prompt pattern, CLI, and acceptance evidence.
2. Create one high-detail full-body image for each direction. Review identity, apparent height, body width, costume landmarks, view angle, and face visibility before continuing.
3. Convert each approved direction separately to a high-resolution pseudo-pixel image. The pseudo-pixel blocks must form a coherent repeated lattice; gradients inside blocks and irregular block sizes reduce recovery quality.
4. Place the eight pseudo-pixel sources in one directory using exact filenames: `north.png`, `northeast.png`, `east.png`, `southeast.png`, `south.png`, `southwest.png`, `west.png`, `northwest.png`.
5. Run `scripts/build_topdown_8dir.py`. Start with automatic integer-grid calibration. Use explicit grid overrides only when the recorded calibration trials or visual evidence justify them.
6. Inspect the recovered 1:1 frames before judging the palette result. If a feature exists after recovery but disappears in the final frame, stop: the processing path violated the no-resampling invariant.
7. Review the contact sheet, head crops, rotation GIF, manifest, grid metrics, and audit. Regenerate only a direction whose source pose or identity is wrong; do not repair source errors by stretching or shrinking recovered pixels.

## Review Priorities

- `N` and `NW/NE` must not accidentally read as frontal.
- `E/W` must read as real profiles with the expected single visible eye.
- `SE/S/SW` must retain the intended eyes and face landmarks; never delete eyes merely to signal direction.
- Opposite views should agree on height, body mass, hair volume, costume landmarks, and handed asymmetries.
- A one-pixel visible-height spread is a useful default for a static pose. Change the tolerance only when perspective or animation genuinely requires it.
- Judge the sprites at native size and nearest-neighbor magnification. Smooth display scaling is not valid pixel-art evidence.

## Delivery Boundary

Keep prototypes outside engine production directories until the user approves the visual set. Engine import, pivots, PPU, slicing, animation clips, and prefab wiring are separate authorized work.

Match user-facing explanations, prompts, and handoffs to the user's language unless the user requests another language. Keep commands, filenames, structured keys, and raw errors unchanged.
