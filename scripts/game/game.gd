class_name Game
extends Node3D
## One run: aiming meters, launch, flight input, scoring, combos, coins and the end of the run.

signal run_finished(result: Dictionary)
signal request_pause

enum Stage { POWER, ANGLE, FLIGHT, OVER }

const POPUPS := ["NICE BOUNCE!", "DOUBLE BOUNCE!", "TRIPLE BOUNCE!", "CRAZY LANDING!", "INSANE COMBO!",
	"INSANE COMBO!", "UNBELIEVABLE!", "UNBELIEVABLE!", "LEGENDARY!", "RILEY-TASTIC!"]

var stage := Stage.POWER
var world := 0
var seed_value := 0
var env: WorldEnv
var level: LevelGen
var launcher: Launcher
var riley: RileyPlayer
var cam: CameraRig
var fx: FX
var hud: Node
var auto_play := false
var auto_reckless := false

var power := 0.0
var angle := 45.0
var locked_power := 0.6
var _meter_t := 0.0
var event_score := 0
var distance := 0.0
var start_x := 0.0
var combo := 0
var best_combo := 0
var combo_timer := 0.0
var combo_time := 6.0
var landings := 0
var perfects := 0
var tricks := 0
var interactions := 0
var coins_run := 0
var crashes := 0
var max_alt := 0.0
var sky_high_done := false
var _last_prop_id := 0
var _same_prop := 0
var _last_land_x := -999.0
var _touches := {}
var _ended := false
var _tutorial := false
var _tutorial_t := 0.0
var _magnet := 1.3
var _auto_t := 0.0


func get_riley() -> Node:
	return riley


func start(world_idx: int, hud_ref: Node, seed_in := -1) -> void:
	world = world_idx
	hud = hud_ref
	var q := int(Save.setting("quality"))
	env = WorldEnv.new()
	add_child(env)
	env.setup(world, q)
	fx = FX.new()
	fx.quality = q
	add_child(fx)
	seed_value = seed_in if seed_in >= 0 else randi() % 1000000
	level = LevelGen.new()
	add_child(level)
	level.setup(self, world, seed_value)
	launcher = Launcher.new()
	add_child(launcher)
	launcher.position = Vector3(-3.0, 0, 0)
	riley = RileyPlayer.new()
	add_child(riley)
	riley.world_gravity = float(Catalog.WORLDS[world]["gravity"])
	riley.apply_upgrades()
	riley.visual.apply_loadout()
	riley.gadget.setup(riley, Save.equipped_gadget(), Save.upgrade_level("gadget"), self)
	riley.game_event.connect(_on_event)
	cam = CameraRig.new()
	add_child(cam)
	cam.target = riley
	cam.current = true
	env.follow = cam
	combo_time = 6.0 + Save.upgrade_level("combo") * 0.9
	_magnet = 1.3 + Save.upgrade_level("magnet") * 0.9
	_tutorial = not bool(Save.setting("tutorial_done"))
	_place_in_cannon()
	cam.snap()
	level.update(0.0)
	if hud and hud.has_method("bind"):
		hud.call("bind", self)
	Audio.music(String(Catalog.WORLDS[world]["music"]))
	Audio.start_loop("wind_loop", -60.0)
	_hint("TAP TO SET POWER")


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Audio.stop_all_loops()


func _place_in_cannon() -> void:
	var d := launcher.dir()
	riley.set_cannon_pose(launcher.muzzle_pos() + d * 0.12, atan2(d.y, d.x))


func _hint(t: String) -> void:
	if hud and hud.has_method("set_hint"):
		hud.call("set_hint", t)


# ------------------------------------------------------------ input
func _input(e: InputEvent) -> void:
	if _ended:
		return
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			if hud and bool(hud.call("hit_pause", st.position)):
				request_pause.emit()
				get_viewport().set_input_as_handled()
				return
			if stage == Stage.POWER or stage == Stage.ANGLE:
				_tap()
			elif stage == Stage.FLIGHT:
				if hud and bool(hud.call("hit_gadget", st.position)):
					use_gadget()
				else:
					_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if _touches.has(sd.index):
			_touches[sd.index] = sd.position
	elif e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER:
				if stage == Stage.POWER or stage == Stage.ANGLE:
					_tap()
			elif k.keycode == KEY_W or k.keycode == KEY_UP or k.keycode == KEY_G:
				use_gadget()
			elif k.keycode == KEY_ESCAPE or k.keycode == KEY_P:
				request_pause.emit()


