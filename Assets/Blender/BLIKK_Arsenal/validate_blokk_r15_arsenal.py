"""Static Blender-side validation for the BLIKK block-R15 authoring library."""

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parent
KEYED_BONES = {
    "UpperTorso",
    "RightUpperArm",
    "RightLowerArm",
    "RightHand",
    "LeftUpperArm",
    "LeftLowerArm",
}
EXPECTED_ACTIONS = {
    "KatanaEquip": 0.120,
    "KatanaSlash1": 0.300,
    "KatanaBlock": 0.180,
    "KatanaAltLaunch": 0.420,
    "ShotgunEquip": 0.100,
    "ShotgunFire": 0.160,
    "ShotgunReload": 0.760,
    "SMGEquip": 0.090,
    "SMGFire": 0.090,
    "SMGReload": 0.680,
    "RifleEquip": 0.105,
    "RifleFire": 0.110,
    "RifleReload": 0.820,
}
EXPECTED_MODELS = {
    "TrainingKatana_MK2": "TrainingKatana_MK2.glb",
    "BLIKK_B8_BREAKSHOT_MK2": "BLIKK_B8_BREAKSHOT_MK2.glb",
    "BLIKK_V9_SMG": "BLIKK_V9_SMG.glb",
    "BLIKK_AR4_RIFLE": "BLIKK_AR4_RIFLE.glb",
}


def keyed_bones(action):
    result = set()
    prefix = 'pose.bones["'
    for curve in action.fcurves:
        if curve.data_path.startswith(prefix):
            result.add(curve.data_path.split(prefix, 1)[1].split('"]', 1)[0])
    return result


def main():
    scene = bpy.context.scene
    fps = scene.render.fps / scene.render.fps_base
    depsgraph = bpy.context.evaluated_depsgraph_get()

    for name, duration in EXPECTED_ACTIONS.items():
        action = bpy.data.actions.get("BLIKK_" + name)
        if action is None:
            raise RuntimeError(f"Missing action: {name}")
        if keyed_bones(action) != KEYED_BONES:
            raise RuntimeError(f"{name} has unexpected keyed bones: {sorted(keyed_bones(action))}")
        actual_duration = action.frame_range[1] / fps
        if abs(actual_duration - duration) > 0.001:
            raise RuntimeError(f"{name} duration {actual_duration:.3f} != {duration:.3f}")
        export = ROOT / "Animations" / f"BLIKK_{name}_BlockR15.fbx"
        if not export.is_file() or export.stat().st_size == 0:
            raise RuntimeError(f"Missing or empty animation export: {export.name}")

    for root_name, filename in EXPECTED_MODELS.items():
        root = bpy.data.objects.get(root_name)
        if root is None or not root.get("BLIKK_OriginalAsset"):
            raise RuntimeError(f"Missing original model root: {root_name}")
        mesh_objects = [obj for obj in bpy.data.objects if obj.parent == root and obj.type == "MESH"]
        if not mesh_objects:
            raise RuntimeError(f"Model has no mesh children: {root_name}")
        triangle_count = 0
        for obj in mesh_objects:
            if not obj.data.materials:
                raise RuntimeError(f"Unmaterialed mesh in {root_name}: {obj.name}")
            evaluated = obj.evaluated_get(depsgraph)
            evaluated_mesh = evaluated.to_mesh()
            evaluated_mesh.calc_loop_triangles()
            triangle_count += len(evaluated_mesh.loop_triangles)
            evaluated.to_mesh_clear()
        budget = int(root.get("BLIKK_TriangleBudget", 0))
        if budget <= 0 or triangle_count > budget:
            raise RuntimeError(f"{root_name} triangles {triangle_count} exceed budget {budget}")
        export = ROOT / "Models" / filename
        if not export.is_file() or export.stat().st_size == 0:
            raise RuntimeError(f"Missing or empty model export: {filename}")
        print(f"{root_name}: Meshes={len(mesh_objects)} ExportTriangles={triangle_count} Budget={budget}")

    forbidden = {"Root", "HumanoidRootPart", "LowerTorso", "LeftUpperLeg", "LeftLowerLeg",
                 "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
    for action in bpy.data.actions:
        if action.name.startswith("BLIKK_") and keyed_bones(action) & forbidden:
            raise RuntimeError(f"{action.name} keys root or lower-body bones")

    print("BLIKK_ARSENAL_VALIDATION_OK")
    print(f"Actions={len(EXPECTED_ACTIONS)} Models={len(EXPECTED_MODELS)} KeyedBones={sorted(KEYED_BONES)}")


if __name__ == "__main__":
    main()
