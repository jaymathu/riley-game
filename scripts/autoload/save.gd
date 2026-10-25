extends Node
## Persistent progress, records and settings (user://riley_save.json). Autoload "Save".

signal coins_changed(value: int)
signal settings_changed
signal loadout_changed

const PATH := "user://riley_save.json"
const VERSION := 1

var data: Dictionary = {}
var _dirty := false


func _ready() -> void:
	load_data()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"coins": 0,
		"lifetime_coins": 0,
		"upgrades": {},
		"gadgets_owned": ["umbrella"],
		"gadget": "umbrella",
		"cosmetics_owned": ["shirt_blue", "shoes_red", "goggles_cyan", "hat_none", "launcher_red", "trail_none"],
		"cosmetics": {"shirt": "shirt_blue", "shoes": "shoes_red", "goggles": "goggles_cyan", "hat": "hat_none",
			"launcher": "launcher_red", "trail": "trail_none"},
		"world": 0,
		"best_distance": [0, 0, 0, 0],
		"best_score": [0, 0, 0, 0],
		"best_combo": 0,
		"top_runs": [],
		"total_runs": 0,
		"total_distance": 0,
		"settings": {"music": 0.7, "sfx": 0.9, "vibration": true, "quality": 1, "sensitivity": 1.0,
			"rotation": 1.0, "left_handed": false, "tutorial_done": false},
	}


func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable, starting fresh")
		return
	var loaded: Dictionary = parsed
	for k in loaded.keys():
		if data.has(k) and typeof(data[k]) == TYPE_DICTIONARY and typeof(loaded[k]) == TYPE_DICTIONARY:
			var d: Dictionary = data[k]
			var l: Dictionary = loaded[k]
			for kk in l.keys():
				d[kk] = l[kk]
		elif data.has(k):
			data[k] = loaded[k]
	# JSON stores numbers as floats; normalise the integer fields we compare.
	data["coins"] = int(data["coins"])
	for key in ["best_distance", "best_score"]:
		var arr: Array = data[key]
		while arr.size() < 4:
			arr.append(0)
		for i in arr.size():
			arr[i] = int(arr[i])


func save_now() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	_dirty = false


func mark_dirty() -> void:
	_dirty = true


func _process(_dt: float) -> void:
	if _dirty:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


# ------------------------------------------------------------ coins
func coins() -> int:
	return int(data["coins"])


func add_coins(n: int) -> void:
	data["coins"] = coins() + n
	data["lifetime_coins"] = int(data.get("lifetime_coins", 0)) + max(n, 0)
	mark_dirty()
	coins_changed.emit(coins())


func spend(n: int) -> bool:
	if coins() < n:
		return false
	data["coins"] = coins() - n
	mark_dirty()
	coins_changed.emit(coins())
	return true


# ------------------------------------------------------------ upgrades
func upgrade_level(id: String) -> int:
	var u: Dictionary = data["upgrades"]
	return int(u.get(id, 0))


func next_upgrade_cost(id: String) -> int:
	var d := Catalog.upgrade_def(id)
	if d.is_empty() or upgrade_level(id) >= int(d["max"]):
		return -1
	return Catalog.upgrade_cost(int(d["base"]), upgrade_level(id))


func buy_upgrade(id: String) -> bool:
	var cost := next_upgrade_cost(id)
	if cost < 0 or not spend(cost):
		return false
	var u: Dictionary = data["upgrades"]
	u[id] = upgrade_level(id) + 1
	mark_dirty()
	return true


# ------------------------------------------------------------ gadgets
func owns_gadget(id: String) -> bool:
	return id in data["gadgets_owned"]


func gadget_unlock_ready(id: String) -> bool:
	var g: Dictionary = Catalog.GADGETS[id]
	return best_distance_any() >= int(g["dist"])


