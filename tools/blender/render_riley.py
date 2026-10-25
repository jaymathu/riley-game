"""Renders review images of Riley from riley.blend.
python render_riley.py <blend> <out_dir> <job> [args]
jobs: turn | faces | poses | hero | test
"""
import sys, os, math
import bpy
from mathutils import Vector as V, Euler

blend, OUT, job = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riley_lib import make_mat, hexcol

sc = bpy.context.scene
rig = bpy.data.objects['RileyRig']
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = int(os.environ.get('SAMPLES', 48))
sc.cycles.use_denoising = True
sc.cycles.max_bounces = 6
sc.view_settings.view_transform = 'Standard'
sc.view_settings.look = 'None'
sc.render.film_transparent = False

# pivot so we can spin / lift the character
pivot = bpy.data.objects.new('Pivot', None)
sc.collection.objects.link(pivot)
rig.parent = pivot

# world
w = bpy.data.worlds.new('W')
sc.world = w
w.use_nodes = True
bg = w.node_tree.nodes['Background']
bg.inputs['Color'].default_value = (*hexcol('#CFE9FF'), 1)
bg.inputs['Strength'].default_value = 0.35

# cyclorama backdrop
import bmesh
bm = bmesh.new()
prof = []
for i in range(17):
    a = math.pi / 2 * i / 16
    prof.append((1.2 - 1.2 * math.cos(a), 1.2 * math.sin(a)) if True else None)
prof = [(-6.0, 0.0)] + [(1.5 + 1.2 * math.sin(math.pi / 2 * i / 16), 1.2 - 1.2 * math.cos(math.pi / 2 * i / 16)) for i in range(17)] + [(2.7, 6.0)]
cols = []
for x in (-6, 6):
    cols.append([bm.verts.new((x, y, z)) for y, z in prof])
for i in range(len(prof) - 1):
    bm.faces.new((cols[0][i], cols[0][i + 1], cols[1][i + 1], cols[1][i]))
for f in bm.faces:
    f.smooth = True
me = bpy.data.meshes.new('Cyc')
bm.to_mesh(me)
cyc = bpy.data.objects.new('Cyc', me)
sc.collection.objects.link(cyc)
me.materials.append(make_mat('Backdrop', '#8CC8F0', 0.9))


def area(name, loc, target, power, size, color='#FFFFFF'):
    L = bpy.data.lights.new(name, 'AREA')
    L.energy = power
    L.size = size
    L.color = hexcol(color)
    o = bpy.data.objects.new(name, L)
    sc.collection.objects.link(o)
    o.location = loc
    d = V(target) - V(loc)
    o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return o


area('Key', (-2.2, -3.0, 3.0), (0, 0, 0.7), 170, 2.5, '#FFF6EA')
area('Fill', (2.8, -2.4, 1.4), (0, 0, 0.7), 70, 3.0, '#E6F2FF')
area('Rim', (0.6, 2.4, 2.6), (0, 0, 0.9), 160, 1.5, '#FFFFFF')

cam_d = bpy.data.cameras.new('Cam')
cam = bpy.data.objects.new('Cam', cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


def aim(loc, target, lens=70):
    cam.location = loc
    cam.rotation_euler = (V(target) - V(loc)).to_track_quat('-Z', 'Y').to_euler()
    cam_d.lens = lens


def pose(action, frame):
    rig.animation_data.action = bpy.data.actions[action]
    sc.frame_set(frame)


def render(path, rx, ry):
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


if job in ('test', 'turn'):
    pose('idle', 0)
    views = [('front', 0), ('three_quarter', -35), ('side', -90), ('back', 180)] if job == 'turn' else [('front', 0), ('three_quarter', -35)]
    for nm, ang in views:
        pivot.rotation_euler = (0, 0, math.radians(ang))
        aim((0, -4.6, 0.95), (0, 0, 0.66), 70)
        render(os.path.join(OUT, f'turn_{nm}.png'), 700, 1000)

if job == 'hero':
    pose('idle', 0)
    pivot.rotation_euler = (0, 0, math.radians(-28))
    aim((0.35, -3.3, 1.05), (0, 0, 0.70), 60)
    render(os.path.join(OUT, 'hero.png'), 1200, 1500)

if job == 'faces':
    pivot.rotation_euler = (0, 0, math.radians(-14))
    items = [('happy', 'idle', 0), ('laugh', 'victory', 0), ('panic', 'panic_flail', 0),
             ('determined', 'landing_prep', 0), ('ouch', 'land_awkward', 12), ('dizzy', 'crash', 20)]
    for nm, act, fr in items:
        pose(act, fr)
        if act == 'crash':
            # look straight down at him lying on his back
            hb = rig.pose.bones['head']
            hp = rig.matrix_world @ hb.head
            hc = rig.matrix_world @ (hb.matrix @ V((0, 0.15, 0)))
            nz = (rig.matrix_world.to_3x3() @ hb.matrix.to_3x3() @ V((0, 0, 1))).normalized()
            aim(hc + nz * 1.6 + V((0, 0, 0.0)), hc, 85)
        else:
            hb = rig.pose.bones['head']
            hc = rig.matrix_world @ (hb.matrix @ V((0, 0.14, -0.01)))
            aim(hc + V((0.25, -1.55, 0.06)), hc, 85)
        render(os.path.join(OUT, f'face_{nm}.png'), 600, 600)

if job == 'poses':
    pivot.rotation_euler = (0, 0, math.radians(-38))
    items = [('launch_prep', 'launch_prep', 6, 0), ('launch', 'launch', 6, 0.3), ('airborne', 'airborne', 10, 0.35),
             ('tumble', 'tumble_forward', 4, 0.45), ('panic', 'panic_flail', 2, 0.35), ('landing_prep', 'landing_prep', 0, 0.3),
             ('perfect', 'land_perfect', 34, 0), ('awkward', 'land_awkward', 6, 0), ('crash', 'crash', 25, 0),
             ('victory', 'victory', 8, 0)]
    only = sys.argv[4].split(',') if len(sys.argv) > 4 else None
    for nm, act, fr, lift in items:
        if only and nm not in only:
            continue
        pose(act, fr)
        pivot.location = (0, 0, lift)
        aim((0, -4.2, 1.0 + lift * 0.5), (0, 0, 0.62 + lift * 0.8), 60)
        if nm == 'crash':
            aim((0.0, -3.4, 2.1), (0, 0.25, 0.2), 60)
        render(os.path.join(OUT, f'pose_{nm}.png'), 640, 760)

if job == 'icon':
    sc.render.film_transparent = True
    cyc.hide_render = True
    pose('victory', 0)
    pivot.rotation_euler = (0, 0, math.radians(-12))
    hb = rig.pose.bones['head']
    hc = rig.matrix_world @ (hb.matrix @ V((0, 0.16, -0.02)))
    aim(hc + V((0.2, -1.9, 0.12)), hc + V((0, 0, -0.02)), 85)
    render(os.path.join(OUT, 'icon_face.png'), 1024, 1024)
    pose('launch', 6)
    pivot.rotation_euler = (0, 0, math.radians(-30))
    pivot.location = (0, 0, 0.3)
    aim((0.3, -4.2, 1.3), (0, 0, 1.0), 60)
    render(os.path.join(OUT, 'splash_riley.png'), 900, 1100)
