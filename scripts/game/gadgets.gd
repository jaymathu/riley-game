class_name GadgetController
extends Node3D
## The equipped mid-air gadget: charges, cooldown, effect on Riley's physics and its 3D model.

signal changed

var riley: RileyPlayer
var id := ""
var def: Dictionary = {}
var charges := 0
var max_charges := 0
var active := 0.0
var cooldown := 0.0
var eff := 0
var worn: Array = []          # models always visible while equipped (shoes, hat, gun)
var effect_model: Node3D      # umbrella / balloon shown while active
var flames: Array = []
var prop_spin: Node3D
var plunger_target := Vector3.ZERO
var has_target := false
var rope: MeshInstance3D
var game: Node


func setup(r: RileyPlayer, gadget_id: String, efficiency: int, game_ref: Node) -> void:
	riley = r
	game = game_ref
	id = gadget_id
	def = Catalog.GADGETS.get(id, {})
	eff = efficiency
	if def.is_empty():
		return
	max_charges = int(def["charges"]) + (1 if eff >= 2 else 0) + (1 if eff >= 4 else 0)
	charges = max_charges
	_spawn_models()
	changed.emit()


func duration() -> float:
	return float(def.get("duration", 1.0)) * (1.0 + 0.12 * eff)


func cooldown_frac() -> float:
	var cd := float(def.get("cooldown", 1.0))
	if active > 0.0:
		return 1.0 - active / maxf(duration(), 0.01)
	return clampf(cooldown / maxf(cd, 0.01), 0.0, 1.0)


func is_ready() -> bool:
	return charges > 0 and cooldown <= 0.0 and active <= 0.0 and riley != null and riley.is_flying()


func activate() -> bool:
	if not is_ready():
		return false
	match id:
		"plunger":
			var t: Variant = game.call("find_plunger_target", riley.global_position) if game else null
			if t == null:
				Audio.play("ui_back")
				return false
			plunger_target = t
			has_target = true
			Audio.play("plunger")
		"mattress":
			if game:
				game.call("spawn_emergency_mattress", riley.global_position + Vector3(0.6, -2.2, 0))
			Audio.play("inflate")
		"umbrella":
			Audio.play("umbrella")
		"rocket":
			Audio.play("rocket")
		"balloon":
			Audio.play("balloon")
		"propeller":
			Audio.play("gadget_whoosh")
	charges -= 1
	active = duration()
	cooldown = float(def.get("cooldown", 1.0))
	Audio.voice("voice_woohoo", 0.6)
	_show_effect(true)
	changed.emit()
	if game and game.has_method("on_gadget_used"):
		game.call("on_gadget_used", id)
	return true


func _physics_process(dt: float) -> void:
	if riley == null:
		return
	if active <= 0.0:
		cooldown = maxf(0.0, cooldown - dt)
	riley.fall_cap = 0.0
	riley.gadget_gravity = 1.0
	riley.stabilize = 0.0
	riley.steer = 0.0
	if active > 0.0:
		if not riley.is_flying():
			_end()
			return
		active -= dt
		match id:
			"umbrella":
				riley.fall_cap = maxf(1.8, 3.4 - eff * 0.25)
				riley.steer = 5.0 + eff
			"rocket":
				riley.add_zone_force(Vector3(1.0, 0.32, 0.0).normalized() * (58.0 + eff * 7.0))
			"balloon":
				riley.gadget_gravity = maxf(0.12, 0.26 - eff * 0.025)
				riley.add_zone_force(Vector3(3.0, 0, 0))
			"propeller":
				riley.stabilize = 1.0
				riley.gadget_gravity = 0.8
				riley.steer = -riley.rot_input * (16.0 + eff * 2.0)
			"plunger":
				if has_target:
					var d := plunger_target - riley.global_position
					if d.length() < 2.0:
						active = 0.0
					else:
						riley.add_zone_force(d.normalized() * (85.0 + eff * 8.0) + Vector3(0, 9.8 * Landing.GRAVITY_SCALE * 0.6, 0))
		if active <= 0.0:
			_end()


func _end() -> void:
	active = 0.0
	has_target = false
	_show_effect(false)
	changed.emit()


func _process(dt: float) -> void:
	if riley == null:
		return
	if effect_model and effect_model.visible:
		if id == "umbrella":
			effect_model.global_position = riley.global_position + Vector3(0.15, 0.55, 0)
		elif id == "balloon":
			var hand := riley.visual.bone_global("hand.R").origin
			effect_model.global_position = hand
	if prop_spin:
		prop_spin.rotation.y += dt * (40.0 if active > 0.0 else 3.0)
	if rope:
		rope.visible = active > 0.0 and has_target
		if rope.visible:
			var a := riley.visual.bone_global("hand.R").origin
			var b := plunger_target
			var mid := (a + b) * 0.5
			var dist_len := a.distance_to(b)
			var y := (b - a).normalized()
			var x := y.cross(Vector3.BACK).normalized()
			if x.length() < 0.01:
				x = Vector3.RIGHT
			var z := x.cross(y)
			rope.global_transform = Transform3D(Basis(x, y * dist_len, z), mid)


func _spawn_models() -> void:
	match id:
		"umbrella":
			effect_model = Assets.prop("umbrella")
		"balloon":
			effect_model = Assets.prop("balloon")
		"rocket":
			for bone in ["shin.L", "shin.R"]:
				var holder := Node3D.new()
				var m := Assets.prop("rocket_shoe")
				m.rotation.x = PI
				m.scale = Vector3.ONE * 0.9
				holder.add_child(m)
				add_child(holder)
				riley.visual.follow(holder, bone, 0.15)
				worn.append(holder)
				var f := m.find_child("Flame", true, false) as Node3D
				if f:
					f.visible = false
					flames.append(f)
		"propeller":
			var hat := Assets.prop("propeller_hat")
			add_child(hat)
			riley.visual.follow(hat, "head", 0.38)
			worn.append(hat)
			prop_spin = hat.find_child("Prop", true, false) as Node3D
			if riley.visual.hat:
				riley.visual.hat.visible = false
		"plunger":
			var gun := Assets.prop("plunger_gun")
			add_child(gun)
			riley.visual.follow(gun, "hand.R", 0.04)
			worn.append(gun)
			rope = MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.025
			cyl.bottom_radius = 0.025
			cyl.height = 1.0
			cyl.radial_segments = 6
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.85, 0.3)
			cyl.material = mat
			rope.mesh = cyl
			rope.top_level = true
			rope.visible = false
			add_child(rope)
	if effect_model:
		effect_model.top_level = true
		effect_model.visible = false
		add_child(effect_model)


func _show_effect(on: bool) -> void:
	for f in flames:
		(f as Node3D).visible = on
	if effect_model:
		if on:
			effect_model.visible = true
			effect_model.scale = Vector3.ONE * 0.05
			var tw := create_tween()
			tw.tween_property(effect_model, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			effect_model.visible = false
