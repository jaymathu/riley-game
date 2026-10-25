class_name ForceZone
extends PropBase
## Fans, wind tunnels, space thrusters, wind gusts, low-gravity fields and booster rings.

var dir := Vector3.UP
var strength := 38.0
var zone: Area3D
var zone_size := Vector3(3, 10, 3)
var spin_part: Node3D
var low_gravity := 0.0
var entered := false
var particles: CPUParticles3D


func configure(k: String, angle_deg := 0.0, str_mul := 1.0) -> ForceZone:
	kind = k
	counts_as_landing = false
	match k:
		"fan":
			display_name = "Giant Fan"; half_width = 1.6; top_y = 1.3; strength = 36.0; interaction_points = 100
			rotation.z = -deg_to_rad(angle_deg)
		"wind_tunnel":
			display_name = "Wind Tunnel"; half_width = 1.7; top_y = 0.5; strength = 42.0; interaction_points = 120
		"thruster":
			display_name = "Thruster"; half_width = 1.0; top_y = 0.0; strength = 40.0; interaction_points = 120
			rotation.z = -deg_to_rad(angle_deg)
		"wind":
			display_name = "Gust"; half_width = 8.0; top_y = 0.0; strength = 16.0 * str_mul
			dir = Vector3(signf(str_mul), 0.25, 0).normalized()
		"lowgrav":
			display_name = "Low-G Field"; half_width = 7.0; top_y = 0.0; strength = 0.0; low_gravity = 0.35
			interaction_points = 80
		"booster":
			display_name = "Booster Ring"; half_width = 1.4; top_y = 0.0; strength = 0.0; interaction_points = 150
			rotation.z = deg_to_rad(angle_deg)
	exit_vel = Vector2(14, 16)
	return self


func build() -> void:
	match kind:
		"fan":
			load_model("fan")
			spin_part = part("Blades")
			add_box(Vector3(3.0, 1.3, 2.0), Vector3(0, 0.65, 0))
			zone = add_area_box(Vector3(3.0, 11.0, 2.5), Vector3(0, 6.8, 0))
			_make_streaks(Vector3(0, 1.3, 0), 11.0, 1.4, Color(1, 1, 1, 0.5))
		"wind_tunnel":
			load_model("wind_tunnel")
			add_box(Vector3(3.4, 0.5, 2.0), Vector3(0, 0.25, 0))
			zone = add_area_box(Vector3(3.0, 9.0, 2.5), Vector3(0, 5.0, 0))
			_make_streaks(Vector3(0, 0.5, 0), 9.0, 1.4, Color(0.7, 1.0, 1.0, 0.55))
		"thruster":
			load_model("thruster")
			spin_part = part("Flame")
			zone = add_area_box(Vector3(2.6, 9.0, 2.5), Vector3(0, 5.0, 0))
			_make_streaks(Vector3(0, 1.0, 0), 9.0, 1.0, Color(1.0, 0.8, 0.3, 0.6))
		"wind":
			zone = add_area_box(Vector3(16, 16, 3), Vector3(0, 8, 0))
			_make_wind()
		"lowgrav":
			zone = add_area_box(Vector3(14, 30, 3), Vector3(0, 15, 0))
			_make_lowgrav_visual()
		"booster":
			load_model("booster_ring")
			spin_part = part("Body")
			var a := add_area_sphere(1.3, Vector3.ZERO)
			trigger_on_enter(a)


func _physics_process(_dt: float) -> void:
	if zone == null:
		return
	var r := riley_ref()
	if r == null:
		return
	var inside := zone.overlaps_body(r as Node3D)
	if inside:
		var world_dir := (global_transform.basis * dir).normalized()
		if kind == "wind":
			world_dir = dir
		if strength > 0.0:
			r.call("add_zone_force", world_dir * strength)
		if low_gravity > 0.0:
			r.call("set_zone_gravity", low_gravity)
		if not entered:
			entered = true
			if interaction_points > 0 and game and game.has_method("on_interaction"):
				game.call("on_interaction", self, interaction_points)
			if kind == "fan" or kind == "wind_tunnel":
				Audio.play("whoosh", -2.0)
	elif entered and kind != "booster":
		entered = false


func _process(dt: float) -> void:
	if spin_part:
		if kind == "booster":
			spin_part.rotation.x += dt * 2.5
		elif kind == "thruster":
			spin_part.scale = Vector3(1.0, 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.03), 1.0)
		else:
			spin_part.rotation.y += dt * 14.0


func surface_normal(_p: Vector3) -> Vector3:
	if kind == "booster":
		return (global_transform.basis * Vector3.RIGHT).normalized()
	return Vector3.ZERO


func on_hit(riley: Node, v_in: Vector3, n: Vector3, q: int, _p: Vector3) -> Vector3:
	if kind == "booster":
		var ax := (global_transform.basis * Vector3.RIGHT).normalized()
		if ax.x < 0.0:
			ax = -ax
		var gw: float = riley.get("world_gravity")
		return ax * maxf(v_in.length() + 12.0, 24.0 * pow(gw, 0.2))
	# landing on top of a fan or tunnel base: cushioned hop
	return Landing.bounce(v_in, n, q, 0.6, 9.0, 7.0)


func react(_q: int, _p: Vector3) -> void:
	if kind == "booster":
		Audio.play("rocket", -3.0, 1.3)
		if game and game.has_method("on_interaction"):
			game.call("on_interaction", self, interaction_points)
		var b := part("Body")
		if b:
			squash(b, -0.2, 0.4)
	else:
		Audio.play("soft_land")


func _particle_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


func _make_streaks(origin: Vector3, height: float, width: float, c: Color) -> void:
	particles = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.9)
	q.material = _particle_material(c)
	particles.mesh = q
	particles.amount = 28
	particles.lifetime = height / 14.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(width, 0.1, 0.6)
	particles.direction = Vector3.UP
	particles.spread = 4.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 13.0
	particles.initial_velocity_max = 15.0
	particles.position = origin
	particles.local_coords = true
	add_child(particles)


func _make_wind() -> void:
	particles = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 0.05)
	q.material = _particle_material(Color(1, 1, 1, 0.55))
	particles.mesh = q
	particles.amount = 36
	particles.lifetime = 1.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(8, 8, 1)
	particles.direction = Vector3(signf(dir.x), 0.1, 0)
	particles.spread = 3.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 14.0
	particles.initial_velocity_max = 18.0
	particles.position = Vector3(0, 8, 0)
	add_child(particles)


func _make_lowgrav_visual() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(14, 30, 0.2)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.35, 1.0, 0.12)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0, 15, -1.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	particles = CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.16
	s.radial_segments = 6
	s.rings = 3
	s.material = _particle_material(Color(0.8, 0.7, 1.0, 0.9))
	particles.mesh = s
	particles.amount = 24
	particles.lifetime = 3.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(7, 15, 1)
	particles.gravity = Vector3(0, 0.6, 0)
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.6
	particles.position = Vector3(0, 15, 0)
	add_child(particles)
