# Executed inside build_riley.py (needs `rig`). Authors Riley's animation clips.
# Rotations are given in degrees about armature axes (X = pitch, +X leans forward /
# swings a hanging limb backward; Y = roll, -Y raises a left arm sideways; Z = yaw).
# '.R' / '*' entries use the same numbers as the left side and are mirrored here.
import math
from mathutils import Euler, Quaternion, Vector
from bpy_extras import anim_utils

pbs = rig.pose.bones
BODY = ['hips', 'spine', 'chest', 'neck', 'head',
        'upper_arm.L', 'forearm.L', 'hand.L', 'upper_arm.R', 'forearm.R', 'hand.R',
        'thigh.L', 'shin.L', 'foot.L', 'thigh.R', 'shin.R', 'foot.R', 'brow.L', 'brow.R']
EYES = ['eyes_open', 'eyes_wide', 'eyes_closed', 'eyes_happy', 'eyes_dizzy']
MOUTHS = ['mouth_grin', 'mouth_laugh', 'mouth_o', 'mouth_grimace']
for pb in pbs:
    pb.rotation_mode = 'QUATERNION'
pbs['hips'].rotation_mode = 'XYZ'
REST = {n: rig.data.bones[n].matrix_local.to_3x3() for n in BODY}
TL = (rig.data.bones['thigh.L'].head_local - rig.data.bones['thigh.L'].tail_local).length
SL = (rig.data.bones['shin.L'].head_local - rig.data.bones['shin.L'].tail_local).length


def crouch(t_abs, s_abs, lean=0.0, extra=None):
    """Leg angles (absolute pitch) -> relative bone rotations + hip drop to keep feet planted."""
    drop = (TL + SL) - (TL * math.cos(math.radians(t_abs)) + SL * math.cos(math.radians(s_abs)))
    p = {'hips': ((lean, 0, 0), (0, 0, -drop)),
         'thigh*': (t_abs - lean, 0, 3), 'shin*': (s_abs - t_abs, 0, 0), 'foot*': (-s_abs, 0, 0)}
    if extra:
        p.update(extra)
    return p


def merge(*ds):
    out = {}
    for d in ds:
        out.update(d)
    return out


def expand(p):
    out = {}
    for k, v in p.items():
        if k.endswith('*'):
            out[k[:-1] + '.L'] = v
            out[k[:-1] + '.R'] = v
        else:
            out[k] = v
    return out


_prev = {}


def set_key(frame, pose, face=('grin', 'open'), brows=(0, 0)):
    p = expand(pose)
    if len(brows) == 2:
        brows = (brows[0], brows[1], brows[0], brows[1])
    p['brow.L'] = ((0, brows[1], 0), (0, 0, brows[0]))
    p['brow.R'] = ((0, brows[3], 0), (0, 0, brows[2]))
    for n in BODY:
        v = p.get(n, (0, 0, 0))
        r, l = (v[0], v[1]) if isinstance(v[0], (tuple, list)) else (v, (0, 0, 0))
        if n.endswith('.R'):
            r, l = (r[0], -r[1], -r[2]), (-l[0], l[1], l[2])
        Bm = REST[n]
        Rw = Euler([math.radians(a) for a in r], 'XYZ').to_matrix()
        q = (Bm.inverted() @ Rw @ Bm).to_quaternion()
        pb = pbs[n]
        pb.location = Bm.inverted() @ Vector(l)
        if pb.rotation_mode == 'XYZ':
            e = q.to_euler('XYZ', _prev.get(n)) if n in _prev else q.to_euler('XYZ')
            _prev[n] = e.copy()
            pb.rotation_euler = e
            pb.keyframe_insert('rotation_euler', frame=frame, group=n)
        else:
            if n in _prev and q.dot(_prev[n]) < 0:
                q.negate()
            _prev[n] = q.copy()
            pb.rotation_quaternion = q
            pb.keyframe_insert('rotation_quaternion', frame=frame, group=n)
        pb.keyframe_insert('location', frame=frame, group=n)
    mouth, eyes = face
    for n in EYES + MOUTHS:
        on = n == 'eyes_' + eyes or n == 'mouth_' + mouth
        pbs[n].scale = (1, 1, 1) if on else (0.001, 0.001, 0.001)
        pbs[n].keyframe_insert('scale', frame=frame, group=n)


