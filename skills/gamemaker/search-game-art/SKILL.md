---
name: search-game-art
description: Search the web for game art assets and produce a source- and license-verified shortlist without downloading or importing files. Use when an art agent needs candidate 2D or 3D models, textures, materials, icons, UI packs, animations, VFX, fonts, or environment kits for a game; when a placeholder needs an open or commercially usable replacement; or when the team needs options compared by visual fit, technical fit, license, attribution, format, and scope. This initial skill is search-only.
---

# Search Game Art

Find viable art candidates and make their legal and technical tradeoffs explicit. Do not download, import, edit, or commit assets in this initial version.

## Build the Search Brief

Read the relevant design, art, level, and technical documents before searching.

Extract or infer:

- gameplay function and where the asset appears;
- 2D or 3D, camera distance, and target platform;
- visual style, mood, palette, and reference works;
- required pieces and estimated quantity;
- file formats, rig, animation, texture, shader, and render-pipeline needs;
- performance constraints such as polygon count or texture resolution;
- acceptable license and attribution burden;
- budget and whether paid candidates are allowed.

Mark inferred requirements as assumptions. Do not turn an example reference into a mandatory style.

## Search

Use internet search because availability, versions, and licenses can change.

Prioritize original asset pages and official creator repositories. Useful source categories include:

- public-domain or CC0 libraries;
- creator-owned asset sites;
- official marketplace listings;
- original GitHub or project repositories;
- reputable open-game-art communities.

Search with multiple axes:

```text
<asset function> + <style> + <dimension> + <engine/format>
<asset function> + CC0
<asset function> + CC BY + Unity
<reference style> + modular kit
```

Do not rely on image-search thumbnails, re-upload sites, compilation blogs, or search snippets as proof of permission.

## Verify Each Candidate

Open the original page and record:

- asset name;
- creator or organization;
- source page;
- current version or publication/update date when available;
- license name and license URL;
- attribution requirement;
- commercial-use and modification status;
- redistribution, share-alike, non-commercial, or AI-training restrictions;
- download format;
- Unity and render-pipeline compatibility;
- polygon count, texture size, rig, animations, modular pieces, or other relevant specifications;
- visual fit and likely adaptation work.

If the page and included license disagree, flag the conflict. If permission is unclear, exclude the asset from the recommended shortlist.

Prefer CC0 for prototypes. CC BY can be recommended when attribution is acceptable. Do not recommend NC assets for a potentially commercial project. Treat SA and custom marketplace licenses as explicit tradeoffs, not equivalent to CC0.

## Compare

Return three to eight strong candidates rather than a long unfiltered catalog.

For each candidate, score:

| Dimension | Question |
| --- | --- |
| Visual fit | Does it support the requested mood and camera distance? |
| Coverage | Does the pack contain the pieces needed for the scene? |
| Technical fit | Will formats, shaders, scale, rig, and performance work? |
| License fit | Can the project use and modify it with an acceptable burden? |
| Adaptation cost | How much remodeling, retexturing, or setup is likely? |

Recommend one primary candidate and one fallback. Explain why; do not decide from aesthetics alone.

## Handoff

Provide:

- the search brief and assumptions;
- a ranked comparison table with direct source links;
- the recommended candidate and fallback;
- license and attribution obligations;
- missing information that must be checked after download;
- the exact files or sub-packages the importing agent should inspect;
- risks requiring art direction, legal review, or technical prototyping.

End with `Search only: no files downloaded or imported.`
