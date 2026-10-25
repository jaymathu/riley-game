class_name PropBase
extends Node3D
## Base for every interactive object. Subclasses build their model + collision in build()
## and decide how Riley leaves the surface in on_hit().

const LAYER_WORLD := 1
const LAYER_TRIGGER := 4

var kind := ""
var display_name := ""
var game: Node = null
var model: Node3D
var half_width := 2.0          # half extent along X (unscaled), used for spacing
var top_y := 1.0               # top landing surface height (unscaled)
var exit_vel := Vector2(12, 14) # typical exit velocity after a good landing (for reach estimates)
var recovery := false          # forgiving surface the generator sprinkles in
var counts_as_landing := true  # false for pass-through effects (fans, boosters)
var interaction_points := 0    # bonus for using environmental objects
var sound := "thud"
var hits := 0


func _ready() -> void:
	build()


func build() -> void:
	pass


func scale_factor() -> float:
	return global_transform.basis.get_scale().x


func reach_estimate(world_gravity: float) -> float:
	var g := Landing.g_eff(world_gravity)
	return exit_vel.x * 2.0 * exit_vel.y / g


## Override: surface normal at a world point, or Vector3.ZERO to use the physics contact normal.
func surface_normal(_p: Vector3) -> Vector3:
	return Vector3.UP


## Override: new velocity for Riley. Runs inside the physics step, so no scene-tree changes here.
func on_hit(_riley: Node, v_in: Vector3, n: Vector3, q: int, _p: Vector3) -> Vector3:
	return Landing.bounce(v_in, n, q, 0.5, 6.0, 6.0)


## Override: visual / audio reaction, called deferred on the main thread after a hit.
func react(_q: int, _p: Vector3) -> void:
	Audio.play(sound)


func is_centered(p: Vector3, frac := 0.35) -> bool:
	return absf(p.x - global_position.x) < half_width * scale_factor() * frac


# ------------------------------------------------------------ helpers
func load_model(model_name: String) -> Node3D:
	model = Assets.prop(model_name)
	add_child(model)
	return model


func part(node_name: String) -> Node3D:
	if model == null:
		return null
	return model.find_child(node_name, true, false) as Node3D


func _tag(body: CollisionObject3D) -> void:
	body.set_meta("prop", self)


func add_box(size: Vector3, center: Vector3, rot_z_deg := 0.0, friction := 0.6, parent: Node3D = null) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = LAYER_WORLD
	b.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = 0.0
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = center
	b.rotation.z = deg_to_rad(rot_z_deg)
	_tag(b)
	(parent if parent else self).add_child(b)
	return b


## Cylinder whose axis points toward the camera (Z), for round props like tires and bumpers.
func add_disc(radius: float, center: Vector3, depth := 2.0, parent: Node3D = null) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = LAYER_WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = depth
	cs.shape = sh
	cs.rotation.x = PI / 2.0
	b.add_child(cs)
	b.position = center
	_tag(b)
	(parent if parent else self).add_child(b)
	return b


## Thin boxes following a 2D polyline (x, y) in local space; builds slides, roofs and ramps.
func add_path(points: Array, thickness := 0.25, friction := 0.2, parent: Node3D = null) -> Array:
	var out := []
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b2: Vector2 = points[i + 1]
		var d := b2 - a
		var mid := (a + b2) * 0.5
		var nrm := Vector2(-d.y, d.x).normalized()
		var c := mid - nrm * thickness * 0.5
		out.append(add_box(Vector3(d.length() + 0.05, thickness, 2.0), Vector3(c.x, c.y, 0), rad_to_deg(d.angle()), friction, parent))
	return out


func add_area_box(size: Vector3, center: Vector3, parent: Node3D = null) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = LAYER_TRIGGER
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	a.position = center
	_tag(a)
	(parent if parent else self).add_child(a)
	return a


func add_area_sphere(radius: float, center: Vector3, parent: Node3D = null) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = LAYER_TRIGGER
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	a.add_child(cs)
	a.position = center
	_tag(a)
	(parent if parent else self).add_child(a)
	return a


## Connect an Area3D so Riley processes it like a surface hit on the next physics step.
func trigger_on_enter(a: Area3D) -> void:
	a.body_entered.connect(_on_trigger_body)


func _on_trigger_body(body: Node3D) -> void:
	if body.has_method("queue_trigger"):
		body.call("queue_trigger", self)


func squash(node: Node3D, amount := 0.25, time := 0.45) -> void:
	if node == null:
		return
	var base := node.scale
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(base.x * (1 + amount * 0.6), base.y * (1 - amount), base.z * (1 + amount * 0.6)), time * 0.18)
	tw.tween_property(node, "scale", Vector3(base.x * (1 - amount * 0.25), base.y * (1 + amount * 0.35), base.z * (1 - amount * 0.25)), time * 0.3)
	tw.tween_property(node, "scale", base, time * 0.52).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func riley_ref() -> Node:
	if game and game.has_method("get_riley"):
		return game.call("get_riley")
	return null
