"""Static Blender-side validation for the isolated B-8 V3 proof."""

from pathlib import Path
import bpy


ROOT = Path(__file__).resolve().parent
EXPECTED_REFERENCES = {"GripAttachment", "ForegripAttachment", "MuzzleAttachment", "StockPivot"}


def main():
    root = bpy.data.objects.get("BLIKK_B8_BREAKSHOT_V3_1")
    if root is None or not root.get("BLIKK_OriginalAsset"):
        raise RuntimeError("Missing V3 asset root")
    if root.get("BLIKK_AssetVersion") != "3.1":
        raise RuntimeError("Incorrect asset version")
    if (root.get("BLIKK_CanonicalForward"), root.get("BLIKK_CanonicalUp"),
            root.get("BLIKK_CanonicalRight")) != ("-Z", "+Y", "+X"):
        raise RuntimeError("Canonical basis changed")
    if root.get("BLIKK_RuntimeIntegrated") is not False:
        raise RuntimeError("Proof asset must not claim runtime integration")

    meshes = [obj for obj in root.children_recursive if obj.type == "MESH"]
    references = {obj.name for obj in root.children if obj.get("BLIKK_Reference")}
    if references != EXPECTED_REFERENCES:
        raise RuntimeError(f"Reference mismatch: {sorted(references)}")
    if len(meshes) < 45:
        raise RuntimeError(f"Mechanical detail regression: only {len(meshes)} mesh objects")

    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    for obj in meshes:
        if not obj.data.materials:
            raise RuntimeError(f"Missing material: {obj.name}")
        if not obj.data.uv_layers:
            raise RuntimeError(f"Missing UV map: {obj.name}")
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    budget = int(root.get("BLIKK_TriangleBudget", 0))
    if triangles < 4000:
        raise RuntimeError(f"V3 proof lacks required hard-surface density: {triangles}")
    if triangles > budget:
        raise RuntimeError(f"Triangle budget exceeded: {triangles} > {budget}")

    if abs(float(root.get("BLIKK_OverallLengthStuds", 0)) - 3.22) > 0.01:
        raise RuntimeError("Slim length contract changed")
    if float(root.get("BLIKK_MaximumWidthStuds", 99)) > 0.45:
        raise RuntimeError("Slim width contract changed")

    export = ROOT / "Models" / "BLIKK_B8_BREAKSHOT_V3_1.glb"
    texture = ROOT / "Textures" / "B8_V3_1_BaseColor.png"
    previews = [
        ROOT / "Previews" / "B8_V3_1_SIDE.png",
        ROOT / "Previews" / "B8_V3_1_FRONT_3Q.png",
        ROOT / "Previews" / "B8_V3_1_REAR_3Q.png",
        ROOT / "Previews" / "B8_V3_1_BLOCK_R15_SCALE.png",
    ]
    for path in [export, texture, *previews]:
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Missing or empty artifact: {path.name}")

    forbidden = [obj.name for obj in root.children_recursive if obj.type in {"SCRIPT", "ARMATURE"}]
    if forbidden:
        raise RuntimeError(f"Unexpected executable/rig content: {forbidden}")

    print(f"BLIKK_B8_V3_VALIDATION_OK Meshes={len(meshes)} Triangles={triangles} Budget={budget}")


if __name__ == "__main__":
    main()
