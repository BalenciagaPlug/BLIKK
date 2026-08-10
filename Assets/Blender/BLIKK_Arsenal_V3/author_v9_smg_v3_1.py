"""Build the original slim BLIKK V9 SMG V3.1 proof in Blender 4.5.

Basis: local -Z to muzzle, +Y up, +X weapon-right. This is an isolated
script-free art proof with no gameplay, animation, or runtime integration.
"""

from pathlib import Path
import math
import sys

import bpy


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
import author_b8_v3 as base

MODEL_DIR = ROOT / "Models"
PREVIEW_DIR = ROOT / "Previews"
MASTER_BLEND = ROOT / "BLIKK_V9_SMG_V3_1_Master.blend"


def reference(root, name, location):
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    empty.location = location
    empty.parent = root
    empty.empty_display_type = "PLAIN_AXES"
    empty["BLIKK_Reference"] = True


def tube_path(name, points_yz, radius, material, tile, parent):
    """Create an open mechanical tube in the side-profile YZ plane."""
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    curve.resolution_u = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points_yz) - 1)
    for point, (y, z) in zip(spline.points, points_yz):
        point.co = (0, y, z, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    return base.finish_mesh(obj, material, tile, 0.004, segments=1)


def create_smg(materials):
    steel, black, burgundy, brass = materials
    root = bpy.data.objects.new("BLIKK_V9_SMG_V3_1", None)
    bpy.context.collection.objects.link(root)
    root.empty_display_type = "ARROWS"
    root["BLIKK_OriginalAsset"] = True
    root["BLIKK_AssetVersion"] = "3.1"
    root["BLIKK_CanonicalForward"] = "-Z"
    root["BLIKK_CanonicalUp"] = "+Y"
    root["BLIKK_CanonicalRight"] = "+X"
    root["BLIKK_OverallLengthStuds"] = 2.64
    root["BLIKK_MaximumWidthStuds"] = 0.38
    root["BLIKK_TriangleBudget"] = 5600
    root["BLIKK_RuntimeIntegrated"] = False
    root["BLIKK_IntendedPresentation"] = "SINGLE_PROOF_DUAL_WIELD_CAPABLE"

    # Layered stamped receiver; no single rectangular Roblox mass.
    base.profile_x("ReceiverUpper", [(0.30, 0.48), (0.35, 0.30), (0.34, -0.54),
                   (0.22, -0.70), (0.03, -0.69), (-0.13, -0.52), (-0.12, 0.37),
                   (0.05, 0.49)], 0.36, steel, 0, 0.030, root)
    base.profile_x("ReceiverLower", [(0.06, 0.38), (0.10, -0.50), (-0.19, -0.52),
                   (-0.26, -0.33), (-0.22, 0.28)], 0.34, black, 1, 0.026, root)
    base.box("TopRib", (0, 0.355, -0.10), (0.20, 0.055, 1.05), black, 1,
             0.010, parent=root)
    base.box("RearCap", (0, 0.06, 0.51), (0.35, 0.44, 0.075), black, 1,
             0.018, parent=root)
    for side in (-1, 1):
        base.box(f"ReceiverSidePlate_{side}", (side * 0.190, 0.06, -0.08),
                 (0.025, 0.30, 0.72), black, 1, 0.008, parent=root)

    # Short shrouded barrel keeps the silhouette compact and front-heavy.
    base.profile_x("ForwardShroud", [(0.24, -0.48), (0.26, -1.05), (0.14, -1.20),
                   (-0.10, -1.16), (-0.18, -0.54)], 0.34, steel, 0, 0.030, root)
    base.cylinder("Barrel", (0, 0.07, -1.24), 0.075, 0.58, steel, 0, 18,
                  parent=root, bevel=0.008)
    base.cylinder("MuzzleCollar", (0, 0.07, -1.55), 0.090, 0.20, steel, 0, 18,
                  parent=root, bevel=0.010)
    base.cylinder("MuzzleBore", (0, 0.07, -1.655), 0.054, 0.025, black, 1, 18,
                  parent=root, bevel=0.002)
    for index in range(4):
        base.box(f"ShroudVent{index}", (0.183, 0.13, -0.63 - index * 0.135),
                 (0.018, 0.075, 0.070), burgundy, 2, 0.004, parent=root)

    # One-handed grip and angled magazine support a later dual-wield presentation.
    base.profile_x("PistolGrip", [(-0.10, 0.47), (-0.15, 0.30), (-0.48, 0.32),
                   (-0.58, 0.44), (-0.54, 0.56), (-0.18, 0.57), (-0.04, 0.51)],
                   0.21, black, 1, 0.028, root)
    for index in range(4):
        base.box(f"GripInset{index}", (0.108, -0.25 - index * 0.070,
                 0.50 + index * 0.012), (0.014, 0.026, 0.14), burgundy, 2,
                 0.004, (math.radians(-8), 0, 0), root)
    base.profile_x("Magazine", [(-0.16, -0.10), (-0.21, -0.48), (-1.06, -0.43),
                   (-1.15, -0.15), (-0.28, -0.01)], 0.27, burgundy, 2, 0.032, root)
    base.box("MagazineWell", (0, -0.20, -0.25), (0.29, 0.13, 0.34), steel, 0,
             0.018, parent=root)
    base.box("MagazineSpine", (0, -0.675, -0.29), (0.19, 0.83, 0.045), black, 1,
             0.008, (math.radians(-6), 0, 0), root)
    base.box("MagazineFloorplate", (0, -1.14, -0.29), (0.30, 0.055, 0.29), brass, 3,
             0.010, parent=root)
    tube_path("TriggerGuard", [(-0.16, 0.20), (-0.21, 0.08), (-0.36, 0.06),
              (-0.45, 0.16), (-0.43, 0.29)], 0.020, steel, 0, root)
    base.box("Trigger", (0.025, -0.28, 0.20), (0.045, 0.18, 0.038), brass, 3,
             0.005, (math.radians(-18), 0, 0), root)

    # Compact skeletal rear brace: period machinery without rifle length.
    base.box("StockUpperStrut", (0, 0.21, 0.70), (0.10, 0.075, 0.48), steel, 0,
             0.012, (math.radians(-4), 0, 0), root)
    base.box("StockLowerStrut", (0, -0.05, 0.68), (0.10, 0.075, 0.45), steel, 0,
             0.012, (math.radians(5), 0, 0), root)
    base.profile_x("StockPad", [(0.26, 0.87), (0.24, 1.00), (-0.25, 1.03),
                   (-0.31, 0.89), (-0.19, 0.82), (0.18, 0.82)],
                   0.30, burgundy, 2, 0.030, root)
    base.box("StockPadInset", (0, -0.01, 0.955), (0.31, 0.35, 0.045), black, 1,
             0.012, parent=root)

    # Readable controls and restrained BLIKK identifiers.
    base.box("EjectionPort", (0.197, 0.15, -0.23), (0.018, 0.13, 0.28), black, 1,
             0.006, parent=root)
    base.box("BoltFace", (0.208, 0.15, -0.23), (0.012, 0.075, 0.18), brass, 3,
             0.003, parent=root)
    base.box("ChargingHandle", (-0.215, 0.29, 0.15), (0.10, 0.055, 0.14), brass, 3,
             0.008, parent=root)
    base.box("RearSight", (0, 0.405, 0.36), (0.10, 0.105, 0.06), steel, 0,
             0.010, parent=root)
    base.box("FrontSight", (0, 0.310, -1.08), (0.065, 0.11, 0.055), brass, 3,
             0.008, parent=root)
    for side in (-1, 1):
        x = side * 0.202
        rotation = (0, math.radians(90), 0)
        base.screw(f"ReceiverPinFront_{side}", (x, 0.02, -0.43), rotation, brass, 3, root)
        base.screw(f"ReceiverPinRear_{side}", (x, 0.10, 0.31), rotation, steel, 0, root)
    base.box("V9Mark", (-0.205, 0.08, -0.12), (0.014, 0.055, 0.19), burgundy, 2,
             0.004, parent=root)
    for offset in (-0.05, 0.0, 0.05):
        base.box(f"V9MarkCut{offset}", (-0.214, 0.08, -0.12 + offset),
                 (0.008, 0.018, 0.020), brass, 3, 0.002, parent=root)

    for name, location in {
        "GripAttachment": (0, -0.28, 0.45),
        "MuzzleAttachment": (0, 0.07, -1.67),
        "StockPivot": (0, 0.09, 0.51),
        "MagazinePivot": (0, -0.19, 0.02),
        "ShellEjectAttachment": (0.22, 0.15, -0.23),
    }.items():
        reference(root, name, location)
    return root


def export_model(root):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(MODEL_DIR / "BLIKK_V9_SMG_V3_1.glb"),
        export_format="GLB", use_selection=True, export_apply=True,
        export_materials="EXPORT", export_yup=True, export_extras=True)


