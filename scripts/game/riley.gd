class_name RileyPlayer
extends RigidBody3D
## Riley's physics body. Flight runs on Godot 3D physics locked to the X/Y plane; landings are
## evaluated here (orientation vs. surface normal, impact speed) and each prop decides the bounce.

signal game_event(info: Dictionary)

enum Phase { CANNON, FLYING, RAGDOLL, DONE }

var phase := Phase.CANNON
var visual: RileyVisual
var gadget: GadgetController
var world_gravity := 1.0
var zone_gravity := 1.0
var gadget_gravity := 1.0
var fall_cap := 0.0
var stabilize := 0.0
var steer := 0.0
var rot_input := 0.0
var rot_accel := 15.0
var max_spin := 9.5
var recovery_deg := 0.0
var air_time := 0.0
var flips := 0
var last_flip_dir := 0

var _zone_force := Vector3.ZERO
var _triggers: Array = []
var _forced_velocity := Vector3.ZERO
var _has_forced := false
var _prev_v := Vector3.ZERO
var _cool := {}
var _events: Array = []
var _ground_cool := 0.0
var _spin_accum := 0.0
var _slow_time := 0.0
var _still_time := 0.0
var _rag_time := 0.0
var _anim_lock := 0.0
var _touching_ground := false
var _crash_pending := false


func _ready() -> void:
	mass = 25.0
	gravity_scale = Landing.GRAVITY_SCALE
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	angular_damp = 0.35
	collision_layer = 2
	collision_mask = 1
	can_sleep = false
	var pm := PhysicsMaterial.new()
	pm.friction = 0.15
	pm.bounce = 0.0
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.25
	cs.shape = cap
	add_child(cs)
	visual = RileyVisual.new()
	add_child(visual)
	gadget = GadgetController.new()
	add_child(gadget)
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC


func apply_upgrades() -> void:
	var rot_lvl := Save.upgrade_level("rotation")
	var sens := float(Save.setting("rotation"))
	rot_accel = (14.0 + rot_lvl * 2.2) * sens
	max_spin = 9.0 + rot_lvl * 0.6
	recovery_deg = Save.upgrade_level("recovery") * 3.5


func set_cannon_pose(pos: Vector3, angle_rad: float) -> void:
	global_transform = Transform3D(Basis(Vector3.BACK, angle_rad - PI / 2.0), pos)


func launch(dir: Vector3, speed: float, flight_time_hint: float) -> void:
	phase = Phase.FLYING
	freeze = false
	linear_velocity = dir * speed
	_prev_v = linear_velocity
	var tilt := atan2(dir.y, dir.x)
	# a gentle forward rotation that would bring him roughly upright around the apex
	angular_velocity = Vector3(0, 0, -tilt / maxf(flight_time_hint, 0.8) * 0.9)
	visual.play_once("launch", 0.05)
	_anim_lock = 0.35
	visual.set_trail(true)


func queue_trigger(prop: Node) -> void:
	if phase == Phase.FLYING and not _triggers.has(prop):
		_triggers.append(prop)


func add_zone_force(f: Vector3) -> void:
	_zone_force += f


func set_zone_gravity(g: float) -> void:
	zone_gravity = minf(zone_gravity, g)


func force_velocity(v: Vector3) -> void:
	_forced_velocity = v
	_has_forced = true


func is_flying() -> bool:
	return phase == Phase.FLYING


func center() -> Vector3:
	if phase == Phase.RAGDOLL:
		return visual.ragdoll_center()
	return global_position


func velocity_now() -> Vector3:
	if phase == Phase.RAGDOLL:
		return visual.ragdoll_velocity()
	return linear_velocity


func body_angle() -> float:
	var up := global_transform.basis.y
	return atan2(-up.x, up.y)


