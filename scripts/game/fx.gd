class_name FX
extends Node3D
## Pooled particle bursts and floating 3D point labels.

var _pool: Array[CPUParticles3D] = []
var _labels: Array[Label3D] = []
var quality := 1
var _sphere_mat: StandardMaterial3D
var _quad_mat: StandardMaterial3D


func _ready() -> void:
	_sphere_mat = StandardMaterial3D.new()
	_sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sphere_mat.vertex_color_use_as_albedo = true
	_quad_mat = _sphere_mat.duplicate() as StandardMaterial3D
	_quad_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _get_particles() -> CPUParticles3D:
	for p in _pool:
		if not p.emitting:
			return p
	var np := CPUParticles3D.new()
	np.one_shot = true
	np.emitting = false
	np.local_coords = false
	np.explosiveness = 0.9
	add_child(np)
	_pool.append(np)
	return np


func burst(pos: Vector3, color: Color, amount := 22, speed := 7.0, size := 0.13, grav := -12.0, life := 0.7,
		shape := "sphere", spread := 180.0, dir := Vector3.UP, color2 := Color(0, 0, 0, 0)) -> void:
	var p := _get_particles()
	if shape == "quad":
		var q := QuadMesh.new()
		q.size = Vector2(size * 1.6, size)
		q.material = _quad_mat
		p.mesh = q
	else:
		var s := SphereMesh.new()
		s.radius = size
		s.height = size * 2.0
		s.radial_segments = 6
		s.rings = 3
		s.material = _sphere_mat
		p.mesh = s
	p.amount = maxi(4, int(amount * (0.5 if quality == 0 else 1.0)))
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.gravity = Vector3(0, grav, 0)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.angular_velocity_min = -360.0 if shape == "quad" else 0.0
	p.angular_velocity_max = 360.0 if shape == "quad" else 0.0
	p.damping_min = 1.0
	p.damping_max = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	p.color = color
	if color2.a > 0.0:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([color, color2])
		p.color_initial_ramp = g
	else:
		p.color_initial_ramp = null
	p.global_position = pos
	p.restart()
	p.emitting = true


func dust(pos: Vector3) -> void:
	burst(pos, Color(0.85, 0.78, 0.62), 18, 5.0, 0.16, -4.0, 0.6)


func smoke(pos: Vector3, dir: Vector3) -> void:
	burst(pos, Color(0.92, 0.92, 0.95), 26, 6.0, 0.32, 1.5, 1.1, "sphere", 25.0, dir)
	burst(pos, Color(1.0, 0.75, 0.2), 14, 9.0, 0.14, -2.0, 0.35, "sphere", 20.0, dir)


func splash(pos: Vector3) -> void:
	burst(pos, Color(0.55, 0.85, 1.0), 34, 11.0, 0.13, -22.0, 0.9, "sphere", 35.0, Vector3.UP)


func confetti(pos: Vector3) -> void:
	burst(pos, Color(1, 0.3, 0.3), 30, 10.0, 0.14, -9.0, 1.2, "quad", 70.0, Vector3.UP, Color(0.3, 0.6, 1.0))
	burst(pos, Color(1, 0.85, 0.2), 20, 9.0, 0.14, -9.0, 1.2, "quad", 70.0, Vector3.UP, Color(0.3, 1.0, 0.4))


func sparkle(pos: Vector3) -> void:
	burst(pos, Color(1.0, 0.95, 0.5), 10, 3.5, 0.08, 0.0, 0.45)


func impact(pos: Vector3, strength: float) -> void:
	burst(pos, Color(1, 1, 1), int(10 + strength * 0.6), 4.0 + strength * 0.15, 0.12, -6.0, 0.5, "sphere", 75.0)


func float_text(pos: Vector3, text: String, color := Color(1, 0.86, 0.2), size := 96) -> void:
	var l: Label3D = null
	for x in _labels:
		if not x.visible:
			l = x
			break
	if l == null:
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font = Assets.font_display
		l.outline_size = 18
		l.outline_modulate = Color(0.04, 0.17, 0.39)
		l.pixel_size = 0.01
		add_child(l)
		_labels.append(l)
	l.text = text
	l.font_size = size
	l.modulate = color
	l.visible = true
	l.global_position = pos
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", pos + Vector3(0, 2.2, 0), 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.7)
	tw.chain().tween_callback(func() -> void: l.visible = false)
