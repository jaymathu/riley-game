class_name SpringPad
extends PropBase
## Giant spring: a strong, predictable launch along its tilt direction.

var launch_deg := 65.0
var power := 22.0


func _init() -> void:
	kind = "spring"
	display_name = "Spring"
	half_width = 0.8
	top_y = 1.46
	sound = "sproing"


func configure(deg: float, pwr := 22.0) -> SpringPad:
	launch_deg = deg
	power = pwr
	exit_vel = Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * power
	return self


func build() -> void:
	load_model("spring")
	model.rotation.z = -deg_to_rad(90.0 - launch_deg) * 0.5
	add_box(Vector3(1.35, 1.46, 2.0), Vector3(0, 0.73, 0))


func surface_normal(p: Vector3) -> Vector3:
	if p.y > global_position.y + 1.1 * scale_factor():
		return Vector3.UP
	return Vector3.ZERO


func on_hit(riley: Node, v_in: Vector3, n: Vector3, q: int, _p: Vector3) -> Vector3:
	if n.y < 0.45:
		return Landing.bounce(v_in, n, Landing.MESSY, 0.4, 3.0, 0.0)
	var gw: float = riley.get("world_gravity")
	var mul: float = [1.12, 1.0, 0.72, 0.5][q]
	var speed := maxf(v_in.length() * 0.55, power * pow(gw, 0.3)) * mul
	var a := deg_to_rad(launch_deg)
	return Vector3(cos(a), sin(a), 0.0) * speed


func react(q: int, _p: Vector3) -> void:
	Audio.play(sound, 0.0, 1.1 if q == Landing.PERFECT else 1.0)
	var coil := part("Coil")
	var top := part("Top")
	if coil:
		var tw := create_tween()
		tw.tween_property(coil, "scale:y", 0.35, 0.06)
		tw.tween_property(coil, "scale:y", 1.25, 0.12).set_trans(Tween.TRANS_SINE)
		tw.tween_property(coil, "scale:y", 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if top:
		var y0 := top.position.y
		var tw2 := create_tween()
		tw2.tween_property(top, "position:y", y0 - 0.7, 0.06)
		tw2.tween_property(top, "position:y", y0 + 0.28, 0.12).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(top, "position:y", y0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