def make_action(name, keys, linear_hips=False):
    _prev.clear()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for k in keys:
        set_key(*k)
    cb = anim_utils.action_get_channelbag_for_slot(act, rig.animation_data.action_slot)
    for fc in cb.fcurves:
        swap = any('"%s"' % n in fc.data_path for n in EYES + MOUTHS) and fc.data_path.endswith('scale')
        for kp in fc.keyframe_points:
            if swap:
                kp.interpolation = 'CONSTANT'
            elif linear_hips and '"hips"' in fc.data_path and 'rotation' in fc.data_path:
                kp.interpolation = 'LINEAR'
    return act


# ---------------------------------------------------------------- pose library
ARMS_REST = {'upper_arm*': (4, 24, 0), 'forearm*': (-14, 0, 0)}
IDLE_A = merge(ARMS_REST, {'spine': (-1, 0, 0), 'chest': (1, 0, 0), 'head': (2, 5, -3)})
IDLE_B = merge({'upper_arm*': (2, 21, 0), 'forearm*': (-17, 0, 0)},
               {'hips': ((0, 0, 0), (0, 0, 0.004)), 'chest': (-3, 0, 0), 'head': (0, 3, 3)})
MISCHIEF = (0.007, -5, 0.0, 4)

PREP = crouch(-50, 30, 8, {'spine': (10, 0, 0), 'chest': (5, 0, 0), 'neck': (-8, 0, 0), 'head': (-14, 0, 0),
                           'upper_arm*': (-35, 20, 0), 'forearm*': (-95, 0, -10)})
PREP_L = merge(PREP, {'upper_arm.L': (-85, 8, 0), 'forearm.L': (-70, 0, -10), 'head': (-17, 0, 5),
                      'hips': ((8, 0, 0), (0, 0, PREP['hips'][1][2] + 0.015))})
PREP_R = merge(PREP, {'upper_arm.R': (-85, 8, 0), 'forearm.R': (-70, 0, -10), 'head': (-17, 0, -5),
                      'hips': ((8, 0, 0), (0, 0, PREP['hips'][1][2] + 0.015))})

STRETCH = {'hips': ((-8, 0, 0), (0, 0, 0.02)), 'spine': (-8, 0, 0), 'chest': (-6, 0, 0), 'head': (-12, 0, 0),
           'upper_arm*': (0, -122, 0), 'forearm*': (-8, 0, 0), 'thigh*': (6, 0, 2), 'shin*': (6, 0, 0), 'foot*': (48, 0, 0)}

AIR_A = {'hips': (-6, 0, 0), 'spine': (-8, 0, 0), 'chest': (-4, 0, 0), 'head': (-10, 0, 0),
         'upper_arm*': (-15, -62, 0), 'forearm*': (-25, 0, 0),
         'thigh.L': (-38, 0, 6), 'shin.L': (62, 0, 0), 'foot.L': (12, 0, 0),
         'thigh.R': (-6, 0, 4), 'shin.R': (26, 0, 0), 'foot.R': (22, 0, 0)}
AIR_B = merge(AIR_A, {'upper_arm*': (-12, -76, 0), 'forearm*': (-35, 0, 0), 'thigh.L': (-26, 0, 6),
                      'thigh.R': (-14, 0, 4), 'head': (-7, 0, 0), 'spine': (-10, 0, 0)})

TUCK = {'spine': (30, 0, 0), 'chest': (15, 0, 0), 'neck': (10, 0, 0), 'head': (4, 0, 0),
        'thigh*': (-115, 0, 6), 'shin*': (135, 0, 0), 'foot*': (30, 0, 0),
        'upper_arm*': (-60, 18, 0), 'forearm*': (-65, 0, -35)}
TUCK_B = merge(TUCK, {'spine': (34, 0, 0), 'thigh*': (-120, 0, 6)})

