class_name RoofProp
extends PropBase
## Houses and sheds. Sloped roofs let Riley slide: up the near slope and off the ridge, or down and off the eave.

var W := 4.0
var slope := 32.0
var wall_h := 3.4
var variant := "house_a"
var roof_pts: Array = []


func configure(v: String) -> RoofProp:
	variant = v
	kind = "house"
	display_name = "Rooftop"
	sound = "roof_land"
	interaction_points = 100
	match v:
		"house_c":
			W = 3.5; slope = 36.0
		"house_d":
			W = 4.5; slope = 26.0
		"shed":
			W = 1.5; slope = 14.0; wall_h = 2.2; kind = "shed"
	half_width = W + 0.45
	exit_vel = Vector2(12, 9)
	return self


func build() -> void:
	load_model(variant)
	if variant == "shed":
		# single slope, high on the left
		var l := Vector2(-1.75, 2.45 + 1.75 * tan(deg_to_rad(14.0)) + 0.09)
		var r := Vector2(1.75, 2.45 - 1.75 * tan(deg_to_rad(14.0)) + 0.09)
		roof_pts = [l, r]
		top_y = l.y
		add_box(Vector3(3.0, 2.2, 2.0), Vector3(0, 1.1, 0))
	else:
		var t := tan(deg_to_rad(slope))
		var over := 0.45
		var peak := wall_h + W * t + 0.12 + 0.14 / cos(deg_to_rad(slope))
		var eave := peak - (W + over) * t
		roof_pts = [Vector2(-(W + over), eave), Vector2(0, peak), Vector2(W + over, eave)]
		top_y = peak
		add_box(Vector3(W * 2.0, wall_h, 2.0), Vector3(0, wall_h * 0.5, 0), 0.0, 0.5)
	add_path(roof_pts, 0.3, 0.03)


func surface_normal(_p: Vector3) -> Vector3:
	return Vector3.ZERO


func on_hit(_riley: Node, v_in: Vector3, n: Vector3, q: int, _p: Vector3) -> Vector3:
	if n.y < 0.45:
		# wall: bump back and down
		return Vector3(-v_in.x * 0.25, maxf(v_in.y, 0.0) + 1.5, 0.0)
	var t := Vector3(n.y, -n.x, 0.0)
	if t.x < 0.0:
		t = -t
	var along := v_in.dot(t)
	var keep: float = Landing.TANGENT_KEEP[q]
	var uphill := t.y > 0.05
	var speed := maxf(along, 13.0 if uphill else 8.0) * keep
	return t * speed + n * (0.8 if q <= Landing.GOOD else 2.5)


func react(_q: int, _p: Vector3) -> void:
	Audio.play(sound)
