class_name HUD
extends Control
## In-run overlay. All touch handling is done by Game; HUD only draws and offers hit tests,
## so multitouch rotation and the gadget button never fight over the same finger.


class PowerMeter extends Control:
	var value := 0.0
	var locked := -1.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UIKit.box(UIKit.NAVY, UIKit.EDGE, 18, 5, 0), r)
		var inner := r.grow(-12)
		var steps := 24
		for i in steps:
			var t := float(i) / steps
			var c := Color(0.25, 0.85, 0.35).lerp(UIKit.SUN, clampf(t * 1.6, 0, 1)).lerp(UIKit.RED, clampf((t - 0.6) * 2.5, 0, 1))
			var h := inner.size.y / steps
			var y := inner.end.y - (i + 1) * h
			var on := t <= value
			draw_rect(Rect2(inner.position.x, y + 1, inner.size.x, h - 2), c if on else Color(c, 0.18))
		var my := inner.end.y - value * inner.size.y
		draw_rect(Rect2(r.position.x - 6, my - 4, r.size.x + 12, 8), UIKit.WHITE)
		if locked >= 0.0:
			var ly := inner.end.y - locked * inner.size.y
			draw_rect(Rect2(r.position.x - 10, ly - 5, r.size.x + 20, 10), UIKit.SUN)


class AngleMeter extends Control:
	var angle := 45.0

	func _draw() -> void:
		var c := Vector2(18, size.y - 18)
		var rad := size.y - 36
		draw_circle(c, rad + 14, Color(UIKit.EDGE, 0.85))
		draw_arc(c, rad, -deg_to_rad(75), -deg_to_rad(15), 32, Color(UIKit.MUTED, 0.5), 18.0)
		draw_arc(c, rad, -deg_to_rad(52), -deg_to_rad(38), 12, Color(UIKit.GREEN, 0.9), 18.0)
		var a := -deg_to_rad(angle)
		var tip := c + Vector2(cos(a), sin(a)) * (rad + 10)
		draw_line(c, tip, UIKit.SUN, 9.0, true)
		draw_circle(c, 12, UIKit.SUN)
		draw_string(Assets.font_display, c + Vector2(30, -12), "%d°" % int(round(angle)), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIKit.WHITE)


class GadgetButton extends Control:
	var tex: Texture2D
	var charges := 0
	var max_charges := 0
	var frac := 0.0
	var is_on := true
	var active := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 6
		draw_circle(c + Vector2(0, 6), r, UIKit.EDGE)
		draw_circle(c, r, UIKit.SUN if is_on or active else Color(0.45, 0.5, 0.6))
		draw_arc(c, r, 0, TAU, 48, UIKit.EDGE, 6.0, true)
		if tex:
			var s := r * 1.25
			draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 1.0 if is_on or active else 0.55))
		if frac > 0.001 and frac < 0.999:
			draw_arc(c, r - 8, -PI / 2, -PI / 2 + TAU * frac, 48, UIKit.WHITE if active else UIKit.RED, 10.0, true)
		for i in max_charges:
			var p := c + Vector2((i - (max_charges - 1) * 0.5) * 26, r + 18)
			draw_circle(p, 9, UIKit.EDGE)
			draw_circle(p, 6.5, UIKit.SUN if i < charges else Color(0.4, 0.45, 0.55))


class RotHint extends Control:
	var dir := 1.0
	var held := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 8
		var a := 0.55 if held else 0.22
		draw_circle(c, r, Color(UIKit.EDGE, a * 0.6))
		var start := -PI * 0.9
		var end := PI * 0.4
		draw_arc(c, r * 0.6, start, end, 24, Color(1, 1, 1, a + 0.2), 9.0, true)
		var ang := end if dir < 0 else start
		var p := c + Vector2(cos(ang), sin(ang)) * r * 0.6
		var t := Vector2(-sin(ang), cos(ang)) * (1.0 if dir < 0 else -1.0)
		var n := Vector2(cos(ang), sin(ang))
		draw_colored_polygon(PackedVector2Array([p + t * 22, p + n * 14, p - n * 14]), Color(1, 1, 1, a + 0.2))


class SpeedLines extends Control:
	var amount := 0.0
	var _seed := 0.0

	func _process(dt: float) -> void:
		_seed += dt
		if amount > 0.02:
			queue_redraw()

	func _draw() -> void:
		if amount <= 0.02:
			return
		var c := size * 0.5
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_seed * 20.0)
		var n := int(18 * amount)
		for i in n:
			var a := rng.randf() * TAU
			var dir := Vector2(cos(a), sin(a))
			var r0 := size.length() * rng.randf_range(0.36, 0.48)
			var r1 := r0 + size.length() * rng.randf_range(0.05, 0.12)
			draw_line(c + dir * r0, c + dir * r1, Color(1, 1, 1, 0.35 * amount), rng.randf_range(2.0, 5.0))


