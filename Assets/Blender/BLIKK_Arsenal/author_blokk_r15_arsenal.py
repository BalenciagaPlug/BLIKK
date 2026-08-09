"""Build BLIKK's original block-R15 weapon and animation authoring library.

Run from Roblox's official RoundMale.blend template with Blender 4.5. The official armature is
retained for compatibility while its round body is replaced in review renders by rigid block-R15
geometry. Models are original BLIKK designs; GunZ informs only compact silhouette, readability, and
cancel-friendly presentation timing.
"""

from __future__ import annotations

import importlib.util
import math
import os
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector


REPO_ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(os.environ.get("BLIKK_ARSENAL_OUTPUT", Path(__file__).resolve().parent))
HELPER_PATH = REPO_ROOT / "Animations" / "KatanaSlash1" / "author_katana_slash1.py"
MASTER_BLEND = OUTPUT / "BLIKK_BlockR15_Arsenal_Master.blend"
MODEL_DIR = OUTPUT / "Models"
ANIMATION_DIR = OUTPUT / "Animations"
PREVIEW_DIR = OUTPUT / "Previews"
FPS = 120

spec = importlib.util.spec_from_file_location("blikk_slash_helper", HELPER_PATH)
helper = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(helper)

ARMATURE_NAME = "Joints"
KEYED_BONES = (
    "UpperTorso",
    "RightUpperArm",
    "RightLowerArm",
    "RightHand",
    "LeftUpperArm",
    "LeftLowerArm",
)


def material(name, color, metallic=0.0, roughness=0.45, emission=None):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = 2.2
    return mat


MAT = {
    "skin": material("BLIKK_R15_Skin", (0.34, 0.16, 0.08, 1), 0.0, 0.72),
    "cloth": material("BLIKK_R15_Cloth", (0.018, 0.020, 0.025, 1), 0.0, 0.72),
    "denim": material("BLIKK_R15_Denim", (0.075, 0.105, 0.13, 1), 0.05, 0.74),
    "sole": material("BLIKK_R15_Sole", (0.62, 0.65, 0.68, 1), 0.05, 0.55),
    "black": material("BLIKK_Y2K_Black", (0.012, 0.014, 0.018, 1), 0.35, 0.32),
    "gunmetal": material("BLIKK_Y2K_Gunmetal", (0.08, 0.095, 0.12, 1), 0.78, 0.24),
    "steel": material("BLIKK_Y2K_Steel", (0.48, 0.53, 0.61, 1), 0.88, 0.17),
    "edge": material("BLIKK_Y2K_Edge", (0.88, 0.91, 0.96, 1), 0.92, 0.10),
    "purple": material("BLIKK_Y2K_Purple", (0.26, 0.035, 0.48, 1), 0.62, 0.20),
    "violet": material("BLIKK_Y2K_VioletGlow", (0.43, 0.05, 0.82, 1), 0.25, 0.18, (0.43, 0.05, 0.82, 1)),
    "acid": material("BLIKK_Y2K_Acid", (0.38, 0.82, 0.08, 1), 0.20, 0.22, (0.38, 0.82, 0.08, 1)),
    "blued": material("BLIKK_Y2K_BluedSteel", (0.025, 0.032, 0.045, 1), 0.84, 0.19),
    "polymer": material("BLIKK_Y2K_Polymer", (0.035, 0.040, 0.048, 1), 0.08, 0.48),
    "burgundy": material("BLIKK_Y2K_Burgundy", (0.16, 0.025, 0.028, 1), 0.18, 0.31),
    "brass": material("BLIKK_Y2K_Brass", (0.48, 0.29, 0.055, 1), 0.78, 0.20),
    "white": material("BLIKK_Y2K_Marking", (0.72, 0.76, 0.82, 1), 0.42, 0.22),
}


def make_collection(name):
    old = bpy.data.collections.get(name)
    if old:
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old)
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def link_only(obj, collection):
    for owner in tuple(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)


