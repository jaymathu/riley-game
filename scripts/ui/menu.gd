class_name MainMenu
extends Control
## Main menu and its sub-screens: upgrades & style, gadgets, worlds, high scores, settings.

signal play_requested(world: int)

var screen := "main"
var main_box: Control
var sub_layer: Control
var coins_label: Label
var _confirm_reset := false


func _ready() -> void:
	UIKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_main()
	sub_layer = Control.new()
	UIKit.full_rect(sub_layer)
	sub_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub_layer)
	Save.coins_changed.connect(_on_coins)
	_on_coins(Save.coins())


func _on_coins(v: int) -> void:
	if coins_label:
		coins_label.text = UIKit.fmt(v)


func _build_main() -> void:
	main_box = Control.new()
	UIKit.full_rect(main_box)
	main_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_box)
	var margin := MarginContainer.new()
	UIKit.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	main_box.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var logo := UIKit.icon(Assets.texture("res://assets/ui/logo.png"), 120)
	logo.custom_minimum_size = Vector2(470, 230)
	col.add_child(logo)
	var play := UIKit.button("PLAY", UIKit.SUN, 46, Vector2(460, 92))
	play.pressed.connect(func() -> void: play_requested.emit(Save.selected_world()))
	col.add_child(play)
	var wl := UIKit.label(String(Catalog.WORLDS[Save.selected_world()]["name"]), 22, UIKit.MUTED, false, 6)
	wl.name = "WorldName"
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wl.custom_minimum_size = Vector2(460, 0)
	col.add_child(wl)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for item in [["UPGRADES", "upgrades"], ["GADGETS", "gadgets"], ["WORLDS", "worlds"], ["HIGH SCORES", "scores"], ["SETTINGS", "settings"], ["STYLE", "style"]]:
		var b := UIKit.button(String(item[0]), UIKit.SKY, 26, Vector2(224, 62))
		var target: String = item[1]
		b.pressed.connect(func() -> void: open(target))
		grid.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	var cp := UIKit.panel()
	var pill := UIKit.coin_pill(32)
	coins_label = pill.get_node("Amount") as Label
	cp.add_child(pill)
	right.add_child(cp)


func refresh_world_label() -> void:
	var wl := main_box.find_child("WorldName", true, false) as Label
	if wl:
		wl.text = String(Catalog.WORLDS[Save.selected_world()]["name"])


func handle_back() -> bool:
	if screen != "main":
		Audio.back()
		close_sub()
		return true
	return false


func close_sub() -> void:
	for c in sub_layer.get_children():
		c.queue_free()
	screen = "main"
	main_box.visible = true
	refresh_world_label()


## Builds a modal page with title + back button and returns its content box.
func _page(title: String) -> VBoxContainer:
	for c in sub_layer.get_children():
		c.queue_free()
	main_box.visible = false
	var dim := ColorRect.new()
	dim.color = UIKit.SHADE
	UIKit.full_rect(dim)
	sub_layer.add_child(dim)
	var margin := MarginContainer.new()
	UIKit.full_rect(margin)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	sub_layer.add_child(margin)
	var panel := UIKit.panel()
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := UIKit.button("BACK", UIKit.SUN, 26, Vector2(150, 60))
	back.pressed.connect(func() -> void:
		Audio.back()
		close_sub())
	head.add_child(back)
	var t := UIKit.label(title, 44, UIKit.SUN, true, 10)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	var cpill := UIKit.coin_pill(28)
	(cpill.get_node("Amount") as Label).text = UIKit.fmt(Save.coins())
	cpill.name = "Coins"
	head.add_child(cpill)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return content


func _update_page_coins() -> void:
	var c := sub_layer.find_child("Coins", true, false)
	if c:
		(c.get_node("Amount") as Label).text = UIKit.fmt(Save.coins())


func open(which: String) -> void:
	screen = which
	match which:
		"upgrades":
			_open_upgrades()
		"style":
			_open_style("shirt")
		"gadgets":
			_open_gadgets()
		"worlds":
			_open_worlds()
		"scores":
			_open_scores()
		"settings":
			_open_settings()


