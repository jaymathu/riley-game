class_name DishProp
extends PropBase
## Satellite dish: redirects Riley along the way the dish faces.

var aim_deg := 55.0


func _init() -> void:
	kind = "dish"
	display_name = "Satellite Dish"
	half_width = 1.3
	top_y = 3.4
	counts_as_landing = false
	interaction_points = 150
	sound = "bumper"


func configure(deg: float) -> DishProp:
	aim_deg = deg
	exit_vel = Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * 20.0
	return self


func build() -> void:
	load_model("satellite_dish")
	var dish := part("Dish")
	if dish:
		dish.rotation.z = deg_to_rad(aim_deg)
	add_box(Vector3(0.2, 2.2, 1.0), Vector3(0, 1.1, 0))
	trigger_on_enter(add_area_sphere(1.35, Vector3(0.25, 2.3, 0)))


func surface_normal(_p: Vector3) -> Vector3:
	var a := deg_to_rad(aim_deg)
	return Vector3(cos(a), sin(a), 0)


func on_hit(_riley: Node, v_in: Vector3, _n: Vector3, _q: int, _p: Vector3) -> Vector3:
	var a := deg_to_rad(aim_deg)
	return Vector3(cos(a), sin(a), 0.0) * maxf(v_in.length() * 0.92, 19.0)


func react(_q: int, _p: Vector3) -> void:
	Audio.play("bumper", -2.0, 0.7)
	Audio.play("whoosh", -4.0)
	if game and game.has_method("on_interaction"):
		game.call("on_interaction", self, interaction_points)
	var dish := part("Dish")
	if dish:
		var r0 := dish.rotation.z
		var tw := create_tween()
		tw.tween_property(dish, "rotation:z", r0 - 0.25, 0.08)
		tw.tween_property(dish, "rotation:z", r0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
