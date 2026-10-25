class_name LevelGen
extends Node3D
## Endless procedural playground. Places interactive props ahead of Riley with gaps bounded by the
## previous prop's reachable distance, sprinkles recovery surfaces, coin arcs and world decor, and
## frees everything that falls far behind. Deterministic for a given seed.

const AHEAD := 150.0
const BEHIND := 75.0

var game: Node
var world := 0
var rng := RandomNumberGenerator.new()
var seed_value := 0
var world_gravity := 1.0
var next_x := 14.0
var decor_x := -50.0
var since_recovery := 0
var prev_top := Vector3(4, 4, 0)
var prev_reach := 30.0
var props: Array = []
var decor: Array = []
var coins: Array = []
var coin_pool: Array = []
var house_toggle := 0


func setup(game_ref: Node, world_idx: int, seed_in: int) -> void:
	game = game_ref
	world = world_idx
	seed_value = seed_in
	rng.seed = seed_in
	world_gravity = float(Catalog.WORLDS[world]["gravity"])
	# a generous first field so any launch has something to land on
	for i in 3:
		var k: String = ["trampoline", "mattress", "trampoline"][i]
		if world == 1 and i == 1:
			k = "house"
		elif world == 2 and i == 1:
			k = "spring"
		elif world == 3:
			k = "floating"
		_spawn(k, 1.15)
		next_x += rng.randf_range(6.0, 10.0)


func update(px: float) -> void:
	var guard := 0
	while next_x < px + AHEAD and guard < 12:
		_place_next()
		guard += 1
	guard = 0
	while decor_x < px + AHEAD + 30.0 and guard < 12:
		_place_decor()
		guard += 1
	_cleanup(px - BEHIND)


func difficulty() -> float:
	return clampf(next_x / 1600.0, 0.0, 1.0)


func _pick_kind() -> String:
	var d := difficulty()
	var table: Dictionary = Catalog.SPAWN[world]
	var entries := []
	var total := 0.0
	var force_recovery := since_recovery >= 3
	for k in table.keys():
		var e: Array = table[k]
		if next_x < float(e[1]):
			continue
		if force_recovery and not (k in Catalog.RECOVERY_KINDS):
			continue
		var w := float(e[0])
		if k in ["wind", "rotating", "ramp", "lowgrav"]:
			w *= 0.4 + d * 1.4
		entries.append([k, w])
		total += w
	if entries.is_empty():
		return "trampoline" if world != 3 else "floating"
	var r := rng.randf() * total
	for e in entries:
		r -= float(e[1])
		if r <= 0.0:
			return String(e[0])
	return String(entries[-1][0])


func _place_next() -> void:
	var d := difficulty()
	var kind := _pick_kind()
	var size := lerpf(1.15, 0.82, d)
	var prop := _spawn(kind, size)
	if prop == null:
		next_x += 10.0
		return
	if not prop.counts_as_landing and kind in ["wind", "lowgrav"]:
		next_x += 4.0
		return  # overlays barely consume spacing
	var reach := prop.reach_estimate(world_gravity)
	var gap_lo := lerpf(6.0, 12.0, d)
	var gap_hi := lerpf(15.0, 28.0, d)
	gap_hi = minf(gap_hi, maxf(reach * 0.85, gap_lo + 2.0))
	next_x += rng.randf_range(gap_lo, gap_hi)