func _row_card() -> PanelContainer:
	var p := UIKit.panel(UIKit.SKY_DEEP)
	p.add_theme_stylebox_override("panel", UIKit.box(UIKit.SKY_DEEP, UIKit.EDGE, 18, 4, 4))
	return p


# ------------------------------------------------------------ upgrades
func _open_upgrades() -> void:
	var content := _page("UPGRADES")
	for u in Catalog.UPGRADES:
		var id: String = u["id"]
		var card := _row_card()
		var h := HBoxContainer.new()
		card.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		info.add_child(UIKit.label(String(u["name"]), 30))
		info.add_child(UIKit.label(String(u["desc"]), 20, UIKit.MUTED, false, 0))
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 6)
		for i in int(u["max"]):
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(34, 16)
			var on := i < Save.upgrade_level(id)
			pip.add_theme_stylebox_override("panel", UIKit.box(UIKit.GREEN if on else UIKit.EDGE, UIKit.EDGE, 6, 2, 0))
			pips.add_child(pip)
		info.add_child(pips)
		h.add_child(info)
		var cost := Save.next_upgrade_cost(id)
		var b: Button
		if cost < 0:
			b = UIKit.button("MAXED", UIKit.GREEN, 26, Vector2(190, 66))
			b.disabled = true
		else:
			b = UIKit.button(UIKit.fmt(cost), UIKit.SUN, 28, Vector2(190, 66))
			b.icon = Assets.icon("coin")
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 34)
			b.disabled = Save.coins() < cost
			b.pressed.connect(func() -> void:
				if Save.buy_upgrade(id):
					Audio.play("purchase")
					_open_upgrades())
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		content.add_child(card)


# ------------------------------------------------------------ style (cosmetics)
func _open_style(slot: String) -> void:
	screen = "style"
	var content := _page("STYLE")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	content.add_child(tabs)
	for s in Catalog.COSMETIC_SLOTS:
		var sl: String = s
		var tb := UIKit.button(String(Catalog.SLOT_NAMES[sl]).to_upper(), UIKit.SUN if sl == slot else UIKit.SKY, 20, Vector2(130, 52))
		tb.pressed.connect(func() -> void: _open_style(sl))
		tabs.add_child(tb)
	content.add_child(UIKit.label("Cosmetics only change how Riley looks.", 20, UIKit.MUTED, false, 0))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for c in Catalog.COSMETICS[slot]:
		var id: String = c["id"]
		var card := _row_card()
		card.custom_minimum_size = Vector2(330, 0)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(v)
		if c.has("color"):
			var sw := Panel.new()
			sw.custom_minimum_size = Vector2(0, 70)
			sw.add_theme_stylebox_override("panel", UIKit.box(Color(String(c["color"])), UIKit.EDGE, 14, 4, 0))
			v.add_child(sw)
		elif c.has("scene"):
			var sc: String = c["scene"]
			if sc != "":
				v.add_child(UIKit.icon(Assets.icon(sc), 80))
			else:
				v.add_child(UIKit.label("—", 50))
		elif c.has("colors"):
			var strip := HBoxContainer.new()
			strip.custom_minimum_size = Vector2(0, 70)
			strip.add_theme_constant_override("separation", 2)
			var cols: Array = c["colors"]
			if cols.is_empty():
				strip.add_child(UIKit.label("none", 30, UIKit.MUTED))
			for col in cols:
				var cr := ColorRect.new()
				cr.color = Color(String(col))
				cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cr.custom_minimum_size = Vector2(0, 60)
				strip.add_child(cr)
			v.add_child(strip)
		var nl := UIKit.label(String(c["name"]), 24)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		var owned := Save.owns_cosmetic(id)
		var equipped := Save.cosmetic(slot) == id
		var b: Button
		if equipped:
			b = UIKit.button("EQUIPPED", UIKit.GREEN, 22, Vector2(200, 54))
			b.disabled = true
		elif owned:
			b = UIKit.button("EQUIP", UIKit.SKY, 22, Vector2(200, 54))
		else:
			b = UIKit.button(UIKit.fmt(int(c["cost"])), UIKit.SUN, 22, Vector2(200, 54))
			b.icon = Assets.icon("coin")
			b.add_theme_constant_override("icon_max_width", 28)
			b.disabled = Save.coins() < int(c["cost"])
		b.pressed.connect(func() -> void:
			var was_owned := Save.owns_cosmetic(id)
			if Save.buy_cosmetic(slot, id):
				Audio.play("ui_click" if was_owned else "purchase")
				_open_style(slot))
		v.add_child(b)
		grid.add_child(card)


