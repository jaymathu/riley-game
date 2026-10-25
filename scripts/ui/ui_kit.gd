class_name UIKit
extends RefCounted
## Shared look for every screen: chunky navy panels, sun-yellow buttons, Lilita One headings.

const NAVY := Color("#0F3F86")
const EDGE := Color("#0A2C63")
const SKY := Color("#2F86E6")
const SKY_DEEP := Color("#155BB5")
const SUN := Color("#FFD22E")
const RED := Color("#E8342C")
const GREEN := Color("#3DBB4E")
const WHITE := Color("#FFFFFF")
const MUTED := Color("#BCD8FF")
const SHADE := Color(0.02, 0.1, 0.25, 0.55)


static func box(bg: Color, border := EDGE, radius := 22, border_w := 5, shadow := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(EDGE, 0.9)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, shadow)
	if shadow > 0:
		s.shadow_size = 1
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Assets.font_body
	t.default_font_size = 26
	t.set_color("font_color", "Label", WHITE)
	t.set_stylebox("panel", "PanelContainer", box(NAVY))
	var grab := box(SUN, EDGE, 16, 4, 0)
	grab.content_margin_left = 0
	t.set_stylebox("slider", "HSlider", box(SKY_DEEP, EDGE, 10, 3, 0))
	t.set_stylebox("grabber_area", "HSlider", box(SUN, EDGE, 10, 3, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(SUN, EDGE, 10, 3, 0))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_stylebox("panel", "TabContainer", box(NAVY, EDGE, 18, 4, 0))
	return t


static func label(text: String, size := 28, color := WHITE, display := true, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Assets.font_display if display else Assets.font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", EDGE)
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, color := SUN, size := 32, min_size := Vector2(240, 72)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", Assets.font_display)
	b.add_theme_font_size_override("font_size", size)
	var dark := color.get_luminance() > 0.6
	var fc := EDGE if dark else WHITE
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.5))
	b.add_theme_stylebox_override("normal", box(color, EDGE, 20, 5, 6))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.08), EDGE, 20, 5, 6))
	var pressed := box(color.darkened(0.08), EDGE, 20, 5, 2)
	pressed.content_margin_top = 14
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), WHITE, 22, 3, 0))
	b.add_theme_stylebox_override("disabled", box(color.darkened(0.35), EDGE, 20, 5, 6))
	b.pressed.connect(func() -> void: Audio.click())
	return b


static func icon(tex: Texture2D, size := 96) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel(bg := NAVY) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg))
	return p


static func coin_pill(size := 30) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon(Assets.icon("coin"), size + 10))
	var l := label("0", size, SUN)
	l.name = "Amount"
	h.add_child(l)
	return h


static func pop(c: Control, amount := 1.12, time := 0.25) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * amount, time * 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(c, "scale", Vector2.ONE, time * 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
