class_name SpecialProp
extends PropBase
## Seesaw, playground slide, conveyor belt, pinball bumper and the breakable wooden ramp.

const SLIDE_PATH := [Vector2(-1.2, 2.6), Vector2(-0.6, 2.45), Vector2(0.6, 1.55), Vector2(1.8, 0.75),
	Vector2(2.6, 0.55), Vector2(3.2, 0.75), Vector2(3.6, 1.05)]
const RAMP_LEN := 4.0
const RAMP_H := 1.8

var plank: Node3D
var post_height := 4.0
var belt_speed := 9.0
var broken := false
var break_speed := 27.0
var forced_quality := -1
var _kick_used := 0.0


func configure(k: String) -> SpecialProp:
	kind = k
	match k:
		"seesaw":
			display_name = "Seesaw"; half_width = 2.3; top_y = 1.0; sound = "thud"; exit_vel = Vector2(10, 15)
		"slide":
			display_name = "Slide"; half_width = 2.4; top_y = 2.6; sound = "roof_land"; exit_vel = Vector2(13, 8)
			interaction_points = 80
		"conveyor":
			display_name = "Conveyor"; half_width = 3.2; top_y = 1.29; sound = "thud"; exit_vel = Vector2(14, 6)
			interaction_points = 60
		"bumper":
			display_name = "Bumper"; half_width = 0.85; top_y = 0.8; sound = "bumper"; exit_vel = Vector2(14, 14)
			interaction_points = 120
		"ramp":
			display_name = "Ramp"; half_width = 2.1; top_y = RAMP_H; sound = "roof_land"; exit_vel = Vector2(15, 11)
			interaction_points = 60
	return self


func build() -> void:
	match kind:
		"seesaw":
			load_model("seesaw")
			plank = part("Plank")
			var body := add_box(Vector3(4.6, 0.2, 2.0), Vector3(0, 0.1, 0), 0.0, 0.6, plank)
			body.position = Vector3(0, 0.12, 0)
		"slide":
			load_model("slide")
			var pts := []
			for p in SLIDE_PATH:
				pts.append(p + Vector2(0, 0.03))
			add_path(pts, 0.3, 0.02)
			add_box(Vector3(0.9, 0.2, 2.0), Vector3(-1.15, 2.55, 0))
			trigger_on_enter(add_area_box(Vector3(0.9, 1.2, 2.4), Vector3(3.3, 1.2, 0)))
		"conveyor":
			load_model("conveyor")
			var b := add_box(Vector3(6.3, 0.35, 2.0), Vector3(0, 1.12, 0), 0.0, 0.9)
			b.constant_linear_velocity = Vector3(belt_speed, 0, 0)
		"bumper":
			load_model("bumper")
			var post := part("Post")
			if post:
				post.scale.y = maxf(post_height, 1.0)
			add_disc(0.85, Vector3.ZERO, 1.4)
		"ramp":
			load_model("ramp")
			add_path([Vector2(-RAMP_LEN * 0.5 - 0.05, 0.06), Vector2(RAMP_LEN * 0.5, RAMP_H + 0.06)], 0.3, 0.03)
			add_box(Vector3(0.25, RAMP_H, 2.0), Vector3(RAMP_LEN * 0.5 - 0.1, RAMP_H * 0.5, 0))


func _process(dt: float) -> void:
	_kick_used = maxf(0.0, _kick_used - dt)


func surface_normal(p: Vector3) -> Vector3:
	match kind:
		"bumper":
			var d := p - global_position
			d.z = 0.0
			return d.normalized() if d.length() > 0.01 else Vector3.UP
		"seesaw":
			return Vector3.UP
		"conveyor":
			return Vector3.UP if p.y > global_position.y + 1.0 * scale_factor() else Vector3.ZERO
	return Vector3.ZERO


