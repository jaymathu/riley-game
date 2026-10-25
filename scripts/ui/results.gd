class_name ResultsScreen
extends Control
## End-of-run summary with counting numbers, record celebration and quick replay.

signal retry
signal upgrades
signal to_menu

var _rows := {}


func show_result(r: Dictionary) -> void:
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
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var record := bool(r.get("distance_record", false)) or bool(r.get("score_record", false))
	var title := UIKit.label("NEW RECORD!" if record else "RUN COMPLETE!", 56, UIKit.SUN, true, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var world_name := String(Catalog.WORLDS[int(r["world"])]["name"])
	var sub := UIKit.label(world_name, 22, UIKit.MUTED, false, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 4)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	v.add_child(gc)
	var w := int(r["world"])
	var rows := [
		["Distance", int(r["distance"]), " m"], ["Highest combo", int(r["best_combo"]), "x"],
		["Successful landings", int(r["landings"]), ""], ["Perfect landings", int(r["perfects"]), ""],
		["Tricks", int(r["tricks"]), ""], ["Coins earned", int(r["coins"]), ""],
		["Personal best", Save.best_distance(w), " m"],
	]
	for row in rows:
		grid.add_child(UIKit.label(String(row[0]), 26, UIKit.WHITE, false, 0))
		var val := UIKit.label("0", 28, UIKit.SUN)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		_count(val, int(row[1]), String(row[2]))
	var score_l := UIKit.label("0", 64, UIKit.WHITE, true, 12)
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(UIKit.label("TOTAL SCORE", 22, UIKit.MUTED, false, 0))
	(v.get_child(v.get_child_count() - 1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score_l)
	_count(score_l, int(r["score"]), "", 1.2)
	if int(r.get("unlocked_world", -1)) >= 0:
		var ul := UIKit.label("World unlocked: " + String(Catalog.WORLDS[int(r["unlocked_world"])]["name"]) + "!", 28, UIKit.GREEN)
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ul)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(btns)
	var rb := UIKit.button("RETRY", UIKit.SUN, 34, Vector2(220, 76))
	rb.pressed.connect(func() -> void: retry.emit())
	btns.add_child(rb)
	var ub := UIKit.button("UPGRADES", UIKit.SKY, 28, Vector2(220, 76))
	ub.pressed.connect(func() -> void: upgrades.emit())
	btns.add_child(ub)
	var mb := UIKit.button("MENU", UIKit.SKY, 28, Vector2(180, 76))
	mb.pressed.connect(func() -> void: to_menu.emit())
	btns.add_child(mb)
	panel.scale = Vector2.ONE * 0.85
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	if record:
		Audio.play("new_record")
		var t2 := create_tween().set_loops(4)
		t2.tween_property(title, "modulate", Color(1, 0.6, 0.6), 0.2)
		t2.tween_property(title, "modulate", Color(1, 1, 1), 0.2)
	rb.grab_focus()


func _count(l: Label, target: int, suffix: String, dur := 0.9) -> void:
	var tw := l.create_tween()
	tw.tween_method(_set_count.bind(l, suffix), 0.0, float(target), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _set_count(x: float, l: Label, suffix: String) -> void:
	var n := int(x)
	l.text = ("x%d" % n) if suffix == "x" else UIKit.fmt(n) + suffix