FLAIL = [
    {'spine': (-10, 0, 0), 'chest': (0, 0, 8), 'head': (-10, 0, 0),
     'upper_arm.L': (-20, -110, 0), 'upper_arm.R': (-20, -25, 0), 'forearm.L': (-40, 0, 0), 'forearm.R': (-60, 0, 0),
     'thigh.L': (-60, 0, 5), 'shin.L': (90, 0, 0), 'thigh.R': (-10, 0, 5), 'shin.R': (30, 0, 0), 'foot*': (20, 0, 0)},
    {'spine': (-12, 0, 0), 'chest': (0, 0, 0), 'head': (-12, 0, 0),
     'upper_arm*': (-75, -55, 0), 'forearm*': (-30, 0, 0),
     'thigh*': (-35, 0, 5), 'shin*': (60, 0, 0), 'foot*': (20, 0, 0)},
    {'spine': (-10, 0, 0), 'chest': (0, 0, -8), 'head': (-10, 0, 0),
     'upper_arm.R': (-20, -110, 0), 'upper_arm.L': (-20, -25, 0), 'forearm.R': (-40, 0, 0), 'forearm.L': (-60, 0, 0),
     'thigh.R': (-60, 0, 5), 'shin.R': (90, 0, 0), 'thigh.L': (-10, 0, 5), 'shin.L': (30, 0, 0), 'foot*': (20, 0, 0)},
    {'spine': (-8, 0, 0), 'chest': (0, 0, 0), 'head': (-8, 0, 0),
     'upper_arm*': (35, -70, 0), 'forearm*': (-50, 0, 0),
     'thigh*': (-35, 0, 5), 'shin*': (60, 0, 0), 'foot*': (20, 0, 0)},
]

LPREP = merge(crouch(-45, 15, 5), {'hips': ((5, 0, 0), (0, 0, 0)), 'spine': (6, 0, 0), 'head': (-12, 0, 0),
                                   'upper_arm*': (-45, -45, 0), 'forearm*': (-20, 0, 0)})
LPREP_B = merge(LPREP, {'upper_arm*': (-50, -38, 0), 'thigh*': (-45, 0, 3)})
STAND = merge(ARMS_REST, {})
ARMS_V = {'upper_arm*': (-8, -122, 0), 'forearm*': (-22, 0, 0)}

LIE = {'hips': ((-90, 0, 0), (0, 0, -0.38)), 'neck': (15, 0, 0), 'head': (25, 0, 0),
       'upper_arm*': (0, -80, 0), 'forearm*': (-20, 0, 0),
       'thigh*': (-50, -20, 0), 'shin*': (40, 0, 0), 'foot*': (10, 0, 0)}

# ---------------------------------------------------------------- clips
make_action('idle', [
    (0, IDLE_A, ('grin', 'open'), MISCHIEF), (30, IDLE_B, ('grin', 'open'), (0.009, -6, 0.0, 4)),
    (47, merge(IDLE_B, {'head': (1, 4, 1)}), ('grin', 'open'), MISCHIEF),
    (48, merge(IDLE_B, {'head': (1, 4, 1)}), ('grin', 'closed'), MISCHIEF),
    (51, merge(IDLE_A, {'head': (1, 5, -1)}), ('grin', 'open'), MISCHIEF),
    (60, IDLE_A, ('grin', 'open'), MISCHIEF)])

make_action('launch_prep', [
    (0, PREP, ('laugh', 'open'), (0.009, -6)), (6, PREP_L, ('laugh', 'open'), (0.012, -6)),
    (12, PREP, ('laugh', 'open'), (0.009, -6)), (18, PREP_R, ('laugh', 'open'), (0.012, -6)),
    (24, PREP, ('laugh', 'open'), (0.009, -6))])

make_action('launch', [
    (0, PREP, ('grin', 'open'), (0.01, -6)), (3, STRETCH, ('o', 'wide'), (0.016, 0)),
    (10, merge(STRETCH, {'upper_arm*': (-6, -128, 0)}), ('o', 'wide'), (0.016, 0)),
    (24, AIR_A, ('laugh', 'open'), (0.01, -3))])

make_action('airborne', [
    (0, AIR_A, ('grin', 'open'), (0.008, -3)), (20, AIR_B, ('grin', 'open'), (0.010, -4)),
    (30, AIR_A, ('grin', 'open'), (0.008, -3)), (31, AIR_A, ('grin', 'closed'), (0.008, -3)),
    (33, AIR_A, ('grin', 'open'), (0.008, -3)), (40, AIR_A, ('grin', 'open'), (0.008, -3))])

