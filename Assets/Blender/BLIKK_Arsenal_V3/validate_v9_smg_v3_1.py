"""Validate the isolated BLIKK V9 SMG V3.1 proof."""

from pathlib import Path
import bpy


ROOT = Path(__file__).resolve().parent
EXPECTED_REFERENCES = {
    "GripAttachment", "MuzzleAttachment", "StockPivot", "MagazinePivot",
    "ShellEjectAttachment",
}


def main():
    root = bpy.data.objects.get("BLIKK_V9_SMG_V3_1")
    if root is None or not root.get("BLIKK_OriginalAsset"):
        raise RuntimeError("Missing V9 SMG V3.1 root")
    if root.get("BLIKK_AssetVersion") != "3.1":
        raise RuntimeError("Incorrect V9 asset version")
    basis = (root.get("BLIKK_CanonicalForward"), root.get("BLIKK_CanonicalUp"),
             root.get("BLIKK_CanonicalRight"))
    if basis != ("-Z", "+Y", "+X"):
        raise RuntimeError(f"V9 basis changed: {basis}")
    if root.get("BLIKK_RuntimeIntegrated") is not False:
        raise RuntimeError("V9 proof must not claim runtime integration")
    if abs(float(root.get("BLIKK_OverallLengthStuds", 0)) - 2.64) > 0.01:
        raise RuntimeError("V9 length contract changed")
    if float(root.get("BLIKK_MaximumWidthStuds", 0)) > 0.38:
        raise RuntimeError("V9 width contract exceeded")
    references = {obj.name for obj in root.children if obj.get("BLIKK_Reference")}
    if references != EXPECTED_REFERENCES:
        raise RuntimeError(f"Reference mismatch: {sorted(references)}")

    meshes = [obj for obj in root.children_recursive if obj.type == "MESH"]
    if len(meshes) < 30:
        raise RuntimeError(f"Detail regression: only {len(meshes)} mesh objects")
    triangles = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        if not obj.data.materials or not obj.data.uv_layers:
            raise RuntimeError(f"Material/UV contract failed: {obj.name}")
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    budget = int(root.get("BLIKK_TriangleBudget", 0))
    if triangles < 2200 or triangles > budget:
        raise RuntimeError(f"Triangle range failed: {triangles} / {budget}")
    if any(obj.type == "ARMATURE" for obj in root.children_recursive):
        raise RuntimeError("V9 proof unexpectedly contains an armature")

    for path in (
        ROOT / "Models" / "BLIKK_V9_SMG_V3_1.glb",
        ROOT / "Previews" / "V9_SMG_V3_1_SIDE.png",
        ROOT / "Previews" / "V9_SMG_V3_1_FRONT_3Q.png",
        ROOT / "Previews" / "V9_SMG_V3_1_REAR_3Q.png",
        ROOT / "Previews" / "V9_SMG_V3_1_BLOCK_R15_SCALE.png",
    ):
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Missing artifact: {path.name}")
    print(f"BLIKK_V9_SMG_V3_1_VALIDATION_OK Meshes={len(meshes)} "
          f"Triangles={triangles} Budget={budget}")


if __name__ == "__main__":
    main()
