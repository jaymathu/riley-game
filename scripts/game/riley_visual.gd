class_name RileyVisual
extends Node3D
## Riley's animated model: clip playback, face swaps, cosmetics, bone-following attachments
## and the articulated ragdoll (PhysicalBoneSimulator3D) used for crashes.

const FACE_YAW := 50.0
const LOOPS := ["idle", "launch_prep", "airborne", "tuck", "tumble_forward", "tumble_backward", "panic_flail",
	"landing_prep", "victory"]
const EYES := ["eyes_open", "eyes_wide", "eyes_closed", "eyes_happy", "eyes_dizzy"]
const MOUTHS := ["mouth_grin", "mouth_laugh", "mouth_o", "mouth_grimace"]
## bone -> [child bone used for length/direction, capsule radius, mass, swing limit]
const RAGDOLL := {
	"hips": ["spine", 0.15, 5.0, 0.0], "spine": ["chest", 0.14, 4.0, 25.0], "chest": ["neck", 0.15, 4.0, 25.0],
	"head": ["", 0.2, 3.5, 35.0], "upper_arm.L": ["forearm.L", 0.05, 1.0, 85.0], "forearm.L": ["hand.L", 0.045, 0.8, 70.0],
	"upper_arm.R": ["forearm.R", 0.05, 1.0, 85.0], "forearm.R": ["hand.R", 0.045, 0.8, 70.0],
	"thigh.L": ["shin.L", 0.06, 2.0, 60.0], "shin.L": ["foot.L", 0.05, 1.5, 70.0],
	"thigh.R": ["shin.R", 0.06, 2.0, 60.0], "shin.R": ["foot.R", 0.05, 1.5, 70.0],
}

var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var current := ""
var sim: Node3D
var phys_bones := {}
var ragdolling := false
var followers: Array = []   # {node, bone_idx, up, side}
var hat: Node3D
var trail: CPUParticles3D


func _ready() -> void:
	model = Assets.riley_scene.instantiate() as Node3D
	add_child(model)
	model.position = Vector3(0, -0.65, 0)
	model.rotation.y = deg_to_rad(FACE_YAW)
	var sk := model.find_children("*", "Skeleton3D", true, false)
	if sk.size() > 0:
		skel = sk[0] as Skeleton3D
	var ap := model.find_children("*", "AnimationPlayer", true, false)
	if ap.size() > 0:
		anim = ap[0] as AnimationPlayer
		for n in LOOPS:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	play("idle", 0.0)


## Bone index tolerant of importers that swap '.' for '_' in bone names.
func bone_idx(bone: String) -> int:
	if skel == null:
		return -1
	var idx := skel.find_bone(bone)
	if idx < 0:
		idx = skel.find_bone(bone.replace(".", "_"))
	return idx


func play(clip: String, blend := 0.15, speed := 1.0) -> void:
	if anim == null or ragdolling:
		return
	if clip == current and anim.is_playing():
		return
	if not anim.has_animation(clip):
		return
	current = clip
	anim.play(clip, blend, speed)


func play_once(clip: String, blend := 0.1) -> void:
	current = ""
	play(clip, blend)


# ------------------------------------------------------------ cosmetics
func apply_loadout() -> void:
	var shirt := Catalog.cosmetic_def("shirt", Save.cosmetic("shirt"))
	if not shirt.is_empty():
		Assets.recolor(model, "Shirt", Color(String(shirt["color"])))
		Assets.recolor(model, "ShirtCollar", Color(String(shirt["color"])).darkened(0.2))
	var shoes := Catalog.cosmetic_def("shoes", Save.cosmetic("shoes"))
	if not shoes.is_empty():
		Assets.recolor(model, "ShoeMain", Color(String(shoes["color"])))
	var gog := Catalog.cosmetic_def("goggles", Save.cosmetic("goggles"))
	if not gog.is_empty():
		Assets.recolor(model, "GoggleLens", Color(String(gog["color"])))
	if hat:
		_remove_follower(hat)
		hat.queue_free()
		hat = null
	var h := Catalog.cosmetic_def("hat", Save.cosmetic("hat"))
	if not h.is_empty() and String(h["scene"]) != "":
		hat = Assets.prop(String(h["scene"]))
		add_child(hat)
		follow(hat, "head", 0.38)
	var tr := Catalog.cosmetic_def("trail", Save.cosmetic("trail"))
	_setup_trail(tr.get("colors", []) if not tr.is_empty() else [])


func _setup_trail(colors: Array) -> void:
	if trail:
		trail.queue_free()
		trail = null
	if colors.is_empty():
		return
	trail = CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.material = m
	trail.mesh = s
	trail.amount = 40
	trail.lifetime = 0.7
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.4
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / maxf(1.0, colors.size() - 1))
		cols.append(Color(String(colors[i])))
	if colors.size() == 1:
		offs.append(1.0)
		cols.append(Color(String(colors[0])))
	var g := Gradient.new()
	g.offsets = offs
	g.colors = cols
	trail.color_initial_ramp = g
	trail.emitting = false
	add_child(trail)


func set_trail(on: bool) -> void:
	if trail:
		trail.emitting = on


# ------------------------------------------------------------ attachments
func follow(node: Node3D, bone: String, up := 0.0, side := Vector3.ZERO) -> void:
	if skel == null:
		return
	var idx := bone_idx(bone)
	if idx < 0:
		return
	node.top_level = true
	followers.append({"node": node, "bone": idx, "up": up, "side": side})