make_action('tuck', [(0, TUCK, ('grimace', 'closed'), (-0.004, -10)), (15, TUCK_B, ('grimace', 'closed'), (-0.004, -12)),
                     (30, TUCK, ('grimace', 'closed'), (-0.004, -10))])

for name, sgn in (('tumble_forward', 1), ('tumble_backward', -1)):
    keys = []
    for i, f in enumerate((0, 8, 15, 23, 30)):
        p = merge(TUCK, {'hips': ((sgn * 90 * i, 0, 0), (0, 0, 0))})
        keys.append((f, p, ('grimace', 'closed') if i % 2 == 0 else ('o', 'wide'), (-0.002, -8)))
    make_action(name, keys, linear_hips=True)

make_action('panic_flail', [(0, FLAIL[0], ('o', 'wide'), (0.013, 12)), (4, FLAIL[1], ('o', 'wide'), (0.013, 12)),
                            (8, FLAIL[2], ('o', 'wide'), (0.013, 12)), (12, FLAIL[3], ('o', 'wide'), (0.013, 12)),
                            (16, FLAIL[0], ('o', 'wide'), (0.013, 12))])

make_action('landing_prep', [(0, LPREP, ('grin', 'open'), (-0.003, -9)), (10, LPREP_B, ('grin', 'open'), (-0.002, -9)),
                             (20, LPREP, ('grin', 'open'), (-0.003, -9))])

IMPACT = crouch(-70, 45, 14, {'spine': (12, 0, 0), 'head': (-22, 0, 0), 'upper_arm*': (-40, -30, 0), 'forearm*': (-30, 0, 0)})
make_action('land_perfect', [
    (0, LPREP, ('grin', 'open'), (-0.003, -9)), (4, IMPACT, ('grimace', 'closed'), (-0.004, -10)),
    (12, crouch(-30, 15, 4, {'upper_arm*': (-30, -80, 0), 'forearm*': (-20, 0, 0)}), ('laugh', 'happy'), (0.012, 0)),
    (18, merge({'hips': ((-4, 0, 0), (0, 0, 0.07)), 'thigh*': (-12, 0, 3), 'shin*': (22, 0, 0), 'foot*': (30, 0, 0),
                'head': (-12, 0, 0), 'spine': (-6, 0, 0)}, ARMS_V), ('laugh', 'happy'), (0.014, 0)),
    (26, merge(crouch(-25, 12, 3), ARMS_V), ('laugh', 'happy'), (0.012, 0)),
    (34, merge({'head': (-6, 0, 0), 'chest': (-4, 0, 0)}, ARMS_V), ('laugh', 'happy'), (0.012, 0)),
    (42, merge({'head': (-6, 4, 0), 'chest': (-4, 0, 0)}, {'upper_arm*': (-8, -118, 0), 'forearm*': (-40, 0, 0)}), ('laugh', 'happy'), (0.012, 0)),
    (50, merge({'head': (-6, 0, 0), 'chest': (-4, 0, 0)}, ARMS_V), ('laugh', 'happy'), (0.012, 0))])