def box(collection, name, size, location, mat, rotation=(0, 0, 0), bevel=0.04, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("BLIKK_EdgeSoftening", "BEVEL")
        mod.width = min(bevel, min(size) * 0.18)
        mod.segments = 2
    obj.data.materials.append(mat)
    obj.parent = parent
    link_only(obj, collection)
    return obj


def cylinder(collection, name, radius, depth, location, mat, rotation=(math.pi / 2, 0, 0), vertices=16, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    link_only(obj, collection)
    return obj


def wedge(collection, name, length, width, height, location, mat, parent=None):
    verts = [
        (-width/2, 0, -height/2), (width/2, 0, -height/2),
        (-width/2, 0, height/2), (width/2, 0, height/2),
        (-width/2, length, -height*0.32), (width/2, length, -height*0.32),
        (-width/2, length, height*0.32), (width/2, length, height*0.32),
    ]
    faces = [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    obj.parent = parent
    collection.objects.link(obj)
    bevel = obj.modifiers.new("BLIKK_EdgeSoftening", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 2
    return obj


def profile_yz(collection, name, points, width, mat, parent=None, bevel=0.035):
    """Extrude an angular weapon side profile across local X."""
    half = width * 0.5
    verts = [(-half, y, z) for z, y in points] + [(half, y, z) for z, y in points]
    count = len(points)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.parent = parent
    collection.objects.link(obj)
    if bevel:
        modifier = obj.modifiers.new("BLIKK_EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    return obj


def profile_xy(collection, name, points, thickness, mat, parent=None, bevel=0.018):
    """Extrude a blade silhouette across local Z."""
    half = thickness * 0.5
    verts = [(x, y, -half) for x, y in points] + [(x, y, half) for x, y in points]
    count = len(points)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.parent = parent
    collection.objects.link(obj)
    if bevel:
        modifier = obj.modifiers.new("BLIKK_EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    return obj


def add_vent_row(collection, prefix, root, z_values, y, width, height, depth, mat):
    for index, z in enumerate(z_values):
        box(collection, f"{prefix}_{index:02d}", (width, height, depth), (0, y, z), mat,
            rotation=(math.radians(18), 0, 0), bevel=.008, parent=root)


def create_block_r15(armature):
    for obj in bpy.context.scene.objects:
        if obj.name.endswith("_Geo") or obj.name.endswith("_OuterCage") or obj.name.endswith("_Att"):
            obj.hide_render = True
            obj.hide_viewport = True
    collection = make_collection("BLIKK_BlockR15_Review")
    definitions = {
        "LowerTorso": ((1.72, 0.72, 0.88), MAT["cloth"]),
        "UpperTorso": ((2.05, 1.28, 1.02), MAT["cloth"]),
        "Head": ((1.46, 1.02, 1.04), MAT["skin"]),
        "RightUpperArm": ((0.61, 0.70, 0.64), MAT["skin"]),
        "RightLowerArm": ((0.57, 0.64, 0.60), MAT["skin"]),
        "RightHand": ((0.55, 0.34, 0.62), MAT["skin"]),
        "LeftUpperArm": ((0.61, 0.70, 0.64), MAT["skin"]),
        "LeftLowerArm": ((0.57, 0.64, 0.60), MAT["skin"]),
        "LeftHand": ((0.55, 0.34, 0.62), MAT["skin"]),
        "RightUpperLeg": ((0.82, 0.84, 0.86), MAT["denim"]),
        "RightLowerLeg": ((0.76, 0.89, 0.82), MAT["denim"]),
        "RightFoot": ((0.78, 0.52, 1.12), MAT["sole"]),
        "LeftUpperLeg": ((0.82, 0.84, 0.86), MAT["denim"]),
        "LeftLowerLeg": ((0.76, 0.89, 0.82), MAT["denim"]),
        "LeftFoot": ((0.78, 0.52, 1.12), MAT["sole"]),
    }
    for bone_name, (dims, mat) in definitions.items():
        bone = armature.data.bones[bone_name]
        center = (bone.head_local + bone.tail_local) * 0.5
        # Roblox's official skinned template keeps shoulder bones inside the
        # torso envelope. Classic block limbs need a small rigid outward
        # offset to match the silhouette of player avatars used in BLIKK.
        if bone_name.startswith("Right") and "Arm" in bone_name or bone_name == "RightHand":
            center.x -= .30
        elif bone_name.startswith("Left") and "Arm" in bone_name or bone_name == "LeftHand":
            center.x += .30
        y_axis = (bone.tail_local - bone.head_local).normalized()
        x_axis = Vector((1, 0, 0))
        x_axis -= y_axis * x_axis.dot(y_axis)
        if x_axis.length < 0.01:
            x_axis = Vector((0, 0, 1))
            x_axis -= y_axis * x_axis.dot(y_axis)
        x_axis.normalize()
        z_axis = x_axis.cross(y_axis).normalized()
        matrix = helper.basis_matrix(x_axis, y_axis, z_axis, center)
        obj = box(collection, "BLIKK_" + bone_name, dims, (0,0,0), mat, bevel=0.025)
        obj.matrix_world = armature.matrix_world @ matrix
        world = obj.matrix_world.copy()
        obj.parent = armature
        obj.parent_type = "BONE"
        obj.parent_bone = bone_name
        obj.matrix_world = world
    return collection


def root_empty(collection, name):
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "ARROWS"
    collection.objects.link(root)
    root["BLIKK_OriginalAsset"] = True
    root["BLIKK_CanonicalForward"] = "-Z"
    root["BLIKK_CanonicalUp"] = "+Y"
    return root


def create_katana():
    c = make_collection("MODEL_BLIKK_TrainingKatana_MK2")
    root = root_empty(c, "TrainingKatana_MK2")
    root["BLIKK_GripToTip"] = "+Y"
    cylinder(c, "HandleCore", .145, 1.04, (0, -.36, 0), MAT["polymer"],
             rotation=(math.pi/2,0,0), vertices=16, parent=root)
    for index in range(8):
        y = -.82 + index * .125
        cylinder(c, f"GripCollar_{index:02d}", .166, .035, (0, y, 0),
                 MAT["burgundy"] if index % 2 == 0 else MAT["purple"],
                 rotation=(math.pi/2,0,0), vertices=12, parent=root)
    cylinder(c, "Pommel", .205, .17, (0, -.93, 0), MAT["blued"],
             rotation=(math.pi/2,0,0), vertices=16, parent=root)
    cylinder(c, "PommelCap", .145, .035, (0, -1.035, 0), MAT["brass"],
             rotation=(math.pi/2,0,0), vertices=16, parent=root)
    cylinder(c, "GuardHub", .31, .085, (0, .185, 0), MAT["blued"],
             rotation=(math.pi/2,0,0), vertices=16, parent=root)
    profile_xy(c, "GuardWing", [(-.55,.13),(-.22,.08),(.22,.08),(.55,.13),(.34,.25),(-.34,.25)],
               .095, MAT["burgundy"], parent=root, bevel=.025)
    blade_points = [
        (-.18,.23),(-.23,.70),(-.27,1.35),(-.28,2.10),(-.25,2.85),(-.14,3.48),
        (.02,3.78),(.12,3.48),(.15,2.82),(.15,.23),
    ]
    profile_xy(c, "Blade", blade_points, .105, MAT["steel"], parent=root, bevel=.014)
    edge_points = [(-.23,.32),(-.275,1.35),(-.28,2.15),(-.245,2.85),(-.14,3.48),
                   (.02,3.78),(-.075,3.39),(-.12,2.80),(-.13,.32)]
    edge = profile_xy(c, "BladeEdge", edge_points, .112, MAT["edge"], parent=root, bevel=.006)
    edge.location.z = -.002
    profile_xy(c, "BladeFuller", [(0.035,.40),(0.065,.40),(0.065,3.18),(0.025,3.43),(-.005,3.14)],
               .116, MAT["purple"], parent=root, bevel=.004)
    profile_xy(c, "BladeMark", [(-.03,.40),(.04,.51),(-.03,.62),(-.10,.51)],
               .122, MAT["violet"], parent=root, bevel=.003)
    root["BLIKK_TriangleBudget"] = 3200
    return c, root


def create_shotgun():
    c = make_collection("MODEL_BLIKK_B8_BREAKSHOT_MK2")
    root = root_empty(c, "BLIKK_B8_BREAKSHOT_MK2")
    profile_yz(c, "Receiver", [(.42,.28),(-.46,.28),(-.58,.10),(-.43,-.31),(.28,-.31),(.48,-.10)],
               .68, MAT["blued"], parent=root, bevel=.055)
    profile_yz(c, "Stock", [(1.58,.22),(.38,.22),(.30,-.16),(.78,-.28),(1.50,-.48),(1.72,-.30)],
               .58, MAT["burgundy"], parent=root, bevel=.06)
    profile_yz(c, "StockInset", [(1.48,.12),(.54,.12),(.62,-.08),(1.45,-.31),(1.58,-.23)],
               .595, MAT["black"], parent=root, bevel=.018)
    profile_yz(c, "PistolGrip", [(.24,-.17),(-.03,-.22),(.12,-.94),(.47,-.91),(.55,-.30)],
               .34, MAT["polymer"], parent=root, bevel=.045)
    profile_yz(c, "TriggerGuard", [(.12,-.20),(-.25,-.18),(-.28,-.48),(.09,-.50)],
               .085, MAT["brass"], parent=root, bevel=.018)
    profile_yz(c, "BarrelShroud", [(-.38,.27),(-2.18,.25),(-2.34,.12),(-2.17,-.05),(-.42,-.06)],
               .56, MAT["gunmetal"], parent=root, bevel=.045)
    for x in (-.16,.16):
        cylinder(c, "BarrelLeft" if x < 0 else "BarrelRight", .105, 2.18,
                 (x,.16,-1.55), MAT["steel"], rotation=(0,0,0), vertices=16, parent=root)
        cylinder(c, "MuzzleRingLeft" if x < 0 else "MuzzleRingRight", .135, .10,
                 (x,.16,-2.66), MAT["brass"], rotation=(0,0,0), vertices=16, parent=root)
    profile_yz(c, "PumpForeEnd", [(-.82,.03),(-1.70,.01),(-1.78,-.30),(-.75,-.31)],
               .64, MAT["burgundy"], parent=root, bevel=.07)
    add_vent_row(c, "PumpRib", root, (-.88,-1.05,-1.22,-1.39,-1.56), -.12, .665, .035, .055, MAT["purple"])
    box(c, "ReceiverTopRail", (.38,.085,.86), (0,.34,-.05), MAT["black"], bevel=.012, parent=root)
    add_vent_row(c, "HeatVent", root, (-.72,-1.02,-1.32,-1.62,-1.92), .285, .34, .035, .10, MAT["black"])
    box(c, "EjectionPort", (.018,.20,.34), (.351,.08,-.12), MAT["brass"], bevel=.008, parent=root)
    box(c, "B8Mark", (.025,.10,.28), (-.351,.07,.08), MAT["violet"], bevel=.006, parent=root)
    box(c, "FrontSight", (.07,.11,.07), (0,.36,-2.54), MAT["acid"], bevel=.014, parent=root)
    root["BLIKK_RightHandGrip"] = "0,-0.38,0.24 / pitch 92deg"
    root["BLIKK_Foregrip"] = "0,-0.05,-1.27"
    root["BLIKK_Muzzle"] = "0,0.03,-2.64"
    root["BLIKK_TriangleBudget"] = 5200
    return c, root


def create_smg():
    c = make_collection("MODEL_BLIKK_V9_SMG")
    root = root_empty(c, "BLIKK_V9_SMG")
    profile_yz(c, "Receiver", [(.50,.28),(-.66,.28),(-.78,.10),(-.64,-.32),(.38,-.34),(.56,-.10)],
               .58, MAT["blued"], parent=root, bevel=.05)
    profile_yz(c, "ReceiverLower", [(.34,-.08),(-.48,-.08),(-.58,-.38),(.30,-.38)],
               .53, MAT["polymer"], parent=root, bevel=.035)
    profile_yz(c, "PistolGrip", [(.30,-.22),(-.02,-.27),(.10,-.92),(.40,-.90),(.50,-.34)],
               .31, MAT["polymer"], parent=root, bevel=.04)
    profile_yz(c, "Magazine", [(-.12,-.31),(-.42,-.32),(-.33,-1.22),(.02,-1.17)],
               .30, MAT["burgundy"], parent=root, bevel=.04)
    profile_yz(c, "Handguard", [(-.54,.18),(-1.15,.16),(-1.28,-.14),(-.56,-.19)],
               .56, MAT["gunmetal"], parent=root, bevel=.045)
    cylinder(c, "Barrel", .095, .72, (0,.08,-1.45), MAT["steel"], rotation=(0,0,0), vertices=16, parent=root)
    cylinder(c, "Muzzle", .15, .22, (0,.08,-1.90), MAT["black"], rotation=(0,0,0), vertices=14, parent=root)
    box(c, "StockStrutTop", (.10,.10,1.08), (0,.14,.94), MAT["steel"], rotation=(math.radians(-5),0,0), bevel=.025, parent=root)
    box(c, "StockStrutBottom", (.10,.10,.92), (0,-.13,.86), MAT["steel"], rotation=(math.radians(8),0,0), bevel=.025, parent=root)
    profile_yz(c, "StockPad", [(1.52,.28),(1.28,.27),(1.20,-.35),(1.50,-.42)],
               .48, MAT["burgundy"], parent=root, bevel=.055)
    box(c, "TopRail", (.34,.075,1.10), (0,.345,-.10), MAT["black"], bevel=.012, parent=root)
    add_vent_row(c, "HandguardVent", root, (-.67,-.84,-1.01), .205, .34, .035, .085, MAT["purple"])
    box(c, "V9Mark", (.025,.11,.30), (-.301,.08,.08), MAT["violet"], bevel=.005, parent=root)
    box(c, "FrontSight", (.065,.11,.07), (0,.34,-1.67), MAT["acid"], bevel=.012, parent=root)
    root["BLIKK_TriangleBudget"] = 4200
    return c, root


def create_rifle():
    c = make_collection("MODEL_BLIKK_AR4_RIFLE")
    root = root_empty(c, "BLIKK_AR4_RIFLE")
    profile_yz(c, "UpperReceiver", [(.55,.32),(-.78,.32),(-.96,.13),(-.72,-.10),(.46,-.10)],
               .60, MAT["blued"], parent=root, bevel=.05)
    profile_yz(c, "LowerReceiver", [(.42,-.04),(-.62,-.05),(-.55,-.42),(.20,-.48),(.50,-.24)],
               .56, MAT["gunmetal"], parent=root, bevel=.045)
    profile_yz(c, "Stock", [(1.82,.25),(.45,.23),(.38,-.08),(.90,-.20),(1.72,-.47),(1.92,-.30)],
               .57, MAT["polymer"], parent=root, bevel=.06)
    profile_yz(c, "StockCheek", [(1.63,.19),(.70,.18),(.82,-.01),(1.58,-.20),(1.76,-.15)],
               .585, MAT["burgundy"], parent=root, bevel=.025)
    profile_yz(c, "PistolGrip", [(.24,-.24),(-.04,-.27),(.08,-1.00),(.42,-.97),(.52,-.34)],
               .33, MAT["polymer"], parent=root, bevel=.045)
    profile_yz(c, "Magazine", [(-.12,-.38),(-.55,-.39),(-.46,-1.24),(-.02,-1.14)],
               .38, MAT["burgundy"], parent=root, bevel=.05)
    profile_yz(c, "Handguard", [(-.70,.24),(-2.23,.23),(-2.38,.04),(-2.18,-.25),(-.72,-.24)],
               .54, MAT["polymer"], parent=root, bevel=.055)
    cylinder(c, "Barrel", .09, 1.26, (0,.08,-2.84), MAT["steel"], rotation=(0,0,0), vertices=16, parent=root)
    cylinder(c, "MuzzleBrake", .16, .34, (0,.08,-3.63), MAT["blued"], rotation=(0,0,0), vertices=14, parent=root)
    box(c, "TopRail", (.34,.075,2.42), (0,.385,-.88), MAT["black"], bevel=.012, parent=root)
    add_vent_row(c, "HandguardVent", root, (-.92,-1.18,-1.44,-1.70,-1.96), .255, .35, .035, .11, MAT["purple"])
    box(c, "ChargingHandle", (.76,.09,.16), (0,.15,.40), MAT["brass"], bevel=.02, parent=root)
    box(c, "AR4Mark", (.025,.12,.34), (-.311,.08,.03), MAT["violet"], bevel=.005, parent=root)
    box(c, "FrontSight", (.065,.12,.07), (0,.43,-2.96), MAT["acid"], bevel=.012, parent=root)
    root["BLIKK_TriangleBudget"] = 5600
    return c, root


# Armature-space pose format matches the deterministic KatanaSlash1 solver:
# time, torso XYZ degrees, right wrist, right elbow pole, right-hand/weapon axis,
# left wrist, left elbow pole. The official template uses -X fighter-right, +Y up, +Z forward.
READY_KATANA = (0.000, (-1,-4,1), (-.76,.08,.10), (-1.24,.64,.10), (.17,-.58,.80), (.88,-.08,0), (1.20,.50,.02))
READY_GUN = (0.000, (-2,-3,0), (-.48,.56,.50), (-1.15,.84,.38), (0,-.05,1), (.44,.47,.74), (1.08,.72,.56))


ANIMATIONS = {
    "KatanaEquip": (0.120, [
        (0.000,(0,8,2),(-.55,.42,-.42),(-1.12,.78,-.32),(-.42,-.18,-.89),(.84,.02,.02),(1.18,.56,.04)),
        (0.055,(-2,1,1),(-.72,.23,-.06),(-1.20,.70,-.02),(.08,-.42,.90),(.88,-.04,.01),(1.20,.52,.03)),
        (0.120,*READY_KATANA[1:]),
    ]),
    "KatanaSlash1": (0.300, helper.POSES),
    "KatanaBlock": (0.180, [
        (0.000,*READY_KATANA[1:]),
        (0.060,(-3,-10,-2),(-.24,.72,.44),(-.88,1.02,.35),(-.12,.96,.24),(.31,.60,.47),(1.00,.96,.40)),
        (0.180,(-3,-10,-2),(-.24,.72,.44),(-.88,1.02,.35),(-.12,.96,.24),(.31,.60,.47),(1.00,.96,.40)),
    ]),
    "KatanaAltLaunch": (0.420, [
        (0.000,*READY_KATANA[1:]),
        (0.070,(-8,18,4),(-.74,-.02,-.20),(-1.22,.52,-.12),(-.12,-.72,-.68),(.80,.08,.05),(1.18,.58,.06)),
        (0.145,(-5,-8,-3),(-.40,.66,.48),(-1.02,.88,.34),(-.04,.98,.18),(.65,.30,.28),(1.13,.72,.24)),
        (0.235,(-2,-18,-4),(-.05,1.02,.36),(-.72,1.18,.28),(.08,.98,.16),(.58,.38,.38),(1.08,.78,.34)),
        (0.420,*READY_KATANA[1:]),
    ]),
    "ShotgunEquip": (0.100, [
        (0.000,(0,4,1),(-.66,.22,-.20),(-1.15,.62,-.14),(0,-.2,.98),(.80,.10,.05),(1.18,.55,.05)),
        (0.050,(-1,0,0),(-.56,.45,.28),(-1.16,.78,.20),(0,-.08,1),(.57,.36,.48),(1.10,.68,.38)),
        (0.100,*READY_GUN[1:]),
    ]),
    "ShotgunFire": (0.160, [
        (0.000,*READY_GUN[1:]),
        (0.020,(-4,-2,0),(-.46,.60,.43),(-1.14,.88,.32),(0,.14,.99),(.45,.52,.66),(1.08,.78,.50)),
        (0.035,(-5,-2,0),(-.45,.63,.40),(-1.13,.91,.30),(0,.18,.98),(.46,.55,.62),(1.08,.80,.48)),
        (0.160,*READY_GUN[1:]),
    ]),
    "ShotgunReload": (0.760, [
        (0.000,*READY_GUN[1:]),
        (0.100,(0,4,1),(-.62,.34,.20),(-1.18,.70,.14),(0,-.28,.96),(.72,.18,.18),(1.12,.62,.20)),
        (0.260,(1,6,2),(-.64,.29,.14),(-1.18,.66,.12),(0,-.34,.94),(.18,.42,.28),(.92,.78,.24)),
        (0.450,(1,5,1),(-.61,.32,.17),(-1.16,.68,.14),(0,-.30,.95),(.42,.28,.12),(1.00,.70,.15)),
        (0.620,(-1,0,0),(-.54,.48,.35),(-1.14,.80,.26),(0,-.10,.99),(.50,.42,.56),(1.06,.74,.42)),
        (0.760,*READY_GUN[1:]),
    ]),
    "SMGEquip": (0.090, [
        (0.000,(0,5,1),(-.64,.26,-.10),(-1.16,.68,-.05),(0,-.15,.99),(.76,.15,.04),(1.15,.58,.05)),
        (0.090,*READY_GUN[1:]),
    ]),
    "SMGFire": (0.090, [
        (0.000,*READY_GUN[1:]),
        (0.012,(-3,-2,0),(-.47,.59,.46),(-1.14,.86,.34),(0,.10,.995),(.45,.51,.69),(1.08,.76,.52)),
        (0.090,*READY_GUN[1:]),
    ]),
    "SMGReload": (0.680, [
        (0.000,*READY_GUN[1:]),
        (0.090,(0,5,1),(-.60,.38,.20),(-1.17,.73,.14),(0,-.20,.98),(.70,.20,.15),(1.14,.63,.17)),
        (0.260,(1,6,1),(-.60,.34,.17),(-1.17,.70,.12),(0,-.25,.97),(.18,.30,.14),(.88,.68,.10)),
        (0.460,(0,3,0),(-.56,.43,.29),(-1.15,.77,.22),(0,-.14,.99),(.42,.30,.38),(1.00,.68,.30)),
        (0.680,*READY_GUN[1:]),
    ]),
    "RifleEquip": (0.105, [
        (0.000,(0,5,1),(-.66,.24,-.14),(-1.17,.67,-.08),(0,-.18,.98),(.78,.14,.05),(1.16,.58,.05)),
        (0.105,*READY_GUN[1:]),
    ]),
    "RifleFire": (0.110, [
        (0.000,*READY_GUN[1:]),
        (0.015,(-3,-2,0),(-.47,.60,.44),(-1.14,.87,.33),(0,.12,.993),(.45,.52,.67),(1.08,.77,.50)),
        (0.110,*READY_GUN[1:]),
    ]),
    "RifleReload": (0.820, [
        (0.000,*READY_GUN[1:]),
        (0.100,(0,5,1),(-.61,.36,.19),(-1.17,.72,.13),(0,-.22,.98),(.70,.20,.16),(1.14,.64,.18)),
        (0.300,(1,7,1),(-.62,.31,.14),(-1.18,.68,.10),(0,-.30,.95),(.16,.31,.10),(.88,.68,.08)),
        (0.560,(0,4,0),(-.57,.42,.27),(-1.15,.76,.20),(0,-.16,.99),(.42,.31,.36),(1.00,.69,.28)),
        (0.820,*READY_GUN[1:]),
    ]),
}


def create_action(armature, name, duration, poses):
    previous = bpy.data.actions.get("BLIKK_" + name)
    if previous:
        bpy.data.actions.remove(previous)
    action = bpy.data.actions.new("BLIKK_" + name)
    # Most actions are not the armature's active action when the master is
    # saved. Keep every library clip explicitly so Blender cannot purge the
    # inactive actions on reopen.
    action.use_fake_user = True
    armature.animation_data_create()
    armature.animation_data.action = action
    for bone in armature.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for pose in poses:
        helper.key_pose(armature, pose)
    helper.configure_curves(action)
    action["BLIKK_DurationSeconds"] = duration
    action["BLIKK_PresentationOnly"] = True
    keyed = sorted({curve.data_path.split('pose.bones["',1)[1].split('"]',1)[0] for curve in action.fcurves})
    if keyed != sorted(KEYED_BONES):
        raise RuntimeError(f"{name} keyed unexpected bones: {keyed}")
    if abs(action.frame_range[1] / FPS - duration) > 0.001:
        raise RuntimeError(f"{name} duration mismatch: {action.frame_range}")
    return action


def export_model(collection, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.all_objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(MODEL_DIR / f"{name}.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
    )


def export_action(armature, action, name):
    armature.animation_data.action = action
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = round(action["BLIKK_DurationSeconds"] * FPS)
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.fbx(
        filepath=str(ANIMATION_DIR / f"BLIKK_{name}_BlockR15.fbx"),
        use_selection=True,
        object_types={"ARMATURE"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z",
        axis_up="Y",
        add_leaf_bones=False,
        bake_anim=True,
        bake_anim_use_all_bones=False,
        bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=False,
        bake_anim_force_startend_keying=False,
        bake_anim_step=1.0,
        bake_anim_simplify_factor=0.0,
    )


def configure_review_scene(scene):
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("BLIKK_Arsenal_World")
    scene.world = world
    world.color = (0.006,0.006,0.012)
    for name, energy, location in (("Key",1200,(-4,-5,7)),("Rim",900,(4,2,6)),("Fill",500,(0,-2,2))):
        data = bpy.data.lights.get(name) or bpy.data.lights.new(name,"AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = 5
        obj = bpy.data.objects.get(name) or bpy.data.objects.new(name,data)
        if not obj.users_collection:
            scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = ((Vector((0,0,1.0))-Vector(location)).to_track_quat("-Z","Y").to_euler())
    camera_data = bpy.data.cameras.get("BLIKK_QA_Camera") or bpy.data.cameras.new("BLIKK_QA_Camera")
    camera = bpy.data.objects.get("BLIKK_QA_Camera") or bpy.data.objects.new("BLIKK_QA_Camera",camera_data)
    if not camera.users_collection:
        scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 58
    return camera


def attach_review_weapon(root, armature, is_katana):
    root.parent = armature
    root.parent_type = "BONE"
    root.parent_bone = "RightHand"
    hand_rest = armature.data.bones["RightHand"].matrix_local.to_3x3()
    canonical_avatar_axis = Vector((0.173648, -0.578856, 0.796727)).normalized()
    canonical_bone_axis = (hand_rest.inverted() @ canonical_avatar_axis).normalized()
    source_axis = Vector((0, 1, 0)) if is_katana else Vector((0, 0, -1))
    root.rotation_mode = "QUATERNION"
    root.rotation_quaternion = source_axis.rotation_difference(canonical_bone_axis)
    root.location = Vector((0, .18 if is_katana else .04, 0))


def render_model_previews(scene, camera, models, block_collection):
    block_collection.hide_render = True
    target = Vector((0,0,0))
    camera.location = Vector((5.6,-7.2,3.2))
    camera.rotation_euler = (target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.lens = 62
    for selected, (collection, root) in enumerate(models):
        for index, (candidate, _) in enumerate(models):
            candidate.hide_render = index != selected
        root.parent = None
        root.location = Vector((0,0,0))
        # Turn the canonical -Z weapon-forward axis sideways for a readable
        # silhouette review. Exported geometry retains its authored basis.
        root.rotation_euler = Euler((0,math.radians(90),0), "XYZ")
        scene.render.filepath = str(PREVIEW_DIR / f"MODEL_{root.name}.png")
        bpy.ops.render.render(write_still=True)
    block_collection.hide_render = False


def render_action_previews(scene, camera, armature, actions, models):
    for collection, _ in models:
        collection.hide_render = True
    views = {"front": Vector((0,-9,.15)), "threequarter": Vector((-6.4,-6.4,.35)), "rear": Vector((0,9,.15))}
    target = Vector((0,0,-.05))
    for name, action in actions.items():
        if name.startswith("Katana"):
            selected_index = 0
        elif name.startswith("Shotgun"):
            selected_index = 1
        elif name.startswith("SMG"):
            selected_index = 2
        else:
            selected_index = 3
        for index, (collection, root) in enumerate(models):
            collection.hide_render = index != selected_index
            if index == selected_index:
                attach_review_weapon(root, armature, index == 0)
        armature.animation_data.action = action
        frame = round(action["BLIKK_DurationSeconds"] * FPS * (0.48 if "Reload" in name else 0.55))
        scene.frame_set(frame)
        for view, location in views.items():
            camera.location = location
            camera.rotation_euler = (target-location).to_track_quat("-Z","Y").to_euler()
            scene.render.filepath = str(PREVIEW_DIR / f"{name}_{view}.png")
            bpy.ops.render.render(write_still=True)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    ANIMATION_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.render.fps_base = 1
    armature = bpy.data.objects.get(ARMATURE_NAME)
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError("Roblox official R15 armature 'Joints' is required")
    create_block_r15(armature)
    block_collection = bpy.data.collections["BLIKK_BlockR15_Review"]
    models = [create_katana(), create_shotgun(), create_smg(), create_rifle()]
    actions = {name: create_action(armature,name,duration,poses) for name,(duration,poses) in ANIMATIONS.items()}
    for collection, root in models:
        export_model(collection, root.name)
    for name, action in actions.items():
        export_action(armature, action, name)
    camera = configure_review_scene(scene)
    render_model_previews(scene,camera,models,block_collection)
    camera.data.lens = 58
    render_action_previews(scene,camera,armature,actions,models)
    armature.animation_data.action = actions["KatanaSlash1"]
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER_BLEND))
    print("BLIKK_BLOCK_R15_ARSENAL_OK")
    print("Models:", sorted(path.name for path in MODEL_DIR.glob("*.glb")))
    print("Animations:", sorted(path.name for path in ANIMATION_DIR.glob("*.fbx")))


if __name__ == "__main__":
    main()
