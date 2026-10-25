class_name PoolProp
extends PropBase
## Inflatable pool: soaks up speed. A clean dive springs Riley back out; anything else is a big slowdown.

var last_result := ""


func _init() -> void:
	kind = "pool"
	display_name = "Pool"
	half_width = 2.15
	top_y = 0.62
	sound = "splash"
	exit_vel = Vector2(9, 12)


func build() -> void:
	load_model("pool")
	add_box(Vector3(0.35, 0.9, 2.0), Vector3(-2.0, 0.45, 0))
	add_box(Vector3(0.35, 0.9, 2.0), Vector3(2.0, 0.45, 0))
	add_box(Vector3(4.2, 0.1, 2.0), Vector3(0, 0.05, 0))
	trigger_on_enter(add_area_box(Vector3(3.6, 0.7, 2.4), Vector3(0, 0.3, 0)))


func surface_normal(_p: Vector3) -> Vector3:
	return Vector3.UP


func on_hit(riley: Node, v_in: Vector3, n: Vector3, q: int, p: Vector3) -> Vector3:
	if p.y < global_position.y + 0.2 * scale_factor() and v_in.y > -2.0:
		return v_in  # already in the water
	if absf(p.x - global_position.x) > 1.85 * scale_factor() and n.y < 0.5:
		return Landing.bounce(v_in, n, Landing.MESSY, 0.4, 3.0, 2.0)
	var body := riley as Node3D
	var up := body.global_transform.basis.y
	var dive := absf(up.dot(v_in.normalized())) > 0.82
	if q == Landing.PERFECT or (dive and q <= Landing.MESSY):
		last_result = "dive"
		return Vector3(maxf(absf(v_in.x) * 0.75, 9.0), 12.0 * pow(float(riley.get("world_gravity")), 0.3), 0.0)
	last_result = "splash"
	return Vector3(v_in.x * 0.28, 3.0, 0.0)


func react(_q: int, _p: Vector3) -> void:
	Audio.play("splash", 0.0, 1.0)
	var w := part("Water")
	if w:
		var tw := create_tween()
		tw.tween_property(w, "position:y", w.position.y - 0.15, 0.1)
		tw.tween_property(w, "position:y", w.position.y, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if game and game.has_method("fx_splash"):
		game.call("fx_splash", global_position + Vector3(0, 0.7 * scale_factor(), 0))