make_action('land_awkward', [
    (0, LPREP, ('grin', 'open'), (-0.003, -9)),
    (4, {'hips': ((10, 12, 10), (0.02, 0, -0.08)), 'spine': (5, -10, 0), 'chest': (0, -10, 8),
         'thigh.L': (-70, 0, -5), 'shin.L': (100, 0, 0), 'foot.L': (-35, 0, 0),
         'thigh.R': (-25, 0, 10), 'shin.R': (20, 0, 0), 'foot.R': (5, 0, 0),
         'upper_arm.L': (-30, -120, 0), 'upper_arm.R': (-10, -70, 0), 'forearm.L': (-30, 0, 0), 'forearm.R': (-60, 0, 0)},
     ('o', 'wide'), (0.012, 12)),
    (12, {'hips': ((5, -10, -8), (-0.02, 0, -0.06)), 'spine': (5, 10, 0), 'chest': (0, 8, -8),
          'thigh.L': (-40, 0, 3), 'shin.L': (60, 0, 0), 'foot.L': (-20, 0, 0),
          'thigh.R': (-60, 0, 3), 'shin.R': (90, 0, 0), 'foot.R': (-25, 0, 0),
          'upper_arm.R': (-30, -120, 0), 'upper_arm.L': (-10, -70, 0), 'forearm.R': (-30, 0, 0), 'forearm.L': (-60, 0, 0)},
     ('grimace', 'wide'), (0.012, 12)),
    (20, merge(crouch(-35, 20, 5), {'hips': ((5, 6, 5), (0, 0, -0.05)), 'upper_arm.L': (-30, -90, 0), 'upper_arm.R': (-20, -100, 0)}),
     ('grimace', 'open'), (0.008, 8)),
    (30, merge(crouch(-30, 20, 5), {'upper_arm*': (-20, -60, 0), 'forearm*': (-20, 0, 0)}), ('grimace', 'closed'), (0.004, 6)),
    (42, merge(STAND, {'head': (0, 8, 0), 'upper_arm.R': (-40, -105, 0), 'forearm.R': (-110, 0, -40)}), ('grin', 'open'), (0.010, 10)),
    (50, merge(STAND, {'head': (0, 8, 0), 'upper_arm.R': (-40, -105, 0), 'forearm.R': (-115, 0, -40)}), ('grin', 'open'), (0.010, 10))])

LIE_B = merge(LIE, {'hips': ((-80, 0, 0), (0, 0, -0.30)), 'thigh*': (-70, -25, 0)})
make_action('crash', [
    (0, merge(FLAIL[0], {'hips': ((0, 0, 0), (0, 0, 0.10))}), ('o', 'wide'), (0.013, 12)),
    (6, LIE, ('o', 'dizzy'), (0.012, 12)), (10, LIE_B, ('o', 'dizzy'), (0.012, 12)),
    (15, LIE, ('grimace', 'dizzy'), (0.012, 12)),
    (25, merge(LIE, {'head': (25, 0, 15)}), ('grimace', 'dizzy'), (0.010, 12)),
    (32, merge(LIE, {'thigh.L': (-58, -20, 0), 'shin.L': (60, 0, 0)}), ('o', 'dizzy'), (0.010, 12)),
    (40, merge(LIE, {'head': (25, 0, -15), 'thigh.R': (-58, -20, 0), 'shin.R': (60, 0, 0)}), ('o', 'dizzy'), (0.010, 12)),
    (50, merge(LIE, {'head': (25, 0, 12)}), ('grimace', 'dizzy'), (0.010, 12)),
    (60, LIE, ('grimace', 'dizzy'), (0.010, 12))])

V_CR = crouch(-30, 20, 5, {'upper_arm*': (-30, 10, 0), 'forearm*': (-100, 0, -20), 'head': (-4, 0, 0)})
V_JL = {'hips': ((0, 0, 0), (0, 0, 0.10)), 'thigh*': (-40, 0, 3), 'shin*': (70, 0, 0), 'foot*': (20, 0, 0),
        'upper_arm.L': (-10, -130, 0), 'forearm.L': (-15, 0, 0), 'upper_arm.R': (-30, 10, 0), 'forearm.R': (-100, 0, -20),
        'head': (-10, 0, 6), 'chest': (-4, 0, 0)}
V_JR = merge(V_JL, {'upper_arm.R': (-10, -130, 0), 'forearm.R': (-15, 0, 0), 'upper_arm.L': (-30, 10, 0),
                    'forearm.L': (-100, 0, -20), 'head': (-10, 0, -6)})
make_action('victory', [(0, V_CR, ('laugh', 'happy'), (0.012, 0)), (8, V_JL, ('laugh', 'happy'), (0.014, 0)),
                        (16, V_CR, ('laugh', 'happy'), (0.012, 0)), (24, V_JR, ('laugh', 'happy'), (0.014, 0)),
                        (32, V_CR, ('laugh', 'happy'), (0.012, 0))])

rig.animation_data.action = bpy.data.actions['idle']
scene.frame_set(0)
print('ACTIONS', [a.name for a in bpy.data.actions])
