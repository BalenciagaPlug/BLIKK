"""Validate the isolated Training Katana V3.1 proof."""

from pathlib import Path
import bpy


ROOT = Path(__file__).resolve().parent
EXPECTED_REFERENCES = {"GripAttachment", "BladeBase", "BladeTip", "Trail0", "Trail1"}


def main():
    root = bpy.data.objects.get("BLIKK_TRAINING_KATANA_V3_1")
    if root is None or not root.get("BLIKK_OriginalAsset"):
        raise RuntimeError("Missing Katana V3.1 root")
    if root.get("BLIKK_AssetVersion") != "3.1":
        raise RuntimeError("Incorrect asset version")
    if (root.get("BLIKK_GripToTip"), root.get("BLIKK_BladeFaceAxis"),
            root.get("BLIKK_CuttingEdgeAxis")) != ("+Y", "+X", "-Z"):
        raise RuntimeError("Katana canonical basis changed")
    if root.get("BLIKK_RuntimeIntegrated") is not False:
        raise RuntimeError("Proof must not claim runtime integration")
    if abs(float(root.get("BLIKK_OverallLengthStuds", 0)) - 2.82) > 0.01:
        raise RuntimeError("Katana scale contract changed")

    references = {obj.name for obj in root.children if obj.get("BLIKK_Reference")}
    if references != EXPECTED_REFERENCES:
        raise RuntimeError(f"Reference mismatch: {sorted(references)}")
    meshes = [obj for obj in root.children_recursive if obj.type == "MESH"]
    if len(meshes) < 20:
        raise RuntimeError(f"Detail regression: only {len(meshes)} mesh objects")
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    for obj in meshes:
        if not obj.data.materials or not obj.data.uv_layers:
            raise RuntimeError(f"Material/UV contract failed: {obj.name}")
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    budget = int(root.get("BLIKK_TriangleBudget", 0))
    if triangles < 1500 or triangles > budget:
        raise RuntimeError(f"Triangle range failed: {triangles} / {budget}")

    paths = [
        ROOT / "Models" / "BLIKK_TRAINING_KATANA_V3_1.glb",
        ROOT / "Textures" / "TrainingKatana_V3_1_BaseColor.png",
        ROOT / "Previews" / "KATANA_V3_1_SIDE.png",
        ROOT / "Previews" / "KATANA_V3_1_FRONT_3Q.png",
        ROOT / "Previews" / "KATANA_V3_1_REAR_3Q.png",
        ROOT / "Previews" / "KATANA_V3_1_BLOCK_R15_SCALE.png",
    ]
    for path in paths:
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Missing artifact: {path.name}")
    if any(obj.type == "ARMATURE" for obj in root.children_recursive):
        raise RuntimeError("Model proof unexpectedly contains an armature")
    print(f"BLIKK_KATANA_V3_1_VALIDATION_OK Meshes={len(meshes)} Triangles={triangles} Budget={budget}")


if __name__ == "__main__":
    main()
