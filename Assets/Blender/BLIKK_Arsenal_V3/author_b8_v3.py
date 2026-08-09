"""Build the original BLIKK B-8 Breakshot V3 proof asset in Blender 4.5.

The model is authored in the existing BLIKK firearm basis:
    local -Z = stock to muzzle, local +Y = up, local +X = weapon-right.

This proof is intentionally isolated from the V2 library and runtime code.
"""

from array import array
from pathlib import Path
import math
import random

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
MODEL_DIR = ROOT / "Models"
PREVIEW_DIR = ROOT / "Previews"
TEXTURE_DIR = ROOT / "Textures"
MASTER_BLEND = ROOT / "BLIKK_B8_BREAKSHOT_V3_1_Master.blend"
for directory in (MODEL_DIR, PREVIEW_DIR, TEXTURE_DIR):
    directory.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras,
                       bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def make_atlas():
    size = 1024
    image = bpy.data.images.new("B8_V3_1_BaseColor", width=size, height=size, alpha=True)
    pixels = array("f", [0.0]) * (size * size * 4)
    random.seed(8082005)
    palettes = (
        ((0.055, 0.065, 0.075), (0.17, 0.19, 0.21)),   # blued steel
        ((0.035, 0.039, 0.045), (0.105, 0.115, 0.125)), # polymer
        ((0.12, 0.030, 0.028), (0.30, 0.075, 0.055)),   # burgundy composite
        ((0.22, 0.19, 0.11), (0.49, 0.42, 0.22)),      # worn brass/accent
    )
    for y in range(size):
        long_wear = 0.018 * math.sin(y * 0.071) + 0.012 * math.sin(y * 0.193)
        for x in range(size):
            tile = min(3, x // 256)
            lo, hi = palettes[tile]
            local_x = x % 256
            edge = min(local_x, 255 - local_x, y, 1023 - y)
            base = 0.30 + 0.12 * math.sin(local_x * 0.043) + long_wear
            grain = (random.random() - 0.5) * (0.050 if tile < 2 else 0.075)
            scratch = 0.0
            if (x * 17 + y * 31) % 997 < 2:
                scratch = 0.11
            if edge < 5:
                scratch += (5 - edge) * 0.018
            value = max(0.0, min(1.0, base + grain + scratch))
            i = (y * size + x) * 4
            pixels[i] = lo[0] + (hi[0] - lo[0]) * value
            pixels[i + 1] = lo[1] + (hi[1] - lo[1]) * value
            pixels[i + 2] = lo[2] + (hi[2] - lo[2]) * value
            pixels[i + 3] = 1.0
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(TEXTURE_DIR / "B8_V3_1_BaseColor.png")
    image.file_format = "PNG"
    image.save()
    return image


def make_material(name, image, tile, metallic, roughness):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material["BLIKK_AtlasTile"] = tile
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def assign_planar_uv(obj, tile):
    mesh = obj.data
    uv_layer = mesh.uv_layers.new(name="UVMap")
    coords = [vertex.co for vertex in mesh.vertices]
    min_y = min(co.y for co in coords)
    max_y = max(co.y for co in coords)
    min_z = min(co.z for co in coords)
    max_z = max(co.z for co in coords)
    span_y = max(max_y - min_y, 0.001)
    span_z = max(max_z - min_z, 0.001)
    u0 = tile * 0.25 + 0.012
    uw = 0.226
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        uv_layer.data[loop.index].uv = (u0 + ((co.z - min_z) / span_z) * uw,
                                        0.025 + ((co.y - min_y) / span_y) * 0.95)


def finish_mesh(obj, material, tile, bevel=0.025, segments=1, weighted=True):
    obj.data.materials.append(material)
    assign_planar_uv(obj, tile)
    if bevel > 0:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = segments
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(24)
    if weighted:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        obj.data.set_sharp_from_angle(angle=math.radians(46))
    obj["BLIKK_RenderMesh"] = True
    return obj


def profile_x(name, points_yz, width, material, tile, bevel=0.025, parent=None):
    vertices = []
    half = width * 0.5
    for x in (-half, half):
        vertices.extend((x, y, z) for y, z in points_yz)
    count = len(points_yz)
    faces = []
    faces.append(tuple(range(count)))
    faces.append(tuple(range(count, count * 2))[::-1])
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, count + j, count + i))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    return finish_mesh(obj, material, tile, bevel)


