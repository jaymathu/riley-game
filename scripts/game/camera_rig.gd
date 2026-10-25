class_name CameraRig
extends Camera3D
## Side-on 2.5D follow camera: speed/altitude zoom, look-ahead, framing of the next landing spot,
## trauma-based shake and a short punch-in on big impacts.

var target: Node3D
var focus_hint := Vector3.ZERO   # next landing opportunity (world), or ZERO
var dist := 15.0
var look := 3.0
var fy := 3.0
var fx := 0.0
var trauma := 0.0
var punch := 0.0
var _t := 0.0
var mode := "launch"


func _ready() -> void:
	fov = 50.0
	near = 0.3
	far = 600.0


func snap() -> void:
	if target == null:
		return
	var p := _target_pos()
	fx = p.x + 6.0
	fy = maxf(p.y + 1.5, 3.0)
	dist = 15.0
	_apply(0.0)


func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)


func add_punch(a: float) -> void:
	punch = clampf(punch + a, 0.0, 0.25)


func _target_pos() -> Vector3:
	if target and target.has_method("center"):
		return target.call("center")
	return target.global_position if target else Vector3.ZERO


func _target_vel() -> Vector3:
	if target and target.has_method("velocity_now"):
		return target.call("velocity_now")
	return Vector3.ZERO


func _process(dt: float) -> void:
	if target == null:
		return
	_t += dt
	var p := _target_pos()
	var v := _target_vel()
	var speed := v.length()
	var alt := maxf(p.y, 0.0)
	var want_dist := clampf(12.5 + speed * 0.3 + alt * 0.42, 12.5, 46.0)
	var want_look := clampf(v.x * 0.42, -3.0, 13.0)
	var want_fx := p.x + want_look
	var want_fy := maxf(p.y * 0.62 + 2.4, 3.2)
	if mode == "launch":
		want_dist = 13.5
		want_fx = p.x + 5.0
		want_fy = maxf(p.y + 1.0, 3.2)
	elif focus_hint != Vector3.ZERO and v.y < 2.0:
		# pull the frame toward the next landing spot so it is visible before arriving
		var gap := focus_hint.x - p.x
		if gap > 0.0 and gap < 40.0:
			want_fx = lerpf(want_fx, (p.x + focus_hint.x) * 0.5, 0.45)
			want_dist = maxf(want_dist, gap * 0.55 + 10.0)
	dist = lerpf(dist, want_dist, 1.0 - exp(-1.6 * dt))
	look = lerpf(look, want_look, 1.0 - exp(-2.0 * dt))
	fx = lerpf(fx, want_fx, 1.0 - exp(-5.0 * dt))
	fy = lerpf(fy, want_fy, 1.0 - exp(-3.2 * dt))
	_apply(dt)


func _apply(dt: float) -> void:
	trauma = maxf(0.0, trauma - dt * 1.6)
	punch = maxf(0.0, punch - dt * 0.9)
	var d := dist * (1.0 - punch)
	var shake := trauma * trauma
	var sx := (sin(_t * 47.0) + sin(_t * 31.0 + 1.3)) * 0.5 * shake * 0.9
	var sy := (sin(_t * 53.0 + 0.7) + sin(_t * 29.0)) * 0.5 * shake * 0.9
	var eye := Vector3(fx + sx, fy + d * 0.16 + sy, d)
	global_position = eye
	look_at(Vector3(fx + sx * 0.5, fy + sy * 0.5, 0.0), Vector3.UP)
