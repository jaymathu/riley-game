class_name SettingsPanel
extends RefCounted
## Settings rows shared by the main menu and the pause screen.


static func build_common(content: VBoxContainer, reopen: Callable) -> void:
	slider(content, "Music volume", "music", 0.0, 1.0)
	slider(content, "Sound effects volume", "sfx", 0.0, 1.0)
	slider(content, "Touch sensitivity", "sensitivity", 0.5, 1.5)
	slider(content, "Air rotation strength", "rotation", 0.6, 1.4)
	toggle(content, "Vibration", "vibration")
	toggle(content, "Left-handed layout (gadget button on the left)", "left_handed")
	quality_row(content, reopen)


static func quality_row(content: VBoxContainer, reopen: Callable) -> void:
	var q := HBoxContainer.new()
	var ql := UIKit.label("Graphics quality", 26, UIKit.WHITE, false, 0)
	ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q.add_child(ql)
	var names := ["LOW", "MEDIUM", "HIGH"]
	for i in 3:
		var lvl: int = i
		var b := UIKit.button(String(names[i]), UIKit.SUN if int(Save.setting("quality")) == i else UIKit.SKY, 22, Vector2(150, 54))
		b.pressed.connect(func() -> void:
			Save.set_setting("quality", lvl)
			reopen.call())
		q.add_child(b)
	content.add_child(q)
	content.add_child(UIKit.label("Graphics changes apply from the next run.", 18, UIKit.MUTED, false, 0))


static func slider(parent: VBoxContainer, text: String, key: String, lo: float, hi: float) -> void:
	var h := HBoxContainer.new()
	var l := UIKit.label(text, 26, UIKit.WHITE, false, 0)
	l.custom_minimum_size = Vector2(380, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Save.setting(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(300, 48)
	s.value_changed.connect(func(v: float) -> void: Save.set_setting(key, v))
	h.add_child(s)
	parent.add_child(h)


static func toggle(parent: VBoxContainer, text: String, key: String) -> void:
	var h := HBoxContainer.new()
	var l := UIKit.label(text, 26, UIKit.WHITE, false, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var on := bool(Save.setting(key))
	var b := UIKit.button("ON" if on else "OFF", UIKit.GREEN if on else UIKit.EDGE, 22, Vector2(130, 54))
	b.pressed.connect(func() -> void:
		var nv := not bool(Save.setting(key))
		Save.set_setting(key, nv)
		b.text = "ON" if nv else "OFF"
		var col := UIKit.GREEN if nv else UIKit.EDGE
		b.add_theme_stylebox_override("normal", UIKit.box(col, UIKit.EDGE, 20, 5, 6))
		b.add_theme_stylebox_override("hover", UIKit.box(col, UIKit.EDGE, 20, 5, 6)))
	h.add_child(b)
	parent.add_child(h)
