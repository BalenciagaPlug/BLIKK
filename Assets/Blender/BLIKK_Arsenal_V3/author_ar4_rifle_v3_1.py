"""Build the isolated original BLIKK AR4 rifle V3.1 art proof."""
from pathlib import Path
import math, sys
import bpy

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
import author_b8_v3 as base
from author_v9_smg_v3_1 import tube_path
MODEL_DIR, PREVIEW_DIR = ROOT / "Models", ROOT / "Previews"
MASTER_BLEND = ROOT / "BLIKK_AR4_RIFLE_V3_1_Master.blend"

def reference(root, name, location):
    obj = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(obj)
    obj.location, obj.parent, obj.empty_display_type = location, root, "PLAIN_AXES"
    obj["BLIKK_Reference"] = True

def create_rifle(materials):
    steel, black, burgundy, brass = materials
    root = bpy.data.objects.new("BLIKK_AR4_RIFLE_V3_1", None)
    bpy.context.collection.objects.link(root); root.empty_display_type = "ARROWS"
    for key, value in {
        "BLIKK_OriginalAsset": True, "BLIKK_AssetVersion": "3.1",
        "BLIKK_CanonicalForward": "-Z", "BLIKK_CanonicalUp": "+Y",
        "BLIKK_CanonicalRight": "+X", "BLIKK_OverallLengthStuds": 3.46,
        "BLIKK_MaximumWidthStuds": 0.43, "BLIKK_TriangleBudget": 7000,
        "BLIKK_RuntimeIntegrated": False,
        "BLIKK_IntendedPresentation": "TWO_HANDED_RIFLE_PROOF",
    }.items(): root[key] = value

    # Layered receiver, deliberately narrow rather than one Roblox-like box.
    base.profile_x("ReceiverUpper", [(0.31,.61),(.38,.43),(.36,-.49),(.18,-.64),
        (-.04,-.59),(-.13,-.41),(-.10,.48),(.08,.61)], .40, steel, 0, .032, root)
    base.profile_x("ReceiverLower", [(.10,.45),(.08,-.46),(-.21,-.49),
        (-.28,-.25),(-.20,.39)], .36, black, 1, .028, root)
    base.box("ReceiverTopRib", (0,.405,.06), (.22,.055,1.05), black,1,.010,parent=root)
    base.box("RearTrunnion", (0,.08,.57), (.39,.42,.10), black,1,.018,parent=root)
    for side in (-1,1):
        base.box(f"ReceiverPlate_{side}",(side*.211,.08,-.02),(.020,.29,.82),black,1,.006,parent=root)

    # Long vented handguard, exposed barrel, and restrained muzzle brake.
    base.profile_x("Handguard", [(.26,-.48),(.29,-1.42),(.17,-1.57),
        (-.08,-1.54),(-.17,-.47)], .37, steel,0,.030,root)
    base.box("HandguardLower",(0,-.01,-1.03),(.31,.12,1.00),black,1,.018,parent=root)
    base.box("HandguardTopSpine",(0,.34,-1.03),(.18,.055,1.02),black,1,.010,parent=root)
    for side in (-1,1):
        for index in range(5):
            base.box(f"HandguardVent_{side}_{index}",(side*.198,.16,-.63-index*.175),
                (.016,.070,.105),burgundy,2,.004,parent=root)
    base.cylinder("Barrel",(0,.07,-1.68),.060,.76,steel,0,20,parent=root,bevel=.006)
    base.cylinder("GasBlock",(0,.07,-1.57),.105,.16,black,1,18,parent=root,bevel=.009)
    base.cylinder("MuzzleBrake",(0,.07,-2.105),.090,.25,steel,0,18,parent=root,bevel=.010)
    base.cylinder("MuzzleBore",(0,.07,-2.235),.047,.025,black,1,18,parent=root,bevel=.002)
    for side in (-1,1):
        base.box(f"MuzzlePort_{side}",(side*.091,.07,-2.10),(.014,.065,.075),black,1,.003,parent=root)

    # Compact rear grip, open guard, visible trigger, and larger forward magazine.
    base.profile_x("PistolGrip", [(-.08,.39),(-.15,.23),(-.55,.28),(-.65,.42),
        (-.58,.52),(-.18,.50)], .22,black,1,.026,root)
    for index in range(4):
        base.box(f"GripInset{index}",(.114,-.27-index*.072,.43+index*.008),
            (.014,.025,.13),burgundy,2,.003,(math.radians(-6),0,0),root)
    tube_path("TriggerGuard",[(-.15,.17),(-.21,.04),(-.38,.02),(-.48,.13),(-.45,.27)],
              .020,steel,0,root)
    base.box("Trigger",(.025,-.31,.15),(.042,.18,.036),brass,3,.004,
             (math.radians(-17),0,0),root)
    base.box("MagazineWell",(0,-.19,-.26),(.32,.15,.38),steel,0,.018,parent=root)
    base.profile_x("Magazine",[(-.13,-.10),(-.22,-.50),(-.92,-.56),
        (-1.20,-.39),(-1.17,-.08),(-.31,.02)],.30,burgundy,2,.034,root)
    base.box("MagazineSpine",(0,-.70,-.35),(.20,.88,.050),black,1,.008,
             (math.radians(-9),0,0),root)
    base.box("MagazineFloorplate",(0,-1.17,-.43),(.33,.060,.30),brass,3,.010,
             (math.radians(-9),0,0),root)

    # Solid shoulder stock makes the AR4 unmistakably distinct from the V9.
    base.profile_x("StockBody",[(.29,.60),(.33,.78),(.22,1.36),(-.11,1.42),
        (-.27,1.29),(-.22,.76),(-.08,.58)],.34,black,1,.032,root)
    base.profile_x("StockCheek",[(.33,.70),(.38,1.24),(.27,1.39),(.15,1.28),
        (.17,.72)],.29,steel,0,.022,root)
    base.profile_x("StockPad",[(.32,1.36),(.28,1.51),(-.27,1.54),(-.35,1.40),
        (-.24,1.31),(.21,1.31)],.38,burgundy,2,.030,root)
    base.box("StockPadInset",(0,-.015,1.465),(.36,.38,.045),black,1,.010,parent=root)
    base.box("StockLowerBrace",(0,-.11,.96),(.13,.10,.60),steel,0,.012,
             (math.radians(4),0,0),root)

    # Mechanical controls and low-noise period detailing.
    base.box("EjectionPort",(.222,.15,-.16),(.018,.13,.34),black,1,.005,parent=root)
    base.box("Bolt",(.232,.15,-.16),(.010,.072,.23),brass,3,.003,parent=root)
    base.box("ChargingHandle",(-.235,.30,.20),(.12,.055,.15),brass,3,.008,parent=root)
    base.box("Selector",(.232,.02,.23),(.016,.055,.13),burgundy,2,.004,parent=root)
    base.box("RearSight",(0,.465,.40),(.12,.12,.07),steel,0,.010,parent=root)
    base.box("FrontSightBase",(0,.34,-1.52),(.10,.10,.08),steel,0,.008,parent=root)
    base.box("FrontSightPost",(0,.43,-1.52),(.035,.12,.035),brass,3,.004,parent=root)
    for side in (-1,1):
        rot=(0,math.radians(90),0)
        base.screw(f"ReceiverPinFront_{side}",(side*.229,.01,-.40),rot,brass,3,root)
        base.screw(f"ReceiverPinRear_{side}",(side*.229,.10,.35),rot,steel,0,root)
    base.box("AR4Mark",(-.232,.08,-.12),(.014,.060,.24),burgundy,2,.004,parent=root)
    for index in range(4):
        base.box(f"AR4MarkCut{index}",(-.241,.08,-.20+index*.055),
                 (.008,.018,.026),brass,3,.002,parent=root)

    for name, location in {
        "GripAttachment":(0,-.30,.43), "ForegripAttachment":(0,-.01,-1.08),
        "MuzzleAttachment":(0,.07,-2.25), "StockPivot":(0,.10,.60),
        "MagazinePivot":(0,-.20,-.05), "ShellEjectAttachment":(.24,.15,-.16),
    }.items(): reference(root,name,location)
    return root