func _rotation_input() -> float:
	var w := get_viewport().get_visible_rect().size.x
	var left := false
	var right := false
	for i in _touches.keys():
		var p: Vector2 = _touches[i]
		if p.x < w * 0.5:
			left = true
		else:
			right = true
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		left = true
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		right = true
	if hud and hud.has_method("set_rotation_feedback"):
		hud.call("set_rotation_feedback", left, right)
	var v := 0.0
	if left:
		v += 1.0
	if right:
		v -= 1.0
	return v * float(Save.setting("sensitivity"))


func _tap() -> void:
	if stage == Stage.POWER:
		locked_power = power
		stage = Stage.ANGLE
		_meter_t = 0.0
		Audio.play("lock")
		if hud and hud.has_method("lock_power"):
			hud.call("lock_power", locked_power)
		_hint("TAP TO FIRE!")
	elif stage == Stage.ANGLE:
		fire()


func fire() -> void:
	stage = Stage.FLIGHT
	var lvl := Save.upgrade_level("power")
	var gw := riley.world_gravity
	var speed := lerpf(16.0, 31.0, locked_power) * (1.0 + 0.06 * lvl) * pow(gw, 0.35)
	var d := launcher.dir()
	var vy := d.y * speed
	var t := 2.0 * vy / Landing.g_eff(gw)
	riley.global_position = launcher.muzzle_pos() + d * 0.2
	riley.launch(d, speed, t)
	launcher.fire()
	fx.smoke(launcher.muzzle_pos(), d)
	cam.add_trauma(0.55)
	cam.mode = "flight"
	Audio.play("launch_boom")
	Audio.play("crank", -6.0)
	Audio.voice("voice_woohoo")
	Save.vibrate(45)
	start_x = launcher.global_position.x + 2.0
	if hud and hud.has_method("on_launched"):
		hud.call("on_launched")
	_hint("HOLD LEFT / RIGHT TO SPIN · LAND FEET FIRST" if _tutorial else "")
	_tutorial_t = 4.0 if _tutorial else 0.0


func use_gadget() -> void:
	if stage == Stage.FLIGHT and riley.gadget.activate():
		Save.vibrate(25)
		if hud and hud.has_method("gadget_changed"):
			hud.call("gadget_changed")


# ------------------------------------------------------------ per frame
func _process(dt: float) -> void:
	match stage:
		Stage.POWER:
			_meter_t += dt
			power = 0.5 - 0.5 * cos(_meter_t * TAU / 1.25)
			if hud:
				hud.call("set_power", power)
			if auto_play and _meter_t > 0.9:
				_tap()
		Stage.ANGLE:
			_meter_t += dt
			var period := 1.5 + 0.3 * Save.upgrade_level("angle")
			angle = lerpf(15.0, 75.0, 0.5 - 0.5 * cos(_meter_t * TAU / period))
			launcher.set_angle(angle)
			_place_in_cannon()
			if hud:
				hud.call("set_angle", angle)
			if auto_play and _meter_t > 0.6:
				_tap()
		Stage.FLIGHT:
			_flight(dt)
	var c := riley.center()
	level.update(c.x)
	cam.focus_hint = level.next_target(c.x) if stage == Stage.FLIGHT else Vector3.ZERO
	if hud:
		var frac := combo_timer / combo_time if combo > 0 else 0.0
		hud.call("update_stats", total_score(), int(distance), combo_mult(), frac, coins_run, riley.velocity_now().length())


func _flight(dt: float) -> void:
	if auto_play:
		# a simple "decent player": flip on the way up, level out on the way down
		_auto_t += dt
		var vv := riley.linear_velocity
		if auto_reckless:
			riley.rot_input = 1.0
		elif vv.y > 7.0 and fmod(_auto_t, 6.0) < 3.0:
			riley.rot_input = 1.0
		else:
			riley.rot_input = clampf(-(riley.body_angle() * 2.5 + riley.angular_velocity.z * 0.55), -1.0, 1.0)
		if vv.y < -6.0 and fmod(_auto_t, 5.0) < dt * 1.5:
			use_gadget()
	else:
		riley.rot_input = _rotation_input()
	var c := riley.center()
	distance = maxf(distance, c.x - start_x)
	max_alt = maxf(max_alt, c.y)
	if not sky_high_done and c.y > 40.0:
		sky_high_done = true
		_award(300, "SKY HIGH!", Color(0.6, 0.9, 1.0))
	if combo > 0 and riley.is_flying():
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo = 0
	if _tutorial_t > 0.0:
		_tutorial_t -= dt
		if _tutorial_t <= 0.0:
			_hint("")
	var sp := riley.velocity_now().length()
	Audio.set_loop("wind_loop", linear_to_db(clampf(sp / 45.0, 0.001, 1.0)) - 6.0, 0.8 + sp / 90.0)
	_collect_coins(dt, c)


