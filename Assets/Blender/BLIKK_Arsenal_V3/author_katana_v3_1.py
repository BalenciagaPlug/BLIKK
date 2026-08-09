"""Build the original slim BLIKK Training Katana V3.1 proof."""

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
MASTER_BLEND = ROOT / "BLIKK_TRAINING_KATANA_V3_1_Master.blend"
for directory in (MODEL_DIR, PREVIEW_DIR, TEXTURE_DIR):
    directory.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                       bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def make_atlas():
    size = 1024
    image = bpy.data.images.new("Katana_V3_1_BaseColor", width=size, height=size, alpha=True)
    pixels = array("f", [0.0]) * (size * size * 4)
    random.seed(20050608)
    palettes = (
        ((0.28, 0.31, 0.35), (0.72, 0.76, 0.80)),  # tempered steel
        ((0.025, 0.030, 0.038), (0.10, 0.11, 0.13)), # lacquer / wrap
        ((0.13, 0.025, 0.030), (0.34, 0.060, 0.075)), # burgundy ray skin
        ((0.25, 0.18, 0.07), (0.58, 0.43, 0.16)),   # aged hardware
    )
    for y in range(size):
        longitudinal = 0.025 * math.sin(y * 0.052) + 0.012 * math.sin(y * 0.211)
        for x in range(size):
            tile = min(3, x // 256)
            lo, hi = palettes[tile]
            local_x = x % 256
            grain = (random.random() - 0.5) * (0.045 if tile == 0 else 0.070)
            brushed = 0.05 * math.sin(local_x * 0.12) if tile == 0 else 0.0
            wear = 0.09 if (x * 13 + y * 29) % 1201 < 2 else 0.0
            value = max(0.0, min(1.0, 0.35 + longitudinal + grain + brushed + wear))
            i = (y * size + x) * 4
            pixels[i] = lo[0] + (hi[0] - lo[0]) * value
            pixels[i + 1] = lo[1] + (hi[1] - lo[1]) * value
            pixels[i + 2] = lo[2] + (hi[2] - lo[2]) * value
            pixels[i + 3] = 1.0
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(TEXTURE_DIR / "TrainingKatana_V3_1_BaseColor.png")
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
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def assign_uv(obj, tile):
    mesh = obj.data
    layer = mesh.uv_layers.new(name="UVMap")
    coords = [vertex.co for vertex in mesh.vertices]
    min_y, max_y = min(c.y for c in coords), max(c.y for c in coords)
    min_z, max_z = min(c.z for c in coords), max(c.z for c in coords)
    span_y, span_z = max(max_y - min_y, 0.001), max(max_z - min_z, 0.001)
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        layer.data[loop.index].uv = (tile * 0.25 + 0.012 + ((co.z - min_z) / span_z) * 0.226,
                                     0.025 + ((co.y - min_y) / span_y) * 0.95)


def finish(obj, material, tile, bevel=0.012, segments=1, smooth=True):
    obj.data.materials.append(material)
    assign_uv(obj, tile)
    if bevel > 0:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = segments
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(22)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        obj.data.set_sharp_from_angle(angle=math.radians(42))
    obj["BLIKK_RenderMesh"] = True
    return obj


def box(name, location, scale, material, tile, bevel=0.012, rotation=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] * 0.5, scale[1] * 0.5, scale[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.parent = parent
    return finish(obj, material, tile, bevel)


def cylinder_y(name, location, radius, depth, material, tile, vertices=20, parent=None, bevel=0.008):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=location, rotation=(math.radians(90), 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    return finish(obj, material, tile, bevel)


def torus_y(name, location, major, minor, material, tile, parent=None, rotation_y=0):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=18, minor_segments=5,
                                    location=location,
                                    rotation=(math.radians(90), rotation_y, 0))
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    # Torus geometry is already rounded; beveling every ring edge multiplies
    # invisible density without improving the Roblox-distance silhouette.
    return finish(obj, material, tile, 0)


def blade_geometry(root, steel, dark, burgundy):
    def spine_z(t):
        # The mune remains one uninterrupted shallow curve through the kissaki.
        # It never collapses toward a moving centreline to manufacture the point.
        return 0.104 + 0.140 * (t ** 1.55)

    def body_width(t):
        # Preserve a readable cutting body for most of the blade. Only the ha
        # sweeps into the kissaki; the mune above stays on its established line.
        if t <= 0.80:
            return 0.215 - 0.025 * (t / 0.80)
        return 0.190

    def edge_z(t):
        spine = spine_z(t)
        width = body_width(t)
        if t <= 0.80:
            return spine - width
        tip_t = (t - 0.80) / 0.20
        # Smoothly lift only the cutting edge into a compact, asymmetric
        # kissaki. The smoothstep gives the fukura a deliberate convex sweep.
        edge_sweep = tip_t * tip_t * (3.0 - 2.0 * tip_t)
        return spine - width * (1.0 - edge_sweep)

    sections = 31
    vertices = []
    for index in range(sections):
        t = index / (sections - 1)
        y = 0.43 + 2.12 * t
        spine = spine_z(t)
        edge = edge_z(t)
        centre = (spine + edge) * 0.5
        thickness = 0.030 * (1 - 0.30 * t)
        if t > 0.90:
            thickness *= max(0.05, 1.0 - ((t - 0.90) / 0.10))
        vertices.extend([
            (-thickness, y, centre),
            (0, y, spine),
            (thickness, y, centre),
            (0, y, edge),
        ])
    faces = []
    for index in range(sections - 1):
        a, b = index * 4, (index + 1) * 4
        faces.extend(((a, b, b + 1, a + 1), (a + 1, b + 1, b + 2, a + 2),
                      (a + 2, b + 2, b + 3, a + 3), (a + 3, b + 3, b, a)))
    faces.extend(((0, 1, 2, 3), tuple(range((sections - 1) * 4, sections * 4))))
    mesh = bpy.data.meshes.new("BladeMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    blade = bpy.data.objects.new("TemperedBlade", mesh)
    bpy.context.collection.objects.link(blade)
    blade.parent = root
    finish(blade, steel, 0, 0.006, 2)

    # Recessed fullers on both faces preserve the long, slim early-PC silhouette.
    for side in (-1, 1):
        verts, quads = [], []
        strip_sections = 22
        for index in range(strip_sections):
            t = index / (strip_sections - 1) * 0.86
            y = 0.54 + 2.12 * t
            spine = spine_z(t)
            edge = edge_z(t)
            width = spine - edge
            x = side * (0.031 * (1 - 0.30 * t) + 0.002)
            verts.extend(((x, y, edge + width * 0.64),
                          (x, y, edge + width * 0.78)))
        for index in range(strip_sections - 1):
            i = index * 2
            quads.append((i, i + 1, i + 3, i + 2))
        fuller_mesh = bpy.data.meshes.new(f"Fuller{side}Mesh")
        fuller_mesh.from_pydata(verts, [], quads)
        fuller_mesh.update()
        fuller = bpy.data.objects.new(f"Fuller_{side}", fuller_mesh)
        bpy.context.collection.objects.link(fuller)
        fuller.parent = root
        finish(fuller, dark, 1, 0, smooth=False)

    # A small original BLIKK identifier near the habaki; no neon stripe along the blade.
    box("BladeIdentifier", (0.034, 0.61, 0.005), (0.008, 0.16, 0.035), burgundy, 2,
        0.002, (math.radians(2), 0, math.radians(-7)), root)


def create_katana(materials):
    steel, dark, burgundy, brass = materials
    root = bpy.data.objects.new("BLIKK_TRAINING_KATANA_V3_1", None)
    bpy.context.collection.objects.link(root)
    root.empty_display_type = "ARROWS"
    root["BLIKK_OriginalAsset"] = True
    root["BLIKK_AssetVersion"] = "3.1"
    root["BLIKK_GripToTip"] = "+Y"
    root["BLIKK_BladeFaceAxis"] = "+X"
    root["BLIKK_CuttingEdgeAxis"] = "-Z"
    root["BLIKK_OverallLengthStuds"] = 2.82
    root["BLIKK_TriangleBudget"] = 4200
    root["BLIKK_RuntimeIntegrated"] = False

    blade_geometry(root, steel, dark, burgundy)
    cylinder_y("Habaki", (0, 0.395, 0.0), 0.102, 0.13, brass, 3, 16, root, 0.008)

    # Slim asymmetrical guard with restrained mechanical cut-outs.
    torus_y("TsubaOuter", (0, 0.315, 0), 0.165, 0.040, dark, 1, root)
    cylinder_y("TsubaCore", (0, 0.315, 0), 0.135, 0.055, burgundy, 2, 16, root, 0.006)
    for angle in (45, 135, 225, 315):
        radians = math.radians(angle)
        box(f"TsubaInlay{angle}", (math.cos(radians) * 0.115, 0.279,
            math.sin(radians) * 0.115), (0.050, 0.018, 0.020), brass, 3, 0.003,
            (0, -radians, 0), root)

    cylinder_y("HandleCore", (0, -0.045, 0), 0.092, 0.66, burgundy, 2, 16, root, 0.010)
    cylinder_y("HandleUnderwrap", (0, -0.045, 0), 0.100, 0.625, dark, 1, 16, root, 0.007)
    # Alternating wrap rings create a readable woven cadence at Roblox camera distance.
    for index in range(9):
        y = 0.225 - index * 0.069
        torus_y(f"HandleWrap{index}", (0, y, 0), 0.102, 0.014,
                dark if index % 2 == 0 else burgundy, 1 if index % 2 == 0 else 2,
                root, math.radians(18 if index % 2 == 0 else -18))
    cylinder_y("Pommel", (0, -0.410, 0), 0.112, 0.09, brass, 3, 18, root, 0.009)
    cylinder_y("PommelCap", (0, -0.465, 0), 0.082, 0.035, dark, 1, 18, root, 0.005)

    references = {
        "GripAttachment": (0, -0.055, 0),
        "BladeBase": (0, 0.43, 0),
        "BladeTip": (0, 2.55, 0.244),
        "Trail0": (0, 0.48, -0.11),
        "Trail1": (0, 2.50, 0.23),
    }
    for name, location in references.items():
        empty = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(empty)
        empty.location = location
        empty.parent = root
        empty.empty_display_type = "PLAIN_AXES"
        empty["BLIKK_Reference"] = True
    return root


def create_review_avatar():
    root = bpy.data.objects.new("BlockR15_ReviewOnly", None)
    bpy.context.collection.objects.link(root)
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
        part = box("Review" + name, location, scale, material, 1, 0.045, parent=root)
        part["BLIKK_ReviewOnly"] = True
    return root


def export_model(root):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(MODEL_DIR / "BLIKK_TRAINING_KATANA_V3_1.glb"),
                              export_format="GLB", use_selection=True, export_apply=True,
                              export_materials="EXPORT", export_yup=True, export_extras=True)


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def configure_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (0.008, 0.010, 0.016)
    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.data.lens = 58
    scene.camera = camera
    floor_material = bpy.data.materials.new("ReviewFloor")
    floor_material.diffuse_color = (0.012, 0.014, 0.020, 1)
    box("ReviewFloor", (0, 0, -0.57), (14, 14, 0.08), floor_material, 1, 0)
    for name, location, energy, size, color in (
        ("Key", (4.5, -3.0, 4.5), 1200, 4.0, (0.58, 0.70, 1.0)),
        ("Rim", (-4.0, 3.0, 2.5), 900, 3.0, (0.50, 0.10, 0.08)),
        ("Fill", (0, 0, 6.0), 600, 4.0, (0.24, 0.20, 0.30)),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        light = bpy.data.objects.new(name, data)
        light.location = location
        bpy.context.collection.objects.link(light)
        look_at(light, (0, 1.0, 0))
    return scene, camera


def render_reviews(scene, camera, model, avatar):
    for item in [avatar, *avatar.children_recursive]:
        item.hide_render = True
    views = {
        "KATANA_V3_1_SIDE": ((5.8, 1.05, 1.8), (0, 1.05, 0)),
        "KATANA_V3_1_FRONT_3Q": ((4.7, -3.7, 2.8), (0, 1.05, 0)),
        "KATANA_V3_1_REAR_3Q": ((-4.7, 4.8, 2.6), (0, 1.05, 0)),
    }
    for name, (location, target) in views.items():
        camera.location = location
        look_at(camera, target)
        scene.render.filepath = str(PREVIEW_DIR / f"{name}.png")
        bpy.ops.render.render(write_still=True)

    for item in [avatar, *avatar.children_recursive]:
        item.hide_render = False
    avatar.rotation_euler = (math.radians(90), 0, 0)
    model.rotation_euler = (math.radians(-110), math.radians(-5), math.radians(8))
    model.location = (0.72, -0.08, 1.55)
    camera.location = (7.4, 7.8, 4.1)
    look_at(camera, (0, 0, 1.42))
    scene.render.filepath = str(PREVIEW_DIR / "KATANA_V3_1_BLOCK_R15_SCALE.png")
    bpy.ops.render.render(write_still=True)
    model.rotation_euler = (0, 0, 0)
    model.location = (0, 0, 0)
    avatar.rotation_euler = (0, 0, 0)


def main():
    clear_scene()
    atlas = make_atlas()
    materials = (
        make_material("KatanaTemperedSteel", atlas, 0, 0.88, 0.20),
        make_material("KatanaDarkLacquer", atlas, 1, 0.18, 0.43),
        make_material("KatanaBurgundyWrap", atlas, 2, 0.10, 0.40),
        make_material("KatanaAgedHardware", atlas, 3, 0.72, 0.28),
    )
    model = create_katana(materials)
    avatar = create_review_avatar()
    export_model(model)
    scene, camera = configure_render()
    render_reviews(scene, camera, model, avatar)
    for item in [avatar, *avatar.children_recursive]:
        item.hide_viewport = True
        item.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER_BLEND))
    print("BLIKK_KATANA_V3_1_AUTHORING_OK")


if __name__ == "__main__":
    main()
