"""Geometry helpers for procedurally building R.I.L.E.Y. assets in Blender (bpy 4.x/5.x).

All parts are authored directly in world space (Z up, character faces -Y),
then joined into one skinned mesh.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree

V = Vector


# ---------------------------------------------------------------- materials
def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip('#')
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def make_mat(name, hexc, rough=0.5, metal=0.0, emit=0.0, coat=0.0, spec=0.5):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes.get('Principled BSDF')
    col = (*hexcol(hexc), 1.0)
    b.inputs['Base Color'].default_value = col
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    b.inputs['Specular IOR Level'].default_value = spec
    b.inputs['Coat Weight'].default_value = coat
    if emit > 0:
        b.inputs['Emission Color'].default_value = col
        b.inputs['Emission Strength'].default_value = emit
    m.diffuse_color = col
    return m


# ---------------------------------------------------------------- bmesh primitives
def lathe(profile, seg=24, smooth=True):
    """Revolve (r, z) profile (bottom->top) around local Z. r==0 closes a pole."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-7:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg),
                                        r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(seg):
                bm.faces.new((a[0], b[(i + 1) % seg], b[i]))
        elif len(b) == 1:
            for i in range(seg):
                bm.faces.new((a[i], a[(i + 1) % seg], b[0]))
        else:
            for i in range(seg):
                bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    _finish(bm, smooth)
    return bm


