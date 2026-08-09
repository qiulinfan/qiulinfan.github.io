# Asset Records

Use these compact records to keep design intent, web claims, downloaded evidence, and engine results separate. Store project-specific records in the target game repository when acquisition or import occurs.

## Demand Record

```yaml
asset_role: clerk_semantic_animation
source_refs: []
priority: vertical_slice
gameplay_function: communicate or execute a rule-authorized action
theme_role: bureaucratic authority expressed through controlled gestures
visual_requirements: low-poly humanoid motion readable at conversational distance
functional_requirements:
  animation_verbs: [sit_down, seated_idle, stand_up, point, push]
technical_requirements:
  engine: Unity
  rig: humanoid_or_verified_retargetable
  preferred_formats: [fbx, glb]
license_requirements: commercial_use_and_modification_allowed
assumptions: []
open_questions: []
```

## Candidate Record

```yaml
asset_name: ""
creator: ""
source_url: ""
source_kind: official_creator_page
version_or_date: ""
price: free
license:
  name: ""
  url: ""
  attribution: ""
  commercial_use: unknown
  modification: unknown
  redistribution: unknown
declared_contents:
  formats: []
  animation_verbs: []
  root_motion: unknown
  engine_support: []
fit:
  visual: ""
  theme: ""
  functional: ""
  technical: ""
  license: ""
  adaptation_cost: ""
unverified_after_download: []
```

## Acquisition Record

```yaml
retrieved_at: ""
source_url: ""
archive_filename: ""
archive_size_bytes: 0
sha256: ""
audit_report: ""
license_files: []
actual_formats: []
unexpected_contents: []
selected_subset: []
rejected_files: []
```

## Unity Import Record

```yaml
project: ""
unity_version: ""
destination: ""
imported_files: []
created_assets: []
import_settings:
  scale: ""
  rig: ""
  materials: ""
  textures: ""
modifications: []
validation:
  editor_import: pending
  console_errors: unknown
  prefab_or_scene: pending
  animation_retarget: not_applicable
  visual_evidence: ""
remaining_risks: []
```

For animation libraries, set `animation_retarget` to `passed`, `failed`, or `pending`; never infer it from compatible-format claims.
