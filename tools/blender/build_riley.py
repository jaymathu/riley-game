"""Builds Riley: modeled, rigged and animated, exported as glTF binary for Godot 4.

Run:  python build_riley.py <out_dir>      (with the `bpy` module, Blender 4.2+)
Outputs: riley.glb, riley.blend
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector as V, Matrix, Euler, Quaternion
from riley_lib import *

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith('.py') else os.getcwd()
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
coll = bpy.data.collections.new('Riley')
scene.collection.children.link(coll)
random.seed(7)

# ------------------------------------------------------------------ palette
M = dict(
    skin=make_mat('Skin', '#F6C29B', 0.55),
    skin_dark=make_mat('SkinShade', '#E59F7C', 0.6),
    hair=make_mat('Hair', '#6E3B1C', 0.45, coat=0.2),
    shirt=make_mat('Shirt', '#2D7BE5', 0.7),
    shirt_trim=make_mat('ShirtTrim', '#F4F6FA', 0.7),
    collar=make_mat('ShirtCollar', '#1F5FBF', 0.7),
    bolt=make_mat('Bolt', '#FFD22E', 0.5),
    shorts=make_mat('Shorts', '#2C3140', 0.75),
    shorts_trim=make_mat('ShortsTrim', '#454C60', 0.75),
    shoe=make_mat('ShoeMain', '#E8342C', 0.4, coat=0.3),
    shoe_white=make_mat('ShoeWhite', '#F7F7F5', 0.5),
    sock=make_mat('Sock', '#FBFBFB', 0.8),
    eye_white=make_mat('EyeWhite', '#FFFFFF', 0.2, coat=0.5),
    iris=make_mat('Iris', '#6B3E1E', 0.2, coat=0.5),
    pupil=make_mat('Pupil', '#120A06', 0.15, coat=0.5),
    eye_hi=make_mat('EyeHighlight', '#FFFFFF', 0.1, emit=2.0),
    ink=make_mat('Ink', '#2A160C', 0.5),
    mouth=make_mat('MouthInside', '#6E1E22', 0.6),
    teeth=make_mat('Teeth', '#FFFFFF', 0.3),
    tongue=make_mat('Tongue', '#F0727A', 0.5),
    brow=make_mat('Brow', '#3B1C0C', 0.6),
    strap=make_mat('GoggleStrap', '#383C47', 0.65),
    brass=make_mat('GoggleRim', '#F0A12C', 0.3, metal=0.6),
    lens=make_mat('GoggleLens', '#5FC6F0', 0.05, metal=0.1, coat=1.0),
)

parts = []  # (obj)


def add(name, bm, mat, weights):
    ob = bm_to_obj(name, bm, M[mat], coll)
    weight_obj(ob, weights)
    parts.append(ob)
    return ob


# ------------------------------------------------------------------ proportions
HEAD_C = V((0, 0, 1.04))
HA, HB, HC = 0.215, 0.195, 0.205
S_L = V((0.150, 0.0, 0.752))           # shoulder
ARM_DIR = V((math.sin(math.radians(36)), 0, -math.cos(math.radians(36))))
E_L = S_L + ARM_DIR * 0.165             # elbow
FORE_DIR = (ARM_DIR + V((0, -0.16, 0.02))).normalized()
W_L = E_L + FORE_DIR * 0.150            # wrist
HIP_L = V((0.082, 0.0, 0.485))
KNEE_L = V((0.088, -0.006, 0.300))
ANK_L = V((0.090, 0.0, 0.105))
TOE_L = V((0.090, -0.135, 0.035))


def mirror(v):
    return V((-v.x, v.y, v.z))


# ------------------------------------------------------------------ head
head = ellipsoid(HEAD_C, (HA, HB, HC), 40, 28)
for v in head.verts:
    lz = (v.co.z - HEAD_C.z) / HC
    ly = (v.co.y - HEAD_C.y) / HB
    if lz < 0.15:   # chubby cheeks / jaw
        k = 1 + 0.07 * smoothstep(0.15, -0.55, lz) * (1 - smoothstep(-0.75, -1.0, lz))
        v.co.x *= k
        if ly < 0:
            v.co.y = HEAD_C.y + (v.co.y - HEAD_C.y) * (1 + 0.04 * smoothstep(0.15, -0.5, lz))
    if lz > 0.3 and ly > 0:  # rounder back of skull
        v.co.y += 0.012 * smoothstep(0.3, 0.8, lz)
head_bvh = bvh_of(head)
head_copy = head.copy()
add('Head', head, 'skin', lambda c: blend2('neck', 'head', 0.86, 0.90, c.z))

FRONT = dict(origin=V((0, -1, 0)), U=V((1, 0, 0)), Vv=V((0, 0, 1)), D=V((0, 1, 0)))

# ears
for sx in (1, -1):
    ec = V((sx * (HA * 1.035), 0.012, 1.012))
    m = Matrix.Rotation(math.radians(-14 * sx), 4, 'Z')
    add('Ear', ellipsoid(ec, (0.030, 0.042, 0.056), 20, 14, m), 'skin', 'head')
    add('EarInner', ellipsoid(ec + V((sx * 0.012, -0.006, -0.002)), (0.022, 0.026, 0.036), 16, 12, m), 'skin_dark', 'head')
    add('EarRim', ellipsoid(ec + V((sx * 0.016, -0.003, 0.004)), (0.018, 0.020, 0.028), 16, 12, m), 'skin', 'head')

# nose
hit = project_point(head_bvh, V((0, -1, 0.985)), V((0, 1, 0)))
add('Nose', ellipsoid(hit[0] + V((0, 0.006, 0)), (0.026, 0.022, 0.020), 16, 12), 'skin', 'head')


# ------------------------------------------------------------------ eyes (variants)
EYE_Z = 1.030
EYE_X = 0.081


def eye(sx, scale=(0.068, 0.030, 0.082), iris_t=40, pupil_t=22, look=(0, 0)):
    """One eye built on a unit sphere then squashed, caps follow the surface."""
    hit = project_point(head_bvh, V((sx * EYE_X, -1, EYE_Z)), V((0, 1, 0)))
    center = hit[0] + V((0, 0.016, 0))
    yaw = math.radians(13 * sx)
    R = Matrix.Rotation(yaw, 4, 'Z')
    S = Matrix.Diagonal((*scale, 1))
    fwd = (Matrix.Rotation(-yaw, 3, 'Z') @ V((look[0], -1, look[1]))).normalized()
    toZ = V((0, 0, 1)).rotation_difference(fwd).to_matrix().to_4x4()
    T = Matrix.Translation(center) @ R @ S
    out = []
    ball = ellipsoid(V((0, 0, 0)), (1, 1, 1), 24, 18)
    out.append((transform(ball, T), 'eye_white'))
    out.append((transform(transform(sphere_cap(1.006, math.radians(iris_t), 28, 6), toZ), T), 'iris'))
    out.append((transform(transform(sphere_cap(1.012, math.radians(pupil_t), 24, 5), toZ), T), 'pupil'))
    for (ax, ay, th) in ((-26 * sx, 24, 9), (18 * sx, -22, 4.5)):
        d = (Matrix.Rotation(math.radians(ay), 3, 'X') @ Matrix.Rotation(math.radians(ax), 3, 'Y') @ V((0, 0, 1)))
        rot = V((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        out.append((transform(transform(transform(sphere_cap(1.018, math.radians(th), 16, 3), rot), toZ), T), 'eye_hi'))
    return out


for sx in (1, -1):
    for bm, mt in eye(sx, look=(0.0, 0.05)):
        add('EyeOpen', bm, mt, 'eyes_open')
    for bm, mt in eye(sx, scale=(0.076, 0.034, 0.092), iris_t=24, pupil_t=12):
        add('EyeWide', bm, mt, 'eyes_wide')


def eye_line(sx, pts_uv, rad, bone, lift=0.006):
    pts = [(sx * EYE_X + sx * u, EYE_Z + v) for u, v in pts_uv]
    if sx < 0:
        pts = pts[::-1]
    add('EyeLine', surface_tube(pts, rad, head_bvh, **FRONT, lift=lift), 'ink', bone)


n = 9
closed = [((-0.048 + 0.096 * i / (n - 1)), -0.006 - 0.012 * math.sin(math.pi * i / (n - 1))) for i in range(n)]
happy = [((-0.046 + 0.092 * i / (n - 1)), -0.012 + 0.030 * math.sin(math.pi * i / (n - 1))) for i in range(n)]
taper = [0.004 + 0.004 * math.sin(math.pi * i / (n - 1)) for i in range(n)]
taper2 = [0.005 + 0.006 * math.sin(math.pi * i / (n - 1)) for i in range(n)]
for sx in (1, -1):
    eye_line(sx, closed, taper, 'eyes_closed')
    eye_line(sx, happy, taper2, 'eyes_happy')
    eye_line(sx, [(-0.035, 0.035), (0.035, -0.035)], 0.0075, 'eyes_dizzy')
    eye_line(sx, [(-0.035, -0.035), (0.035, 0.035)], 0.0075, 'eyes_dizzy', lift=0.0075)

# brows
for sx, b in ((1, 'brow.L'), (-1, 'brow.R')):
    pts = [(sx * (EYE_X - 0.040 + 0.080 * i / 8), 1.128 + 0.013 * math.sin(math.pi * i / 8) + 0.004 * (i / 8) * (1 if sx > 0 else 1)) for i in range(9)]
    if sx < 0:
        pts = pts[::-1]
    rad = [0.0075 + 0.0065 * math.sin(math.pi * (0.25 + 0.75 * i / 8)) for i in range(9)]
    if sx < 0:
        rad = rad[::-1]
    add('Brow', surface_tube(pts, rad, head_bvh, **FRONT, lift=0.009), 'brow', b)


# ------------------------------------------------------------------ mouths (variants)
MZ = 0.916


def curve(f, a, b, n):
    return [(a + (b - a) * i / (n - 1), f(a + (b - a) * i / (n - 1))) for i in range(n)]


def mouth_set(bone, w, top_k, depth, smirk=0.0, teeth=True, tongue=True, cz=MZ):
    vt = lambda u: cz + 0.004 + top_k * (u / w) ** 2 + smirk * u
    vb = lambda u: vt(u) - depth * max(0.0, 1 - (u / w) ** 2) ** 0.75
    outline = curve(vt, w, -w, 24) + curve(vb, -w * 0.97, w * 0.97, 24)
    add('Mouth', decal(outline, head_bvh, **FRONT, offset=0.0025, depth=0.004), 'mouth', bone)
    if teeth:
        tw = w * 0.70
        tb = lambda u: min(vt(u) - 0.004, max(vt(u) - depth * 0.30, vb(u) + 0.005))
        poly = curve(lambda u: vt(u) - 0.0015, tw, -tw, 16) + curve(tb, -tw, tw, 16)
        add('Teeth', decal(poly, head_bvh, **FRONT, offset=0.0040, depth=0.004), 'teeth', bone)
    if tongue:
        tc = (w * 0.12, vb(w * 0.12) + depth * 0.30)
        rx, rz = w * 0.50, depth * 0.24
        poly = [(tc[0] + rx * math.cos(a), tc[1] + rz * math.sin(a)) for a in
                [2 * math.pi * i / 24 for i in range(24)]]
        poly = [(u, max(v, vb(u) + 0.003)) for u, v in poly]
        add('Tongue', decal(poly, head_bvh, **FRONT, offset=0.0040, depth=0.004), 'tongue', bone)


mouth_set('mouth_grin', 0.068, 0.018, 0.044, smirk=0.10)
mouth_set('mouth_laugh', 0.076, 0.012, 0.064)
# "O" shock mouth
oc = (0.0, MZ - 0.012)
add('Mouth', decal([(0.026 * math.cos(a), oc[1] + 0.034 * math.sin(a)) for a in
                    [2 * math.pi * i / 32 for i in range(32)]], head_bvh, **FRONT, offset=0.0025), 'mouth', 'mouth_o')
add('Tongue', decal([(0.016 * math.cos(a), oc[1] - 0.018 + 0.010 * math.sin(a)) for a in
                     [2 * math.pi * i / 20 for i in range(20)]], head_bvh, **FRONT, offset=0.004), 'tongue', 'mouth_o')
# gritted-teeth grimace
gw, gh = 0.055, 0.017
rect = lambda w, h, cz: ([(w * math.cos(a) ** 0.6 if math.cos(a) >= 0 else -w * (-math.cos(a)) ** 0.6,
                          cz + h * (math.sin(a) ** 0.6 if math.sin(a) >= 0 else -(-math.sin(a)) ** 0.6))
                         for a in [2 * math.pi * i / 40 for i in range(40)]])
add('Mouth', decal([(u, v - 0.004 * (u / gw)) for u, v in rect(gw + 0.006, gh + 0.006, MZ - 0.004)], head_bvh, **FRONT, offset=0.0025), 'mouth', 'mouth_grimace')
add('Teeth', decal([(u, v - 0.004 * (u / gw)) for u, v in rect(gw, gh, MZ - 0.004)], head_bvh, **FRONT, offset=0.004), 'teeth', 'mouth_grimace')
add('MouthLine', surface_tube([(-gw + 2 * gw * i / 10, MZ - 0.004 - 0.004 * ((-gw + 2 * gw * i / 10) / gw)) for i in range(11)],
                              0.0028, head_bvh, **FRONT, lift=0.0045, seg=6), 'mouth', 'mouth_grimace')
for k in (-0.5, 0.0, 0.5):
    add('MouthLine', surface_tube([(k * gw, MZ - 0.004 - 0.004 * k + gh * s) for s in (-0.95, 0, 0.95)],
                                  0.0022, head_bvh, **FRONT, lift=0.0045, seg=6), 'mouth', 'mouth_grimace')


# ------------------------------------------------------------------ hair
HAIR_C = HEAD_C + V((0, 0.010, 0.014))
HR = (HA * 1.07, HB * 1.08, HC * 1.07)


def hairline(nx, ny):
    base = 0.10 + (0.58 * (-ny) if ny < 0 else -0.72 * ny)
    return base - 0.10 * smoothstep(0.75, 0.98, abs(nx)) * (1 if ny < 0.2 else 0)


cap = ellipsoid(V((0, 0, 0)), (1, 1, 1), 40, 30)
kill = [v for v in cap.verts if v.co.z < hairline(v.co.x, v.co.y)]
bmesh.ops.delete(cap, geom=kill, context='VERTS')
for v in cap.verts:
    v.co = HAIR_C + V((v.co.x * HR[0], v.co.y * HR[1], v.co.z * HR[2]))
add('HairCap', cap, 'hair', 'head')


def lock(base, axis, length, r0, bend_dir, bend, flat=0.5, twist=0.0):
    """A chunky, flattened, curved lock of cartoon hair."""
    prof = [(r0 * (1 - t ** 2.2) ** 0.8 * (1 - 0.6 * t) if t < 1 else 0, length * t)
            for t in [i / 9 for i in range(10)]]
    bm = lathe(prof, 12)
    for v in bm.verts:
        t = v.co.z / length
        v.co.x *= flat
        v.co.x += bend * length * t * t
    axis = V(axis).normalized()
    bx = (V(bend_dir) - axis * V(bend_dir).dot(axis)).normalized()
    by = axis.cross(bx)
    m = frame_matrix(base, bx, by, axis) @ Matrix.Rotation(twist, 4, 'Z')
    return transform(bm, m)


def cap_point(d):
    d = V(d).normalized()
    p = HAIR_C + V((d.x * HR[0], d.y * HR[1], d.z * HR[2]))
    nrm = V((d.x / HR[0], d.y / HR[1], d.z / HR[2])).normalized()
    return p, nrm


def sph(az, el):
    az, el = math.radians(az), math.radians(el)
    return V((math.cos(el) * math.sin(az), -math.cos(el) * math.cos(az), math.sin(el)))


# (azimuth: 0=front, +90=Riley's left, 180=back ; elevation ; length ; radius ; sweep dir ; bend)
LOCKS = []
for az in (-140, -100, -60, -20, 20, 60, 100, 140, 180):                       # crown ring, swept back
    LOCKS.append((az, 55, 0.16, 0.090, V((0, 1.0, 0.1)), 0.5, 0.12))
for az in (-150, -110, 110, 150, 180):                                # mid/back ring
    LOCKS.append((az, 18, 0.15, 0.10, V((0, 1.0, -0.25)), 0.45, 0.15))
for az in (-125, 125, 180):                                                   # low back, sweep down
    LOCKS.append((az, -12, 0.11, 0.095, V((0, 0.6, -1.0)), 0.35, 0.0))
for az in (-60, 0, 60):                                                        # top
    LOCKS.append((az, 78, 0.16, 0.090, V((0, 1.0, 0.25)), 0.55, 0.45))
for (az, el, ln, r0, sw, bd, up) in LOCKS:
    az += random.uniform(-7, 7)
    p, nrm = cap_point(sph(az, el))
    tng = sw - nrm * sw.dot(nrm)
    axis = tng.normalized() + nrm * 0.65 + V((0, 0, 1)) * up
    add('HairLock', lock(p - nrm * 0.03, axis, ln * random.uniform(0.85, 1.15), r0 * random.uniform(0.95, 1.1),
                         -nrm + V((0, 0, -0.2)), bd * random.uniform(0.8, 1.2), 0.55, random.uniform(-0.25, 0.25)), 'hair', 'head')
# signature front swoop: up, back and toward Riley's right
for (az, el, ax, ln, r0, bd) in ((40, 40, (0.1, -0.3, 1.0), 0.15, 0.075, 0.6), (10, 42, (-0.25, -0.5, 1.0), 0.19, 0.085, 0.75),
                                 (-22, 40, (-0.5, -0.35, 0.9), 0.17, 0.080, 0.65), (-52, 34, (-0.85, -0.05, 0.7), 0.14, 0.070, 0.55),
                                 (72, 30, (0.6, -0.05, 0.9), 0.12, 0.068, 0.5), (-6, 36, (-0.35, -0.45, 0.9), 0.12, 0.065, 0.5)):
    p, nrm = cap_point(sph(az, el))
    add('HairBang', lock(p - nrm * 0.025, ax, ln, r0, V((0, 0.7, 0.3)), bd, 0.55), 'hair', 'head')
# sideburns
for sx in (1, -1):
    add('HairSide', lock(V((sx * 0.205, 0.03, 1.08)), (sx * 0.35, 0.15, -1), 0.075, 0.04, V((0, 1, 0)), 0.3), 'hair', 'head')

# ------------------------------------------------------------------ goggles (pushed up on forehead)
hair_bvh = bvh_of(ellipsoid(HAIR_C, HR, 32, 24))
strap = []
for i in range(56):
    phi = 2 * math.pi * i / 56
    c, s = math.cos(phi), math.sin(phi)
    z = 1.175 + 0.052 * (-s)
    lz = (z - HAIR_C.z) / HR[2]
    rr = math.sqrt(max(0.0, 1 - lz * lz) / ((c / HR[0]) ** 2 + (s / HR[1]) ** 2)) + 0.006 + 0.050 * max(0.0, -s) ** 3
    strap.append(V((HAIR_C.x + rr * c, HAIR_C.y + rr * s, z)))
sb = bmesh.new()
rings = []
for p in strap:
    out = V((p.x - HAIR_C.x, p.y - HAIR_C.y, 0)).normalized()
    up = V((0, 0, 1))
    rings.append([sb.verts.new(p + out * o + up * h) for o, h in ((0, -0.017), (0.009, -0.016), (0.011, 0), (0.009, 0.016), (0, 0.017))])
for i in range(len(rings)):
    a, b = rings[i], rings[(i + 1) % len(rings)]
    for k in range(4):
        sb.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
from riley_lib import _finish
_finish(sb)
add('GoggleStrap', sb, 'strap', 'head')
lens_centers = []
for sx in (1, -1):
    hit = project_point(hair_bvh, V((sx * 0.066, -1, 1.222)), V((0, 1, 0)))
    nrm = (hit[1] + V((sx * 0.22, -0.35, 0.0))).normalized()
    base = hit[0] + nrm * 0.048
    Mx = align_matrix(base, nrm)
    add('GoggleCup', transform(lathe([(0, -0.050), (0.036, -0.050), (0.046, -0.02), (0.048, 0.006), (0.048, 0.024), (0.040, 0.030), (0, 0.030)], 28), Mx), 'brass', 'head')
    add('GoggleRim', tube(ring_points(base + nrm * 0.031, nrm, 0.043, n=28), 0.0075, closed=True, seg=8), 'strap', 'head')
    add('GoggleLens', transform(transform(sphere_cap(0.12, math.asin(0.040 / 0.12), 24, 4), Matrix.Translation(V((0, 0, -0.12 + 0.036)))), Mx), 'lens', 'head')
    add('GoggleShine', transform(ellipsoid(V((-0.012 * sx, 0, 0.012)), (0.010, 0.006, 0.003), 12, 8, Matrix.Rotation(math.radians(35 * sx), 4, 'Z')),
                                 Mx @ Matrix.Translation(V((0, 0, 0.0365)))), 'eye_hi', 'head')
    lens_centers.append(base + nrm * 0.02)
add('GoggleBridge', capsule(lens_centers[0] + V((-0.035, 0, 0)), lens_centers[1] + V((0.035, 0, 0)), 0.009, 0.009, 10, 3), 'strap', 'head')


# ------------------------------------------------------------------ torso / shirt
def torso_w(c):
    if c.z < 0.60:
        return {'hips': 1.0}
    if c.z < 0.69:
        return blend2('hips', 'spine', 0.60, 0.69, c.z)
    return blend2('spine', 'chest', 0.69, 0.77, c.z)


prof = [(0, 0.500), (0.150, 0.500), (0.166, 0.506), (0.169, 0.522), (0.162, 0.570), (0.157, 0.630),
        (0.160, 0.690), (0.164, 0.735), (0.160, 0.772), (0.142, 0.803), (0.108, 0.828), (0.070, 0.842), (0, 0.846)]
shirt = lathe(prof, 36)
for v in shirt.verts:
    v.co.y *= 0.70
    if v.co.y < 0:
        v.co.y *= 1 + 0.06 * smoothstep(0.52, 0.62, v.co.z) * (1 - smoothstep(0.66, 0.74, v.co.z))  # tummy
shirt_bvh = bvh_of(shirt)
add('Shirt', shirt, 'shirt', torso_w)
add('Collar', tube(ring_points(V((0, 0, 0.836)), V((0, 0, 1)), 0.088, 0.066, 36), 0.012, closed=True, seg=8), 'collar',
    lambda c: blend2('chest', 'neck', 0.83, 0.86, c.z))
add('ShirtHem', tube(ring_points(V((0, 0, 0.508)), V((0, 0, 1)), 0.168, 0.168 * 0.70, 40), 0.008, closed=True, seg=6), 'collar', 'hips')
bolt = [(0.022, 0.085), (-0.050, -0.006), (-0.004, -0.006), (-0.030, -0.088), (0.056, 0.012), (0.010, 0.012), (0.044, 0.085)]
bolt = [(u * 0.95, 0.682 + v * 0.95) for u, v in bolt]
add('Bolt', decal(bolt, shirt_bvh, **FRONT, offset=0.0035, depth=0.004, cuts=3), 'bolt', torso_w)

# neck
add('Neck', capsule(V((0, 0.005, 0.79)), V((0, 0.005, 0.90)), 0.050, 0.048, 16, 4), 'skin',
    lambda c: blend2('neck', 'head', 0.88, 0.92, c.z) if c.z > 0.86 else blend2('chest', 'neck', 0.81, 0.85, c.z))


# ------------------------------------------------------------------ arms
def build_arm(sx, side):
    S, E, W = (S_L, E_L, W_L) if sx > 0 else (mirror(S_L), mirror(E_L), mirror(W_L))
    ad = (E - S).normalized()
    fd = (W - E).normalized()
    ua, fa, hd = 'upper_arm.' + side, 'forearm.' + side, 'hand.' + side
    sleeve = lathe([(0, -0.030), (0.040, -0.026), (0.058, -0.012), (0.064, 0.02), (0.066, 0.075), (0.067, 0.090), (0.05, 0.091), (0, 0.091)], 24)
    add('Sleeve', transform(sleeve, align_matrix(S, ad)), 'shirt', ua)
    add('SleeveCuff', tube(ring_points(S + ad * 0.086, ad, 0.066, n=24), 0.010, closed=True, seg=8), 'shirt_trim', ua)
    add('UpperArm', capsule(S + ad * 0.045, E, 0.045, 0.041, 16, 4), 'skin', ua)
    add('Forearm', capsule(E, W, 0.042, 0.037, 16, 4), 'skin', fa)
    # hand frame
    f = fd
    n_ = V((-sx, 0, 0))
    n_ = (n_ - f * n_.dot(f)).normalized()
    w = f.cross(n_).normalized()
    if w.y > 0:
        w = -w
    HM = frame_matrix(V((0, 0, 0)), w, n_, f)
    add('Palm', superellipsoid(W + f * 0.040, (0.040, 0.025, 0.043), 0.55, 20, 14, HM), 'skin', hd)
    for off, ln in ((-0.026, 0.042), (0.0, 0.047), (0.026, 0.042)):
        st = W + f * 0.064 + w * off
        d = (f + n_ * 0.45).normalized()
        add('Finger', capsule(st, st + d * ln, 0.0140, 0.0130, 12, 3), 'skin', hd)
    st = W + f * 0.022 + w * 0.030
    add('Thumb', capsule(st, st + (f * 0.55 + w * 0.65 + n_ * 0.35).normalized() * 0.040, 0.0145, 0.013, 12, 3), 'skin', hd)


build_arm(1, 'L')
build_arm(-1, 'R')

# ------------------------------------------------------------------ shorts & legs
pel = lathe([(0, 0.415), (0.118, 0.415), (0.146, 0.440), (0.152, 0.490), (0.145, 0.540), (0.120, 0.575), (0, 0.580)], 32)
for v in pel.verts:
    v.co.y *= 0.70
add('Pelvis', pel, 'shorts', 'hips')


def build_leg(sx, side):
    H, K, A, T = (HIP_L, KNEE_L, ANK_L, TOE_L) if sx > 0 else (mirror(HIP_L), mirror(KNEE_L), mirror(ANK_L), mirror(TOE_L))
    th, sh, ft = 'thigh.' + side, 'shin.' + side, 'foot.' + side
    leg_dir = (V((sx * 0.012, 0, -1))).normalized()
    sl = lathe([(0, -0.02), (0.07, -0.02), (0.079, 0.0), (0.082, 0.12), (0.085, 0.146), (0.07, 0.15), (0, 0.15)], 24)
    sl = transform(sl, align_matrix(H + V((sx * 0.004, 0, 0.03)), leg_dir))
    add('ShortsLeg', sl, 'shorts', th)
    add('ShortsHem', tube(ring_points(H + V((sx * 0.004, 0, 0.03)) + leg_dir * 0.142, leg_dir, 0.084, n=24), 0.009, closed=True, seg=6), 'shorts_trim', th)
    add('Thigh', capsule(H, K, 0.058, 0.052, 16, 4), 'skin', th)
    add('Shin', capsule(K, A, 0.052, 0.044, 16, 4), 'skin', sh)
    add('Sock', transform(lathe([(0, -0.045), (0.05, -0.045), (0.056, -0.02), (0.056, 0.085), (0.044, 0.088), (0, 0.088)], 24),
                          Matrix.Translation(A)), 'sock', sh)
    add('SockCuff', tube(ring_points(A + V((0, 0, 0.084)), V((0, 0, 1)), 0.055, n=24), 0.008, closed=True, seg=6), 'sock', sh)
    add('SockStripe', tube(ring_points(A + V((0, 0, 0.060)), V((0, 0, 1)), 0.056, n=24), 0.0065, closed=True, seg=6), 'shoe', sh)
    # sneaker
    x = A.x
    add('Sole', superellipsoid(V((x, -0.038, 0.020)), (0.062, 0.122, 0.022), 0.35, 28, 16), 'shoe_white', ft)
    upper = superellipsoid(V((x, -0.030, 0.066)), (0.056, 0.106, 0.052), 0.55, 28, 18)
    up_bvh = bvh_of(upper.copy())
    add('ShoeUpper', upper, 'shoe', ft)
    add('ToeCap', superellipsoid(V((x, -0.104, 0.050)), (0.054, 0.050, 0.036), 0.6, 20, 14), 'shoe_white', ft)
    add('ShoeCollar', tube(ring_points(V((x, 0.010, 0.112)), V((0, 0.25, 1)), 0.062, 0.066, 28), 0.012, closed=True, seg=8), 'shoe_white', ft)
    for yy in (-0.072, -0.048, -0.024):
        add('Lace', surface_tube([(x + s * 0.026, yy - 0.004 * abs(s)) for s in (-1, -0.5, 0, 0.5, 1)], 0.0055, up_bvh,
                                 origin=V((0, 0, 1)), U=V((1, 0, 0)), Vv=V((0, 1, 0)), D=V((0, 0, -1)), lift=0.002, seg=6), 'shoe_white', ft)
    star = []
    for i in range(10):
        a = math.pi / 2 + 2 * math.pi * i / 10
        rr = 0.024 if i % 2 == 0 else 0.0105
        star.append((-0.025 + rr * math.cos(a) * (1 if sx > 0 else -1), 0.064 + rr * math.sin(a)))
    star_poly = [(-u if sx > 0 else u, v) for u, v in star]
    add('ShoeStar', decal(star_poly, up_bvh, origin=V((sx * 1.0, 0, 0)), U=V((0, -sx, 0)), Vv=V((0, 0, 1)), D=V((-sx, 0, 0)),
                          offset=0.0025, depth=0.003, cuts=2), 'shoe_white', ft)


build_leg(1, 'L')
build_leg(-1, 'R')

# ------------------------------------------------------------------ armature
arm_data = bpy.data.armatures.new('RileyRig')
rig = bpy.data.objects.new('RileyRig', arm_data)
coll.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones
BONES = {}


def bone(name, h, t, parent=None, deform=True, roll=0.0):
    b = eb.new(name)
    b.head, b.tail = V(h), V(t)
    b.roll = roll
    if parent:
        b.parent = eb[parent]
        b.use_connect = False
    b.use_deform = deform
    BONES[name] = b
    return b


bone('hips', (0, 0, 0.50), (0, 0, 0.62))
bone('spine', (0, 0, 0.62), (0, 0, 0.73), 'hips')
bone('chest', (0, 0, 0.73), (0, 0, 0.83), 'spine')
bone('neck', (0, 0.005, 0.83), (0, 0.005, 0.90), 'chest')
bone('head', (0, 0.005, 0.90), (0, 0.005, 1.25), 'neck')
for side, sx in (('L', 1), ('R', -1)):
    mv = (lambda v: v) if sx > 0 else mirror
    bone('upper_arm.' + side, mv(S_L), mv(E_L), 'chest')
    bone('forearm.' + side, mv(E_L), mv(W_L), 'upper_arm.' + side)
    bone('hand.' + side, mv(W_L), mv(W_L + FORE_DIR * 0.10), 'forearm.' + side)
    bone('thigh.' + side, mv(HIP_L), mv(KNEE_L), 'hips')
    bone('shin.' + side, mv(KNEE_L), mv(ANK_L), 'thigh.' + side)
    bone('foot.' + side, mv(ANK_L), mv(TOE_L), 'shin.' + side)
    bone('brow.' + side, (sx * EYE_X, -0.13, 1.13), (sx * EYE_X, -0.18, 1.13), 'head')
for nm, z in (('eyes_open', EYE_Z), ('eyes_wide', EYE_Z), ('eyes_closed', EYE_Z), ('eyes_happy', EYE_Z), ('eyes_dizzy', EYE_Z),
              ('mouth_grin', MZ), ('mouth_laugh', MZ), ('mouth_o', MZ), ('mouth_grimace', MZ)):
    bone(nm, (0, -0.12, z), (0, -0.12, z + 0.05), 'head')
bpy.ops.object.mode_set(mode='OBJECT')

# ------------------------------------------------------------------ join + skin
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:
    ob.select_set(True)
body = parts[0]
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = 'Riley'
body.data.name = 'RileyMesh'
bpy.ops.object.select_all(action='DESELECT')
body.parent = rig
mod = body.modifiers.new('Armature', 'ARMATURE')
mod.object = rig
# limit to 4 influences, normalized
for v in body.data.vertices:
    gs = sorted(v.groups, key=lambda g: -g.weight)
    for g in gs[4:]:
        body.vertex_groups[g.group].remove([v.index])
print('TRIS', sum(len(p.vertices) - 2 for p in body.data.polygons), 'VERTS', len(body.data.vertices))

# ------------------------------------------------------------------ animation
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'riley_anims.py')).read())

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'riley.blend'))
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT, 'riley.glb'), export_format='GLB', export_animations=True,
    export_animation_mode='ACTIONS', export_force_sampling=True, export_frame_step=1,
    export_anim_slide_to_zero=True, export_def_bones=False, export_leaf_bone=False,
    export_reset_pose_bones=True, export_optimize_animation_size=True, export_yup=True,
    export_skins=True, export_influence_nb=4, export_lights=False, export_cameras=False,
    export_texcoords=False, export_normals=True, export_apply=False)
print('EXPORTED', OUT)