def _finish(bm, smooth=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth


def capsule_profile(L, r1, r2, n=6):
    p = []
    for i in range(n + 1):
        a = -math.pi / 2 + (math.pi / 2) * i / n
        p.append((r1 * math.cos(a), r1 * math.sin(a)))
    for i in range(1, n + 1):
        a = (math.pi / 2) * i / n
        p.append((r2 * math.cos(a), L + r2 * math.sin(a)))
    return p


def align_matrix(p1, direction, up_hint=None):
    """Matrix taking local Z to `direction`, translating origin to p1."""
    d = V(direction).normalized()
    q = V((0, 0, 1)).rotation_difference(d)
    return Matrix.Translation(V(p1)) @ q.to_matrix().to_4x4()


def frame_matrix(origin, x, y, z):
    m = Matrix((
        (x[0], y[0], z[0], origin[0]),
        (x[1], y[1], z[1], origin[1]),
        (x[2], y[2], z[2], origin[2]),
        (0, 0, 0, 1)))
    return m


def capsule(p1, p2, r1, r2, seg=16, n=5):
    p1, p2 = V(p1), V(p2)
    L = (p2 - p1).length
    bm = lathe(capsule_profile(L, r1, r2, n), seg)
    bmesh.ops.transform(bm, matrix=align_matrix(p1, p2 - p1), verts=bm.verts)
    return bm


def ellipsoid(center, radii, useg=24, vseg=16, matrix=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    for v in bm.verts:
        v.co = V((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    bmesh.ops.translate(bm, vec=V(center), verts=bm.verts)
    _finish(bm)
    return bm


def superellipsoid(center, half, e=0.4, useg=24, vseg=16, matrix=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    for v in bm.verts:
        c = v.co
        v.co = V(tuple(math.copysign(abs(c[i]) ** e, c[i]) * half[i] for i in range(3)))
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    bmesh.ops.translate(bm, vec=V(center), verts=bm.verts)
    _finish(bm)
    return bm


def sphere_cap(R, theta, seg=24, rings=6):
    """Spherical cap around +Z of sphere radius R, half-angle theta (open edge)."""
    prof = []
    for i in range(rings, -1, -1):
        phi = theta * i / rings
        prof.append((R * math.sin(phi), R * math.cos(phi)))
    return lathe(prof, seg)


def tube(points, radii, closed=False, seg=10, cap=True):
    """Sweep a circle along a polyline. radii: float or list per point."""
    pts = [V(p) for p in points]
    n = len(pts)
    if not hasattr(radii, '__len__'):
        radii = [radii] * n
    bm = bmesh.new()
    tangents = []
    for i in range(n):
        if closed:
            t = pts[(i + 1) % n] - pts[(i - 1) % n]
        else:
            t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        tangents.append(t.normalized())
    # parallel-transport frame
    t0 = tangents[0]
    ref = V((0, 0, 1)) if abs(t0.z) < 0.9 else V((1, 0, 0))
    nrm = t0.cross(ref).normalized()
    rings = []
    for i in range(n):
        t = tangents[i]
        if i > 0:
            q = tangents[i - 1].rotation_difference(t)
            nrm = (q @ nrm)
            nrm = (nrm - t * nrm.dot(t)).normalized()
        b = t.cross(nrm)
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            ring.append(bm.verts.new(pts[i] + (nrm * math.cos(a) + b * math.sin(a)) * radii[i]))
        rings.append(ring)
    pairs = list(zip(rings, rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    for a, b in pairs:
        for k in range(seg):
            bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    if not closed and cap:
        for ring, p in ((rings[0], pts[0]), (rings[-1], pts[-1])):
            c = bm.verts.new(p)
            for k in range(seg):
                bm.faces.new((ring[k], ring[(k + 1) % seg], c))
    _finish(bm)
    return bm


def ring_points(center, axis, radius_a, radius_b=None, n=32, ref=None):
    axis = V(axis).normalized()
    ref = V(ref) if ref else (V((1, 0, 0)) if abs(axis.x) < 0.9 else V((0, 1, 0)))
    u = (ref - axis * ref.dot(axis)).normalized()
    w = axis.cross(u)
    rb = radius_b if radius_b is not None else radius_a
    return [V(center) + u * radius_a * math.cos(2 * math.pi * i / n) + w * rb * math.sin(2 * math.pi * i / n)
            for i in range(n)]


def transform(bm, m):
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


# ---------------------------------------------------------------- projection decals
def bvh_of(bm):
    return BVHTree.FromBMesh(bm)


def project_point(bvh, p, d):
    hit = bvh.ray_cast(V(p) - V(d) * 2.0, V(d))
    return hit  # (loc, normal, index, dist)


def decal(poly, bvh, origin, U, Vv, D, offset=0.003, depth=0.004, cuts=2):
    """Fill a 2D polygon (u,v) in plane (origin,U,V), project along D onto the BVH surface
    and give it a little thickness so it reads cleanly on a curved surface."""
    origin, U, Vv, D = V(origin), V(U), V(Vv), V(D).normalized()
    bm = bmesh.new()
    verts = [bm.verts.new(origin + U * u + Vv * v) for u, v in poly]
    edges = [bm.edges.new((verts[i], verts[(i + 1) % len(verts)])) for i in range(len(verts))]
    bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=edges)
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    bmesh.ops.beautify_fill(bm, faces=bm.faces[:], edges=bm.edges[:])
    for f in bm.faces:
        f.normal_update()
        if f.normal.dot(D) > 0:
            f.normal_flip()
    for v in bm.verts:
        hit = project_point(bvh, v.co, D)
        if hit[0] is None:
            continue
        v.co = hit[0] - hit[1] * depth
    ret = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    newv = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMVert)]
    for v in newv:
        loc, n, i, dd = bvh.find_nearest(v.co)
        if n is not None:
            v.co = v.co + n * (offset + depth)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.dot(D) > 0.5 and
                               all(v not in newv for v in f.verts)], context='FACES_ONLY')
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    return bm


def surface_tube(uv_points, radii, bvh, origin, U, Vv, D, lift=0.004, seg=8):
    """A tube drawn on a surface (brows, closed-eye lines, laces)."""
    origin, U, Vv, D = V(origin), V(U), V(Vv), V(D).normalized()
    pts = []
    for u, v in uv_points:
        hit = project_point(bvh, origin + U * u + Vv * v, D)
        pts.append(hit[0] + hit[1] * lift)
    return tube(pts, radii, seg=seg)


# ---------------------------------------------------------------- objects
def bm_to_obj(name, bm, mat, coll=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    return ob


def weight_obj(ob, fn_or_bone):
    """Assign vertex groups. fn returns dict{bone: w} for a world-space coordinate."""
    groups = {}
    for v in ob.data.vertices:
        if isinstance(fn_or_bone, str):
            w = {fn_or_bone: 1.0}
        else:
            w = fn_or_bone(v.co)
        tot = sum(w.values()) or 1.0
        for b, x in w.items():
            if x <= 1e-4:
                continue
            g = groups.get(b) or ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
            groups[b] = g
            g.add([v.index], x / tot, 'REPLACE')


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def blend2(b0, b1, e0, e1, x):
    t = smoothstep(e0, e1, x)
    return {b0: 1 - t, b1: t}
