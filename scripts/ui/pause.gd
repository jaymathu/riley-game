class_name PauseScreen
extends Control
## Pause overlay (also shown automatically when the app goes to the background).

signal resume
signal restart
signal quit_to_menu

var seed_text := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func open(seed_value: int) -> void:
	seed_text = "Level seed %d" % seed_value
	_build_main()


func _clear() -> VBoxContainer:
	for c in get_children():
		c.queue_free()
	UIKit.full_rect(self)
	var dim := ColorRect.new()
	dim.color = UIKit.SHADE
	UIKit.full_rect(dim)
	add_child(dim)
	var center := CenterContainer.new()
	UIKit.full_rect(center)
	add_child(center)
	var panel := UIKit.panel()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	return v


func _build_main() -> void:
	var v := _clear()
	var t := UIKit.label("PAUSED", 60, UIKit.SUN, true, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r := UIKit.button("RESUME", UIKit.SUN, 36, Vector2(360, 80))
	r.pressed.connect(func() -> void: resume.emit())
	v.add_child(r)
	var rs := UIKit.button("RESTART", UIKit.SKY, 30, Vector2(360, 70))
	rs.pressed.connect(func() -> void: restart.emit())
	v.add_child(rs)
	var st := UIKit.button("SETTINGS", UIKit.SKY, 30, Vector2(360, 70))
	st.pressed.connect(_build_settings)
	v.add_child(st)
	var m := UIKit.button("MAIN MENU", UIKit.SKY, 30, Vector2(360, 70))
	m.pressed.connect(func() -> void: quit_to_menu.emit())
	v.add_child(m)
	var sl := UIKit.label(seed_text, 18, UIKit.MUTED, false, 0)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sl)
	r.grab_focus()


func _build_settings() -> void:
	var v := _clear()
	var head := HBoxContainer.new()
	var b := UIKit.button("BACK", UIKit.SUN, 26, Vector2(150, 60))
	b.pressed.connect(_build_main)
	head.add_child(b)
	var t := UIKit.label("SETTINGS", 44, UIKit.SUN, true, 10)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	v.add_child(head)
	v.custom_minimum_size = Vector2(900, 0)
	SettingsPanel.build_common(v, _build_settings)


func handle_back() -> bool:
	if get_child_count() > 0 and visible:
		resume.emit()
		return true
	return false