# ------------------------------------------------------------ physics
func _integrate_forces(s: PhysicsDirectBodyState3D) -> void:
	if phase != Phase.FLYING:
		return
	var dt := s.step
	var v := s.linear_velocity
	var av := s.angular_velocity
	var gmul := world_gravity * zone_gravity * gadget_gravity
	v.y -= 9.8 * Landing.GRAVITY_SCALE * (gmul - 1.0) * dt
	zone_gravity = 1.0
	v += _zone_force * dt
	_zone_force = Vector3.ZERO
	v *= 1.0 - Landing.AIR_DRAG * dt
	if fall_cap > 0.0 and v.y < -fall_cap:
		v.y = move_toward(v.y, -fall_cap, 70.0 * dt)
	v.x += steer * dt
	if rot_input != 0.0:
		av.z = clampf(av.z + rot_input * rot_accel * dt, -max_spin, max_spin)
	elif stabilize > 0.0:
		var up := s.transform.basis.y
		var ang := atan2(-up.x, up.y)
		av.z = lerpf(av.z, -ang * 5.0, clampf(stabilize * 6.0 * dt, 0.0, 1.0))

	var landed := false
	for i in s.get_contact_count():
		var res: Variant = _contact(s.get_contact_collider_object(i), s.get_contact_local_normal(i),
			s.get_contact_local_position(i), s)
		if res != null:
			v = res
			av = s.angular_velocity
			landed = true
			break
	if not landed:
		for prop in _triggers:
			if is_instance_valid(prop):
				var res2: Variant = _contact(prop, Vector3.ZERO, s.transform.origin, s, true)
				if res2 != null:
					v = res2
					av = s.angular_velocity
					break
	_triggers.clear()
	if _has_forced:
		v = _forced_velocity
		_has_forced = false
	v.z = 0.0
	v = v.limit_length(Landing.MAX_SPEED)
	s.linear_velocity = v
	s.angular_velocity = Vector3(0, 0, av.z)
	_prev_v = v


func _quality(n: Vector3, s: PhysicsDirectBodyState3D) -> int:
	var up := s.transform.basis.y
	var ang := rad_to_deg(up.angle_to(n))
	var q := Landing.CRASH
	if ang <= 30.0 + recovery_deg:
		q = Landing.PERFECT
	elif ang <= 58.0 + recovery_deg:
		q = Landing.GOOD
	elif ang <= 122.0:
		q = Landing.MESSY
	if q == Landing.PERFECT and absf(s.angular_velocity.z) > 6.5:
		q = Landing.GOOD
	return q


func _contact(obj: Object, cn: Vector3, cp: Vector3, s: PhysicsDirectBodyState3D, is_trigger := false) -> Variant:
	var prop: PropBase = null
	if obj is PropBase:
		prop = obj as PropBase
	elif obj != null and obj.has_meta("prop"):
		prop = obj.get_meta("prop") as PropBase
	if prop == null:
		return _ground(cn, s)
	if not is_instance_valid(prop):
		return null
	var id := prop.get_instance_id()
	if float(_cool.get(id, 0.0)) > 0.0:
		return null
	var v_in := _prev_v
	var n := prop.surface_normal(cp)
	if n == Vector3.ZERO:
		n = cn if cn != Vector3.ZERO else -v_in.normalized()
	n.z = 0.0
	if n.length() < 0.01:
		n = Vector3.UP
	n = n.normalized()
	if n.dot(v_in) > 0.0 and not is_trigger:
		n = -n
	if not is_trigger and -v_in.dot(n) < 1.2:
		return null
	var q := _quality(n, s)
	var out: Vector3 = prop.on_hit(self, v_in, n, q, cp)
	_cool[id] = 0.25
	if prop.counts_as_landing:
		if q <= Landing.GOOD:
			var target := atan2(-n.x, n.y)
			var cur := atan2(-s.transform.basis.y.x, s.transform.basis.y.y)
			s.transform = Transform3D(Basis(Vector3.BACK, lerp_angle(cur, target, 0.55)), s.transform.origin)
			s.angular_velocity = Vector3(0, 0, s.angular_velocity.z * 0.15)
		else:
			s.angular_velocity = Vector3(0, 0, randf_range(4.0, 7.0) * (1.0 if randf() < 0.5 else -1.0))
	_events.append({"type": "landing", "prop": prop, "quality": q, "point": cp, "speed": v_in.length(),
		"flips": flips, "flip_dir": last_flip_dir, "air": air_time, "out": out})
	prop.call_deferred("react", q, cp)
	if prop.counts_as_landing:
		_reset_air()
	return out


func _ground(cn: Vector3, s: PhysicsDirectBodyState3D) -> Variant:
	if absf(cn.y) < 0.6:
		return null
	_touching_ground = true
	if _ground_cool > 0.0:
		return null
	var v_in := _prev_v
	var vn := -v_in.y
	if vn < 2.0:
		var v := s.linear_velocity
		v.x *= 1.0 - 1.6 * s.step
		return v
	_ground_cool = 0.15
	var q := _quality(Vector3.UP, s)
	if (q == Landing.CRASH and vn > 6.0) or (q == Landing.MESSY and vn > 30.0) or vn > 44.0:
		_crash_pending = true
		_events.append({"type": "crash", "speed": v_in.length(), "point": cp_or(s)})
		return null
	var keep: float = [0.8, 0.7, 0.5, 0.4][q]
	var out := Vector3(v_in.x * keep, vn * (0.3 if q <= Landing.GOOD else 0.2), 0.0)
	if out.y < 2.5:
		out.y = 0.0
	if q >= Landing.MESSY:
		s.angular_velocity = Vector3(0, 0, -absf(v_in.x) * 0.25)
	else:
		var cur := atan2(-s.transform.basis.y.x, s.transform.basis.y.y)
		s.transform = Transform3D(Basis(Vector3.BACK, lerp_angle(cur, 0.0, 0.5)), s.transform.origin)
		s.angular_velocity = Vector3.ZERO
	_events.append({"type": "ground", "quality": q, "speed": v_in.length(), "point": s.transform.origin})
	_reset_air()
	return out


