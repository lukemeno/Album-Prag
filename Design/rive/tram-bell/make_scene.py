"""Baut scene.rml für die Tram-Klingel aus den Blender-Drehpunkten (renders/rig.json).

Aufbau:
  Halterung (fest) · Klöppel (eigener Knochen, schwingt nachgezogen) · Glocke (zwei Knochen:
  Schale schwingt um den Knauf, der Rand federt nach).
Die Bilder liegen mit Ursprung oben links bei (0, 0), damit Bild-, Artboard- und Blender-Pixel identisch sind.
State Machine: Trigger „ring“ spielt „Klingeln“ einmal und kehrt in „Ruhe“ zurück.

Aufruf: python3 make_scene.py
"""
import base64, json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
rig = json.load(open(os.path.join(HERE, "renders", "rig.json")))
S = rig["size"]
bx, by = rig["bellPivot"]
lip_y = rig["bellLip"][1]
cx, cy = rig["clapperPivot"]
tip_y = rig["clapperTip"][1]
DOWN = math.pi / 2  # Knochen zeigen nach unten (y wächst nach unten)
rim_start = by + (lip_y - by) * 0.5

def varuint(n):
    out = bytearray()
    while True:
        b = n & 0x7F; n >>= 7
        out.append(b | (0x80 if n else 0))
        if not n: return bytes(out)

def grid_mesh(xs, ys, weight_for_row):
    """Gitter-Mesh über das ganze Bild; Gewichte je Zeile. Außen herum zuerst (Kontur), innen danach."""
    cols, rows = len(xs), len(ys)
    idx = lambda c, r: r * cols + c
    vertices = [(x, y, r) for r, y in enumerate(ys) for x in xs]
    contour = [idx(c, 0) for c in range(cols)] + [idx(cols - 1, r) for r in range(1, rows)] \
        + [idx(c, rows - 1) for c in range(cols - 2, -1, -1)] + [idx(0, r) for r in range(rows - 2, 0, -1)]
    inner = [i for i in range(len(vertices)) if i not in contour]
    order = contour + inner
    position = {old: new for new, old in enumerate(order)}
    triangles = []
    for r in range(rows - 1):
        for c in range(cols - 1):
            a, b, d, e = idx(c, r), idx(c + 1, r), idx(c + 1, r + 1), idx(c, r + 1)
            triangles += [position[a], position[b], position[d], position[a], position[d], position[e]]
    lines = []
    for n, old in enumerate(order):
        x, y, r = vertices[old]
        kind = "ContourMeshVertex" if n < len(contour) else "MeshVertex"
        values, indices = weight_for_row(r)
        lines.append(f'<{kind} x="{x:.1f}" y="{y:.1f}" u="{x / S:.4f}" v="{y / S:.4f}" name="V{n}">'
                     f'<Weight values="{values}" indices="{indices}"/></{kind}>')
    tri = base64.b64encode(b"".join(varuint(i) for i in triangles)).decode()
    return tri, "\n".join(lines)

# Glocke: oben (bis zum Drehpunkt) an der Schale, unten am Rand, dazwischen gemischt.
bell_rows = [0, by, rim_start, lip_y + 30, S]
def bell_weight(row):
    if bell_rows[row] <= by: return 255, 1                      # Schale
    if bell_rows[row] <= rim_start: return 128 | (127 << 8), 1 | (2 << 8)  # halb/halb
    return 255, 2                                               # Rand
bell_tri, bell_vertices = grid_mesh([0, bx - 160, bx, bx + 160, S], bell_rows, bell_weight)
clapper_tri, clapper_vertices = grid_mesh([0, S], [0, S], lambda r: (255, 1))

def keys(object_id, prop, frames, base):
    """Schwingung um einen Grundwert, jede Stufe mit weicher Ein-/Ausblendung."""
    body = []
    for n, (frame, offset) in enumerate(frames):
        last = n == len(frames) - 1
        interp = "" if last else ' interpolationType="cubic"'
        ease = "" if last else '<CubicEaseInterpolator x1="0.37" y1="0" x2="0.63" y2="1"/>'
        body.append(f'<KeyFrameDouble value="{base + offset:.5f}" frame="{frame}"{interp}>{ease}</KeyFrameDouble>')
    return (f'<KeyedObject objectId="{object_id}"><KeyedProperty propertyKey="{prop}">'
            + "".join(body) + "</KeyedProperty></KeyedObject>")

