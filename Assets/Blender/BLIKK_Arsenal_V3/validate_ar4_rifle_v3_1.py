"""Validate the isolated BLIKK AR4 rifle V3.1 proof."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parent
EXPECTED={"GripAttachment","ForegripAttachment","MuzzleAttachment","StockPivot",
          "MagazinePivot","ShellEjectAttachment"}

def main():
    root=bpy.data.objects.get("BLIKK_AR4_RIFLE_V3_1")
    if root is None or not root.get("BLIKK_OriginalAsset"): raise RuntimeError("Missing AR4 root")
    if root.get("BLIKK_AssetVersion")!="3.1": raise RuntimeError("Incorrect AR4 version")
    basis=(root.get("BLIKK_CanonicalForward"),root.get("BLIKK_CanonicalUp"),root.get("BLIKK_CanonicalRight"))
    if basis!=("-Z","+Y","+X"): raise RuntimeError(f"AR4 basis changed: {basis}")
    if root.get("BLIKK_RuntimeIntegrated") is not False: raise RuntimeError("AR4 must remain isolated")
    if abs(float(root.get("BLIKK_OverallLengthStuds",0))-3.46)>.01: raise RuntimeError("AR4 length changed")
    if float(root.get("BLIKK_MaximumWidthStuds",0))>.43: raise RuntimeError("AR4 width exceeded")
    refs={obj.name for obj in root.children if obj.get("BLIKK_Reference")}
    if refs!=EXPECTED: raise RuntimeError(f"Reference mismatch: {sorted(refs)}")
    meshes=[obj for obj in root.children_recursive if obj.type=="MESH"]
    if len(meshes)<38: raise RuntimeError(f"Detail regression: {len(meshes)} meshes")
    triangles=0; depsgraph=bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        if not obj.data.materials or not obj.data.uv_layers: raise RuntimeError(f"Material/UV failed: {obj.name}")
        evaluated=obj.evaluated_get(depsgraph); mesh=evaluated.to_mesh(); mesh.calc_loop_triangles()
        triangles+=len(mesh.loop_triangles); evaluated.to_mesh_clear()
    budget=int(root.get("BLIKK_TriangleBudget",0))
    if triangles<3000 or triangles>budget: raise RuntimeError(f"Triangles failed: {triangles}/{budget}")
    if any(obj.type=="ARMATURE" for obj in root.children_recursive): raise RuntimeError("Unexpected armature")
    for path in (ROOT/"Models"/"BLIKK_AR4_RIFLE_V3_1.glb",
        ROOT/"Previews"/"AR4_RIFLE_V3_1_SIDE.png",ROOT/"Previews"/"AR4_RIFLE_V3_1_FRONT_3Q.png",
        ROOT/"Previews"/"AR4_RIFLE_V3_1_REAR_3Q.png",ROOT/"Previews"/"AR4_RIFLE_V3_1_BLOCK_R15_SCALE.png"):
        if not path.is_file() or path.stat().st_size==0: raise RuntimeError(f"Missing {path.name}")
    print(f"BLIKK_AR4_RIFLE_V3_1_VALIDATION_OK Meshes={len(meshes)} Triangles={triangles} Budget={budget}")

if __name__=="__main__": main()
