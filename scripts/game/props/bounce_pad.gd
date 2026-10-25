class_name BouncePad
extends PropBase
## Trampolines, bounce houses, mattresses, cushions, the rubber duck, giant tires,
## floating space platforms and the gadget's emergency mattress.

var restitution := 0.9
var min_out := 12.0
var forward_min := 8.0
var spread_deg := 0.0
var squash_name := "Body"
var squash_amt := 0.25
var radial := false
var radial_center := Vector3.ZERO
var pitch := 1.0
var life := -1.0
var last_centered := false


func configure(k: String) -> BouncePad:
	kind = k
	match k:
		"trampoline":
			display_name = "Trampoline"
			half_width = 1.65; top_y = 0.81; restitution = 1.0; min_out = 16.5; forward_min = 9.0
			squash_name = "Bed"; squash_amt = 0.0; sound = "boing"; recovery = true; exit_vel = Vector2(12, 17)
		"bounce_house":
			display_name = "Bounce House"
			half_width = 2.55; top_y = 1.9; restitution = 0.92; min_out = 13.5; spread_deg = 14.0
			squash_amt = 0.12; sound = "boing"; pitch = 0.75; recovery = true; exit_vel = Vector2(12, 14)
		"mattress", "emergency_mattress":
			display_name = "Mattress"
			half_width = 1.5; top_y = 0.48; restitution = 0.35; min_out = 6.5; forward_min = 7.5
			squash_amt = 0.35; sound = "soft_land"; recovery = true; exit_vel = Vector2(8, 7)
			if k == "emergency_mattress":
				restitution = 0.85; min_out = 14.0; forward_min = 10.0; life = 4.0; recovery = false
		"cushion":
			display_name = "Cushion"
			half_width = 1.6; top_y = 1.05; restitution = 0.62; min_out = 10.0
			squash_amt = 0.3; sound = "soft_land"; pitch = 1.3; recovery = true; exit_vel = Vector2(10, 10)
		"duck":
			display_name = "Rubber Duck"
			half_width = 1.35; top_y = 2.0; restitution = 0.88; min_out = 12.0; spread_deg = 22.0
			squash_amt = 0.18; sound = "squeak"; exit_vel = Vector2(11, 12)
		"tire":
			display_name = "Giant Tire"
			half_width = 1.75; top_y = 3.46; restitution = 0.82; min_out = 11.0; radial = true
			radial_center = Vector3(0, 1.73, 0); squash_amt = 0.1; sound = "boing"; pitch = 0.6; exit_vel = Vector2(11, 12)
		"floating":
			display_name = "Space Pad"
			half_width = 1.75; top_y = 0.05; restitution = 0.95; min_out = 15.0; forward_min = 10.0
			squash_amt = 0.08; sound = "boing"; pitch = 1.35; recovery = true; exit_vel = Vector2(13, 15)
	return self


func build() -> void:
	match kind:
		"trampoline":
			load_model("trampoline")
			add_box(Vector3(3.2, 0.3, 2.0), Vector3(0, 0.66, 0))
		"bounce_house":
			load_model("bounce_house")
			add_box(Vector3(4.5, 1.9, 2.0), Vector3(0, 0.95, 0))
		"mattress":
			load_model("mattress")
			add_box(Vector3(3.0, 0.48, 2.0), Vector3(0, 0.24, 0))
		"emergency_mattress":
			load_model("emergency_mattress")
			add_box(Vector3(3.0, 0.48, 2.0), Vector3(0, 0.24, 0))
			scale = Vector3.ONE * 0.01
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"cushion":
			load_model("cushion")
			add_box(Vector3(3.2, 1.0, 2.0), Vector3(0, 0.5, 0))
		"duck":
			load_model("duck")
			add_box(Vector3(2.3, 1.45, 2.0), Vector3(-0.05, 0.72, 0))
			add_box(Vector3(1.2, 1.1, 2.0), Vector3(0.55, 1.85, 0))
		"tire":
			load_model("tire")
			add_disc(1.73, radial_center, 1.6)
		"floating":
			load_model("floating_platform")
			add_box(Vector3(3.5, 0.5, 2.0), Vector3(0, -0.2, 0))
			add_box(Vector3(2.6, 1.2, 2.0), Vector3(0, -1.05, 0))


func _process(dt: float) -> void:
	if life > 0.0:
		life -= dt
		if life <= 0.0:
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
			tw.tween_callback(queue_free)
	if kind == "floating":
		rotation.z = sin(Time.get_ticks_msec() * 0.0012 + position.x) * 0.03


func surface_normal(p: Vector3) -> Vector3:
	if radial:
		var d := p - global_transform * radial_center
		d.z = 0.0
		return d.normalized() if d.length() > 0.01 else Vector3.UP
	var top := global_position.y + top_y * scale_factor()
	if p.y > top - 0.45 * scale_factor():
		return Vector3.UP
	return Vector3.ZERO


func on_hit(riley: Node, v_in: Vector3, n: Vector3, q: int, p: Vector3) -> Vector3:
	var gw: float = riley.get("world_gravity")
	var soft := pow(gw, 0.3)
	if n.y < 0.45 and not radial:
		return Landing.bounce(v_in, n, Landing.MESSY, 0.45, 4.0, 0.0)
	var nn := n
	if spread_deg > 0.0:
		nn = n.rotated(Vector3.BACK, deg_to_rad(randf_range(-spread_deg, spread_deg) * (0.5 if q == Landing.PERFECT else 1.0)))
	var rest := restitution
	var mo := min_out * soft
	last_centered = false
	if kind == "trampoline" and q == Landing.PERFECT and is_centered(p):
		last_centered = true
		mo *= 1.18
		rest *= 1.08
	return Landing.bounce(v_in, nn, q, rest, mo, forward_min)


func react(q: int, _p: Vector3) -> void:
	Audio.play(sound, 0.0, pitch * (1.1 if q == Landing.PERFECT else 1.0))
	if kind == "trampoline":
		var bed := part("Bed")
		if bed:
			var y0 := bed.position.y
			var tw := create_tween()
			tw.tween_property(bed, "position:y", y0 - 0.32, 0.08)
			tw.tween_property(bed, "position:y", y0 + 0.06, 0.14).set_trans(Tween.TRANS_SINE)
			tw.tween_property(bed, "position:y", y0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			var tw2 := create_tween()
			tw2.tween_property(bed, "scale", Vector3(1.0, 1.0, 1.0) * Vector3(0.96, 3.0, 0.96), 0.08)
			tw2.tween_property(bed, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	elif kind == "duck":
		var body := part("Body")
		if body:
			var tw := create_tween()
			tw.tween_property(body, "rotation:z", randf_range(-0.35, 0.35), 0.12)
			tw.tween_property(body, "rotation:z", 0.0, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		squash(body, squash_amt)
	elif squash_amt > 0.0:
		squash(part(squash_name), squash_amt)