ROT = 15
ring = "\n".join([
    # Schale: kräftiger Schlag, dann ausschwingen.
    keys("0:30", ROT, [(0, 0), (7, 0.32), (17, -0.24), (27, 0.15), (37, -0.08), (47, 0.035), (60, 0)], DOWN),
    # Rand federt leicht gegen die Bewegung.
    keys("0:31", ROT, [(0, 0), (7, -0.06), (17, 0.05), (27, -0.03), (37, 0.015), (60, 0)], 0),
    # Klöppel hängt nach und schlägt weiter aus.
    keys("0:40", ROT, [(0, 0), (4, -0.1), (12, 0.55), (22, -0.42), (32, 0.26), (42, -0.13), (52, 0.05), (66, 0)], DOWN),
])

rml = f'''<Rive version="1" kind="fragment">
    <ImageAsset file="renders/bracket.png" name="Halterung" id="0:60"/>
    <ImageAsset file="renders/clapper.png" name="Klöppel" id="0:61"/>
    <ImageAsset file="renders/bell.png" name="Glocke" id="0:62"/>

    <Artboard defaultStateMachineId="0:7" styleId="0:5" width="{S}" height="{S}" name="Tram-Klingel" id="0:2">
        <LayoutComponentStyle name="Artboard Style" id="0:5"/>

        <!-- Zeichenreihenfolge: das erste Element liegt oben. -->
        <RootBone x="{bx:.1f}" y="{by:.1f}" rotation="{DOWN:.7f}" length="{rim_start - by:.1f}" name="Schale" id="0:30">
            <Bone length="{lip_y - rim_start:.1f}" rotation="0" name="Rand" id="0:31"/>
        </RootBone>
        <Image x="0" y="0" originX="0" originY="0" assetId="0:62" name="Glocke" id="0:23">
            <Mesh triangleIndexBytes="{bell_tri}" name="Mesh" id="0:24">
{bell_vertices}
                <Skin tx="0" ty="0" name="Skin">
                    <Tendon boneId="0:30" xx="0" xy="1" yx="-1" yy="0" tx="{bx:.1f}" ty="{by:.1f}" name="Schale"/>
                    <Tendon boneId="0:31" xx="0" xy="1" yx="-1" yy="0" tx="{bx:.1f}" ty="{rim_start:.1f}" name="Rand"/>
                </Skin>
            </Mesh>
        </Image>

        <RootBone x="{cx:.1f}" y="{cy:.1f}" rotation="{DOWN:.7f}" length="{tip_y - cy:.1f}" name="Klöppel" id="0:40"/>
        <Image x="0" y="0" originX="0" originY="0" assetId="0:61" name="Klöppel" id="0:21">
            <Mesh triangleIndexBytes="{clapper_tri}" name="Mesh" id="0:22">
{clapper_vertices}
                <Skin tx="0" ty="0" name="Skin">
                    <Tendon boneId="0:40" xx="0" xy="1" yx="-1" yy="0" tx="{cx:.1f}" ty="{cy:.1f}" name="Klöppel"/>
                </Skin>
            </Mesh>
        </Image>

        <Image x="0" y="0" originX="0" originY="0" assetId="0:60" name="Halterung" id="0:20"/>

        <StateMachine name="Klingel" id="0:7">
            <StateMachineTrigger name="ring" id="0:50"/>
            <StateMachineLayer name="Klingel" id="0:8">
                <AnyState x="200" y="-120"/>
                <ExitState x="400" y="-120"/>
                <EntryState><StateTransition stateToId="0:12"/></EntryState>
                <AnimationState x="200" y="0" animationId="0:10" id="0:12">
                    <StateTransition stateToId="0:13">
                        <TransitionTriggerCondition inputId="0:50"/>
                    </StateTransition>
                </AnimationState>
                <AnimationState x="400" y="0" animationId="0:11" id="0:13">
                    <StateTransition stateToId="0:13">
                        <TransitionTriggerCondition inputId="0:50"/>
                    </StateTransition>
                    <StateTransition stateToId="0:12" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
            </StateMachineLayer>
        </StateMachine>

        <LinearAnimation duration="1" name="Ruhe" id="0:10"/>
        <LinearAnimation duration="66" name="Klingeln" id="0:11">
{ring}
        </LinearAnimation>
    </Artboard>
</Rive>
'''
open(os.path.join(HERE, "scene.rml"), "w").write(rml)
open(os.path.join(HERE, "rive.yaml"), "w").write("name: tram-bell\n")
print("scene.rml geschrieben")