func _spawn(kind: String, size: float) -> PropBase:
	var prop: PropBase = null
	var y := 0.0
	var scl := size
	match kind:
		"trampoline", "bounce_house", "mattress", "cushion", "duck", "tire", "floating":
			prop = BouncePad.new().configure(kind)
			if kind == "floating":
				y = rng.randf_range(1.5, 6.5) + difficulty() * 3.0
		"spring":
			prop = SpringPad.new().configure(rng.randf_range(56.0, 74.0), rng.randf_range(20.0, 25.0))
		"pool":
			prop = PoolProp.new()
		"house":
			var variants := ["house_a", "house_b", "house_c", "house_d"]
			var v: String = variants[rng.randi() % variants.size()]
			if world == 0:
				v = "shed"
			prop = RoofProp.new().configure(v)
			scl = 1.0
		"dish":
			prop = DishProp.new().configure(rng.randf_range(38.0, 68.0))
			scl = 1.0
		"fan":
			prop = ForceZone.new().configure("fan", rng.randf_range(0.0, 28.0))
		"wind_tunnel":
			prop = ForceZone.new().configure("wind_tunnel")
		"thruster":
			prop = ForceZone.new().configure("thruster", rng.randf_range(15.0, 45.0))
			y = rng.randf_range(2.0, 6.0)
			scl = 1.0
		"wind":
			var s := rng.randf_range(0.8, 1.4) * (-1.0 if rng.randf() < 0.5 + difficulty() * 0.2 else 1.0)
			prop = ForceZone.new().configure("wind", 0.0, s)
			scl = 1.0
		"lowgrav":
			prop = ForceZone.new().configure("lowgrav")
			scl = 1.0
		"booster":
			prop = ForceZone.new().configure("booster", rng.randf_range(0.0, 35.0))
			y = rng.randf_range(3.0, 9.0)
			scl = 1.0
		"truck", "rotating":
			prop = MovingProp.new().configure(kind, rng)
			scl = 1.0 if kind == "truck" else size
		"seesaw", "slide", "conveyor", "bumper", "ramp":
			var sp := SpecialProp.new().configure(kind)
			if kind == "bumper":
				y = rng.randf_range(2.5, 8.0)
				sp.post_height = y / size
			prop = sp
	if prop == null:
		return null
	prop.game = game
	prop.scale = Vector3.ONE * scl
	var overlay := kind in ["wind", "lowgrav"]
	var x := next_x + prop.half_width * scl
	if overlay:
		x = next_x + rng.randf_range(2.0, 8.0)
	prop.position = Vector3(x, y, 0)
	add_child(prop)
	props.append(prop)
	if overlay:
		return prop
	next_x = x + prop.half_width * scl
	if prop.counts_as_landing or kind in ["dish", "booster", "fan", "wind_tunnel", "thruster"]:
		var top := Vector3(x, y + prop.top_y * scl, 0)
		_coin_arc(prev_top, top)
		prev_top = top
		since_recovery = 0 if prop.recovery else since_recovery + 1
	return prop


func _coin_arc(a: Vector3, b: Vector3) -> void:
	if b.x - a.x < 6.0 or rng.randf() < 0.25:
		return
	var n := rng.randi_range(5, 8)
	var h := rng.randf_range(3.0, 7.0) + (b.x - a.x) * 0.08
	for i in n:
		var t := (i + 1.0) / (n + 1.0)
		var p := a.lerp(b, t)
		p.y += 4.0 * h * t * (1.0 - t) + 1.2
		_add_coin(p)


func _add_coin(p: Vector3) -> void:
	var c: Node3D
	if coin_pool.is_empty():
		c = Assets.prop("coin")
		Assets.set_shadows(c, false)
		add_child(c)
	else:
		c = coin_pool.pop_back()
		c.visible = true
	c.position = p
	c.scale = Vector3.ONE
	c.set_meta("collected", false)
	coins.append(c)


func recycle_coin(c: Node3D) -> void:
	coins.erase(c)
	c.visible = false
	coin_pool.append(c)


func _process(dt: float) -> void:
	var spin := Time.get_ticks_msec() * 0.004
	for c in coins:
		(c as Node3D).rotation.y = spin + (c as Node3D).position.x * 0.3


func _cleanup(limit: float) -> void:
	for i in range(props.size() - 1, -1, -1):
		if not is_instance_valid(props[i]):
			props.remove_at(i)
			continue
		var p: Node3D = props[i]
		if p.position.x + 20.0 < limit:
			p.queue_free()
			props.remove_at(i)
	for i in range(decor.size() - 1, -1, -1):
		var dn: Node3D = decor[i]
		if dn.position.x + 40.0 < limit:
			dn.queue_free()
			decor.remove_at(i)
	for i in range(coins.size() - 1, -1, -1):
		var c: Node3D = coins[i]
		if c.position.x < limit:
			recycle_coin(c)


## Next landing opportunity ahead of x (for camera framing), or ZERO.
func next_target(px: float, max_ahead := 40.0) -> Vector3:
	var best := Vector3.ZERO
	var best_x := INF
	for p in props:
		if not is_instance_valid(p):
			continue
		var pr: PropBase = p
		if not pr.counts_as_landing:
			continue
		var x := pr.global_position.x
		if x > px + 3.0 and x < px + max_ahead and x < best_x:
			best_x = x
			best = Vector3(x, pr.global_position.y + pr.top_y * pr.scale_factor(), 0)
	return best


func plunger_target(pos: Vector3) -> Variant:
	var best: Variant = null
	var best_d := 24.0
	for p in props:
		if not is_instance_valid(p):
			continue
		var pr: PropBase = p
		if pr.kind in ["wind", "lowgrav"]:
			continue
		var t := pr.global_position + Vector3(0, pr.top_y * pr.scale_factor() + 0.6, 0)
		if t.x < pos.x + 2.0:
			continue
		var dd := t.distance_to(pos)
		if dd < best_d:
			best_d = dd
			best = t
	return best