# ------------------------------------------------------------ gadgets
func _open_gadgets() -> void:
	var content := _page("GADGETS")
	content.add_child(UIKit.label("Equip one gadget per run. Tap the gadget button mid-air to use it.", 20, UIKit.MUTED, false, 0))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	var eff := Save.upgrade_level("gadget")
	for gid in Catalog.GADGET_ORDER:
		var id: String = gid
		var g: Dictionary = Catalog.GADGETS[id]
		var card := _row_card()
		card.custom_minimum_size = Vector2(340, 0)
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(UIKit.icon(Assets.icon(String(g["icon"])), 90))
		var nl := UIKit.label(String(g["name"]), 28)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		var dl := UIKit.label(String(g["desc"]), 18, UIKit.MUTED, false, 0)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(300, 0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dl)
		var charges := int(g["charges"]) + (1 if eff >= 2 else 0) + (1 if eff >= 4 else 0)
		var sl := UIKit.label("Charges: %d" % charges, 18, UIKit.WHITE, false, 0)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sl)
		var b: Button
		if Save.owns_gadget(id):
			if Save.equipped_gadget() == id:
				b = UIKit.button("EQUIPPED", UIKit.GREEN, 22, Vector2(220, 56))
				b.disabled = true
			else:
				b = UIKit.button("EQUIP", UIKit.SKY, 22, Vector2(220, 56))
				b.pressed.connect(func() -> void:
					Save.equip_gadget(id)
					_open_gadgets())
		elif not Save.gadget_unlock_ready(id):
			b = UIKit.button("REACH %d m" % int(g["dist"]), UIKit.EDGE, 20, Vector2(220, 56))
			b.disabled = true
		else:
			b = UIKit.button(UIKit.fmt(int(g["cost"])), UIKit.SUN, 22, Vector2(220, 56))
			b.icon = Assets.icon("coin")
			b.add_theme_constant_override("icon_max_width", 28)
			b.disabled = Save.coins() < int(g["cost"])
			b.pressed.connect(func() -> void:
				if Save.buy_gadget(id):
					Audio.play("purchase")
					_open_gadgets())
		v.add_child(b)
		grid.add_child(card)


# ------------------------------------------------------------ worlds
func _open_worlds() -> void:
	var content := _page("WORLDS")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	var thumbs := ["trampoline", "house_a", "ferris_wheel", "planet"]
	for i in Catalog.WORLDS.size():
		var w: Dictionary = Catalog.WORLDS[i]
		var idx: int = i
		var card := _row_card()
		card.custom_minimum_size = Vector2(540, 0)
		var h := HBoxContainer.new()
		card.add_child(h)
		var ic := UIKit.icon(Assets.icon(String(thumbs[i])), 110)
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 4)
		h.add_child(v)
		v.add_child(UIKit.label("%d. %s" % [i + 1, String(w["name"])], 28))
		var bl := UIKit.label(String(w["blurb"]), 18, UIKit.MUTED, false, 0)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(360, 0)
		v.add_child(bl)
		var unlocked := Save.world_unlocked(i)
		v.add_child(UIKit.label("Best: %d m" % Save.best_distance(i), 20, UIKit.SUN, false, 0))
		var b: Button
		if not unlocked:
			b = UIKit.button("REACH %d m IN %s" % [int(w["unlock"]), String(Catalog.WORLDS[i - 1]["short"]).to_upper()], UIKit.EDGE, 18, Vector2(300, 52))
			b.disabled = true
			ic.modulate = Color(0.3, 0.35, 0.45)
		elif Save.selected_world() == i:
			b = UIKit.button("SELECTED", UIKit.GREEN, 22, Vector2(220, 52))
			b.pressed.connect(func() -> void: play_requested.emit(idx))
		else:
			b = UIKit.button("SELECT", UIKit.SUN, 22, Vector2(220, 52))
			b.pressed.connect(func() -> void:
				Save.select_world(idx)
				_open_worlds())
		v.add_child(b)
		grid.add_child(card)