var game: Node
var distance_label: Label
var score_label: Label
var combo_badge: Label
var combo_bar: ColorRect
var combo_bar_bg: ColorRect
var coin_box: HBoxContainer
var pause_btn: Button
var gadget_btn: GadgetButton
var power_meter: PowerMeter
var angle_meter: AngleMeter
var hint_label: Label
var popup_label: Label
var flip_label: Label
var rot_left: RotHint
var rot_right: RotHint
var speed_lines: SpeedLines
var aim_box: Control
var _last_combo := 0
var _last_coins := 0
var _rot_fade := 0.0


func _ready() -> void:
	UIKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_lines = SpeedLines.new()
	UIKit.full_rect(speed_lines)
	speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(speed_lines)

	var margin := MarginContainer.new()
	UIKit.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)

	# top bar
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(top)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	top.add_child(left)
	var sp := UIKit.panel()
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	score_label = UIKit.label("0", 34, UIKit.WHITE)
	sp.add_child(score_label)
	left.add_child(sp)
	var crow := HBoxContainer.new()
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_badge = UIKit.label("x1", 44, UIKit.SUN, true, 12)
	crow.add_child(combo_badge)
	var barwrap := Control.new()
	barwrap.custom_minimum_size = Vector2(120, 16)
	barwrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_bar_bg = ColorRect.new()
	combo_bar_bg.color = Color(UIKit.EDGE, 0.7)
	combo_bar_bg.size = Vector2(120, 14)
	combo_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barwrap.add_child(combo_bar_bg)
	combo_bar = ColorRect.new()
	combo_bar.color = UIKit.SUN
	combo_bar.size = Vector2(120, 14)
	combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barwrap.add_child(combo_bar)
	crow.add_child(barwrap)
	left.add_child(crow)

	var mid := CenterContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(mid)
	var dp := UIKit.panel()
	dp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_label = UIKit.label("0 m", 48, UIKit.WHITE, true, 10)
	dp.add_child(distance_label)
	mid.add_child(dp)

	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(right)
	var cp := UIKit.panel()
	cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_box = UIKit.coin_pill(30)
	cp.add_child(coin_box)
	right.add_child(cp)
	pause_btn = UIKit.button("II", UIKit.SUN, 32, Vector2(76, 70))
	pause_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_btn.focus_mode = Control.FOCUS_NONE
	right.add_child(pause_btn)

	# gadget button
	gadget_btn = GadgetButton.new()
	gadget_btn.custom_minimum_size = Vector2(150, 150)
	gadget_btn.size = Vector2(150, 150)
	gadget_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gadget_btn)

	# rotation hints
	rot_left = RotHint.new()
	rot_left.dir = 1.0
	rot_right = RotHint.new()
	rot_right.dir = -1.0
	for h in [rot_left, rot_right]:
		(h as Control).size = Vector2(150, 150)
		(h as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)

	# aiming meters
	aim_box = Control.new()
	aim_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(aim_box)
	power_meter = PowerMeter.new()
	power_meter.size = Vector2(70, 300)
	power_meter.position = Vector2(0, 0)
	aim_box.add_child(power_meter)
	angle_meter = AngleMeter.new()
	angle_meter.size = Vector2(230, 230)
	angle_meter.position = Vector2(100, 70)
	aim_box.add_child(angle_meter)
	var pl := UIKit.label("POWER", 22, UIKit.WHITE)
	pl.position = Vector2(-4, 306)
	aim_box.add_child(pl)

	hint_label = UIKit.label("", 40, UIKit.WHITE, true, 12)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_label)
	popup_label = UIKit.label("", 72, UIKit.SUN, true, 16)
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(popup_label)
	flip_label = UIKit.label("", 44, UIKit.WHITE, true, 12)
	flip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(flip_label)
	get_viewport().size_changed.connect(_layout)
	Save.settings_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	var lefty := bool(Save.setting("left_handed"))
	var gx := 40.0 if lefty else s.x - 190.0
	gadget_btn.position = Vector2(gx, s.y - 200.0)
	rot_left.position = Vector2(30.0 if not lefty else 220.0, s.y - 180.0)
	rot_right.position = Vector2(s.x - 180.0 if lefty else s.x - 380.0, s.y - 180.0)
	aim_box.position = Vector2(40, s.y - 380.0)
	hint_label.position = Vector2(0, s.y - 120.0)
	hint_label.size = Vector2(s.x, 60)
	popup_label.position = Vector2(0, s.y * 0.24)
	popup_label.size = Vector2(s.x, 90)
	popup_label.pivot_offset = Vector2(s.x * 0.5, 45)
	flip_label.position = Vector2(0, s.y * 0.24 + 90)
	flip_label.size = Vector2(s.x, 60)
	flip_label.pivot_offset = Vector2(s.x * 0.5, 30)


