"""Contact sheet of prop .glb files: python render_contact.py <props_dir> <out_png_dir>"""
import sys, os, math, glob
import bpy
from mathutils import Vector as V

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
files = sorted(glob.glob(os.path.join(src, '*.glb')))
only = sys.argv[3].split(',') if len(sys.argv) > 3 else None
for f in files:
    name = os.path.basename(f)[:-4]
    if only and name not in only:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 12
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x = sc.render.resolution_y = 320
    sc.render.film_transparent = os.environ.get('TRANSPARENT') == '1'
    w = bpy.data.worlds.new('w'); sc.world = w
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.55, 0.75, 0.95, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8
    bpy.ops.import_scene.gltf(filepath=f)
    meshes = [o for o in sc.objects if o.type == 'MESH']
    pts = [o.matrix_world @ V(c) for o in meshes for c in o.bound_box]
    lo = V((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = V((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2
    r = max((hi - lo).length / 2, 0.3)
    L = bpy.data.lights.new('sun', 'SUN'); L.energy = 3.5
    lo_ = bpy.data.objects.new('sun', L); sc.collection.objects.link(lo_)
    lo_.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    cd = bpy.data.cameras.new('c'); cam = bpy.data.objects.new('c', cd); sc.collection.objects.link(cam); sc.camera = cam
    cd.lens = 50
    d = r / math.tan(math.radians(18)) * 1.05
    # glTF import is Y-up converted back to Blender Z-up; camera from -Y, slightly above and to the left
    pos = c + V((-0.35, -1.0, 0.35)).normalized() * d
    cam.location = pos
    cam.rotation_euler = (c - pos).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, name + '.png')
    bpy.ops.render.render(write_still=True)
    print('RENDERED', name)