func _physics_process(_dt: float) -> void:
	pass


func _collect_coins(dt: float, c: Vector3) -> void:
	var list := level.coins.duplicate()
	for co in list:
		var node := co as Node3D
		if node == null or not node.visible:
			continue
		var d := node.position.distance_to(c)
		if d < _magnet:
			node.position = node.position.move_toward(c, (18.0 + 12.0 / maxf(d, 0.2)) * dt)
			if node.position.distance_to(c) < 0.75:
				coins_run += 1
				event_score += 25
				Audio.play("coin", -4.0, 1.0 + minf(coins_run % 12, 11) * 0.02, 0.02)
				fx.sparkle(node.position)
				level.recycle_coin(node)


func combo_mult() -> int:
	return clampi(combo, 1, 10)


func total_score() -> int:
	return event_score + int(distance * 10.0)


func _award(points: int, text: String, color := Color(1, 0.86, 0.2), big := false) -> void:
	event_score += points
	if hud and hud.has_method("popup") and text != "":
		hud.call("popup", text, color, big)
	if points > 0:
		fx.float_text(riley.center() + Vector3(0, 1.4, 0), "+%d" % points, color, 80)


func _slowmo(time_scale := 0.35, dur := 0.3) -> void:
	Engine.time_scale = time_scale
	get_tree().create_timer(dur, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


# ------------------------------------------------------------ events from Riley
func _on_event(e: Dictionary) -> void:
	match String(e["type"]):
		"landing":
			_on_landing(e)
		"ground":
			var q: int = e["quality"]
			combo = 0
			fx.dust(riley.center() + Vector3(0, -0.6, 0))
			Audio.play("thud", 0.0, 0.9)
			cam.add_trauma(minf(float(e["speed"]) / 60.0, 0.5))
			if q >= Landing.MESSY:
				Audio.voice("voice_oof", 0.8)
				if hud:
					hud.call("popup", "OUCH!", Color(1, 0.5, 0.4), false)
			Save.vibrate(30)
		"flip":
			tricks += 1
			var n: int = e["count"]
			var name_txt := "BACKFLIP" if int(e["dir"]) > 0 else "FRONT FLIP"
			var pre: String = ["", "", "DOUBLE ", "TRIPLE ", "QUAD ", "MEGA "][mini(n, 5)]
			if hud:
				hud.call("flip_popup", pre + name_txt + "!")
			Audio.play("whoosh", -6.0, 1.0 + n * 0.08)
		"crash":
			crashes += 1
			combo = 0
			Audio.play("crash_bonk")
			Audio.voice("voice_ouch")
			cam.add_trauma(0.85)
			cam.add_punch(0.12)
			fx.impact(riley.center(), float(e["speed"]))
			fx.dust(riley.center())
			if hud:
				hud.call("popup", "CRASH!", Color(1, 0.4, 0.35), true)
			_slowmo(0.4, 0.35)
			Save.vibrate(80)
		"stopped", "ragdoll_done":
			get_tree().create_timer(1.1).timeout.connect(end_run)


func _on_landing(e: Dictionary) -> void:
	var prop_v: Variant = e["prop"]
	if not is_instance_valid(prop_v):
		return
	var prop := prop_v as PropBase
	var q: int = e["quality"]
	var p: Vector3 = e["point"]
	var speed := float(e["speed"])
	if not prop.counts_as_landing:
		return
	var id := prop.get_instance_id()
	var progressed := riley.global_position.x - _last_land_x
	var farming := id == _last_prop_id and progressed < 6.0
	_same_prop = _same_prop + 1 if farming else 0
	_last_prop_id = id
	_last_land_x = riley.global_position.x
	var farm_mul := pow(0.3, _same_prop)
	if prop is PoolProp and (prop as PoolProp).last_result == "splash":
		combo = 0
		_award(50, "SPLASH!", Color(0.5, 0.85, 1.0))
		fx.splash(p)
		return
	if q <= Landing.GOOD:
		if not farming:
			combo += 1
		best_combo = maxi(best_combo, combo)
		landings += 1
		combo_timer = combo_time
		var mult := combo_mult()
		var base := 500 if q == Landing.PERFECT else 200
		var label: String = POPUPS[clampi(combo - 1, 0, POPUPS.size() - 1)]
		if q == Landing.PERFECT:
			perfects += 1
			if combo <= 1:
				label = "PERFECT!"
		if prop is BouncePad and (prop as BouncePad).last_centered:
			base += 250
			label = "BULLSEYE!"
		var pts := int(base * mult * farm_mul)
		var flips: int = e["flips"]
		if flips > 0:
			pts += int(300 * flips * mult)
			label = ("DOUBLE " if flips == 2 else ("TRIPLE " if flips >= 3 else "")) + "FLIP LANDED!"
		if float(e["air"]) > 4.0:
			pts += 400
			label = "HANG TIME!"
		var col := Color(1.0, 0.86, 0.2) if q == Landing.PERFECT else Color(1, 1, 1)
		_award(pts, label if not farming else "", col, combo >= 4 or q == Landing.PERFECT)
		Audio.play("combo", -4.0, 1.0 + minf(combo, 10) * 0.05, 0.0)
		if q == Landing.PERFECT:
			if combo >= 3 and combo % 3 == 0:
				Audio.play("perfect", -2.0)
			if combo >= 3:
				fx.confetti(p + Vector3(0, 0.5, 0))
			else:
				fx.burst(p, Color(1, 0.9, 0.3), 16, 6.0)
			Audio.voice(["voice_yay", "voice_yeah", "voice_woohoo"][randi() % 3], 0.5)
			if combo >= 4 or flips >= 2:
				_slowmo()
		else:
			fx.burst(p, Color(1, 1, 1), 12, 5.0)
		if speed > 26.0:
			cam.add_punch(0.06)
			cam.add_trauma(0.2)
		Save.vibrate(18 if q == Landing.GOOD else 30)
	else:
		combo = maxi(0, combo - 1) if q == Landing.MESSY else 0
		_award(int(50 * combo_mult() * farm_mul), "WOBBLY!" if q == Landing.MESSY else "OOPS!", Color(1, 0.7, 0.5))
		Audio.voice("voice_whoa", 0.6)
		fx.dust(p)
		cam.add_trauma(0.25)


## Environmental interaction (fans, dishes, boosters, bumpers...).
func on_interaction(prop: Node, points: int) -> void:
	if stage != Stage.FLIGHT:
		return
	interactions += 1
	if combo > 0:
		combo_timer = combo_time
	var pr := prop as PropBase
	_award(int(points * combo_mult()), (pr.display_name.to_upper() + "!") if pr else "", Color(0.6, 1.0, 0.7))


func on_gadget_used(_id: String) -> void:
	if hud and hud.has_method("gadget_changed"):
		hud.call("gadget_changed")


func find_plunger_target(pos: Vector3) -> Variant:
	return level.plunger_target(pos)


func spawn_emergency_mattress(pos: Vector3) -> void:
	var m := BouncePad.new().configure("emergency_mattress")
	m.game = self
	m.position = Vector3(pos.x, maxf(pos.y, 0.0), 0)
	level.add_child(m)
	level.props.append(m)


func fx_splash(pos: Vector3) -> void:
	fx.splash(pos)


func fx_burst(pos: Vector3, color: Color) -> void:
	fx.burst(pos, color, 16, 7.0)


# ------------------------------------------------------------ end
func end_run() -> void:
	if _ended:
		return
	_ended = true
	stage = Stage.OVER
	Engine.time_scale = 1.0
	Audio.stop_loop("wind_loop")
	var total := total_score()
	var coins_earned := coins_run + int(distance / 15.0) + int(total / 2500.0)
	Save.add_coins(coins_earned)
	if _tutorial:
		Save.set_setting("tutorial_done", true)
	var result := {"world": world, "seed": seed_value, "distance": int(distance), "score": total,
		"best_combo": best_combo, "landings": landings, "perfects": perfects, "tricks": tricks,
		"interactions": interactions, "coins": coins_earned, "coins_collected": coins_run}
	var rec := Save.record_run(world, result)
	result.merge(rec)
	if riley.phase == RileyPlayer.Phase.DONE and not riley.visual.ragdolling:
		riley.visual.play_once("victory" if bool(rec["distance_record"]) else "idle")
	run_finished.emit(result)
