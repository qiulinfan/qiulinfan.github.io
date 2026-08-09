#!/usr/bin/env python3
"""Inventory meshes, rigs, materials, images, and actions inside Blender."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset", type=Path, help=".blend, .fbx, .glb, or .gltf to open/import")
    parser.add_argument("--output", type=Path, help="Optional JSON output path")
    return parser.parse_args(argv)


def load_asset(path: Path) -> None:
    suffix = path.suffix.lower()
    if suffix == ".blend":
        bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
        return
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    if suffix == ".fbx":
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(path.resolve()))
    elif suffix in {".glb", ".gltf"}:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(path.resolve()))
    else:
        raise ValueError(f"Unsupported asset extension: {suffix}")


def action_record(action: bpy.types.Action) -> dict[str, object]:
    paths: list[str] = []
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for bag in getattr(strip, "channelbags", []):
                paths.extend(curve.data_path for curve in getattr(bag, "fcurves", []))
    if not paths and hasattr(action, "fcurves"):
        paths.extend(curve.data_path for curve in action.fcurves)
    return {
        "name": action.name,
        "frame_range": [float(action.frame_range[0]), float(action.frame_range[1])],
        "curve_count": len(paths),
        "has_pose_bone_curves": any(path.startswith('pose.bones["') for path in paths),
        "has_object_transform_curves": any(path in {"location", "rotation_euler", "rotation_quaternion", "scale"} for path in paths),
    }


def build_inventory(asset: Path | None) -> dict[str, object]:
    objects = list(bpy.data.objects)
    meshes = [obj for obj in objects if obj.type == "MESH"]
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    return {
        "asset": str(asset.resolve()) if asset else bpy.data.filepath,
        "blender_version": bpy.app.version_string,
        "scene_fps": bpy.context.scene.render.fps,
        "objects": {kind: sum(1 for obj in objects if obj.type == kind) for kind in sorted({obj.type for obj in objects})},
        "meshes": [
            {
                "name": obj.name,
                "vertices": len(obj.data.vertices),
                "edges": len(obj.data.edges),
                "polygons": len(obj.data.polygons),
                "dimensions": [float(value) for value in obj.dimensions],
                "material_slots": [slot.material.name if slot.material else None for slot in obj.material_slots],
            }
            for obj in meshes
        ],
        "armatures": [
            {
                "name": obj.name,
                "bone_count": len(obj.data.bones),
                "bones": [bone.name for bone in obj.data.bones],
            }
            for obj in armatures
        ],
        "materials": sorted(material.name for material in bpy.data.materials),
        "images": sorted({image.filepath or image.name for image in bpy.data.images}),
        "action_count": len(bpy.data.actions),
        "actions": [action_record(action) for action in sorted(bpy.data.actions, key=lambda item: item.name)],
    }


def main() -> int:
    args = parse_args()
    if args.asset:
        load_asset(args.asset)
    result = build_inventory(args.asset)
    payload = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    print(payload, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