# ------------------------------------------------------------ scores
func _open_scores() -> void:
	var content := _page("HIGH SCORES")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for t in ["WORLD", "BEST DISTANCE", "BEST SCORE", ""]:
		grid.add_child(UIKit.label(t, 22, UIKit.SUN))
	for i in Catalog.WORLDS.size():
		grid.add_child(UIKit.label(String(Catalog.WORLDS[i]["short"]), 24))
		grid.add_child(UIKit.label("%d m" % Save.best_distance(i), 24, UIKit.WHITE, false, 0))
		grid.add_child(UIKit.label(UIKit.fmt(int(Save.data["best_score"][i])), 24, UIKit.WHITE, false, 0))
		grid.add_child(UIKit.label("" if Save.world_unlocked(i) else "locked", 20, UIKit.MUTED, false, 0))
	content.add_child(UIKit.label("Best combo: x%d   ·   Runs: %d   ·   Total distance: %s m" % [int(Save.data["best_combo"]),
		int(Save.data["total_runs"]), UIKit.fmt(int(Save.data["total_distance"]))], 22, UIKit.MUTED, false, 0))
	content.add_child(UIKit.label("TOP RUNS", 30, UIKit.SUN))
	var top: Array = Save.data["top_runs"]
	if top.is_empty():
		content.add_child(UIKit.label("No runs yet. Go launch Riley!", 22, UIKit.WHITE, false, 0))
	for i in top.size():
		var r: Dictionary = top[i]
		var line := "%d.  %s pts   %d m   x%d   %s · %s" % [i + 1, UIKit.fmt(int(r["score"])), int(r["distance"]), int(r["combo"]),
			String(Catalog.WORLDS[int(r["world"])]["short"]), String(r.get("date", ""))]
		content.add_child(UIKit.label(line, 22, UIKit.WHITE, false, 0))


# ------------------------------------------------------------ settings
func _open_settings() -> void:
	var content := _page("SETTINGS")
	build_settings(content, func() -> void: _open_settings())


func build_settings(content: VBoxContainer, reopen: Callable) -> void:
	SettingsPanel.build_common(content, reopen)
	var r := HBoxContainer.new()
	var rl := UIKit.label("Reset all progress", 26, UIKit.WHITE, false, 0)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(rl)
	if _confirm_reset:
		var yes := UIKit.button("YES, RESET", UIKit.RED, 22, Vector2(200, 54))
		yes.pressed.connect(func() -> void:
			Save.reset_progress()
			_confirm_reset = false
			reopen.call())
		r.add_child(yes)
		var no := UIKit.button("CANCEL", UIKit.SKY, 22, Vector2(160, 54))
		no.pressed.connect(func() -> void:
			_confirm_reset = false
			reopen.call())
		r.add_child(no)
	else:
		var rb := UIKit.button("RESET", UIKit.RED, 22, Vector2(160, 54))
		rb.pressed.connect(func() -> void:
			_confirm_reset = true
			reopen.call())
		r.add_child(rb)
	content.add_child(r)
	content.add_child(UIKit.label("R.I.L.E.Y. v%s · Music & sounds are original and synthesized for this game." % String(ProjectSettings.get_setting("application/config/version", "1.0")), 18, UIKit.MUTED, false, 0))