def configure_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 1000, 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (0.025, 0.028, 0.036)
    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.data.lens = 58
    scene.camera = camera
    floor_material = bpy.data.materials.new("ReviewFloor")
    floor_material.diffuse_color = (0.012, 0.014, 0.020, 1)
    base.box("ReviewFloor", (0, 0, -0.62), (14, 14, 0.08), floor_material, 1, 0)
    for name, location, energy, size, color in (
        ("Key", (4.5, 4.0, -3.0), 1600, 4.0, (0.62, 0.74, 1.0)),
        ("Rim", (-4.0, 2.0, 2.0), 1200, 3.0, (0.52, 0.14, 0.10)),
        ("Fill", (0.0, 5.0, 4.0), 1250, 5.0, (0.34, 0.28, 0.42)),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        light = bpy.data.objects.new(name, data)
        light.location = location
        bpy.context.collection.objects.link(light)
        base.look_at(light, (0, 0, -0.45))
    return scene, camera


def render_reviews(scene, camera, model, avatar):
    for item in [avatar, *avatar.children_recursive]:
        item.hide_render = True
    model.rotation_euler = (math.radians(90), 0, 0)
    views = {
        "V9_SMG_V3_1_SIDE": ((6.4, 0.0, 1.7), (0, 0, -0.10)),
        "V9_SMG_V3_1_FRONT_3Q": ((5.0, 5.2, 2.5), (0, 0, -0.10)),
        "V9_SMG_V3_1_REAR_3Q": ((-5.0, -5.2, 2.5), (0, 0, -0.10)),
    }
    for name, (location, target) in views.items():
        camera.location = location
        base.look_at(camera, target)
        scene.render.filepath = str(PREVIEW_DIR / f"{name}.png")
        bpy.ops.render.render(write_still=True)
    for item in [avatar, *avatar.children_recursive]:
        item.hide_render = False
    avatar.rotation_euler = (math.radians(90), 0, 0)
    model.rotation_euler = (math.radians(90), math.radians(-5), math.radians(-8))
    model.location = (0.68, -0.06, 1.70)
    camera.location = (7.8, 8.0, 4.4)
    base.look_at(camera, (0, 0, 1.42))
    scene.render.filepath = str(PREVIEW_DIR / "V9_SMG_V3_1_BLOCK_R15_SCALE.png")
    bpy.ops.render.render(write_still=True)


def main():
    base.clear_scene()
    atlas = bpy.data.images.load(str(ROOT / "Textures" / "B8_V3_1_BaseColor.png"))
    materials = (
        base.make_material("V9_BluedSteel", atlas, 0, 0.80, 0.27),
        base.make_material("V9_DarkPolymer", atlas, 1, 0.12, 0.47),
        base.make_material("V9_BurgundyComposite", atlas, 2, 0.10, 0.40),
        base.make_material("V9_WornHardware", atlas, 3, 0.66, 0.30),
    )
    model = create_smg(materials)
    avatar = base.create_review_avatar()
    export_model(model)
    scene, camera = configure_render()
    render_reviews(scene, camera, model, avatar)
    for item in [avatar, *avatar.children_recursive]:
        item.hide_viewport = True
        item.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER_BLEND))
    print("BLIKK_V9_SMG_V3_1_AUTHORING_OK")


if __name__ == "__main__":
    main()