def export_model(root):
    bpy.ops.object.select_all(action="DESELECT"); root.select_set(True)
    for child in root.children_recursive: child.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(MODEL_DIR/"BLIKK_AR4_RIFLE_V3_1.glb"),
        export_format="GLB",use_selection=True,export_apply=True,
        export_materials="EXPORT",export_yup=True,export_extras=True)

def configure_render():
    scene=bpy.context.scene; scene.render.engine="BLENDER_EEVEE_NEXT"
    scene.render.resolution_x,scene.render.resolution_y=1100,720
    scene.render.resolution_percentage=100; scene.render.image_settings.file_format="PNG"
    scene.world.color=(.045,.050,.065)
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 1.0
    data=bpy.data.cameras.new("ReviewCamera"); camera=bpy.data.objects.new("ReviewCamera",data)
    bpy.context.collection.objects.link(camera); camera.data.lens=60; scene.camera=camera
    floor=bpy.data.materials.new("ReviewFloor"); floor.diffuse_color=(.018,.021,.030,1)
    base.box("ReviewFloor",(0,0,-.65),(15,15,.08),floor,1,0)
    for name,location,energy,size,color in (
        ("Key",(4.8,4.8,-3.4),2300,4.5,(.72,.82,1.0)),
        ("Rim",(-4.5,2.5,2.8),1700,3.5,(.64,.19,.14)),
        ("Fill",(0,5.8,4.5),1900,5.5,(.42,.36,.52))):
        ld=bpy.data.lights.new(name,"AREA"); ld.energy,ld.size,ld.color=energy,size,color
        light=bpy.data.objects.new(name,ld); light.location=location
        bpy.context.collection.objects.link(light); base.look_at(light,(0,0,-.35))
    return scene,camera