def box(name, location, scale, material, tile, bevel=0.025, rotation=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] * 0.5, scale[1] * 0.5, scale[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.parent = parent
    return finish_mesh(obj, material, tile, bevel)


def cylinder(name, location, radius, depth, material, tile, vertices=20,
             rotation=(0, 0, 0), parent=None, bevel=0.012):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    return finish_mesh(obj, material, tile, bevel, segments=2)


def torus(name, location, major_radius, minor_radius, material, tile,
          rotation=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius,
                                    major_segments=20, minor_segments=6,
                                    location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    return finish_mesh(obj, material, tile, 0.008, segments=1)


def screw(name, location, rotation, material, tile, parent):
    return cylinder(name, location, 0.034, 0.020, material, tile, vertices=12,
                    rotation=rotation, parent=parent, bevel=0.005)


def create_b8(materials):
    root = bpy.data.objects.new("BLIKK_B8_BREAKSHOT_V3_1", None)
    bpy.context.collection.objects.link(root)
    root.empty_display_type = "ARROWS"
    root["BLIKK_OriginalAsset"] = True
    root["BLIKK_AssetVersion"] = "3.1"
    root["BLIKK_CanonicalForward"] = "-Z"
    root["BLIKK_CanonicalUp"] = "+Y"
    root["BLIKK_CanonicalRight"] = "+X"
    root["BLIKK_TriangleBudget"] = 8000
    root["BLIKK_RuntimeIntegrated"] = False

    steel, black, burgundy, brass = materials

    # Receiver: a layered, tapered shell rather than one rectangular mass.
    receiver = profile_x("ReceiverCore", [(-0.25, 0.58), (0.18, 0.58), (0.30, 0.38),
                        (0.27, -0.42), (0.07, -0.60), (-0.27, -0.50), (-0.32, 0.24)],
                        0.52, steel, 0, 0.038, root)
    box("ReceiverRightPlate", (0.282, 0.015, -0.04), (0.045, 0.43, 0.74), black, 1,
        0.016, (math.radians(1), 0, 0), root)
    box("ReceiverLeftPlate", (-0.282, 0.015, -0.04), (0.045, 0.43, 0.74), black, 1,
        0.016, (math.radians(-1), 0, 0), root)
    box("ReceiverTopSpine", (0, 0.315, -0.08), (0.42, 0.085, 0.78), steel, 0, 0.018, parent=root)
    box("ReceiverRearCap", (0, 0.03, 0.575), (0.48, 0.44, 0.10), black, 1, 0.026, parent=root)

    # Ejection and loading details give readable mechanical depth from game camera distance.
    box("EjectionPort", (0.307, 0.095, -0.20), (0.028, 0.17, 0.36), black, 1, 0.008, parent=root)
    box("EjectionBolt", (0.324, 0.105, -0.18), (0.022, 0.105, 0.22), brass, 3, 0.005, parent=root)
    box("LoadingGate", (0, -0.302, -0.04), (0.25, 0.026, 0.31), black, 1, 0.008, parent=root)
    box("ActionRelease", (-0.295, -0.075, -0.30), (0.024, 0.075, 0.16), brass, 3, 0.006, parent=root)

    # Shaped stock with a separate cheek rest and rubber butt pad.
    profile_x("StockBody", [(0.20, 0.66), (0.28, 0.52), (0.23, 1.08), (0.10, 1.34),
              (-0.18, 1.31), (-0.30, 1.05), (-0.24, 0.63), (-0.08, 0.49)],
              0.44, burgundy, 2, 0.045, root)
    profile_x("StockInset", [(0.13, 0.73), (0.18, 0.60), (0.13, 1.10), (0.03, 1.23),
              (-0.10, 1.20), (-0.17, 1.03), (-0.13, 0.72)],
              0.454, black, 1, 0.018, root)
    profile_x("CheekRest", [(0.24, 0.68), (0.33, 0.82), (0.33, 1.16), (0.25, 1.24),
              (0.19, 0.79)], 0.36, black, 1, 0.028, root)
    profile_x("ButtPad", [(0.13, 1.29), (0.21, 1.34), (0.12, 1.45), (-0.22, 1.43),
              (-0.29, 1.35), (-0.18, 1.28)], 0.47, black, 1, 0.026, root)
    box("StockSpine", (0, 0.16, 0.62), (0.32, 0.16, 0.25), steel, 0, 0.025, parent=root)

    # Angled pistol grip and fully modelled trigger group.
    profile_x("PistolGrip", [(-0.12, 0.35), (-0.20, 0.10), (-0.56, 0.26), (-0.70, 0.43),
              (-0.65, 0.59), (-0.27, 0.55), (-0.08, 0.47)],
              0.29, black, 1, 0.035, root)
    for index in range(4):
        box(f"GripGroove{index}", (0.151, -0.31 - index * 0.085, 0.40 + index * 0.036),
            (0.018, 0.032, 0.23), burgundy, 2, 0.005,
            (math.radians(-12), 0, 0), root)
    torus("TriggerGuard", (0, -0.255, 0.015), 0.165, 0.026, steel, 0,
          (math.radians(90), 0, 0), root)
    box("Trigger", (0, -0.255, 0.04), (0.035, 0.18, 0.035), brass, 3, 0.009,
        (math.radians(-18), 0, 0), root)

    # Barrel assembly. The upper barrel, lower magazine tube and heat shield read independently.
    cylinder("Barrel", (0, 0.155, -1.48), 0.125, 1.90, steel, 0, 24, parent=root, bevel=0.010)
    cylinder("BarrelBore", (0, 0.155, -2.445), 0.092, 0.035, black, 1, 24, parent=root, bevel=0.003)
    cylinder("MagazineTube", (0, -0.115, -1.39), 0.105, 1.68, black, 1, 20, parent=root)
    cylinder("MagazineCap", (0, -0.115, -2.245), 0.125, 0.105, steel, 0, 20, parent=root)
    box("BarrelBridge", (0, 0.04, -0.57), (0.34, 0.30, 0.15), steel, 0, 0.025, parent=root)
    box("HeatShield", (0, 0.295, -1.47), (0.31, 0.055, 1.70), black, 1, 0.014, parent=root)
    for index in range(7):
        box(f"HeatVent{index}", (0, 0.326, -0.82 - index * 0.205),
            (0.19, 0.018, 0.095), steel, 0, 0.014, parent=root)
    box("SightRail", (0, 0.355, -1.31), (0.10, 0.055, 1.56), steel, 0, 0.012, parent=root)
    box("FrontSight", (0, 0.418, -2.28), (0.07, 0.12, 0.06), brass, 3, 0.010, parent=root)

    # Pump with chamfered silhouette and individual traction ribs.
    profile_x("PumpCore", [(0.01, -0.82), (0.11, -0.91), (0.10, -1.68),
              (-0.19, -1.75), (-0.31, -1.62), (-0.31, -0.91), (-0.16, -0.79)],
              0.42, burgundy, 2, 0.035, root)
    for index in range(7):
        z = -0.91 - index * 0.105
        box(f"PumpRib{index}", (0, -0.10, z), (0.455, 0.31, 0.040), black, 1, 0.009, parent=root)
    cylinder("ActionBarRight", (0.205, -0.02, -0.88), 0.025, 0.70, brass, 3, 10, parent=root)
    cylinder("ActionBarLeft", (-0.205, -0.02, -0.88), 0.025, 0.70, brass, 3, 10, parent=root)

    # Pins, controls, receiver seam, and restrained BLIKK identifier.
    for side in (-1, 1):
        x = side * 0.310
        rotation = (0, math.radians(90), 0)
        screw(f"ReceiverPinA_{side}", (x, 0.11, 0.22), rotation, brass, 3, root)
        screw(f"ReceiverPinB_{side}", (x, -0.11, -0.34), rotation, steel, 0, root)
    cylinder("Safety", (-0.315, 0.19, 0.42), 0.045, 0.035, burgundy, 2, 12,
             (0, math.radians(90), 0), root, 0.004)
    box("BLIKKMark", (-0.314, 0.11, -0.10), (0.022, 0.055, 0.20), burgundy, 2, 0.005, parent=root)
    for offset in (-0.06, 0.0, 0.06):
        box(f"BLIKKMarkCut{offset}", (-0.327, 0.11, -0.10 + offset),
            (0.010, 0.018, 0.025), brass, 3, 0.002, parent=root)

    # Import-contract references. These empties are excluded from rendered geometry but exported.
    references = {
        "GripAttachment": (0, -0.29, 0.40),
        "ForegripAttachment": (0, -0.13, -1.22),
        "MuzzleAttachment": (0, 0.155, -2.48),
        "StockPivot": (0, 0.13, 1.34),
    }
    for name, location in references.items():
        empty = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(empty)
        empty.location = location
        empty.parent = root
        empty.empty_display_type = "PLAIN_AXES"
        empty["BLIKK_Reference"] = True

    # The first V3 proof established the detail language but read too large and
    # toy-like on block R15. This measured proportion pass preserves every pivot
    # and mechanical relationship while targeting a 2000s PC-game weapon profile.
    width_scale = 0.72
    height_scale = 0.76
    length_scale = 0.82
    for child in root.children_recursive:
        child.location = (child.location.x * width_scale,
                          child.location.y * height_scale,
                          child.location.z * length_scale)
        if child.type == "MESH":
            child.scale = (child.scale.x * width_scale,
                           child.scale.y * height_scale,
                           child.scale.z * length_scale)
            bpy.context.view_layer.objects.active = child
            child.select_set(True)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            child.select_set(False)
    root["BLIKK_OverallLengthStuds"] = 3.22
    root["BLIKK_MaximumWidthStuds"] = 0.45
    root["BLIKK_ProportionPass"] = "SLIM_EARLY_2000S"
    return root


def create_review_avatar():
    root = bpy.data.objects.new("BlockR15_ReviewOnly", None)
    bpy.context.collection.objects.link(root)
    root["BLIKK_Export"] = False
    material = bpy.data.materials.new("ReviewAvatar")
    material.diffuse_color = (0.12, 0.13, 0.15, 1)
    parts = (
        ("Torso", (0, 1.82, 0), (1.28, 1.34, 0.66)),
        ("Head", (0, 2.94, 0), (0.74, 0.74, 0.74)),
        ("LeftArm", (-0.82, 1.73, 0), (0.36, 1.45, 0.40)),
        ("RightArm", (0.82, 1.73, 0), (0.36, 1.45, 0.40)),
        ("LeftLeg", (-0.33, 0.38, 0), (0.54, 1.55, 0.58)),
        ("RightLeg", (0.33, 0.38, 0), (0.54, 1.55, 0.58)),
    )
    for name, location, scale in parts:
        part = box("Review" + name, location, scale, material, 1, 0.05, parent=root)
        part["BLIKK_ReviewOnly"] = True
    return root


def export_model(root):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(MODEL_DIR / "BLIKK_B8_BREAKSHOT_V3_1.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
        export_extras=True,
    )


def look_at(camera, target):
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


def configure_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.008, 0.010, 0.016)
    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 54
    floor_material = bpy.data.materials.new("ReviewFloor")
    floor_material.diffuse_color = (0.012, 0.014, 0.020, 1)
    box("ReviewFloor", (0, 0, -0.72), (16, 16, 0.08), floor_material, 1, 0)
    for name, location, energy, size, color in (
        ("Key", (4.5, 4.0, -3.0), 1050, 4.0, (0.55, 0.68, 1.0)),
        ("Rim", (-4.0, 2.0, 1.8), 900, 3.0, (0.45, 0.12, 0.08)),
        ("Fill", (0.0, 5.0, 4.0), 650, 5.0, (0.22, 0.18, 0.28)),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        data.color = color
        light = bpy.data.objects.new(name, data)
        light.location = location
        bpy.context.collection.objects.link(light)
        look_at(light, (0, 0, -0.55))
    return scene, camera


def render_reviews(scene, camera, model, avatar):
    for item in [avatar, *avatar.children_recursive]:
        item.hide_render = True
    # Source assets use Roblox's Y-up convention. Rotate the review root only so
    # Blender's Z-up cameras show the canonical stock-to-muzzle axis horizontally.
    model.rotation_euler = (math.radians(90), 0, 0)
    views = {
        "B8_V3_1_SIDE": ((7.5, 0.0, 2.0), (0, 0, 0.04)),
        "B8_V3_1_FRONT_3Q": ((5.9, 6.2, 2.8), (0, 0, 0.04)),
        "B8_V3_1_REAR_3Q": ((-5.9, -6.2, 2.8), (0, 0, 0.04)),
    }
    for name, (location, target) in views.items():
        camera.location = location
        look_at(camera, target)
        scene.render.filepath = str(PREVIEW_DIR / f"{name}.png")
        bpy.ops.render.render(write_still=True)

    # A block-R15 scale proof; no gameplay grip or pose is implied by this review mount.
    for item in [avatar, *avatar.children_recursive]:
        item.hide_render = False
    avatar.rotation_euler = (math.radians(90), 0, 0)
    model.rotation_euler = (math.radians(90), math.radians(-5), math.radians(-8))
    model.location = (0.58, -0.10, 1.58)
    camera.location = (8.2, 8.4, 4.7)
    look_at(camera, (0, 0, 1.45))
    scene.render.filepath = str(PREVIEW_DIR / "B8_V3_1_BLOCK_R15_SCALE.png")
    bpy.ops.render.render(write_still=True)
    model.rotation_euler = (0, 0, 0)
    model.location = (0, 0, 0)
    avatar.rotation_euler = (0, 0, 0)


def main():
    clear_scene()
    atlas = make_atlas()
    materials = (
        make_material("B8_BluedSteel", atlas, 0, 0.78, 0.28),
        make_material("B8_DarkPolymer", atlas, 1, 0.12, 0.48),
        make_material("B8_BurgundyComposite", atlas, 2, 0.08, 0.42),
        make_material("B8_WornHardware", atlas, 3, 0.68, 0.30),
    )
    model = create_b8(materials)
    avatar = create_review_avatar()
    export_model(model)
    scene, camera = configure_render()
    render_reviews(scene, camera, model, avatar)
    avatar.hide_viewport = True
    avatar.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER_BLEND))
    print("BLIKK_B8_V3_AUTHORING_OK")


if __name__ == "__main__":
    main()