## Test hook: crash right now (used by the automated smoke test).
func debug_crash() -> void:
	if phase == Phase.FLYING:
		_crash_pending = true
		_events.append({"type": "crash", "speed": linear_velocity.length(), "point": global_position})


func cp_or(s: PhysicsDirectBodyState3D) -> Vector3:
	return s.transform.origin


func _reset_air() -> void:
	flips = 0
	_spin_accum = 0.0
	air_time = 0.0


# ------------------------------------------------------------ per-frame logic
func _physics_process(dt: float) -> void:
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - dt
		if float(_cool[k]) <= 0.0:
			_cool.erase(k)
	_ground_cool = maxf(0.0, _ground_cool - dt)
	_anim_lock = maxf(0.0, _anim_lock - dt)

	if phase == Phase.FLYING:
		air_time += dt
		_spin_accum += angular_velocity.z * dt
		if absf(_spin_accum) >= TAU * 0.9:
			var d := 1 if _spin_accum > 0.0 else -1
			flips += 1
			last_flip_dir = d
			_spin_accum -= d * TAU
			_events.append({"type": "flip", "count": flips, "dir": d})
		var sp := linear_velocity.length()
		_slow_time = _slow_time + dt if (_touching_ground and sp < 2.6) else 0.0
		_still_time = _still_time + dt if sp < 0.9 else 0.0
		if _slow_time > 0.45 or _still_time > 2.2:
			_finish_stop()
		_touching_ground = false
		visual.set_trail(sp > 9.0)
	elif phase == Phase.RAGDOLL:
		_rag_time += dt
		if _rag_time > 1.0 and (visual.ragdoll_velocity().length() < 1.2 or _rag_time > 4.0):
			_events.append({"type": "ragdoll_done"})
			phase = Phase.DONE

	if _crash_pending:
		_crash_pending = false
		_begin_ragdoll()

	var evs := _events.duplicate()
	_events.clear()
	for e in evs:
		_on_own_event(e)
		game_event.emit(e)
	_update_anim()


func _finish_stop() -> void:
	phase = Phase.DONE
	set_deferred("freeze", true)
	linear_velocity = Vector3.ZERO
	visual.set_trail(false)
	var up := global_transform.basis.y
	if up.y > 0.6:
		visual.play_once("land_awkward")
	else:
		visual.play_once("crash")
	_events.append({"type": "stopped"})


func _begin_ragdoll() -> void:
	phase = Phase.RAGDOLL
	_rag_time = 0.0
	visual.set_trail(false)
	var v := _prev_v
	var ok := visual.start_ragdoll(v * 0.8, angular_velocity.z)
	set_deferred("freeze", true)
	collision_layer = 0
	collision_mask = 0
	if not ok:
		_rag_time = 0.5


func _on_own_event(e: Dictionary) -> void:
	match String(e["type"]):
		"landing":
			var prop_v: Variant = e["prop"]
			if is_instance_valid(prop_v) and (prop_v as PropBase).counts_as_landing:
				var q: int = e["quality"]
				if q == Landing.PERFECT:
					visual.play_once("land_perfect", 0.05)
					_anim_lock = 0.3
				elif q >= Landing.MESSY:
					visual.play_once("land_awkward", 0.05)
					_anim_lock = 0.35
		"ground":
			visual.play_once("land_awkward", 0.05)
			_anim_lock = 0.3


func _update_anim() -> void:
	if _anim_lock > 0.0 or visual == null:
		return
	match phase:
		Phase.CANNON:
			visual.play("launch_prep")
		Phase.FLYING:
			var v := linear_velocity
			var spin := absf(angular_velocity.z)
			if spin > 4.2:
				visual.play("tuck", 0.12)
			elif v.y < -12.0 and global_transform.basis.y.y < 0.25:
				visual.play("panic_flail", 0.15)
			elif v.y < -3.0 and _surface_below(5.5):
				visual.play("landing_prep", 0.18)
			else:
				visual.play("airborne", 0.2)


func _surface_below(dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	var ex: Array[RID] = [get_rid()]
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -dist, 0), 1, ex)
	var hit := space.intersect_ray(q)
	return not hit.is_empty()