def render_reviews(scene,camera,model,avatar):
    for item in [avatar,*avatar.children_recursive]: item.hide_render=True
    model.rotation_euler=(math.radians(90),0,0)
    views={
        "AR4_RIFLE_V3_1_SIDE":((8.4,0,1.8),(0,0,-.28)),
        "AR4_RIFLE_V3_1_FRONT_3Q":((6.6,6.8,3.0),(0,0,-.28)),
        "AR4_RIFLE_V3_1_REAR_3Q":((-6.6,-6.8,3.0),(0,0,-.28))}
    for name,(location,target) in views.items():
        camera.location=location; base.look_at(camera,target)
        scene.render.filepath=str(PREVIEW_DIR/f"{name}.png"); bpy.ops.render.render(write_still=True)
    for item in [avatar,*avatar.children_recursive]: item.hide_render=False
    avatar.rotation_euler=(math.radians(90),0,0)
    model.rotation_euler=(math.radians(90),math.radians(-4),math.radians(-7))
    model.location=(.74,-.08,1.72); camera.location=(8.4,8.4,4.6)
    base.look_at(camera,(0,0,1.42)); scene.render.filepath=str(PREVIEW_DIR/"AR4_RIFLE_V3_1_BLOCK_R15_SCALE.png")
    bpy.ops.render.render(write_still=True)

def main():
    base.clear_scene(); atlas=bpy.data.images.load(str(ROOT/"Textures"/"B8_V3_1_BaseColor.png"))
    materials=(base.make_material("AR4_BluedSteel",atlas,0,.78,.26),
        base.make_material("AR4_DarkPolymer",atlas,1,.12,.46),
        base.make_material("AR4_BurgundyComposite",atlas,2,.11,.39),
        base.make_material("AR4_WornHardware",atlas,3,.64,.29))
    model=create_rifle(materials); avatar=base.create_review_avatar(); export_model(model)
    scene,camera=configure_render(); render_reviews(scene,camera,model,avatar)
    for item in [avatar,*avatar.children_recursive]: item.hide_viewport=item.hide_render=True
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER_BLEND))
    print("BLIKK_AR4_RIFLE_V3_1_AUTHORING_OK")

if __name__ == "__main__": main()