# ------------------------------------------------------------ decor
func _deco(model_name: String, x: float, z: float, s := 1.0, y := 0.0, rot_y := 0.0, shadows := true) -> Node3D:
	var n := Assets.prop(model_name)
	n.position = Vector3(x, y, z)
	n.scale = Vector3.ONE * s
	n.rotation.y = rot_y
	if not shadows or z < -16.0:
		Assets.set_shadows(n, false)
	add_child(n)
	decor.append(n)
	return n


func _place_decor() -> void:
	var x0 := decor_x
	var span := 24.0
	decor_x += span
	var r := rng
	match world:
		0:
			for i in 6:
				_deco("fence", x0 + i * 4.0 + 2.0, -4.5)
			for i in r.randi_range(2, 4):
				var m: String = ["tree_round", "tree_round_big", "bush", "tree_pine", "bush"][r.randi() % 5]
				_deco(m, x0 + r.randf_range(0, span), r.randf_range(-22.0, -8.0), r.randf_range(0.8, 1.3), 0, r.randf_range(-0.5, 0.5))
			if r.randf() < 0.5:
				_deco(["swing_set", "shed", "bush"][r.randi() % 3], x0 + r.randf_range(0, span), r.randf_range(-13.0, -9.0), 1.0, 0, r.randf_range(-0.3, 0.3))
			if r.randf() < 0.6:
				_deco(["house_a", "house_b", "house_c", "house_d"][r.randi() % 4], x0 + r.randf_range(0, span), r.randf_range(-34.0, -26.0), 1.0, 0, r.randf_range(-0.2, 0.2), false)
			if r.randf() < 0.35:
				_deco("bush", x0 + r.randf_range(0, span), r.randf_range(5.0, 7.0), 0.8)
		1:
			house_toggle += 1
			for i in 2:
				_deco(["house_a", "house_b", "house_c", "house_d"][r.randi() % 4], x0 + i * 12.0 + 6.0, -13.5, 1.0, 0, 0.0)
			_deco("streetlamp", x0 + 3.0, -5.6)
			if r.randf() < 0.6:
				_deco(["hydrant", "mailbox", "road_sign"][r.randi() % 3], x0 + r.randf_range(0, span), -6.6)
			for i in r.randi_range(1, 3):
				_deco(["tree_round", "tree_round_big", "tree_pine"][r.randi() % 3], x0 + r.randf_range(0, span), r.randf_range(-26.0, -19.0), r.randf_range(0.9, 1.3))
			if r.randf() < 0.5:
				_deco("tree_round", x0 + r.randf_range(0, span), r.randf_range(7.0, 9.0), 0.8)
		2:
			if r.randf() < 0.55:
				_deco("tent", x0 + r.randf_range(0, span), r.randf_range(-20.0, -13.0), r.randf_range(0.9, 1.3))
			if int(x0) % 144 < 24:
				_deco("ferris_wheel", x0 + 12.0, -42.0, 1.4, 0, 0.0, false)
			elif r.randf() < 0.45:
				_deco("coaster", x0 + 12.0, -28.0, 1.0, 0, 0.0, false)
			_deco("streetlamp", x0 + 5.0, -4.8)
			for i in r.randi_range(1, 3):
				_deco(["bush", "tree_round"][r.randi() % 2], x0 + r.randf_range(0, span), r.randf_range(-16.0, -7.0), r.randf_range(0.8, 1.1))
		3:
			for i in r.randi_range(2, 4):
				_deco("moon_rock", x0 + r.randf_range(0, span), r.randf_range(-24.0, -5.0), r.randf_range(0.6, 2.2), 0, r.randf() * TAU)
			if r.randf() < 0.15:
				_deco("flag", x0 + r.randf_range(0, span), r.randf_range(-9.0, -6.0))
			if int(x0) % 240 < 24:
				_deco("planet", x0 + 40.0, -160.0, 4.0, r.randf_range(35.0, 60.0), 0.0, false)
			elif int(x0) % 240 >= 120 and int(x0) % 240 < 144:
				_deco("space_station", x0 + 20.0, -110.0, 1.5, r.randf_range(25.0, 40.0), 0.3, false)
	if world != 3 and r.randf() < 0.55:
		_deco("cloud", x0 + r.randf_range(0, span), r.randf_range(-70.0, -45.0), r.randf_range(1.5, 3.0), r.randf_range(18.0, 34.0), 0.0, false)
