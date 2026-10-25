class_name Launcher
extends Node3D
## Riley's homemade cannon. The barrel follows the angle meter while aiming.

var model: Node3D
var barrel: Node3D
var muzzle: Node3D
var smoke: CPUParticles3D


func _ready() -> void:
	model = Assets.prop("launcher")
	model.scale = Vector3.ONE * 1.25
	add_child(model)
	barrel = model.find_child("Barrel", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	var skin := Catalog.cosmetic_def("launcher", Save.cosmetic("launcher"))
	if not skin.is_empty():
		Assets.recolor(model, "Red", Color(String(skin["color"])))
	set_angle(35.0)


func set_angle(deg: float) -> void:
	if barrel:
		barrel.rotation.z = deg_to_rad(deg)


func muzzle_pos() -> Vector3:
	return muzzle.global_position if muzzle else global_position + Vector3(1.5, 1.4, 0)


func dir() -> Vector3:
	if barrel:
		var d := barrel.global_transform.basis.x
		d.z = 0.0
		return d.normalized()
	return Vector3(1, 1, 0).normalized()


func fire() -> void:
	if barrel:
		var p0 := barrel.position
		var back := -barrel.transform.basis.x.normalized() * 0.35
		var tw := create_tween()
		tw.tween_property(barrel, "position", p0 + back, 0.05)
		tw.tween_property(barrel, "position", p0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var tw2 := create_tween()
	tw2.tween_property(model, "rotation:z", 0.08, 0.05)
	tw2.tween_property(model, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
