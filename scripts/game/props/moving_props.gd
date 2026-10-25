class_name MovingProp
extends PropBase
## Props with moving collision: the moving truck and the rotating platform.

var mover: AnimatableBody3D
var travel := 12.0
var speed := 5.0
var omega := 1.0
var _t := 0.0
var _x0 := 0.0
var surface_vel := Vector3.ZERO
var wheels: Array = []


func configure(k: String, rng: RandomNumberGenerator) -> MovingProp:
	kind = k
	if k == "truck":
		display_name = "Moving Truck"; half_width = 2.9; top_y = 3.2; sound = "roof_land"
		travel = rng.randf_range(8.0, 14.0); speed = rng.randf_range(3.5, 6.5); exit_vel = Vector2(13, 10)
		interaction_points = 80
	else:
		display_name = "Spinner"; half_width = 2.45; top_y = 3.2; sound = "thud"
		omega = rng.randf_range(0.8, 1.5) * (1.0 if rng.randf() < 0.5 else -1.0); exit_vel = Vector2(11, 12)
	return self


func build() -> void:
	mover = AnimatableBody3D.new()
	mover.sync_to_physics = true
	mover.collision_layer = LAYER_WORLD
	mover.collision_mask = 0
	_tag(mover)
	add_child(mover)
	if kind == "truck":
		model = Assets.prop("truck")
		mover.add_child(model)
		_shape(Vector3(4.1, 2.75, 2.0), Vector3(-0.7, 1.95, 0))
		_shape(Vector3(1.5, 2.0, 2.0), Vector3(2.05, 1.5, 0))
		_shape(Vector3(5.6, 0.5, 2.0), Vector3(-0.5, 0.6, 0))
		for i in 6:
			var w := model.find_child("Wheel%d" % i, true, false)
			if w:
				wheels.append(w)
	else:
		model = Assets.prop("rotating_platform")
		add_child(model)
		var plat := model.find_child("Platform", true, false) as Node3D
		mover.position = Vector3(0, 3.0, 0)
		if plat:
			plat.reparent(mover, false)
			plat.position = Vector3.ZERO
		_shape(Vector3(4.6, 0.34, 2.0), Vector3.ZERO)


func _shape(size: Vector3, center: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = center
	mover.add_child(cs)


func _physics_process(dt: float) -> void:
	_t += dt
	if kind == "truck":
		var w := speed / travel * PI
		var x := travel * 0.5 * (1.0 - cos(_t * w))
		var vx := travel * 0.5 * sin(_t * w) * w
		mover.position.x = x
		surface_vel = Vector3(vx * scale_factor(), 0, 0)
		for wh in wheels:
			(wh as Node3D).rotation.z -= vx * dt / 0.46
	else:
		mover.rotation.z += omega * dt


func surface_normal(p: Vector3) -> Vector3:
	if kind == "truck":
		if p.y > global_position.y + 2.9 * scale_factor():
			return Vector3.UP
		return Vector3.ZERO
	var up := mover.global_transform.basis.y.normalized()
	var local := mover.global_transform.affine_inverse() * p
	if absf(local.x) > 2.15:
		return Vector3.ZERO
	return up if (p - mover.global_position).dot(up) >= 0.0 else -up


func on_hit(_riley: Node, v_in: Vector3, n: Vector3, q: int, p: Vector3) -> Vector3:
	if kind == "truck":
		if n.y < 0.45:
			return Vector3(minf(v_in.x, surface_vel.x) - 2.0, maxf(v_in.y, 2.0), 0.0)
		var out := Landing.bounce(v_in, n, q, 0.5, 8.5, 6.0)
		out.x += surface_vel.x
		return out
	var r := p - mover.global_position
	var vs := Vector3(-omega * r.y, omega * r.x, 0.0)
	var o := Landing.bounce(v_in - vs, n, q, 0.55, 9.0, 7.0) + vs * 0.8
	o.z = 0.0
	return o


func react(_q: int, _p: Vector3) -> void:
	Audio.play(sound)
	if kind == "truck" and randf() < 0.5:
		Audio.play("horn", -4.0)
