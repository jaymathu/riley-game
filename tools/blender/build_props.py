"""Builds every non-character 3D asset for R.I.L.E.Y. as individual .glb files.

python build_props.py <out_dir>  (bpy 4.2+)

Conventions: Blender Z up, travel direction +X, camera looks from -Y (game camera).
Origins sit at ground level unless noted. Named child objects are animated in Godot.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector as V, Matrix
from riley_lib import (make_mat, lathe, capsule, ellipsoid, superellipsoid, tube, ring_points,
                       transform, align_matrix, frame_matrix, sphere_cap, smoothstep, _finish)

OUT = sys.argv[-1] if not sys.argv[-1].endswith('.py') else os.getcwd()
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(11)

P = {}


def mat(name, hexc, rough=0.5, metal=0.0, emit=0.0, coat=0.0):
    if name not in P:
        P[name] = make_mat(name, hexc, rough, metal, emit, coat)
    return P[name]


C = dict(
    red=('Red', '#E8342C', 0.45), yellow=('Yellow', '#FFC928', 0.45), blue=('Blue', '#2D7BE5', 0.5),
    navy=('Navy', '#1C3F8C', 0.5), white=('White', '#F6F7FA', 0.5), black=('Rubber', '#24262C', 0.8),
    green=('Green', '#43B649', 0.6), lime=('Lime', '#8FD14F', 0.6), orange=('Orange', '#FF8A1F', 0.45),
    purple=('Purple', '#8A55D8', 0.5), lavender=('Lavender', '#D9CCF7', 0.6), pink=('Pink', '#FF7FB0', 0.5),
    cyan=('Cyan', '#38C8F0', 0.3), water=('Water', '#47C4EE', 0.08), wood=('Wood', '#B57A43', 0.75),
    wood_dark=('WoodDark', '#7E5130', 0.8), metal=('Metal', '#AEB6C2', 0.3), steel=('Steel', '#6F7A88', 0.35),
    gold=('Gold', '#F5B921', 0.25), grey=('Grey', '#8C93A0', 0.6), glass=('Glass', '#9FDBF7', 0.05),
    cream=('Cream', '#FFF1D6', 0.7), brick=('Brick', '#C9573E', 0.8), roof_red=('RoofRed', '#C83A33', 0.7),
    roof_grey=('RoofGrey', '#4D5562', 0.7), wall_yellow=('WallYellow', '#FFE08A', 0.8),
    wall_blue=('WallBlue', '#A9D6F5', 0.8), wall_mint=('WallMint', '#B8EBC8', 0.8), wall_peach=('WallPeach', '#FFC8A8', 0.8),
    leaf=('Leaf', '#3FA34D', 0.75), leaf_light=('LeafLight', '#6CC24A', 0.75), leaf_dark=('LeafDark', '#2E7D3A', 0.75),
    trunk=('Trunk', '#8A5A35', 0.85), rock=('Rock', '#8E86A8', 0.85), rock_dark=('RockDark', '#5E5878', 0.85),
    glow=('Glow', '#5CF2FF', 0.3), flame=('Flame', '#FFB52E', 0.4), cloud=('Cloud', '#FFFFFF', 0.9),
    teal=('Teal', '#19B3A6', 0.5), magenta=('Magenta', '#E83E8C', 0.45), chrome=('Chrome', '#DDE3EA', 0.12),
)


def M(key):
    n, h, r = C[key]
    emit = 2.5 if key in ('glow', 'flame') else 0.0
    metal = 0.9 if key in ('chrome', 'metal', 'gold', 'steel') else 0.0
    return mat(n, h, r, metal, emit)


coll = bpy.context.scene.collection


def world_loc(o):
    loc = V()
    while o is not None:
        loc = loc + o.location
        o = o.parent
    return loc


def obj(name, parts, origin=(0, 0, 0), parent=None):
    """Combine (bmesh, material_key) parts into one object; mesh is authored in world space."""
    target = bmesh.new()
    mats = []
    for bm, mk in parts:
        tmp = bpy.data.meshes.new('tmp')
        bm.to_mesh(tmp)
        bm.free()
        n0 = len(target.faces)
        target.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        m = M(mk)
        if m not in mats:
            mats.append(m)
        idx = mats.index(m)
        target.faces.ensure_lookup_table()
        for f in target.faces[n0:]:
            f.material_index = idx
    origin = V(origin)
    bmesh.ops.translate(target, vec=-origin, verts=target.verts)
    me = bpy.data.meshes.new(name)
    target.to_mesh(me)
    target.free()
    for m in mats:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    if parent is not None:
        o.parent = parent
        o.location = origin - world_loc(parent)
    else:
        o.location = origin
    return o


def empty(name, loc=(0, 0, 0), parent=None):
    e = bpy.data.objects.new(name, None)
    coll.objects.link(e)
    e.location = V(loc) - (world_loc(parent) if parent else V())
    e.parent = parent
    return e


def rbox(center, half, e=0.22, seg=(20, 12), matrix=None):
    return superellipsoid(center, half, e, seg[0], seg[1], matrix)


def box(center, half, matrix=None):
    return superellipsoid(center, half, 0.08, 16, 8, matrix)


def cyl(p1, p2, r, seg=20):
    p1, p2 = V(p1), V(p2)
    L = (p2 - p1).length
    bm = lathe([(0, 0), (r, 0), (r, L), (0, L)], seg)
    return transform(bm, align_matrix(p1, p2 - p1))


def cone(p1, p2, r1, r2=0.0, seg=20):
    p1, p2 = V(p1), V(p2)
    L = (p2 - p1).length
    bm = lathe([(0, 0), (r1, 0), (r2, L), (0, L)] if r2 > 0 else [(0, 0), (r1, 0), (0, L)], seg)
    return transform(bm, align_matrix(p1, p2 - p1))


def torus(center, axis, R, r, n=36, seg=10):
    return tube(ring_points(center, axis, R, n=n), r, closed=True, seg=seg)


def star_prism(center, r_out, r_in, thick, axis='Y', points=5):
    bm = bmesh.new()
    pts = []
    for i in range(points * 2):
        a = math.pi / 2 + math.pi * i / points
        rr = r_out if i % 2 == 0 else r_in
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    front = [bm.verts.new((x, -thick / 2, y)) for x, y in pts]
    back = [bm.verts.new((x, thick / 2, y)) for x, y in pts]
    cf = bm.verts.new((0, -thick / 2, 0))
    cb = bm.verts.new((0, thick / 2, 0))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], cf))
        bm.faces.new((back[j], back[i], cb))
        bm.faces.new((front[j], front[i], back[i], back[j]))
    _finish(bm, smooth=False)
    if axis == 'Z':
        transform(bm, Matrix.Rotation(math.radians(90), 4, 'X'))
    elif axis == 'X':
        transform(bm, Matrix.Rotation(math.radians(90), 4, 'Z'))
    bmesh.ops.translate(bm, vec=V(center), verts=bm.verts)
    return bm


def helix(base, radius, height, turns, r, n=120):
    pts = [V((base[0] + radius * math.cos(2 * math.pi * turns * i / n), base[1] + radius * math.sin(2 * math.pi * turns * i / n),
              base[2] + height * i / n)) for i in range(n + 1)]
    return tube(pts, r, seg=10)


def export(name):
    path = os.path.join(OUT, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_apply=True, export_texcoords=False,
                              export_normals=True, export_animations=False, export_lights=False, export_cameras=False,
                              export_yup=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    tris = 0
    print('PROP', name)


def tris_of_scene():
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')


# =============================================================== LAUNCHER
def launcher():
    root = empty('Launcher')
    parts = []
    parts.append((rbox((0, 0, 0.55), (0.95, 0.55, 0.22), 0.25), 'wood'))
    for x in (-0.65, 0.65):
        for y in (-0.62, 0.62):
            w = lathe([(0, -0.09), (0.40, -0.09), (0.45, -0.05), (0.45, 0.05), (0.40, 0.09), (0, 0.09)], 24)
            parts.append((transform(w, Matrix.Translation(V((x, y, 0.45))) @ Matrix.Rotation(math.radians(90), 4, 'X')), 'wood_dark'))
            parts.append((torus(V((x, y + (0.1 if y > 0 else -0.1), 0.45)), V((0, 1, 0)), 0.42, 0.04, 24, 6), 'steel'))
            parts.append((cyl((x, y - 0.12 if y < 0 else y + 0.12, 0.45), (x, y, 0.45), 0.08, 12), 'gold'))
    for y in (-0.42, 0.42):
        parts.append((rbox((0, y, 0.95), (0.18, 0.08, 0.32), 0.3), 'wood_dark'))
    parts.append((cyl((-0.85, 0, 0.75), (-1.35, 0, 0.35), 0.06, 10), 'wood_dark'))  # tow bar
    obj('Cart', parts, (0, 0, 0), root)
    piv = empty('Barrel', (0, 0, 1.12), root)
    bp = []
    prof = [(0, -0.55), (0.30, -0.55), (0.38, -0.45), (0.40, -0.2), (0.36, 0.3), (0.33, 1.2), (0.38, 1.28), (0.40, 1.42),
            (0.34, 1.46), (0.25, 1.46), (0.25, 0.4), (0, 0.4)]
    b = lathe(prof, 32)
    m = Matrix.Translation(V((0, 0, 1.12))) @ Matrix.Rotation(math.radians(90), 4, 'Y')
    bp.append((transform(b, m), 'red'))
    for t in (-0.25, 0.55, 1.2):
        bp.append((transform(torus(V((0, 0, t)), V((0, 0, 1)), 0.39 if t > 0 else 0.41, 0.045, 32, 8), m), 'yellow'))
    bp.append((transform(lathe([(0, -0.62), (0.18, -0.62), (0.2, -0.56), (0.0, -0.5)], 16), m), 'yellow'))
    for s in (-1, 1):
        bp.append((star_prism((0.25, s * 0.37, 1.12), 0.16, 0.07, 0.04, 'Y'), 'white'))
    bp.append((cyl((0, -0.46, 1.12), (0, 0.46, 1.12), 0.09, 14), 'gold'))  # trunnion
    obj('BarrelMesh', bp, (0, 0, 1.12), piv)
    empty('Muzzle', (1.45, 0, 1.12), piv)
    export('launcher')


# =============================================================== TRAMPOLINE
def trampoline():
    root = empty('Trampoline')
    R, H = 1.6, 0.75
    parts = []
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.3
        top = V((R * math.cos(a), R * 0.55 * math.sin(a), H))
        foot = V((R * 1.05 * math.cos(a), R * 0.6 * math.sin(a), 0.0))
        parts.append((capsule(foot, top, 0.055, 0.05, 10, 3), 'steel'))
        parts.append((ellipsoid(foot + V((0, 0, 0.02)), (0.12, 0.12, 0.04), 12, 8), 'black'))
    parts.append((tube(ring_points(V((0, 0, H)), V((0, 0, 1)), R, R * 0.55, 48), 0.06, closed=True, seg=10), 'steel'))
    pad = tube(ring_points(V((0, 0, H + 0.06)), V((0, 0, 1)), R - 0.05, (R - 0.05) * 0.55, 48), 0.13, closed=True, seg=12)
    for v in pad.verts:
        v.co.z = H + 0.06 + (v.co.z - H - 0.06) * 0.55
    parts.append((pad, 'blue'))
    obj('Frame', parts, (0, 0, 0), root)
    bed = lathe([(0, H + 0.02), (R - 0.12, H + 0.04), (R - 0.12, H + 0.07), (0, H + 0.05)], 40)
    for v in bed.verts:
        v.co.y *= 0.55
    bp = [(bed, 'black')]
    st = star_prism((0, 0, H + 0.075), 0.42, 0.18, 0.02, 'Z')
    for v in st.verts:
        v.co.y *= 0.55
    bp.append((st, 'white'))
    obj('Bed', bp, (0, 0, H + 0.04), root)
    export('trampoline')


# =============================================================== BOUNCE HOUSE
def bounce_house():
    root = empty('BounceHouse')
    parts = []
    W, D, Hb = 2.1, 1.5, 1.55
    parts.append((rbox((0, 0, 0.35), (W, D, 0.35), 0.3), 'blue'))
    for sx in (-1, 1):  # side walls
        parts.append((rbox((sx * (W - 0.18), 0, Hb / 2 + 0.35), (0.2, D, Hb / 2), 0.3), 'red'))
    parts.append((rbox((0, D - 0.18, Hb / 2 + 0.35), (W, 0.2, Hb / 2), 0.3), 'yellow'))
    parts.append((rbox((0, -(D - 0.18), 0.9), (W, 0.2, 0.18), 0.4), 'yellow'))
    for i in range(7):  # castle crenels
        x = -W + 0.3 + i * (2 * W - 0.6) / 6
        parts.append((rbox((x, D - 0.18, Hb + 0.55), (0.18, 0.2, 0.18), 0.35), 'yellow' if i % 2 else 'red'))
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = V((sx * (W - 0.1), sy * (D - 0.1), 0))
            parts.append((lathe([(0, 0), (0.42, 0), (0.45, 0.2), (0.45, 2.4), (0.4, 2.5), (0, 2.5)], 24), 'red' if sy < 0 else 'blue'))
            transform(parts[-1][0], Matrix.Translation(c))
            parts.append((torus(c + V((0, 0, 1.2)), V((0, 0, 1)), 0.45, 0.06, 24, 6), 'yellow'))
            parts.append((torus(c + V((0, 0, 1.8)), V((0, 0, 1)), 0.45, 0.06, 24, 6), 'yellow'))
            parts.append((cone(c + V((0, 0, 2.45)), c + V((0, 0, 3.3)), 0.55, 0, 24), 'yellow' if sy < 0 else 'red'))
            parts.append((ellipsoid(c + V((0, 0, 3.32)), (0.08, 0.08, 0.08), 10, 8), 'white'))
    # arch entrance (front)
    parts.append((tube([V((-0.65, -D - 0.02, 0.7)), V((-0.6, -D - 0.02, 1.5)), V((0, -D - 0.02, 1.85)), V((0.6, -D - 0.02, 1.5)), V((0.65, -D - 0.02, 0.7))], 0.16, seg=12), 'red'))
    parts.append((rbox((0, -D + 0.05, 1.15), (0.55, 0.06, 0.45), 0.4), 'navy'))
    obj('Body', parts, (0, 0, 0), root)
    export('bounce_house')


# =============================================================== POOL
def pool():
    root = empty('Pool')
    R = 2.0
    parts = []
    for k, (z, mk) in enumerate(((0.16, 'blue'), (0.44, 'white'), (0.72, 'blue'))):
        t = tube(ring_points(V((0, 0, z)), V((0, 0, 1)), R, R * 0.55, 48), 0.15, closed=True, seg=12)
        parts.append((t, mk))
    parts.append((lathe([(0, 0.02), (R, 0.02), (R, 0.05), (0, 0.05)], 40), 'blue'))
    for v in parts[-1][0].verts:
        v.co.y *= 0.55
    obj('Rim', parts, (0, 0, 0), root)
    w = lathe([(0, 0.6), (R - 0.05, 0.6), (R - 0.05, 0.62), (0, 0.62)], 40)
    for v in w.verts:
        v.co.y *= 0.55
    obj('Water', [(w, 'water')], (0, 0, 0.6), root)
    export('pool')


# =============================================================== SPRING
def spring():
    root = empty('Spring')
    obj('Base', [(rbox((0, 0, 0.09), (0.75, 0.55, 0.09), 0.3), 'steel'), (rbox((0, 0, 0.2), (0.45, 0.45, 0.05), 0.3), 'grey')], (0, 0, 0), root)
    obj('Coil', [(helix((0, 0, 0.2), 0.38, 1.0, 5, 0.07), 'gold')], (0, 0, 0.2), root)
    top = [(rbox((0, 0, 1.3), (0.62, 0.5, 0.1), 0.3), 'red'), (rbox((0, 0, 1.42), (0.5, 0.4, 0.04), 0.3), 'yellow')]
    arrow = bmesh.new()
    pts = [(-0.08, -0.25), (0.08, -0.25), (0.08, 0.02), (0.2, 0.02), (0, 0.26), (-0.2, 0.02), (-0.08, 0.02)]
    vs = [arrow.verts.new((x, -0.001, y)) for x, y in pts]
    arrow.faces.new(vs)
    bmesh.ops.triangulate(arrow, faces=arrow.faces[:])
    ext = bmesh.ops.extrude_face_region(arrow, geom=arrow.faces[:])
    for v in ext['geom']:
        if isinstance(v, bmesh.types.BMVert):
            v.co.y += 0.03
    _finish(arrow, False)
    transform(arrow, Matrix.Translation(V((0, 0, 1.465))) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    top.append((arrow, 'white'))
    obj('Top', top, (0, 0, 1.3), root)
    export('spring')


# =============================================================== MATTRESS
def mattress(name='mattress', main='white', trim='purple'):
    root = empty('Mattress')
    parts = [(rbox((0, 0, 0.24), (1.5, 0.75, 0.24), 0.3, (28, 14)), main),
             (tube(ring_points(V((0, 0, 0.24)), V((0, 0, 1)), 1.42, 0.68, 40, None), 0.06, closed=True, seg=8), trim)]
    t = parts[-1][0]
    for v in t.verts:  # squarer ring
        d = V((v.co.x, v.co.y, 0))
        if d.length > 0:
            sx = math.copysign(min(1.0, abs(v.co.x) / 1.2) ** 0.2, v.co.x)
    for i in range(3):
        for j in range(2):
            parts.append((ellipsoid((-0.9 + i * 0.9, -0.3 + j * 0.6, 0.48), (0.07, 0.07, 0.03), 10, 6), trim))
    parts.append((star_prism((0, -0.76, 0.24), 0.17, 0.075, 0.02, 'Y'), 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    export(name)


# =============================================================== HOUSE (rooftop surface)
def house(name, wall, roof, door='red', W=4.0, D=3.0, Hw=3.4, slope=32):
    root = empty('House')
    parts = [(box((0, 0, Hw / 2), (W, D, Hw / 2)), wall)]
    parts.append((box((0, 0, 0.12), (W + 0.06, D + 0.06, 0.12)), 'brick'))
    rh = W * math.tan(math.radians(slope))
    # gable walls (front/back triangles)
    g = bmesh.new()
    for y in (-D, D):
        vs = [g.verts.new((-W, y, Hw)), g.verts.new((W, y, Hw)), g.verts.new((0, y, Hw + rh))]
        g.faces.new(vs if y > 0 else vs[::-1])
    _finish(g, False)
    parts.append((g, wall))
    # roof planes (thick)
    over = 0.45
    L = (W + over) / math.cos(math.radians(slope))
    for sx in (-1, 1):
        ang = math.radians(slope) * sx
        c = V((sx * (W + over) / 2, 0, Hw + rh - (W + over) / 2 * math.tan(math.radians(slope)) + 0.12))
        m = Matrix.Translation(c) @ Matrix.Rotation(ang, 4, 'Y')
        parts.append((box((0, 0, 0), (L / 2, D + 0.35, 0.14), m), roof))
        for k in range(1, 5):  # shingle lines
            off = -L / 2 + k * L / 5
            parts.append((cyl(m @ V((off, -D - 0.35, 0.15)), m @ V((off, D + 0.35, 0.15)), 0.035, 6), roof))
    parts.append((cyl((0, -D - 0.36, Hw + rh + 0.2), (0, D + 0.36, Hw + rh + 0.2), 0.12, 10), roof))
    parts.append((box((W * 0.45, 0.6, Hw + rh * 0.75), (0.32, 0.32, rh * 0.5)), 'brick'))  # chimney
    # door + windows on the camera side
    parts.append((box((-W * 0.45, -D - 0.03, 1.05), (0.5, 0.06, 1.05)), door))
    parts.append((ellipsoid((-W * 0.45 + 0.3, -D - 0.1, 1.0), (0.06, 0.04, 0.06), 8, 6), 'gold'))
    for x in (W * 0.1, W * 0.6):
        parts.append((box((x, -D - 0.03, 2.0), (0.55, 0.05, 0.55)), 'white'))
        parts.append((box((x, -D - 0.06, 2.0), (0.45, 0.05, 0.45)), 'glass'))
        parts.append((box((x, -D - 0.1, 2.0), (0.04, 0.03, 0.45)), 'white'))
        parts.append((box((x, -D - 0.1, 2.0), (0.45, 0.03, 0.04)), 'white'))
        parts.append((box((x, -D - 0.12, 1.4), (0.62, 0.1, 0.06)), 'white'))
    parts.append((box((0, -D - 0.03, Hw + rh * 0.42), (0.35, 0.05, 0.35)), 'white'))
    parts.append((box((0, -D - 0.06, Hw + rh * 0.42), (0.27, 0.05, 0.27)), 'glass'))
    obj('Body', parts, (0, 0, 0), root)
    export(name)


# =============================================================== SATELLITE DISH
def satellite_dish():
    root = empty('SatelliteDish')
    obj('Pole', [(cyl((0, 0, 0), (0, 0, 2.3), 0.08, 12), 'steel'), (rbox((0, 0, 0.08), (0.4, 0.4, 0.08), 0.3), 'grey')], (0, 0, 0), root)
    piv = empty('Dish', (0, 0, 2.3), root)
    prof = [(0, 0.0)] + [(1.15 * (i / 10), 0.35 * (i / 10) ** 2) for i in range(1, 11)] + [(1.12, 0.38)] + \
           [(1.05 * (1 - i / 10) + 0.02, 0.36 * (1 - i / 10) ** 2 + 0.03) for i in range(0, 11)]
    d = lathe(prof, 36)
    m = Matrix.Translation(V((0, 0, 2.3))) @ Matrix.Rotation(math.radians(90), 4, 'Y')  # opens toward +X
    parts = [(transform(d, m), 'white'), (transform(torus(V((0, 0, 0.36)), V((0, 0, 1)), 1.13, 0.04, 36, 6), m), 'grey')]
    for k in range(3):
        a = 2 * math.pi * k / 3
        parts.append((transform(cyl((0.9 * math.cos(a), 0.9 * math.sin(a), 0.32), (0, 0, 1.0), 0.025, 6), m), 'grey'))
    parts.append((transform(ellipsoid((0, 0, 1.02), (0.1, 0.1, 0.12), 12, 8), m), 'red'))
    parts.append((transform(cyl((0, 0, -0.2), (0, 0, 0.05), 0.12, 12), m), 'steel'))
    obj('DishMesh', parts, (0, 0, 2.3), piv)
    export('satellite_dish')


# =============================================================== GIANT FAN (blows along +Z)
def fan():
    root = empty('Fan')
    parts = [(rbox((0, 0, 0.2), (1.0, 0.8, 0.2), 0.3), 'steel'),
             (lathe([(0, 0.4), (1.45, 0.4), (1.5, 0.5), (1.5, 1.2), (1.38, 1.25), (1.38, 0.5), (0, 0.5)], 40), 'teal'),
             (torus(V((0, 0, 1.26)), V((0, 0, 1)), 1.44, 0.07, 40, 8), 'yellow')]
    for k in range(8):
        a = math.pi * k / 8
        parts.append((cyl((1.42 * math.cos(a), 1.42 * math.sin(a), 1.28), (-1.42 * math.cos(a), -1.42 * math.sin(a), 1.28), 0.018, 6), 'chrome'))
    parts.append((torus(V((0, 0, 1.28)), V((0, 0, 1)), 0.75, 0.018, 32, 6), 'chrome'))
    obj('Housing', parts, (0, 0, 0), root)
    bl = [(ellipsoid((0, 0, 0.9), (0.22, 0.22, 0.18), 16, 10), 'red')]
    for k in range(5):
        a = 2 * math.pi * k / 5
        m = Matrix.Translation(V((0, 0, 0.9))) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(math.radians(25), 4, 'X')
        bl.append((ellipsoid((0.75, 0, 0), (0.6, 0.26, 0.035), 16, 8, m), 'white'))
    obj('Blades', bl, (0, 0, 0.9), root)
    export('fan')


# =============================================================== MOVING TRUCK (drives toward +X)
def truck():
    root = empty('Truck')
    parts = [(rbox((-0.7, 0, 1.95), (2.0, 1.05, 1.25), 0.15), 'white'),
             (box((-0.7, -1.06, 1.6), (1.9, 0.02, 0.22)), 'blue'), (box((-0.7, -1.07, 2.1), (1.9, 0.02, 0.08)), 'orange'),
             (rbox((2.05, 0, 1.35), (0.75, 1.0, 0.75), 0.3), 'red'), (rbox((1.95, 0, 2.2), (0.6, 0.95, 0.3), 0.35), 'red'),
             (box((2.6, 0, 2.15), (0.08, 0.85, 0.28)), 'glass'), (box((2.0, -1.0, 2.15), (0.35, 0.02, 0.22)), 'glass'),
             (rbox((-0.5, 0, 0.62), (2.9, 0.85, 0.12), 0.3), 'grey'), (box((2.85, 0, 0.8), (0.08, 0.9, 0.15)), 'chrome')]
    for x in (2.8,):
        for y in (-0.6, 0.6):
            parts.append((ellipsoid((x, y, 1.15), (0.04, 0.16, 0.12), 10, 8), 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    for i, (x, y) in enumerate(((-1.9, -0.9), (-1.9, 0.9), (-0.9, -0.9), (-0.9, 0.9), (2.0, -0.9), (2.0, 0.9))):
        w = lathe([(0, -0.16), (0.42, -0.16), (0.46, -0.1), (0.46, 0.1), (0.42, 0.16), (0, 0.16)], 24)
        wp = [(transform(w, Matrix.Translation(V((x, y, 0.46))) @ Matrix.Rotation(math.radians(90), 4, 'X')), 'black'),
              (cyl((x, y * 1.18, 0.46), (x, y * 1.05, 0.46), 0.22, 16), 'chrome')]
        obj('Wheel%d' % i, wp, (x, y, 0.46), root)
    export('truck')


# =============================================================== RUBBER DUCK
def duck():
    root = empty('Duck')
    parts = [(ellipsoid((0, 0, 0.75), (1.15, 0.85, 0.72), 32, 20), 'yellow'),
             (ellipsoid((-1.0, 0, 1.15), (0.35, 0.25, 0.25), 16, 10, Matrix.Rotation(math.radians(30), 4, 'Y')), 'yellow'),
             (ellipsoid((0.55, 0, 1.85), (0.6, 0.55, 0.58), 28, 18), 'yellow'),
             (ellipsoid((1.12, 0, 1.75), (0.32, 0.26, 0.1), 16, 10), 'orange'),
             (ellipsoid((1.08, 0, 1.68), (0.26, 0.22, 0.07), 16, 10), 'orange')]
    for sy in (-1, 1):
        parts.append((ellipsoid((0.88, sy * 0.3, 2.0), (0.12, 0.08, 0.14), 12, 8), 'white'))
        parts.append((ellipsoid((0.97, sy * 0.33, 2.02), (0.06, 0.05, 0.08), 10, 8), 'black'))
        parts.append((ellipsoid((-0.05, sy * 0.78, 0.95), (0.55, 0.12, 0.32), 16, 10, Matrix.Rotation(math.radians(-15), 4, 'Y')), 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    export('duck')


# =============================================================== SEESAW
def seesaw():
    root = empty('Seesaw')
    parts = []
    for y in (-0.45, 0.45):
        parts.append((cyl((-0.5, y, 0), (0, y, 0.7), 0.07, 10), 'blue'))
        parts.append((cyl((0.5, y, 0), (0, y, 0.7), 0.07, 10), 'blue'))
    parts.append((cyl((0, -0.55, 0.7), (0, 0.55, 0.7), 0.09, 12), 'steel'))
    obj('Stand', parts, (0, 0, 0), root)
    pl = [(rbox((0, 0, 0.82), (2.3, 0.32, 0.07), 0.3), 'red')]
    for sx in (-1, 1):
        pl.append((rbox((sx * 1.95, 0, 0.92), (0.3, 0.3, 0.05), 0.4), 'yellow'))
        pl.append((tube([V((sx * 1.6, -0.25, 0.85)), V((sx * 1.6, -0.25, 1.25)), V((sx * 1.6, 0.25, 1.25)), V((sx * 1.6, 0.25, 0.85))], 0.035, seg=8), 'steel'))
    obj('Plank', pl, (0, 0, 0.8), root)
    export('seesaw')


# =============================================================== GIANT TIRE (standing, axis toward camera)
def tire():
    root = empty('Tire')
    R, r = 1.25, 0.48
    t = torus(V((0, 0, R + r)), V((0, 1, 0)), R, r, 48, 16)
    for v in t.verts:
        d = V((v.co.x, 0, v.co.z - (R + r)))
        ang = math.atan2(d.z, d.x)
        if d.length > R:
            v.co += d.normalized() * 0.04 * (1 if int((ang + math.pi) / (2 * math.pi) * 24) % 2 == 0 else 0)
        v.co.y *= 0.75
    hub = lathe([(0, -0.3), (0.75, -0.3), (0.8, 0), (0.75, 0.3), (0, 0.3)], 32)
    transform(hub, Matrix.Translation(V((0, 0, R + r))) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    obj('Body', [(t, 'black'), (hub, 'yellow')], (0, 0, 0), root)
    export('tire')


# =============================================================== SLIDE (chute from top-left down to right with a kicker lip)
SLIDE_PATH = [(-1.2, 2.6), (-0.6, 2.45), (0.6, 1.55), (1.8, 0.75), (2.6, 0.55), (3.2, 0.75), (3.6, 1.05)]


def slide():
    root = empty('Slide')
    parts = []
    for y in (-0.45, 0.45):
        parts.append((cyl((-1.9, y, 0), (-1.3, y, 2.6), 0.07, 10), 'blue'))
    for k in range(6):
        z = 0.35 + k * 0.4
        x = -1.9 + 0.6 * z / 2.6
        parts.append((cyl((x, -0.45, z), (x, 0.45, z), 0.045, 8), 'steel'))
    parts.append((rbox((-1.15, 0, 2.55), (0.45, 0.55, 0.08), 0.3), 'red'))
    for y in (-0.5, 0.5):
        parts.append((cyl((-0.9, y, 0), (-0.9, y, 2.5), 0.06, 10), 'blue'))
        parts.append((cyl((2.5, y, 0), (2.5, y, 0.5), 0.06, 10), 'blue'))
    pts = [V((x, 0, z)) for x, z in SLIDE_PATH]
    bm = bmesh.new()
    rows = []
    for p in pts:
        rows.append([bm.verts.new(p + V((0, y, dz))) for y, dz in ((-0.55, 0.28), (-0.5, 0.02), (-0.4, -0.05), (0.4, -0.05), (0.5, 0.02), (0.55, 0.28))])
    for a, b in zip(rows, rows[1:]):
        for k in range(5):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
    _finish(bm)
    sol = bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.06)
    parts.append((bm, 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    export('slide')


# =============================================================== ROTATING PLATFORM (bar spins in the play plane)
def rotating_platform():
    root = empty('RotatingPlatform')
    obj('Pole', [(cyl((0, 0.35, 0), (0, 0.35, 3.0), 0.12, 14), 'steel'), (rbox((0, 0.35, 0.1), (0.5, 0.5, 0.1), 0.3), 'grey')], (0, 0, 0), root)
    pl = [(rbox((0, 0, 3.0), (2.2, 0.55, 0.16), 0.3), 'purple'), (cyl((0, -0.2, 3.0), (0, 0.5, 3.0), 0.25, 20), 'yellow')]
    for sx in (-1, 1):
        pl.append((rbox((sx * 1.6, 0, 3.17), (0.45, 0.45, 0.04), 0.4), 'magenta'))
        pl.append((ellipsoid((sx * 2.25, 0, 3.0), (0.2, 0.55, 0.22), 14, 10), 'yellow'))
    obj('Platform', pl, (0, 0, 3.0), root)
    export('rotating_platform')


# =============================================================== CONVEYOR (belt moves toward +X)
def conveyor():
    root = empty('Conveyor')
    parts = []
    for x in (-2.6, 2.6):
        for y in (-0.6, 0.6):
            parts.append((cyl((x, y, 0), (x, y, 1.0), 0.08, 10), 'steel'))
    parts.append((rbox((0, -0.68, 1.12), (3.2, 0.06, 0.18), 0.3), 'orange'))
    parts.append((rbox((0, 0.68, 1.12), (3.2, 0.06, 0.18), 0.3), 'orange'))
    for x in (-3.0, 3.0):
        parts.append((cyl((x, -0.62, 1.12), (x, 0.62, 1.12), 0.17, 18), 'chrome'))
    parts.append((rbox((0, 0, 1.12), (3.0, 0.62, 0.17), 0.12, (28, 8)), 'black'))
    for k in range(7):
        x = -2.4 + k * 0.8
        ch = bmesh.new()
        pts = [(-0.18, 0.25), (0.0, 0.25), (0.22, 0.0), (0.0, -0.25), (-0.18, -0.25), (0.04, 0.0)]
        vs = [ch.verts.new((x + px, py, 1.295)) for px, py in pts]
        ch.faces.new(vs)
        bmesh.ops.triangulate(ch, faces=ch.faces[:])
        e = bmesh.ops.extrude_face_region(ch, geom=ch.faces[:])
        for v in e['geom']:
            if isinstance(v, bmesh.types.BMVert):
                v.co.z += 0.015
        _finish(ch, False)
        parts.append((ch, 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    export('conveyor')


# =============================================================== INFLATABLE CUSHION
def cushion():
    root = empty('Cushion')
    b = rbox((0, 0, 0.45), (1.6, 0.9, 0.45), 0.55, (32, 18))
    for v in b.verts:
        r = (abs(v.co.x) / 1.6) ** 2 + (abs(v.co.y) / 0.9) ** 2
        if v.co.z > 0.45:
            v.co.z += 0.15 * max(0, 1 - r)
    parts = [(b, 'lime'), (tube(ring_points(V((0, 0, 0.45)), V((0, 0, 1)), 1.55, 0.86, 40), 0.05, closed=True, seg=8), 'green')]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append((ellipsoid((sx * 1.45, sy * 0.78, 0.48), (0.16, 0.16, 0.16), 12, 8), 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    export('cushion')


# =============================================================== PINBALL BUMPER (Head at origin, Post goes down 1m)
def bumper():
    root = empty('Bumper')
    m = Matrix.Rotation(math.radians(90), 4, 'X')
    head = [(transform(lathe([(0, -0.35), (0.78, -0.35), (0.8, -0.25), (0.8, 0.25), (0.78, 0.35), (0, 0.35)], 36), m), 'red'),
            (transform(torus(V((0, 0, -0.38)), V((0, 0, 1)), 0.8, 0.07, 36, 8), m), 'white'),
            (transform(torus(V((0, 0, 0.38)), V((0, 0, 1)), 0.8, 0.07, 36, 8), m), 'white'),
            (transform(lathe([(0, -0.42), (0.55, -0.42), (0.6, -0.4), (0, -0.36)], 32), m), 'yellow'),
            (star_prism((0, -0.44, 0), 0.38, 0.16, 0.04, 'Y'), 'white')]
    obj('Head', head, (0, 0, 0), root)
    obj('Post', [(cyl((0, 0.2, -1.0), (0, 0.2, -0.3), 0.1, 12), 'steel')], (0, 0, 0), root)
    export('bumper')


# =============================================================== WIND TUNNEL (blows up)
def wind_tunnel():
    root = empty('WindTunnel')
    parts = [(lathe([(0, 0), (1.6, 0), (1.7, 0.1), (1.7, 0.45), (1.55, 0.5), (0, 0.5)], 40), 'steel'),
             (torus(V((0, 0, 0.52)), V((0, 0, 1)), 1.45, 0.06, 40, 8), 'glow')]
    for k in range(12):
        a = math.pi * k / 12
        parts.append((cyl((1.4 * math.cos(a), 1.4 * math.sin(a), 0.52), (-1.4 * math.cos(a), -1.4 * math.sin(a), 0.52), 0.02, 6), 'chrome'))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        parts.append((cyl((1.6 * math.cos(a), 1.6 * math.sin(a), 0.4), (1.6 * math.cos(a), 1.6 * math.sin(a), 7.0), 0.07, 10), 'chrome'))
    parts.append((torus(V((0, 0, 7.0)), V((0, 0, 1)), 1.6, 0.09, 40, 8), 'magenta'))
    parts.append((torus(V((0, 0, 3.7)), V((0, 0, 1)), 1.6, 0.05, 40, 6), 'magenta'))
    obj('Body', parts, (0, 0, 0), root)
    export('wind_tunnel')


# =============================================================== BREAKABLE RAMP (rises toward +X)
RAMP_LEN, RAMP_H = 4.0, 1.8


def ramp():
    root = empty('Ramp')
    ang = math.atan2(RAMP_H, RAMP_LEN)
    L = math.hypot(RAMP_LEN, RAMP_H)
    fr = []
    for y in (-1.0, 1.0):
        fr.append((cyl((-RAMP_LEN / 2, y, 0.05), (RAMP_LEN / 2, y, RAMP_H - 0.1), 0.07, 8), 'wood_dark'))
        for k in range(1, 4):
            x = -RAMP_LEN / 2 + RAMP_LEN * k / 4
            h = RAMP_H * k / 4
            fr.append((cyl((x, y, 0), (x, y, h - 0.1), 0.07, 8), 'wood_dark'))
        fr.append((cyl((-RAMP_LEN / 4, y, 0.05), (RAMP_LEN / 4, y, RAMP_H * 0.75 - 0.1), 0.04, 6), 'wood_dark'))
        fr.append((cyl((RAMP_LEN / 2, y, 0), (RAMP_LEN / 2, y, RAMP_H - 0.1), 0.08, 8), 'wood_dark'))
    obj('Frame', fr, (0, 0, 0), root)
    n = 8
    for k in range(n):
        t = (k + 0.5) / n
        c = V((-RAMP_LEN / 2 + RAMP_LEN * t, 0, RAMP_H * t))
        m = Matrix.Translation(c) @ Matrix.Rotation(-ang, 4, 'Y')
        mk = 'wood' if k % 2 == 0 else 'wood_dark'
        pl = [(box((0, 0, 0), (L / n / 2 - 0.01, 1.1, 0.05), m), mk)]
        if k in (n - 1,):
            pl.append((box((0.0, -1.11, 0.0), (L / n / 2 - 0.02, 0.01, 0.045), m), 'yellow'))
        obj('Plank%d' % k, pl, c, root)
    sign = [(cyl((RAMP_LEN / 2 + 0.25, -1.0, 0), (RAMP_LEN / 2 + 0.25, -1.0, 1.4), 0.04, 8), 'steel')]
    sm = Matrix.Translation(V((RAMP_LEN / 2 + 0.25, -1.06, 1.45))) @ Matrix.Rotation(math.radians(45), 4, 'Y')
    sign.append((box((0, 0, 0), (0.3, 0.02, 0.3), sm), 'yellow'))
    sign.append((box((0, -0.025, 0), (0.24, 0.01, 0.24), sm), 'black'))
    sign.append((box((0, -0.035, 0), (0.18, 0.01, 0.18), sm), 'yellow'))
    obj('Sign', sign, (0, 0, 0), root)
    export('ramp')


# =============================================================== COIN
def coin():
    root = empty('Coin')
    m = Matrix.Rotation(math.radians(90), 4, 'X')
    parts = [(transform(lathe([(0, -0.05), (0.33, -0.05), (0.36, -0.03), (0.36, 0.03), (0.33, 0.05), (0, 0.05)], 28), m), 'gold'),
             (star_prism((0, -0.055, 0), 0.2, 0.09, 0.03, 'Y'), 'yellow'), (star_prism((0, 0.055, 0), 0.2, 0.09, 0.03, 'Y'), 'yellow')]
    obj('Body', parts, (0, 0, 0), root)
    export('coin')


# =============================================================== SPACE PIECES
def floating_platform():
    root = empty('FloatingPlatform')
    rock = ellipsoid((0, 0, -0.9), (1.9, 1.2, 1.0), 28, 18)
    random.seed(3)
    for v in rock.verts:
        n = math.sin(v.co.x * 3.1) * math.cos(v.co.y * 2.7) * 0.12 + random.uniform(-0.05, 0.05)
        v.co += (v.co - V((0, 0, -0.9))).normalized() * n
        if v.co.z > -0.1:
            v.co.z = -0.1
        if v.co.z < -1.4:
            v.co.z = -1.4 - (v.co.z + 1.4) * 0.3 - 0.4 * (1 - min(1, V((v.co.x, v.co.y, 0)).length / 1.2))
    parts = [(rock, 'rock'), (rbox((0, 0, -0.05), (1.75, 1.05, 0.08), 0.3), 'rock_dark'),
             (tube(ring_points(V((0, 0, 0.02)), V((0, 0, 1)), 1.55, 0.9, 40), 0.05, closed=True, seg=8), 'glow')]
    for x in (-1.2, 1.2):
        parts.append((ellipsoid((x, -0.5, -0.9), (0.25, 0.2, 0.2), 12, 8), 'rock_dark'))
    obj('Body', parts, (0, 0, 0), root)
    export('floating_platform')


def booster_ring():
    root = empty('BoosterRing')
    m = Matrix.Rotation(math.radians(90), 4, 'Y')
    parts = [(transform(torus(V((0, 0, 0)), V((0, 0, 1)), 1.35, 0.16, 48, 12), m), 'orange'),
             (transform(torus(V((0, 0, 0.18)), V((0, 0, 1)), 1.35, 0.06, 48, 8), m), 'glow')]
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append((ellipsoid((0, 1.35 * math.cos(a), 1.35 * math.sin(a)), (0.2, 0.12, 0.12), 10, 8), 'chrome'))
    obj('Body', parts, (0, 0, 0), root)
    export('booster_ring')


def thruster():
    root = empty('Thruster')
    parts = [(lathe([(0, -0.9), (0.55, -0.9), (0.6, -0.6), (0.6, 0.2), (0.4, 0.5), (0.6, 1.0), (0.5, 1.0), (0.32, 0.55), (0, 0.55)], 32), 'steel'),
             (torus(V((0, 0, -0.3)), V((0, 0, 1)), 0.6, 0.06, 32, 8), 'red'), (torus(V((0, 0, 0.05)), V((0, 0, 1)), 0.6, 0.06, 32, 8), 'red')]
    for k in range(4):
        a = 2 * math.pi * k / 4
        parts.append((rbox((0.7 * math.cos(a), 0.7 * math.sin(a), -0.6), (0.25 * abs(math.cos(a)) + 0.04, 0.25 * abs(math.sin(a)) + 0.04, 0.3), 0.3), 'red'))
    obj('Body', parts, (0, 0, 0), root)
    obj('Flame', [(lathe([(0, 1.0), (0.45, 1.0), (0.3, 1.8), (0, 2.6)], 20), 'flame')], (0, 0, 1.0), root)
    export('thruster')


# =============================================================== GADGETS
def umbrella():
    root = empty('Umbrella')
    parts = [(tube([V((0, 0, 0)), V((0, 0, 1.0))], 0.022, seg=8), 'steel'),
             (tube([V((0, 0, 0.02)), V((0, 0, -0.12)), V((0.04, 0, -0.2)), V((0.11, 0, -0.18)), V((0.12, 0, -0.1))], 0.03, seg=8), 'red')]
    for k in range(8):
        a0, a1 = 2 * math.pi * k / 8, 2 * math.pi * (k + 1) / 8
        bm = bmesh.new()
        rows = []
        for i in range(7):
            t = i / 6
            rr = 0.78 * math.sin(t * math.pi / 2 * 0.95)
            z = 1.0 + 0.38 * math.cos(t * math.pi / 2 * 0.95) - 0.38
            rows.append([bm.verts.new((rr * math.cos(a0 + (a1 - a0) * j / 4), rr * math.sin(a0 + (a1 - a0) * j / 4),
                                       z - 0.06 * t * math.sin(math.pi * j / 4))) for j in range(5)])
        for a, b in zip(rows, rows[1:]):
            for j in range(4):
                bm.faces.new((a[j], a[j + 1], b[j + 1], b[j]))
        _finish(bm)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.015)
        parts.append((bm, 'red' if k % 2 == 0 else 'white'))
    parts.append((ellipsoid((0, 0, 1.03), (0.04, 0.04, 0.06), 8, 6), 'yellow'))
    obj('Canopy', parts, (0, 0, 0), root)
    export('umbrella')


def rocket_shoe():
    root = empty('RocketShoe')
    parts = [(lathe([(0, -0.05), (0.07, -0.05), (0.08, 0.0), (0.08, 0.2), (0.0, 0.3)], 16), 'chrome'),
             (lathe([(0, -0.1), (0.06, -0.1), (0.05, -0.05), (0, -0.05)], 16), 'steel')]
    for k in range(3):
        a = 2 * math.pi * k / 3
        parts.append((rbox((0.09 * math.cos(a), 0.09 * math.sin(a), 0.0), (0.035 * abs(math.cos(a)) + 0.01, 0.035 * abs(math.sin(a)) + 0.01, 0.06), 0.3), 'red'))
    obj('Body', parts, (0, 0, 0), root)
    obj('Flame', [(lathe([(0, -0.1), (0.06, -0.1), (0.04, -0.25), (0, -0.4)], 12), 'flame')], (0, 0, -0.1), root)
    export('rocket_shoe')


def balloon():
    root = empty('Balloon')
    prof = [(0, 0.95)] + [(0.5 * math.sin(math.pi * t) ** 0.8 * (1 - 0.25 * t), 0.95 + 0.95 * (1 - math.cos(math.pi * t)) / 2 * 1.15) for t in [i / 16 for i in range(1, 16)]] + [(0, 2.05)]
    parts = [(lathe(prof, 28), 'red'), (lathe([(0, 0.88), (0.06, 0.88), (0.03, 0.96), (0, 0.97)], 12), 'red'),
             (tube([V((0, 0, 0.9)), V((0.04, 0, 0.6)), V((-0.03, 0, 0.3)), V((0, 0, 0))], 0.008, seg=6), 'white'),
             (ellipsoid((-0.18, -0.38, 1.75), (0.08, 0.04, 0.14), 10, 8), 'white')]
    obj('Body', parts, (0, 0, 0), root)
    export('balloon')


def propeller_hat():
    root = empty('PropellerHat')
    parts = []
    cols = ['red', 'yellow', 'blue', 'green']
    for k in range(4):
        bm = lathe([(0, 0.2)] + [(0.24 * math.sin(t * math.pi / 2), 0.2 * math.cos(t * math.pi / 2)) for t in [i / 8 for i in range(1, 9)]], 24)
        kill = []
        a0 = 2 * math.pi * k / 4
        for v in bm.verts:
            a = math.atan2(v.co.y, v.co.x) % (2 * math.pi)
            d = (a - a0) % (2 * math.pi)
            if d > math.pi / 2 + 0.15 and v.co.length > 0.02 and abs(v.co.x) + abs(v.co.y) > 1e-4:
                kill.append(v)
        bmesh.ops.delete(bm, geom=kill, context='VERTS')
        parts.append((bm, cols[k]))
    parts.append((torus(V((0, 0, 0.0)), V((0, 0, 1)), 0.24, 0.025, 24, 6), 'navy'))
    parts.append((rbox((0, -0.27, 0.01), (0.14, 0.08, 0.015), 0.4), 'navy'))
    parts.append((cyl((0, 0, 0.19), (0, 0, 0.3), 0.02, 8), 'chrome'))
    obj('Cap', parts, (0, 0, 0), root)
    pr = [(ellipsoid((0, 0, 0.31), (0.04, 0.04, 0.03), 10, 6), 'red')]
    for k in range(2):
        pr.append((ellipsoid((0, 0, 0), (0.24, 0.06, 0.012), 14, 6, Matrix.Translation(V((0, 0, 0.31))) @ Matrix.Rotation(math.pi * k, 4, 'Z') @ Matrix.Translation(V((0.18, 0, 0))) @ Matrix.Rotation(0.3, 4, 'X')), 'yellow'))
    obj('Prop', pr, (0, 0, 0.31), root)
    export('propeller_hat')


def plunger_gun():
    root = empty('PlungerGun')
    parts = [(rbox((0.12, 0, 0.1), (0.18, 0.06, 0.07), 0.3), 'orange'), (rbox((0.0, 0, 0.0), (0.05, 0.05, 0.1), 0.3), 'navy'),
             (cyl((0.25, 0, 0.12), (0.5, 0, 0.12), 0.035, 12), 'yellow'), (cyl((-0.05, 0, 0.12), (0.0, 0, 0.12), 0.06, 12), 'navy')]
    obj('Body', parts, (0, 0, 0), root)
    export('plunger_gun')
    root = empty('PlungerHead')
    parts = [(cyl((-0.3, 0, 0), (0.0, 0, 0), 0.02, 8), 'wood'),
             (transform(lathe([(0, 0), (0.03, 0), (0.1, 0.06), (0.1, 0.08), (0, 0.06)], 16), Matrix.Rotation(math.radians(90), 4, 'Y')), 'red')]
    obj('Body', parts, (0, 0, 0), root)
    export('plunger_head')


# =============================================================== COSMETIC HEADWEAR (origin = crown of head)
def helmets():
    root = empty('BikeHelmet')
    sh = ellipsoid((0, 0.02, 0.0), (0.27, 0.29, 0.22), 28, 16)
    bmesh.ops.delete(sh, geom=[v for v in sh.verts if v.co.z < -0.04], context='VERTS')
    bmesh.ops.solidify(sh, geom=sh.faces[:], thickness=0.03)
    parts = [(sh, 'lime')]
    for k in range(3):
        parts.append((rbox(((k - 1) * 0.09, 0.0, 0.215), (0.025, 0.16, 0.015), 0.4), 'navy'))
    parts.append((rbox((0, -0.28, -0.03), (0.17, 0.04, 0.02), 0.4), 'navy'))
    obj('Body', parts, (0, 0, 0), root)
    export('hat_bike_helmet')
    root = empty('VikingHelmet')
    sh = ellipsoid((0, 0, 0.0), (0.27, 0.27, 0.24), 28, 16)
    bmesh.ops.delete(sh, geom=[v for v in sh.verts if v.co.z < -0.05], context='VERTS')
    bmesh.ops.solidify(sh, geom=sh.faces[:], thickness=0.03)
    parts = [(sh, 'steel'), (torus(V((0, 0, -0.04)), V((0, 0, 1)), 0.27, 0.035, 32, 8), 'gold')]
    for sx in (-1, 1):
        pts = [V((sx * (0.24 + 0.12 * t + 0.05 * t * t), 0, 0.05 + 0.32 * t * t)) for t in [i / 8 for i in range(9)]]
        parts.append((tube(pts, [0.07 * (1 - t) + 0.008 for t in [i / 8 for i in range(9)]], seg=10), 'cream'))
    obj('Body', parts, (0, 0, 0), root)
    export('hat_viking')
    root = empty('PotHelmet')
    parts = [(lathe([(0, 0.26), (0.26, 0.26), (0.27, 0.0), (0.29, -0.03), (0.27, -0.03), (0.25, 0.0), (0.24, 0.24), (0, 0.24)], 32), 'chrome')]
    for sx in (-1, 1):
        parts.append((tube([V((sx * 0.26, 0, 0.18)), V((sx * 0.36, 0, 0.17)), V((sx * 0.36, 0, 0.1)), V((sx * 0.26, 0, 0.09))], 0.018, seg=8), 'black'))
    obj('Body', parts, (0, 0, 0), root)
    export('hat_pot')
    root = empty('PartyHat')
    parts = [(cone((0, 0, 0), (0, 0, 0.5), 0.2, 0, 24), 'magenta'), (ellipsoid((0, 0, 0.52), (0.06, 0.06, 0.06), 10, 8), 'yellow'),
             (torus(V((0, 0, 0.12)), V((0, 0, 1)), 0.155, 0.015, 24, 6), 'yellow'), (torus(V((0, 0, 0.28)), V((0, 0, 1)), 0.095, 0.015, 24, 6), 'cyan')]
    obj('Body', parts, (0, 0, 0), root)
    export('hat_party')


# =============================================================== DECOR
def tree_round(name='tree_round', h=4.5):
    root = empty('Tree')
    parts = [(cone((0, 0, 0), (0, 0, h * 0.55), 0.28, 0.16, 12), 'trunk')]
    for (x, y, z, r, mk) in ((0, 0, h * 0.72, 1.3, 'leaf'), (-0.8, 0.2, h * 0.58, 0.9, 'leaf_dark'), (0.85, -0.1, h * 0.6, 0.95, 'leaf_light'),
                             (0.1, -0.3, h * 0.92, 0.85, 'leaf_light'), (0.2, 0.5, h * 0.55, 0.8, 'leaf')):
        parts.append((ellipsoid((x, y, z), (r, r, r * 0.92), 16, 10), mk))
    obj('Body', parts, (0, 0, 0), root)
    export(name)


def tree_pine():
    root = empty('Pine')
    parts = [(cyl((0, 0, 0), (0, 0, 1.2), 0.22, 10), 'trunk')]
    for k, (z, r) in enumerate(((1.0, 1.5), (2.3, 1.2), (3.5, 0.9), (4.6, 0.6))):
        parts.append((lathe([(0, z), (r, z), (r * 0.9, z + 0.15), (0, z + 1.6)], 14), 'leaf_dark' if k % 2 == 0 else 'leaf'))
    obj('Body', parts, (0, 0, 0), root)
    export('tree_pine')


def bush():
    root = empty('Bush')
    parts = [(ellipsoid((x, y, z), (r, r, r * 0.85), 14, 8), mk) for x, y, z, r, mk in
             ((0, 0, 0.45, 0.6, 'leaf'), (-0.55, 0.1, 0.35, 0.45, 'leaf_dark'), (0.55, -0.05, 0.38, 0.5, 'leaf_light'))]
    parts.append((ellipsoid((0.2, -0.45, 0.6), (0.07, 0.07, 0.07), 8, 6), 'pink'))
    parts.append((ellipsoid((-0.4, -0.35, 0.5), (0.07, 0.07, 0.07), 8, 6), 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    export('bush')


def fence():
    root = empty('Fence')
    parts = []
    for k in range(10):
        x = -1.8 + k * 0.4
        parts.append((rbox((x, 0, 0.55), (0.08, 0.03, 0.55), 0.3), 'white'))
        parts.append((cone((x, 0, 1.1), (x, 0, 1.25), 0.08, 0, 4), 'white'))
    for z in (0.35, 0.85):
        parts.append((rbox((0, 0.05, z), (2.0, 0.025, 0.05), 0.3), 'white'))
    obj('Body', parts, (0, 0, 0), root)
    export('fence')


def shed():
    root = empty('Shed')
    parts = [(box((0, 0, 1.1), (1.5, 1.2, 1.1)), 'wall_mint'), (box((0, -1.22, 0.85), (0.45, 0.04, 0.85)), 'wood')]
    m = Matrix.Translation(V((0, 0, 2.45))) @ Matrix.Rotation(math.radians(-14), 4, 'Y')
    parts.append((box((0, 0, 0), (1.75, 1.4, 0.09), m), 'roof_red'))
    g = bmesh.new()
    for y in (-1.2, 1.2):
        vs = [g.verts.new((-1.5, y, 2.2)), g.verts.new((1.5, y, 2.2)), g.verts.new((1.5, y, 2.2 - 0.75)), g.verts.new((-1.5, y, 2.2 + 0.75))]
    _finish(g, False)
    parts.append((box((0.8, -1.22, 1.4), (0.3, 0.04, 0.3)), 'glass'))
    obj('Body', parts, (0, 0, 0), root)
    export('shed')


def swing_set():
    root = empty('SwingSet')
    parts = []
    for x in (-1.8, 1.8):
        for y in (-0.8, 0.8):
            parts.append((cyl((x, y, 0), (x, 0, 2.4), 0.07, 10), 'red'))
    parts.append((cyl((-1.9, 0, 2.4), (1.9, 0, 2.4), 0.08, 12), 'blue'))
    for x in (-0.8, 0.8):
        for dx in (-0.25, 0.25):
            parts.append((cyl((x + dx, 0, 2.4), (x + dx, 0, 0.6), 0.015, 6), 'steel'))
        parts.append((rbox((x, 0, 0.58), (0.32, 0.18, 0.04), 0.3), 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    export('swing_set')


def cloud():
    root = empty('Cloud')
    parts = [(ellipsoid((x, 0, z), (r, r * 0.8, r * 0.85), 16, 10), 'cloud') for x, z, r in
             ((0, 0, 1.4), (-1.4, -0.3, 1.0), (1.5, -0.2, 1.1), (0.6, 0.6, 1.0), (-0.7, 0.4, 0.9), (2.4, -0.5, 0.7), (-2.3, -0.55, 0.65))]
    obj('Body', parts, (0, 0, 0), root)
    export('cloud')


def streetlamp():
    root = empty('Lamp')
    parts = [(cyl((0, 0, 0), (0, 0, 4.2), 0.09, 10), 'navy'), (tube([V((0, 0, 4.1)), V((0.2, 0, 4.4)), V((0.7, 0, 4.4))], 0.06, seg=8), 'navy'),
             (ellipsoid((0.75, 0, 4.25), (0.28, 0.2, 0.12), 14, 8), 'navy'), (ellipsoid((0.75, 0, 4.15), (0.18, 0.14, 0.06), 12, 6), 'yellow')]
    obj('Body', parts, (0, 0, 0), root)
    export('streetlamp')


def road_sign():
    root = empty('Sign')
    sm = Matrix.Translation(V((0, -0.06, 2.0))) @ Matrix.Rotation(math.radians(45), 4, 'Y')
    parts = [(cyl((0, 0, 0), (0, 0, 2.0), 0.05, 8), 'steel'), (box((0, 0, 0), (0.45, 0.025, 0.45), sm), 'yellow'),
             (box((0, -0.03, 0), (0.38, 0.01, 0.38), sm), 'black'), (box((0, -0.04, 0), (0.32, 0.01, 0.32), sm), 'yellow'),
             (star_prism((0, -0.07, 2.0), 0.18, 0.08, 0.02, 'Y'), 'black')]
    obj('Body', parts, (0, 0, 0), root)
    export('road_sign')


def hydrant():
    root = empty('Hydrant')
    parts = [(lathe([(0, 0), (0.22, 0), (0.2, 0.08), (0.17, 0.1), (0.17, 0.6), (0.2, 0.62), (0.2, 0.68), (0.14, 0.75), (0.05, 0.85), (0, 0.85)], 16), 'red')]
    for sx in (-1, 1):
        parts.append((cyl((sx * 0.15, 0, 0.45), (sx * 0.27, 0, 0.45), 0.07, 10), 'red'))
    obj('Body', parts, (0, 0, 0), root)
    export('hydrant')


def mailbox():
    root = empty('Mailbox')
    parts = [(cyl((0, 0, 0), (0, 0, 1.0), 0.05, 8), 'wood'), (rbox((0, 0, 1.15), (0.3, 0.16, 0.15), 0.6), 'blue'),
             (rbox((0.08, 0.17, 1.25), (0.02, 0.02, 0.1), 0.3), 'red')]
    obj('Body', parts, (0, 0, 0), root)
    export('mailbox')


def ferris_wheel():
    root = empty('FerrisWheel')
    R = 6.0
    parts = []
    for y in (-0.6, 0.6):
        parts.append((cyl((-3.0, y, 0), (0, y * 0.5, 7.0), 0.15, 10), 'white'))
        parts.append((cyl((3.0, y, 0), (0, y * 0.5, 7.0), 0.15, 10), 'white'))
    obj('Stand', parts, (0, 0, 0), root)
    wh = []
    for y in (-0.35, 0.35):
        wh.append((torus(V((0, y, 7.0)), V((0, 1, 0)), R, 0.09, 64, 6), 'magenta'))
    for k in range(12):
        a = 2 * math.pi * k / 12
        wh.append((cyl((0, 0, 7.0), (R * math.cos(a), 0, 7.0 + R * math.sin(a)), 0.05, 6), 'white'))
        c = V((R * math.cos(a), 0, 7.0 + R * math.sin(a) - 0.6))
        wh.append((rbox(c, (0.45, 0.4, 0.35), 0.4), ['red', 'yellow', 'cyan', 'lime'][k % 4]))
    wh.append((cyl((0, -0.6, 7.0), (0, 0.6, 7.0), 0.4, 16), 'yellow'))
    obj('Wheel', wh, (0, 0, 7.0), root)
    export('ferris_wheel')


def coaster():
    root = empty('Coaster')
    pts = [V((x, 0, 3.0 + 2.5 * math.sin(x * 0.35) + 1.2 * math.sin(x * 0.9))) for x in [i * 0.5 - 8 for i in range(33)]]
    parts = []
    for y in (-0.4, 0.4):
        parts.append((tube([p + V((0, y, 0)) for p in pts], 0.08, seg=8), 'red'))
    for i in range(0, 33, 2):
        p = pts[i]
        parts.append((cyl(p + V((0, -0.45, 0)), p + V((0, 0.45, 0)), 0.05, 6), 'white'))
        if i % 4 == 0:
            parts.append((cyl(V((p.x, 0, 0)), p, 0.09, 8), 'white'))
    obj('Body', parts, (0, 0, 0), root)
    export('coaster')


def tent():
    root = empty('Tent')
    parts = []
    for k in range(12):
        a0, a1 = 2 * math.pi * k / 12, 2 * math.pi * (k + 1) / 12
        bm = bmesh.new()
        vs = [bm.verts.new((3 * math.cos(a0), 3 * math.sin(a0), 0)), bm.verts.new((3 * math.cos(a1), 3 * math.sin(a1), 0)),
              bm.verts.new((3 * math.cos(a1), 3 * math.sin(a1), 2.2)), bm.verts.new((3 * math.cos(a0), 3 * math.sin(a0), 2.2))]
        bm.faces.new(vs)
        top = bm.verts.new((0, 0, 5.0))
        bm.faces.new((vs[3], vs[2], top))
        _finish(bm, False)
        parts.append((bm, 'red' if k % 2 == 0 else 'white'))
    parts.append((cyl((0, 0, 5.0), (0, 0, 5.8), 0.05, 6), 'steel'))
    parts.append((box((0.25, 0, 5.65), (0.25, 0.01, 0.15)), 'yellow'))
    obj('Body', parts, (0, 0, 0), root)
    export('tent')


def planet():
    root = empty('Planet')
    parts = [(ellipsoid((0, 0, 0), (3, 3, 3), 32, 20), 'orange'), (torus(V((0, 0, 0)), V((0.2, -0.3, 1)), 4.5, 0.25, 64, 6), 'lavender'),
             (ellipsoid((1.0, -2.6, 0.8), (0.6, 0.3, 0.5), 12, 8), 'pink')]
    obj('Body', parts, (0, 0, 0), root)
    export('planet')


def space_station():
    root = empty('Station')
    parts = [(torus(V((0, 0, 0)), V((0, 1, 0)), 4, 0.5, 48, 12), 'white'), (cyl((0, -1.5, 0), (0, 1.5, 0), 1.0, 20), 'steel')]
    for k in range(4):
        a = math.pi * k / 2
        parts.append((cyl((0, 0, 0), (4 * math.cos(a), 0, 4 * math.sin(a)), 0.18, 8), 'chrome'))
    for sx in (-1, 1):
        parts.append((box((sx * 7.0, 0, 0), (2.2, 0.05, 1.0)), 'navy'))
        parts.append((cyl((sx * 4.3, 0, 0), (sx * 4.8, 0, 0), 0.1, 8), 'chrome'))
    parts.append((ellipsoid((0, -1.6, 0), (0.6, 0.15, 0.6), 16, 8), 'glow'))
    obj('Body', parts, (0, 0, 0), root)
    export('space_station')


def moon_rock():
    root = empty('MoonRock')
    random.seed(9)
    r = ellipsoid((0, 0, 0.35), (0.9, 0.7, 0.6), 16, 10)
    for v in r.verts:
        v.co += V((random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08)))
        v.co.z = max(v.co.z, 0)
    obj('Body', [(r, 'rock')], (0, 0, 0), root)
    export('moon_rock')


def flag():
    root = empty('Flag')
    parts = [(cyl((0, 0, 0), (0, 0, 2.6), 0.04, 8), 'chrome'), (box((0.5, 0, 2.3), (0.5, 0.01, 0.3)), 'red'),
             (star_prism((0.5, -0.02, 2.3), 0.16, 0.07, 0.02, 'Y'), 'yellow')]
    obj('Body', parts, (0, 0, 0), root)
    export('flag')


# =============================================================== run
for fn in (launcher, trampoline, bounce_house, pool, spring, mattress, satellite_dish, fan, truck, duck, seesaw, tire,
           slide, rotating_platform, conveyor, cushion, bumper, wind_tunnel, ramp, coin, floating_platform, booster_ring,
           thruster, umbrella, rocket_shoe, balloon, propeller_hat, plunger_gun, helmets, tree_pine, bush, fence, shed,
           swing_set, cloud, streetlamp, road_sign, hydrant, mailbox, ferris_wheel, coaster, tent, planet, space_station,
           moon_rock, flag):
    fn()
mattress('emergency_mattress', 'orange', 'yellow')
tree_round('tree_round', 4.5)
tree_round('tree_round_big', 6.5)
house('house_a', 'wall_yellow', 'roof_red', 'red')
house('house_b', 'wall_blue', 'roof_grey', 'yellow')
house('house_c', 'wall_mint', 'roof_red', 'blue', W=3.5, slope=36)
house('house_d', 'wall_peach', 'roof_grey', 'green', W=4.5, slope=26)
print('DONE')
