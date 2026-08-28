# Pipeline Contract and Operating Reference

Read this reference when preparing a new eight-direction asset, prompting the raster generator, running the processor, or reviewing a delivery.

## Asset Contract

Record these facts before generation:

- character identity, age range, body proportions, hair, costume, equipment, and protected asymmetric details;
- gameplay role and pose or animation state;
- camera projection and elevation, with top-down rather than isometric explicitly stated;
- direction order: `N, NE, E, SE, S, SW, W, NW`;
- final canvas dimensions, intended visible-height target and tolerance, bottom contact, pivot, and PPU assumption;
- high-detail and pseudo-pixel source locations;
- palette limit or approved palette family;
- alpha policy, filenames, intended engine destination, and approval boundary;
- generator provenance, source hashes, processing versions, and license facts when applicable.

## Direction Semantics

| File | Character faces | Expected face visibility |
| --- | --- | --- |
| `north.png` | away/up | back of head; no frontal face |
| `northeast.png` | away-right/up-right | rear three-quarter; little or no frontal face |
| `east.png` | right | true profile; one visible eye when unobscured |
| `southeast.png` | toward-right/down-right | front three-quarter; readable eyes and nose direction |
| `south.png` | toward camera/down | frontal face |
| `southwest.png` | toward-left/down-left | front three-quarter; readable eyes and nose direction |
| `west.png` | left | true profile; one visible eye when unobscured |
| `northwest.png` | away-left/up-left | rear three-quarter; little or no frontal face |

Treat direction semantics as visual requirements, not instructions to erase facial features. If a diagonal source reads frontal, regenerate that source.

## Two-Pass Generation Pattern

For the high-detail pass, request one isolated full-body character, one exact direction, a fixed top-down camera, identical neutral pose, consistent proportions, and a transparent background. Supply the approved identity anchor and, when supported, the nearest approved direction.

For the pseudo-pixel pass, transform only that approved direction. Require large coherent square pixel clusters aligned to one repeated grid, hard nearest-neighbor-like edges, no antialiasing, no painterly texture, unchanged anatomy and costume, and transparent background. Do not ask the model to redesign the character.

Image generators may return RGB images with a baked checkerboard despite a transparency request. Keep the raw file, record the mode, and let the processor recover only corner-connected neutral matte pixels. Visually inspect pale costume edges after recovery.

## Processor

The script has PEP 723 dependencies and is intended to run with `uv`:

```sh
uv run scripts/build_topdown_8dir.py \
  --pseudo-dir /absolute/path/to/pseudo-pixel-directions \
  --output-root /absolute/path/to/output \
  --artifact-slug character-idle-8dir-64 \
  --frame-size 64 \
  --target-visible-height 52 \
  --height-tolerance 1 \
  --target-bottom 61 \
  --colors 32
```

The automatic calibration begins with `--grid 64`, measures each recovered visible height, and makes an integer grid correction with refinement fixed at zero. To reproduce an approved calibration exactly, pass overrides:

```sh
--grid-overrides north=64,northeast=67,east=61,southeast=68,south=64,southwest=64,west=69,northwest=67
```

The processor must fail rather than rescale when a recovered sprite cannot fit the requested canvas or bottom contact.

## Expected Output

- `working/source-transparent/`: alpha-preserved or audited matte-recovered sources;
- `working/perfect-pixel/`: selected logical-pixel recovery for each direction;
- `working/final-frames/`: shared-palette, binary-alpha frames placed 1:1;
- `generated/<slug>.png`: 4x2 sheet in canonical direction order;
- `generated/<slug>.json`: frame rectangles, pivots, palette, hashes, and processing facts;
- `generated/<slug>-audit.json`: machine checks and measurements;
- `evidence/background-extraction.json`: raw-mode and matte-recovery evidence;
- `evidence/perfect-pixel-grid-metrics.json`: every calibration trial and selected grid;
- contact sheet, head crops, and rotation GIF under `evidence/`.

## Acceptance

Automated acceptance requires eight nonempty frames of the requested size, canonical direction order, binary alpha, palette within the requested limit, common bottom contact, every visible height within tolerance, zero post-recovery resampling, bounded recovery grids, and deterministic hashes on repetition.

Human acceptance checks identity, angle readability, face integrity, costume continuity, silhouette mass, native-size readability, and motion continuity in the rotation GIF. Record source-level limitations separately from processing defects.

For an animation, first approve one eight-direction identity and idle baseline. Then repeat the same contract per animation frame or key pose; keep direction ordering, pivot, palette, and no-resampling rules unchanged.