func on_hit(riley: Node, v_in: Vector3, n: Vector3, q: int, p: Vector3) -> Vector3:
	var gw: float = riley.get("world_gravity")
	match kind:
		"seesaw":
			var left := p.x < global_position.x
			var mul: float = [1.1, 1.0, 0.7, 0.45][q]
			if left:
				return Vector3(maxf(v_in.x, 9.0), maxf(-v_in.y * 0.85, 15.0 * pow(gw, 0.3)), 0) * mul
			return Vector3(maxf(v_in.x * 0.8, 6.0), maxf(-v_in.y * 0.45, 8.0), 0) * mul
		"slide":
			if p.x > global_position.x + 3.0 * scale_factor() and n.y < 0.95:
				# the kicker lip at the end of the chute
				if _kick_used > 0.0:
					return v_in
				_kick_used = 1.0
				var sp := maxf(v_in.length(), 10.0) + 7.0
				return Vector3(0.78, 0.62, 0).normalized() * sp
			var t := Vector3(n.y, -n.x, 0.0)
			if t.x < 0.0:
				t = -t
			return t * maxf(v_in.dot(t), 11.0) * float(Landing.TANGENT_KEEP[q]) + n * 0.6
		"conveyor":
			var o := Landing.bounce(v_in, n, q, 0.25, 3.0, 4.0)
			if n.y > 0.5:
				o.x += 8.0
			return o
		"bumper":
			return n * maxf(v_in.length() * 1.05, 19.0)
		"ramp":
			if broken:
				return v_in
			var hard := v_in.length() > break_speed or q >= Landing.MESSY
			if hard and n.y > 0.2:
				broken = true
				call_deferred("_break")
				return v_in * 0.7
			if n.y < 0.3:
				return Vector3(-v_in.x * 0.25, maxf(v_in.y, 1.0), 0)
			var tr := Vector3(n.y, -n.x, 0.0)
			if tr.x < 0.0:
				tr = -tr
			return tr * maxf(v_in.dot(tr), 14.0) * float(Landing.TANGENT_KEEP[q]) + n * 0.5
	return Landing.bounce(v_in, n, q, 0.5, 6.0, 6.0)


func react(q: int, p: Vector3) -> void:
	match kind:
		"seesaw":
			Audio.play("thud", 0.0, 0.8)
			if plank:
				var side := 1.0 if p.x < global_position.x else -1.0
				var tw := create_tween()
				tw.tween_property(plank, "rotation:z", 0.32 * side, 0.08)
				tw.tween_property(plank, "rotation:z", -0.15 * side, 0.25).set_trans(Tween.TRANS_SINE)
				tw.tween_property(plank, "rotation:z", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		"bumper":
			Audio.play("bumper", 0.0, 1.0 + randf() * 0.15)
			squash(part("Head"), -0.25, 0.35)
			if game and game.has_method("fx_burst"):
				game.call("fx_burst", p, Color(1, 0.9, 0.3))
		"slide", "ramp":
			if not broken:
				Audio.play(sound)
		_:
			Audio.play(sound)


func _break() -> void:
	Audio.play("wood_break")
	for i in 8:
		var pl := part("Plank%d" % i)
		if pl == null:
			continue
		var rb := RigidBody3D.new()
		rb.collision_layer = 16
		rb.collision_mask = 1
		rb.mass = 2.0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.55, 0.1, 2.2)
		cs.shape = sh
		rb.add_child(cs)
		var gt := pl.global_transform
		get_parent().add_child(rb)
		rb.global_transform = gt
		pl.reparent(rb, true)
		rb.linear_velocity = Vector3(randf_range(2, 9), randf_range(4, 10), randf_range(-1, 1))
		rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		get_tree().create_timer(4.0).timeout.connect(rb.queue_free)
	for c in get_children():
		if c is StaticBody3D:
			(c as StaticBody3D).collision_layer = 0
	var frame := part("Frame")
	if frame:
		var tw := create_tween()
		tw.tween_property(frame, "rotation:z", -0.35, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