func _remove_follower(node: Node3D) -> void:
	for i in range(followers.size() - 1, -1, -1):
		if followers[i]["node"] == node:
			followers.remove_at(i)


func unfollow(node: Node3D) -> void:
	_remove_follower(node)


func bone_global(bone: String) -> Transform3D:
	if skel == null:
		return global_transform
	var idx := bone_idx(bone)
	if idx < 0:
		return global_transform
	return skel.global_transform * skel.get_bone_global_pose(idx)


func _process(_dt: float) -> void:
	if skel == null:
		return
	var fwd := model.global_transform.basis.z.normalized()
	for f in followers:
		var node: Node3D = f["node"]
		if not is_instance_valid(node):
			continue
		var pose: Transform3D = skel.global_transform * skel.get_bone_global_pose(int(f["bone"]))
		var y := pose.basis.y.normalized()
		var z := (fwd - y * fwd.dot(y))
		if z.length() < 0.01:
			z = Vector3.BACK
		z = z.normalized()
		var x := y.cross(z).normalized()
		node.global_transform = Transform3D(Basis(x, y, z), pose.origin + y * float(f["up"]) + pose.basis * (f["side"] as Vector3))


# ------------------------------------------------------------ face (for when no clip drives it)
func set_face(mouth: String, eyes: String) -> void:
	if skel == null:
		return
	for n in EYES + MOUTHS:
		var idx := bone_idx(n)
		if idx >= 0:
			var on: bool = (n == "eyes_" + eyes) or (n == "mouth_" + mouth)
			skel.set_bone_pose_scale(idx, Vector3.ONE if on else Vector3.ONE * 0.001)


# ------------------------------------------------------------ ragdoll
func _build_ragdoll() -> bool:
	if skel == null or not ClassDB.class_exists("PhysicalBoneSimulator3D"):
		return false
	sim = ClassDB.instantiate("PhysicalBoneSimulator3D") as Node3D
	sim.name = "Ragdoll"
	skel.add_child(sim)
	for bone_name in RAGDOLL.keys():
		var idx := bone_idx(bone_name)
		if idx < 0:
			continue
		var cfg: Array = RAGDOLL[bone_name]
		var child_name: String = cfg[0]
		var child_vec := Vector3(0, 0.3, 0)
		if child_name != "":
			var ci := bone_idx(child_name)
			if ci >= 0:
				child_vec = skel.get_bone_rest(ci).origin
		var half := child_vec.length() * 0.5
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name.replace(".", "_")
		pb.bone_name = skel.get_bone_name(idx)
		pb.mass = float(cfg[2])
		pb.friction = 0.8
		pb.bounce = 0.15
		pb.linear_damp = 0.15
		pb.angular_damp = 2.5
		pb.collision_layer = 8
		pb.collision_mask = 1
		var up := Vector3.UP
		if up.cross(child_vec).is_zero_approx():
			up = Vector3.BACK
		var body_t := Transform3D()
		body_t.basis = Basis.looking_at(child_vec, up)
		body_t.origin = body_t.basis * Vector3(0, 0, -half)
		pb.body_offset = body_t
		var joint_t := Transform3D()
		joint_t.origin = Vector3(0, 0, half)
		pb.joint_offset = joint_t
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		var radius: float = cfg[1]
		cap.radius = radius
		cap.height = maxf(half * 2.0, radius * 2.0 + 0.01)
		cs.shape = cap
		cs.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3.ZERO)
		pb.add_child(cs)
		sim.add_child(pb)
		var swing: float = cfg[3]
		if swing <= 0.0:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", swing)
			pb.set("joint_constraints/twist_span", 25.0)
			pb.set("joint_constraints/softness", 0.8)
			pb.set("joint_constraints/relaxation", 1.0)
		phys_bones[bone_name] = pb
	return true


func start_ragdoll(vel: Vector3, ang_z: float) -> bool:
	if ragdolling:
		return true
	if sim == null and not _build_ragdoll():
		play_once("crash")
		return false
	ragdolling = true
	if anim:
		anim.stop(true)
	set_face("o", "dizzy")
	for bone_name in phys_bones.keys():
		var pb: PhysicalBone3D = phys_bones[bone_name]
		var idx := bone_idx(bone_name)
		pb.global_transform = skel.global_transform * skel.get_bone_global_pose(idx) * pb.body_offset
	if sim.has_method("set"):
		sim.set("active", true)
	sim.call("physical_bones_start_simulation")
	for bone_name in phys_bones.keys():
		var pb: PhysicalBone3D = phys_bones[bone_name]
		pb.linear_velocity = vel + Vector3(randf_range(-0.6, 0.6), randf_range(0, 1.0), 0)
		pb.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), ang_z)
	return true


func stop_ragdoll() -> void:
	if not ragdolling or sim == null:
		return
	sim.call("physical_bones_stop_simulation")
	ragdolling = false


func ragdoll_center() -> Vector3:
	if ragdolling and phys_bones.has("hips"):
		return (phys_bones["hips"] as Node3D).global_position
	return global_position


func ragdoll_velocity() -> Vector3:
	if ragdolling and phys_bones.has("hips"):
		return (phys_bones["hips"] as PhysicalBone3D).linear_velocity
	return Vector3.ZERO