func buy_gadget(id: String) -> bool:
	if owns_gadget(id) or not gadget_unlock_ready(id):
		return false
	if not spend(int(Catalog.GADGETS[id]["cost"])):
		return false
	var owned: Array = data["gadgets_owned"]
	owned.append(id)
	data["gadget"] = id
	mark_dirty()
	loadout_changed.emit()
	return true


func equip_gadget(id: String) -> void:
	if owns_gadget(id):
		data["gadget"] = id
		mark_dirty()
		loadout_changed.emit()


func equipped_gadget() -> String:
	return String(data["gadget"])


# ------------------------------------------------------------ cosmetics
func owns_cosmetic(id: String) -> bool:
	return id in data["cosmetics_owned"]


func buy_cosmetic(slot: String, id: String) -> bool:
	if owns_cosmetic(id):
		equip_cosmetic(slot, id)
		return true
	var d := Catalog.cosmetic_def(slot, id)
	if d.is_empty() or not spend(int(d["cost"])):
		return false
	var owned: Array = data["cosmetics_owned"]
	owned.append(id)
	equip_cosmetic(slot, id)
	return true


func equip_cosmetic(slot: String, id: String) -> void:
	var c: Dictionary = data["cosmetics"]
	c[slot] = id
	mark_dirty()
	loadout_changed.emit()


func cosmetic(slot: String) -> String:
	var c: Dictionary = data["cosmetics"]
	return String(c.get(slot, ""))


# ------------------------------------------------------------ worlds & records
func best_distance(world: int) -> int:
	return int(data["best_distance"][world])


func best_distance_any() -> int:
	var m := 0
	for v in data["best_distance"]:
		m = max(m, int(v))
	return m


func world_unlocked(i: int) -> bool:
	if i <= 0:
		return true
	return best_distance(i - 1) >= int(Catalog.WORLDS[i]["unlock"])


func selected_world() -> int:
	var w := int(data["world"])
	return w if world_unlocked(w) else 0


func select_world(i: int) -> void:
	if world_unlocked(i):
		data["world"] = i
		mark_dirty()


## Stores a finished run; returns {"distance_record": bool, "score_record": bool, "unlocked_world": int}.
func record_run(world: int, run: Dictionary) -> Dictionary:
	var out := {"distance_record": false, "score_record": false, "unlocked_world": -1}
	var was_unlocked := []
	for i in Catalog.WORLDS.size():
		was_unlocked.append(world_unlocked(i))
	var dist := int(run["distance"])
	var score := int(run["score"])
	if dist > best_distance(world):
		data["best_distance"][world] = dist
		out["distance_record"] = true
	if score > int(data["best_score"][world]):
		data["best_score"][world] = score
		out["score_record"] = true
	data["best_combo"] = max(int(data["best_combo"]), int(run["best_combo"]))
	data["total_runs"] = int(data["total_runs"]) + 1
	data["total_distance"] = int(data["total_distance"]) + dist
	var top: Array = data["top_runs"]
	top.append({"world": world, "score": score, "distance": dist, "combo": int(run["best_combo"]),
		"date": Time.get_date_string_from_system()})
	top.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	while top.size() > 10:
		top.pop_back()
	for i in Catalog.WORLDS.size():
		if world_unlocked(i) and not was_unlocked[i]:
			out["unlocked_world"] = i
	mark_dirty()
	return out


# ------------------------------------------------------------ settings
func setting(key: String) -> Variant:
	var s: Dictionary = data["settings"]
	return s.get(key, defaults()["settings"].get(key))


func set_setting(key: String, value: Variant) -> void:
	var s: Dictionary = data["settings"]
	s[key] = value
	mark_dirty()
	settings_changed.emit()


func reset_progress() -> void:
	var keep: Dictionary = data["settings"].duplicate()
	data = defaults()
	data["settings"] = keep
	save_now()
	coins_changed.emit(coins())
	loadout_changed.emit()


func vibrate(ms: int) -> void:
	if bool(setting("vibration")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