func bind(g: Node) -> void:
	game = g
	var rl: RileyPlayer = game.get("riley")
	var gc := rl.gadget
	gadget_btn.tex = Assets.icon(String(gc.def.get("icon", "umbrella")))
	gadget_changed()
	aim_box.visible = true
	aim_box.modulate.a = 1.0
	angle_meter.visible = false
	gadget_btn.visible = false
	rot_left.visible = false
	rot_right.visible = false
	power_meter.locked = -1.0


func set_power(v: float) -> void:
	power_meter.value = v
	power_meter.queue_redraw()


func lock_power(v: float) -> void:
	power_meter.locked = v
	power_meter.queue_redraw()
	angle_meter.visible = true


func set_angle(a: float) -> void:
	angle_meter.angle = a
	angle_meter.queue_redraw()


func on_launched() -> void:
	var tw := create_tween()
	tw.tween_property(aim_box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: aim_box.visible = false)
	gadget_btn.visible = true
	rot_left.visible = true
	rot_right.visible = true
	_rot_fade = 6.0


func set_hint(t: String) -> void:
	hint_label.text = t
	if t != "":
		UIKit.pop(hint_label, 1.08)


func gadget_changed() -> void:
	if game == null:
		return
	var rl: RileyPlayer = game.get("riley")
	var gc := rl.gadget
	gadget_btn.charges = gc.charges
	gadget_btn.max_charges = gc.max_charges
	gadget_btn.queue_redraw()


func set_rotation_feedback(l: bool, r: bool) -> void:
	if rot_left.held != l or rot_right.held != r:
		rot_left.held = l
		rot_right.held = r
		rot_left.queue_redraw()
		rot_right.queue_redraw()


func update_stats(score: int, dist: int, mult: int, frac: float, coins: int, speed: float) -> void:
	score_label.text = UIKit.fmt(score)
	distance_label.text = "%d m" % dist
	combo_badge.text = "x%d" % mult
	combo_badge.modulate = Color(1, 1, 1, 1.0 if mult > 1 else 0.55)
	if mult != _last_combo:
		if mult > _last_combo:
			UIKit.pop(combo_badge, 1.35, 0.35)
		_last_combo = mult
	combo_bar.size.x = 120.0 * clampf(frac, 0.0, 1.0)
	var amt := coin_box.get_node("Amount") as Label
	amt.text = str(coins)
	if coins != _last_coins:
		_last_coins = coins
		UIKit.pop(coin_box, 1.15, 0.2)
	speed_lines.amount = clampf((speed - 26.0) / 22.0, 0.0, 1.0)
	if game:
		var rl: RileyPlayer = game.get("riley")
		var gc := rl.gadget
		gadget_btn.frac = gc.cooldown_frac()
		gadget_btn.is_on = gc.is_ready()
		gadget_btn.active = gc.active > 0.0
		gadget_btn.charges = gc.charges
		gadget_btn.queue_redraw()


func _process(dt: float) -> void:
	if _rot_fade > 0.0:
		_rot_fade -= dt
		var a := clampf(_rot_fade / 1.5, 0.35, 1.0)
		rot_left.modulate.a = a
		rot_right.modulate.a = a


func popup(text: String, color: Color, big := false) -> void:
	popup_label.text = text
	popup_label.add_theme_color_override("font_color", color)
	popup_label.add_theme_font_size_override("font_size", 84 if big else 64)
	popup_label.modulate.a = 1.0
	popup_label.scale = Vector2.ONE * 0.3
	popup_label.rotation = randf_range(-0.06, 0.06)
	var tw := popup_label.create_tween()
	tw.tween_property(popup_label, "scale", Vector2.ONE * 1.1, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup_label, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.6)
	tw.tween_property(popup_label, "modulate:a", 0.0, 0.3)


func flip_popup(text: String) -> void:
	flip_label.text = text
	flip_label.modulate.a = 1.0
	flip_label.scale = Vector2.ONE * 0.5
	var tw := flip_label.create_tween()
	tw.tween_property(flip_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(flip_label, "modulate:a", 0.0, 0.25)


func hit_pause(pos: Vector2) -> bool:
	return pause_btn.get_global_rect().grow(18).has_point(pos)


func hit_gadget(pos: Vector2) -> bool:
	if not gadget_btn.visible:
		return false
	var c := gadget_btn.get_global_rect().get_center()
	return pos.distance_to(c) < 95.0
