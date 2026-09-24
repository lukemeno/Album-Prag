"""Tram-Klingel für Album: Modell, Rig-Drehpunkte und Render der Einzelteile.

Aufruf (ohne Oberfläche):
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tram_bell.py -- <ausgabeordner>

Ergebnis im Ausgabeordner:
  bell.png, clapper.png, bracket.png, preview.png  (transparent, gleiche Kamera, 600 × 600)
  rig.json  Drehpunkte (Pixel) für die Knochen in Rive
"""
import bpy, bmesh, json, math, sys, os
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/tram-bell"
os.makedirs(out, exist_ok=True)
SIZE = 600

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def material(name, color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

brass = material("Messing", (0.83, 0.58, 0.19), 1.0, 0.22)
dark_brass = material("Messing dunkel", (0.45, 0.30, 0.10), 1.0, 0.35)
iron = material("Eisen", (0.05, 0.05, 0.06), 0.8, 0.45)

def attach(child, parent):
    """Hängt ein Objekt an, ohne dass es springt (Blender verschiebt sonst um die Elternposition)."""
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()

def lathe(name, profile, segments=96):
    """Dreht ein Profil (r, z) um die Z-Achse."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile])
    for i in range(segments):
        ring, nxt = rings[i], rings[(i + 1) % segments]
        for j in range(len(profile) - 1):
            bm.faces.new((ring[j], ring[j + 1], nxt[j + 1], nxt[j]))
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    for p in obj.data.polygons: p.use_smooth = True
    return obj

# Glockenkörper: klassische Straßenbahn-Glockenschale, oben geschlossen, unten offen mit Wulst.
bell_profile = [(0.0, 1.00), (0.10, 0.99), (0.22, 0.96), (0.34, 0.90), (0.44, 0.80), (0.52, 0.66),
                (0.58, 0.50), (0.63, 0.34), (0.68, 0.20), (0.74, 0.10), (0.78, 0.05), (0.78, 0.02),
                (0.74, 0.00), (0.70, 0.03)]
bell = lathe("Glocke", bell_profile)
bell.data.materials.append(brass)
# Knauf oben
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0, 0, 1.04), segments=48, ring_count=24)
knob = bpy.context.object; knob.name = "Knauf"; knob.data.materials.append(dark_brass)
bpy.ops.object.shade_smooth()
attach(knob, bell)

# Klöppel: Stange mit Kugel, hängt im Inneren und schaut unten heraus.
bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.12, location=(0, 0, 0.36), vertices=32)
rod = bpy.context.object; rod.name = "Klöppel"; rod.data.materials.append(iron)
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0, 0, -0.22), segments=48, ring_count=24)
ball = bpy.context.object; ball.name = "Klöppelkugel"; ball.data.materials.append(iron)
bpy.ops.object.shade_smooth()
attach(ball, rod)

# Halterung: gebogener Arm von oben zum Knauf plus Wandplatte.
bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
arm = bpy.context.object; arm.name = "Halterung"
pts = arm.data.splines[0].bezier_points
pts[0].co = Vector((-0.9, 0, 1.55)); pts[0].handle_left = Vector((-1.1, 0, 1.55)); pts[0].handle_right = Vector((-0.5, 0, 1.55))
pts[1].co = Vector((0, 0, 1.12)); pts[1].handle_left = Vector((-0.05, 0, 1.45)); pts[1].handle_right = Vector((0.05, 0, 0.9))
arm.data.bevel_depth = 0.045; arm.data.bevel_resolution = 8
arm.data.materials.append(iron)
bpy.ops.mesh.primitive_cube_add(size=1, location=(-0.95, 0, 1.55))
plate = bpy.context.object; plate.name = "Wandplatte"; plate.scale = (0.06, 0.28, 0.28); plate.data.materials.append(iron)
attach(plate, arm)

# Kamera: orthografisch, leicht von oben, damit man in die Glocke ahnt.
cam_data = bpy.data.cameras.new("Kamera"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 3.0
cam = bpy.data.objects.new("Kamera", cam_data); scene.collection.objects.link(cam)
cam.location = (0.35, -6, 1.45); cam.rotation_euler = (math.radians(86), 0, math.radians(3))
scene.camera = cam

# Licht: warmes Hauptlicht, kühles Gegenlicht für die Metallkante, Welt leicht warm.
def area(name, loc, rot, energy, color, size):
    data = bpy.data.lights.new(name, "AREA"); data.energy = energy; data.color = color; data.size = size
    obj = bpy.data.objects.new(name, data); obj.location = loc; obj.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(obj)
area("Haupt", (-3, -4, 4), (55, 0, -35), 900, (1.0, 0.93, 0.82), 3)
area("Kante", (3.5, 2, 2.5), (70, 0, 130), 700, (0.75, 0.85, 1.0), 2)
area("Boden", (0, -3, -2), (-60, 0, 0), 150, (1.0, 0.9, 0.8), 4)
world = bpy.data.worlds.new("Welt"); scene.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.55, 0.50, 0.44, 1); bg.inputs["Strength"].default_value = 0.6

# Rendern
scene.render.engine = "CYCLES"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"

parts = {"bracket": [arm, plate], "bell": [bell, knob], "clapper": [rod, ball]}
everything = [o for group in parts.values() for o in group]

def render(name, visible):
    for o in everything:
        o.hide_render = o not in visible
        # Unsichtbare Teile werfen trotzdem keinen Schatten auf die sichtbaren.
    scene.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)

for name, objs in parts.items():
    render(name, objs)
render("preview", everything)

def pixel(point):
    co = world_to_camera_view(scene, cam, Vector(point))
    return [round(co.x * SIZE, 1), round((1 - co.y) * SIZE, 1)]

rig = {
    "size": SIZE,
    # Glocke dreht um den Knauf, der Klöppel um seinen Aufhängepunkt oben in der Glocke.
    "bellPivot": pixel((0, 0, 1.08)),
    "bellLip": pixel((0, 0, 0.0)),
    "clapperPivot": pixel((0, 0, 0.92)),
    "clapperTip": pixel((0, 0, -0.22)),
}
with open(os.path.join(out, "rig.json"), "w") as f:
    json.dump(rig, f, indent=2)
print("RIG", json.dumps(rig))
