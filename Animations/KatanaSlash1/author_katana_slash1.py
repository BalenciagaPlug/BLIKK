"""Generate BLIKK's original KatanaSlash1 on Roblox's official R15 Blender template.

Run with Blender 4.5 after opening the official RoundMale.blend template. The script keys only
the R15 upper-body bones approved in docs/ANIMATION_ASSETS.md, creates a non-exported preview
Katana, saves an authoring .blend, renders QA stills, and exports an R15 FBX for Studio import.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector


ACTION_NAME = "BLIKK_KatanaSlash1"
ARMATURE_NAME = "Joints"
FPS = 120
START_FRAME = 0
END_FRAME = 36  # Exactly 0.300 seconds at 120 FPS.

OUTPUT_DIRECTORY = Path(os.environ.get("BLIKK_ANIMATION_OUTPUT", Path.cwd()))
AUTHORING_BLEND_PATH = OUTPUT_DIRECTORY / "BLIKK_KatanaSlash1_Authoring.blend"
EXPORT_FBX_PATH = OUTPUT_DIRECTORY / "BLIKK_KatanaSlash1_R15.fbx"
PREVIEW_DIRECTORY = OUTPUT_DIRECTORY / "preview_final"

KEYED_BONES = (
    "UpperTorso",  # Roblox Waist joint.
    "RightUpperArm",  # Roblox RightShoulder joint.
    "RightLowerArm",  # Roblox RightElbow joint.
    "RightHand",  # Roblox RightWrist joint.
    "LeftUpperArm",  # Roblox LeftShoulder joint.
    "LeftLowerArm",  # Roblox LeftElbow joint.
)

# Targets use the official template's armature space: -X is fighter-right, +Y is up, and +Z is
# forward. Explicit anatomical targets avoid assuming that Blender bone axes match Roblox part axes.
# The first and final rows are identical so an uncancelled slash returns cleanly to ready.
POSES = (
    # time, torso XYZ degrees, right wrist, right elbow pole, blade axis,
    # left wrist, left elbow pole
    (0.000, (-1, -4, 1), (-0.76, 0.08, 0.10), (-1.24, 0.64, 0.10), (0.17, -0.58, 0.80),
     (0.88, -0.08, 0.00), (1.20, 0.50, 0.02)),
    (0.025, (-5, 18, 4), (-0.76, 0.40, -0.28), (-1.24, 0.86, -0.18), (-0.18, -0.30, -0.94),
     (0.78, 0.20, 0.16), (1.16, 0.76, 0.18)),
    (0.055, (-4, 8, 2), (-0.68, 0.55, 0.18), (-1.16, 0.90, 0.23), (0.20, -0.08, 0.98),
     (0.82, 0.18, -0.08), (1.18, 0.74, -0.12)),
    (0.085, (-4, -8, -2), (-0.14, 0.63, 0.57), (-0.72, 0.92, 0.62), (0.96, -0.20, 0.20),
     (0.78, 0.14, -0.24), (1.15, 0.70, -0.28)),
    (0.130, (-4, -30, -5), (0.34, 0.53, 0.42), (-0.16, 0.90, 0.54), (0.91, -0.36, -0.15),
     (0.75, 0.08, -0.34), (1.12, 0.64, -0.38)),
    (0.205, (-2, -14, -2), (-0.25, 0.25, 0.16), (-0.84, 0.70, 0.24), (0.34, -0.75, 0.57),
     (0.82, -0.01, -0.10), (1.17, 0.54, -0.13)),
    (0.300, (-1, -4, 1), (-0.76, 0.08, 0.10), (-1.24, 0.64, 0.10), (0.17, -0.58, 0.80),
     (0.88, -0.08, 0.00), (1.20, 0.50, 0.02)),
)

MARKERS = (
    ("SlashStart", 0.025),
    ("DirectionSet", 0.075),
    ("ContactVisual", 0.090),
    ("TrailOff", 0.140),
    ("CancelClose", 0.205),
    ("Recovered", 0.300),
)

PREVIEW_FRAMES = (0, 3, 7, 10, 16, 25, 36)
PREVIEW_CAMERAS = {
    "front": Vector((0.0, -8.0, 2.45)),
    "front_three_quarter": Vector((-5.8, -5.8, 2.70)),
    "right": Vector((-8.0, 0.0, 2.45)),
    "rear": Vector((0.0, 8.0, 2.45)),
}


def degrees_to_radians(values: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(math.radians(value) for value in values)


def time_to_frame(time_seconds: float) -> float:
    return time_seconds * FPS


def require_armature() -> bpy.types.Object:
    armature = bpy.data.objects.get(ARMATURE_NAME)
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError(f"Expected official R15 armature {ARMATURE_NAME!r}")
    missing = [name for name in KEYED_BONES if armature.pose.bones.get(name) is None]
    if missing:
        raise RuntimeError(f"Official R15 template is missing required bones: {missing}")
    return armature


def clear_existing_animation(armature: bpy.types.Object) -> bpy.types.Action:
    if armature.animation_data is None:
        armature.animation_data_create()
    armature.animation_data_clear()
    armature.animation_data_create()
    previous = bpy.data.actions.get(ACTION_NAME)
    if previous is not None:
        bpy.data.actions.remove(previous)
    action = bpy.data.actions.new(ACTION_NAME)
    armature.animation_data.action = action
    return action


def basis_matrix(x_axis: Vector, y_axis: Vector, z_axis: Vector, origin: Vector) -> Matrix:
    rotation = Matrix((x_axis, y_axis, z_axis)).transposed().to_4x4()
    rotation.translation = origin
    return rotation


def solve_elbow(shoulder: Vector, wrist: Vector, pole: Vector, upper_length: float, lower_length: float) -> Vector:
    shoulder_to_wrist = wrist - shoulder
    distance = max(shoulder_to_wrist.length, 1e-5)
    direction = shoulder_to_wrist / distance
    clamped_distance = min(distance, upper_length + lower_length - 1e-4)
    along = (upper_length * upper_length - lower_length * lower_length + clamped_distance * clamped_distance) / (
        2.0 * clamped_distance
    )
    height = math.sqrt(max(upper_length * upper_length - along * along, 0.0))
    pole_direction = pole - shoulder
    pole_direction -= direction * pole_direction.dot(direction)
    if pole_direction.length < 1e-5:
        pole_direction = Vector((1.0, 0.0, 0.0))
        pole_direction -= direction * pole_direction.dot(direction)
    pole_direction.normalize()
    return shoulder + direction * along + pole_direction * height


def set_pose_matrix(bone: bpy.types.PoseBone, desired_pose_matrix: Matrix) -> None:
    parent = bone.parent
    if parent is None:
        basis = bone.bone.convert_local_to_pose(
            desired_pose_matrix,
            bone.bone.matrix_local,
            invert=True,
        )
    else:
        basis = bone.bone.convert_local_to_pose(
            desired_pose_matrix,
            bone.bone.matrix_local,
            parent_matrix=parent.matrix,
            parent_matrix_local=parent.bone.matrix_local,
            invert=True,
        )
    bone.matrix_basis = basis


def orient_bone_between(bone: bpy.types.PoseBone, head: Vector, tail: Vector, pole_direction: Vector) -> None:
    y_axis = (tail - head).normalized()
    x_axis = pole_direction - y_axis * pole_direction.dot(y_axis)
    if x_axis.length < 1e-5:
        x_axis = Vector((1.0, 0.0, 0.0))
        x_axis -= y_axis * x_axis.dot(y_axis)
    x_axis.normalize()
    z_axis = x_axis.cross(y_axis).normalized()
    x_axis = y_axis.cross(z_axis).normalized()
    set_pose_matrix(bone, basis_matrix(x_axis, y_axis, z_axis, head))


def solve_arm(
    armature: bpy.types.Object,
    upper_name: str,
    lower_name: str,
    hand_name: str,
    wrist: Vector,
    pole: Vector,
    blade_axis: Vector | None,
) -> None:
    upper = armature.pose.bones[upper_name]
    lower = armature.pose.bones[lower_name]
    hand = armature.pose.bones[hand_name]
    upper.rotation_mode = "QUATERNION"
    lower.rotation_mode = "QUATERNION"
    hand.rotation_mode = "QUATERNION"
    upper_length = armature.data.bones[upper_name].length
    lower_length = armature.data.bones[lower_name].length
    shoulder = upper.head.copy()
    elbow = solve_elbow(shoulder, wrist, pole, upper_length, lower_length)
    pole_direction = (pole - shoulder).normalized()
    orient_bone_between(upper, shoulder, elbow, pole_direction)
    bpy.context.view_layer.update()
    orient_bone_between(lower, elbow, wrist, pole_direction)
    bpy.context.view_layer.update()

    if blade_axis is not None:
        rest_rotation = armature.data.bones[hand_name].matrix_local.to_3x3()
        canonical_axis = Vector((0.173648, -0.578856, 0.796727)).normalized()
        desired_axis = blade_axis.normalized()
        delta = canonical_axis.rotation_difference(desired_axis).to_matrix()
        hand_rotation = delta @ rest_rotation
        desired_hand_matrix = hand_rotation.to_4x4()
        desired_hand_matrix.translation = wrist
        set_pose_matrix(hand, desired_hand_matrix)
    else:
        lower_rest = armature.data.bones[lower_name].matrix_local.to_3x3()
        hand_rest = armature.data.bones[hand_name].matrix_local.to_3x3()
        relative_rest = lower_rest.inverted() @ hand_rest
        hand_rotation = lower.matrix.to_3x3() @ relative_rest
        desired_hand_matrix = hand_rotation.to_4x4()
        desired_hand_matrix.translation = wrist
        set_pose_matrix(hand, desired_hand_matrix)


def key_pose(armature: bpy.types.Object, pose) -> None:
    time_seconds, torso_degrees, right_wrist, right_pole, blade_axis, left_wrist, left_pole = pose
    frame = time_to_frame(time_seconds)
    whole_frame = math.floor(frame)
    bpy.context.scene.frame_set(whole_frame, subframe=frame - whole_frame)

    torso = armature.pose.bones["UpperTorso"]
    torso.rotation_mode = "QUATERNION"
    torso.rotation_quaternion = Euler(degrees_to_radians(torso_degrees), "XYZ").to_quaternion()
    bpy.context.view_layer.update()

    solve_arm(
        armature,
        "RightUpperArm",
        "RightLowerArm",
        "RightHand",
        Vector(right_wrist),
        Vector(right_pole),
        Vector(blade_axis),
    )
    solve_arm(
        armature,
        "LeftUpperArm",
        "LeftLowerArm",
        "LeftHand",
        Vector(left_wrist),
        Vector(left_pole),
        None,
    )

    for bone_name in KEYED_BONES:
        bone = armature.pose.bones[bone_name]
        bone.rotation_mode = "QUATERNION"
        bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone_name)


def configure_curves(action: bpy.types.Action) -> None:
    linear_start_frames = {
        time_to_frame(0.055),
        time_to_frame(0.085),
    }
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            if any(abs(key.co.x - frame) < 0.001 for frame in linear_start_frames):
                key.interpolation = "LINEAR"
            else:
                key.interpolation = "BEZIER"
                key.handle_left_type = "AUTO_CLAMPED"
                key.handle_right_type = "AUTO_CLAMPED"


def add_timeline_markers(scene: bpy.types.Scene) -> None:
    scene.timeline_markers.clear()
    for name, time_seconds in MARKERS:
        scene.timeline_markers.new(name, frame=round(time_to_frame(time_seconds)))


def make_material(name: str, color: tuple[float, float, float, float], metallic=0.0, roughness=0.5):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = color
    material.metallic = metallic
    material.roughness = roughness
    return material


def add_box(name: str, dimensions: tuple[float, float, float], location, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    part = bpy.context.object
    part.name = name
    part.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    part.data.materials.append(material)
    return part


def create_preview_katana(armature: bpy.types.Object) -> bpy.types.Object:
    old = bpy.data.objects.get("BLIKK_KatanaPreviewRoot")
    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)

    collection = bpy.data.collections.get("BLIKK_KatanaSlash1_Preview")
    if collection is None:
        collection = bpy.data.collections.new("BLIKK_KatanaSlash1_Preview")
        bpy.context.scene.collection.children.link(collection)

    root = bpy.data.objects.new("BLIKK_KatanaPreviewRoot", None)
    collection.objects.link(root)
    root.empty_display_type = "ARROWS"
    root.parent = armature
    root.parent_type = "BONE"
    root.parent_bone = "RightHand"

    hand_rest = armature.data.bones["RightHand"].matrix_local.to_3x3()
    canonical_axis_avatar = Vector((0.173648, -0.578856, 0.796727)).normalized()
    canonical_axis_bone = (hand_rest.inverted() @ canonical_axis_avatar).normalized()
    grip_rotation = Vector((0.0, 1.0, 0.0)).rotation_difference(canonical_axis_bone)
    root.rotation_mode = "QUATERNION"
    root.rotation_quaternion = grip_rotation
    root.location = Vector((0.0, 0.18, 0.0))

    dark = make_material("BLIKK_Katana_Dark", (0.025, 0.022, 0.032, 1.0), 0.65, 0.28)
    purple = make_material("BLIKK_Katana_Purple", (0.22, 0.07, 0.34, 1.0), 0.55, 0.24)
    steel = make_material("BLIKK_Katana_Steel", (0.55, 0.58, 0.64, 1.0), 0.75, 0.18)
    edge = make_material("BLIKK_Katana_Edge", (0.91, 0.89, 0.82, 1.0), 0.45, 0.12)

    parts = (
        add_box("Preview_Handle", (0.30, 1.00, 0.30), (0.0, 0.0, 0.0), dark),
        add_box("Preview_Grip", (0.36, 0.82, 0.36), (0.0, -0.02, 0.0), purple),
        add_box("Preview_Guard", (0.90, 0.12, 0.44), (0.0, 0.56, 0.0), purple),
        add_box("Preview_Blade", (0.16, 3.50, 0.42), (0.0, 2.40, 0.0), steel),
        add_box("Preview_Edge", (0.045, 3.36, 0.44), (-0.105, 2.40, 0.0), edge),
        add_box("Preview_Pommel", (0.36, 0.15, 0.36), (0.0, -0.575, 0.0), purple),
    )
    for part in parts:
        for owner_collection in tuple(part.users_collection):
            owner_collection.objects.unlink(part)
        collection.objects.link(part)
        part.parent = root
    return root


def configure_preview_scene(scene: bpy.types.Scene) -> bpy.types.Object:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False

    # Roblox's official authoring template includes fitting cages and visible
    # attachment locators. They are useful while fitting an avatar, but they
    # are not runtime body geometry and would obscure animation QA renders.
    for scene_object in scene.objects:
        if scene_object.name.endswith("_OuterCage") or scene_object.name.endswith("_Att"):
            scene_object.hide_render = True

    world = scene.world or bpy.data.worlds.new("BLIKK_KatanaSlash1_World")
    scene.world = world
    world.color = (0.008, 0.008, 0.012)

    camera_data = bpy.data.cameras.get("BLIKK_KatanaSlash1_QA_Camera") or bpy.data.cameras.new(
        "BLIKK_KatanaSlash1_QA_Camera"
    )
    camera = bpy.data.objects.get("BLIKK_KatanaSlash1_QA_Camera")
    if camera is None:
        camera = bpy.data.objects.new("BLIKK_KatanaSlash1_QA_Camera", camera_data)
        scene.collection.objects.link(camera)
    camera.data.lens = 52
    scene.camera = camera
    return camera


def point_camera(camera: bpy.types.Object, location: Vector) -> None:
    target = Vector((0.0, 0.0, 1.95))
    camera.location = location
    camera.rotation_euler = (target - location).to_track_quat("-Z", "Y").to_euler()


def render_previews(scene: bpy.types.Scene, camera: bpy.types.Object) -> None:
    PREVIEW_DIRECTORY.mkdir(parents=True, exist_ok=True)
    for frame in PREVIEW_FRAMES:
        scene.frame_set(frame)
        for view_name, location in PREVIEW_CAMERAS.items():
            point_camera(camera, location)
            scene.render.filepath = str(PREVIEW_DIRECTORY / f"frame_{frame:03d}_{view_name}.png")
            bpy.ops.render.render(write_still=True)


def save_authoring_file() -> None:
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(AUTHORING_BLEND_PATH))


def export_animation_fbx(armature: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.fbx(
        filepath=str(EXPORT_FBX_PATH),
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
        use_armature_deform_only=False,
    )


def validate_action(action: bpy.types.Action) -> None:
    keyed = set()
    for curve in action.fcurves:
        if 'pose.bones["' not in curve.data_path:
            raise RuntimeError(f"Unexpected non-pose animation channel: {curve.data_path}")
        keyed.add(curve.data_path.split('pose.bones["', 1)[1].split('"]', 1)[0])
    if keyed != set(KEYED_BONES):
        raise RuntimeError(f"Unexpected keyed bones. Expected {KEYED_BONES}, got {sorted(keyed)}")
    if abs((END_FRAME - START_FRAME) / FPS - 0.300) > 1e-9:
        raise RuntimeError("KatanaSlash1 duration drifted from 0.300 seconds")


def main() -> None:
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.render.fps_base = 1.0
    scene.frame_start = START_FRAME
    scene.frame_end = END_FRAME

    armature = require_armature()
    action = clear_existing_animation(armature)
    for pose in POSES:
        key_pose(armature, pose)
    configure_curves(action)
    add_timeline_markers(scene)
    validate_action(action)
    create_preview_katana(armature)
    camera = configure_preview_scene(scene)
    save_authoring_file()
    render_previews(scene, camera)
    export_animation_fbx(armature)
    print(f"BLIKK KatanaSlash1 authoring file: {AUTHORING_BLEND_PATH}")
    print(f"BLIKK KatanaSlash1 animation FBX: {EXPORT_FBX_PATH}")


if __name__ == "__main__":
    main()
