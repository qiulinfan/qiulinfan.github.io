---
name: search-game-art
description: Read a game design brief, turn visual, thematic, gameplay, animation, and technical needs into an asset requirement matrix, then search for source- and license-verified game art. Use for 2D or 3D models, textures, materials, icons, UI, animation, VFX, fonts, or environment kits when appearance and functional coverage must both fit. In selection mode, return a ranked shortlist without downloading. When the user explicitly asks to acquire or import assets, audit the actual files, stage only the needed subset, preserve provenance, and hand Unity integration to the project scene workflow.
---

# Search Game Art

Find assets that support the game design, not merely assets that resemble a reference image. Treat visual fit, thematic role, gameplay function, animation coverage, technical compatibility, and license as separate requirements.

## Choose the Mode

Use the least invasive mode authorized by the user:

- **Selection mode**: search, verify, compare, and recommend. Do not download or import.
- **Acquisition mode**: when the user explicitly asks to download, acquire, or import, also audit the selected files and stage the smallest useful subset.
- **Unity integration mode**: when the user explicitly asks to put the asset into a Unity project or scene, use `$build-unity-scene` for project-aware import, configuration, placement, and validation after this Skill completes source, license, and file auditing.

Do not convert a search request into an import. Do not treat permission to download one candidate as permission to purchase paid content or accept a custom license.

## Read the Design Source Hierarchy

Read the project's authoritative design, art, level, interaction, and technical documents before searching. Resolve conflicts according to the project's documented source hierarchy. Separate:

- confirmed requirements from source documents;
- synthesis that combines multiple confirmed facts;
- assumptions needed to proceed;
- open questions that materially affect selection.

Do not turn an example, mood reference, or brainstorm into a mandatory requirement.

## Build an Asset Requirement Matrix

Create one row per asset role or animation family. Use the demand-record schema in [references/asset-records.md](references/asset-records.md).

For each row, capture:

- gameplay function and player-visible feedback;
- narrative or thematic role;
- visual style, mood, palette, silhouette, and camera distance;
- required pieces, variants, states, and estimated quantity;
- required animation verbs and transitions;
- engine, render pipeline, format, scale, rig, shader, and texture constraints;
- performance budget and target platform;
- acceptable license, attribution burden, and budget;
- priority: current vertical slice, near-term reusable, or speculative.

Animation verbs must be semantic and testable, such as `sit_down`, `seated_idle`, `stand_up`, `point`, `push`, `open_door`, or `carry`. Do not accept the label “animated” as coverage.

## Search by Coverage

Use internet search because availability, versions, prices, and licenses can change. Prefer original asset pages and official creator repositories.

Search each high-priority row across multiple axes:

```text
<gameplay function> + <visual style> + <dimension> + <engine/format>
<animation verb family> + humanoid + FBX/GLB + Unity
<thematic object> + low poly + CC0
<reference style> + modular kit
```

Useful source categories include public-domain or CC0 libraries, creator-owned asset sites, official marketplaces, original repositories, and reputable open-game-art communities.

Do not use image thumbnails, re-upload sites, compilation blogs, search snippets, or AI summaries as proof of permission or file contents.

## Verify Declared Evidence

Open the original page for every serious candidate and record:

- asset name, creator, source page, version, and publication/update date;
- license name, license URL, attribution, commercial use, modification, redistribution, share-alike, non-commercial, and AI-use restrictions;
- price and whether the free download is genuinely available;
- the exact edition, tier, or sub-package covered by each headline claim;
- declared formats, engine support, render pipeline, polygon count, texture size, rig, animation list, root-motion behavior, and modular contents;
- visual fit, functional coverage, and likely adaptation work.

If the source and license disagree, permission is unclear, or the only evidence is a re-upload, exclude the candidate from the recommended shortlist. Prefer CC0 for prototypes. Treat CC BY, share-alike, and marketplace licenses as explicit tradeoffs. Do not recommend non-commercial assets for a potentially commercial project.

## Compare Candidates

Return three to eight strong candidates when the user asks for a broad shortlist. A focused acquisition pass may use one primary candidate and one fallback.

Score each candidate independently on:

| Dimension | Question |
| --- | --- |
| Visual fit | Does the silhouette, mood, palette, and camera-distance readability fit? |
| Theme fit | Does the asset reinforce the narrative or rule language of the scene? |
| Functional coverage | Does it contain the exact pieces, states, and animation verbs required? |
| Technical fit | Will format, scale, rig, shaders, textures, and performance work? |
| License fit | Can the project use, modify, and ship it with an acceptable burden? |
| Adaptation cost | How much remodeling, retexturing, retargeting, or setup remains? |

Recommend one primary candidate and one fallback. Do not select from aesthetics alone. Prefer an asset that closes a current gameplay gap over a large pack whose useful contents are speculative.

## Audit Acquired Files

In acquisition mode, download to a temporary directory first. Do not import an archive directly into the project.

1. Record the source URL, retrieval date, filename, size, and SHA-256.
2. Run `python scripts/audit_artifact.py <archive-or-directory>` before extraction.
3. Reject unsafe archive paths, unexpected executables, missing license evidence, or contents that materially contradict the source page.
4. Extract into a dedicated temporary directory and inventory the actual formats and candidate license files.
5. For `.blend`, `.fbx`, `.glb`, or `.gltf` files, run Blender headlessly with `scripts/blender_asset_inventory.py` when rig, mesh, material, image, or animation facts matter.
6. Import only the files needed for the selected requirement rows. Avoid copying redundant source formats, previews, unrelated variants, or an entire large pack by default.

The source page is declared evidence; the downloaded archive and imported files are audited evidence. Keep both and report discrepancies.

Marketing totals may combine free, paid, source, or add-on tiers. Count the actions, models, and variants in the exact acquired package before claiming coverage.

## Apply the Animation Gate

For animated 3D assets, verify the following before claiming production readiness:

- an actual armature exists and has a plausible bone hierarchy;
- actions contain pose-bone curves rather than only object transforms;
- the exact required animation verbs exist, including transitions where needed;
- clips are looping or one-shot as intended;
- frame rate and clip ranges are sane;
- root-motion and in-place variants are identified;
- humanoid or generic rig type is known;
- retarget compatibility is tested against the intended character, not inferred from marketing copy;
- scale, forward axis, foot sliding, hand contact, and prop alignment are checked in engine.

An animation library may be imported as `pending retarget validation`, but do not describe it as integrated with a character until a retarget test passes.

## Preserve Provenance

Use the acquisition and import record schemas in [references/asset-records.md](references/asset-records.md). Keep the original license text or a source snapshot when redistribution permits it. Record:

- original source and creator;
- license and attribution obligations;
- downloaded archive hash;
- files actually imported;
- local renames, conversions, material changes, or other modifications;
- unresolved compatibility risks.

Do not place credentials, purchase receipts, cookies, or personal account data in the project.

## Integrate with Unity

When Unity integration is requested, hand the audited candidate and import record to `$build-unity-scene`. That workflow must inspect the project architecture, place third-party files under the project's established asset structure, configure importer settings, create only useful prefabs/materials/controllers, and validate in the Editor.

Do not destabilize a working character or scene merely to test a new rig. Prefer a duplicate prefab, isolated validation scene, or staged asset marked pending compatibility when a reversible test is available.

## Improve This Skill from Real Runs

After a real search or import pass, update this Skill only with generalizable findings: new evidence gates, reusable record fields, or repeatable audit steps. Keep project-specific asset choices and one-off URLs in the target project's provenance records, not in this Skill.

For a material Skill change, follow the repository's Skill maintenance rules, update discovery/catalog/workflow documentation when behavior changed, validate with the active `skill-creator` validator, run `git diff --check`, and inspect the diff.

## Handoff

Match user-facing explanations, prompts, and handoffs to the user's language unless the user requests another language. Keep commands, identifiers, structured keys/action codes, and raw errors unchanged.

In selection mode, provide the requirement matrix, ranked comparison, recommendation, fallback, license obligations, and post-download checks. End with `Search only: no files downloaded or imported.`

In acquisition or Unity integration mode, provide the selected requirements, downloaded archive hashes, audited contents, imported files, provenance locations, validation evidence, and remaining compatibility risks. Never claim that an asset was imported, animated, or retargeted without corresponding evidence.
