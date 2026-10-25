extends Node
## App flow: menu stage <-> run, results, pause, Android back/background handling, smoke test.

var ui_root: Control
var menu: MainMenu
var hud: HUD
var results: ResultsScreen
var pause_screen: PauseScreen
var fade: ColorRect
var game: Game
var menu_stage: Node3D
var menu_riley: RileyVisual
var _smoke := false
var _last_world := 0


func _ready() -> void:
	Engine.max_fps = 60
	Assets.preload_all()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui_root = Control.new()
	UIKit.full_rect(ui_root)
	ui_root.theme = UIKit.make_theme()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(ui_root)
	hud = HUD.new()
	ui_root.add_child(hud)
	hud.visible = false
	menu = MainMenu.new()
	ui_root.add_child(menu)
	menu.play_requested.connect(start_run)
	results = ResultsScreen.new()
	ui_root.add_child(results)
	results.visible = false
	results.retry.connect(func() -> void: start_run(_last_world))
	results.upgrades.connect(func() -> void:
		show_menu()
		menu.open("upgrades"))
	results.to_menu.connect(show_menu)
	pause_screen = PauseScreen.new()
	ui_root.add_child(pause_screen)
	pause_screen.visible = false
	pause_screen.resume.connect(resume)
	pause_screen.restart.connect(func() -> void:
		resume()
		start_run(_last_world))
	pause_screen.quit_to_menu.connect(func() -> void:
		resume()
		show_menu())
	fade = ColorRect.new()
	fade.color = Color(0.05, 0.2, 0.45, 0.0)
	UIKit.full_rect(fade)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(fade)
	Save.loadout_changed.connect(_refresh_menu_riley)
	_smoke = "--smoke" in OS.get_cmdline_user_args()
	show_menu()
	if _smoke:
		_run_smoke()


func _apply_quality() -> void:
	var q := int(Save.setting("quality"))
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(q, 0, 2)]
	vp.scaling_3d_scale = [0.72, 0.88, 1.0][clampi(q, 0, 2)]


func _flash() -> void:
	fade.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.35)


# ------------------------------------------------------------ menu
func show_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_clear_game()
	results.visible = false
	pause_screen.visible = false
	hud.visible = false
	menu.visible = true
	menu.close_sub()
	_build_menu_stage()
	Audio.music("music_menu")
	_flash()


func _clear_game() -> void:
	if game:
		game.queue_free()
		game = null
	if menu_stage:
		menu_stage.queue_free()
		menu_stage = null
		menu_riley = null


func _build_menu_stage() -> void:
	_apply_quality()
	menu_stage = Node3D.new()
	add_child(menu_stage)
	var env := WorldEnv.new()
	menu_stage.add_child(env)
	env.setup(Save.selected_world(), int(Save.setting("quality")))
	var cam := Camera3D.new()
	cam.fov = 40.0
	menu_stage.add_child(cam)
	cam.position = Vector3(0.2, 2.0, 8.2)
	cam.look_at(Vector3(1.9, 1.15, 0), Vector3.UP)
	cam.current = true
	menu_riley = RileyVisual.new()
	menu_stage.add_child(menu_riley)
	menu_riley.position = Vector3(3.0, 0.65, 0.8)
	menu_riley.rotation.y = deg_to_rad(-38)
	menu_riley.apply_loadout()
	var launcher := Launcher.new()
	menu_stage.add_child(launcher)
	launcher.position = Vector3(5.6, 0, -1.6)
	launcher.rotation.y = deg_to_rad(-25)
	var tramp := Assets.prop("trampoline")
	menu_stage.add_child(tramp)
	tramp.position = Vector3(0.6, 0, -3.5)
	for i in 4:
		var t := Assets.prop(["tree_round", "bush", "tree_round_big", "bush"][i])
		menu_stage.add_child(t)
		t.position = Vector3(-6.0 + i * 5.0, 0, -9.0 - (i % 2) * 4.0)


func _refresh_menu_riley() -> void:
	if menu_riley and is_instance_valid(menu_riley):
		menu_riley.apply_loadout()
		menu_riley.play_once("land_perfect")
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if menu_riley and is_instance_valid(menu_riley):
				menu_riley.play("idle"))


# ------------------------------------------------------------ run
func start_run(world: int) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_last_world = world
	_clear_game()
	_apply_quality()
	menu.visible = false
	results.visible = false
	pause_screen.visible = false
	hud.visible = true
	game = Game.new()
	add_child(game)
	game.auto_play = _smoke
	game.run_finished.connect(_on_run_finished)
	game.request_pause.connect(pause)
	game.start(world, hud)
	_flash()


func _on_run_finished(result: Dictionary) -> void:
	await get_tree().create_timer(0.7).timeout
	if game == null:
		return
	hud.visible = false
	results.visible = true
	results.show_result(result)


func pause() -> void:
	if game == null or results.visible or pause_screen.visible:
		return
	get_tree().paused = true
	pause_screen.visible = true
	pause_screen.open(game.seed_value)
	Audio.click()


func resume() -> void:
	get_tree().paused = false
	pause_screen.visible = false
	for c in pause_screen.get_children():
		c.queue_free()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if game and not results.visible:
				pause()
			Save.save_now()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_back()


func _back() -> void:
	if pause_screen.visible:
		resume()
	elif results.visible:
		show_menu()
	elif game:
		pause()
	elif menu.handle_back():
		pass
	else:
		Save.save_now()
		get_tree().quit()


# ------------------------------------------------------------ automated smoke test (CI)
var _shot_dir := ""


func _shot(shot_name: String) -> void:
	if _shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.resize(960, int(960.0 * img.get_height() / maxf(1.0, img.get_width())), Image.INTERPOLATE_BILINEAR)
	img.save_png(_shot_dir.path_join(shot_name + ".png"))


func _run_smoke() -> void:
	print("SMOKE: start")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screens="):
			_shot_dir = a.substr(10)
			DirAccess.make_dir_recursive_absolute(_shot_dir)
	await get_tree().create_timer(1.5).timeout
	await _shot("00_menu")
	for sub in ["upgrades", "style", "gadgets", "worlds", "scores", "settings"]:
		menu.open(sub)
		await get_tree().create_timer(0.4).timeout
		await _shot("01_menu_" + sub)
		menu.close_sub()
	Save.add_coins(20000)
	Save.buy_upgrade("power")
	Save.buy_cosmetic("hat", "hat_viking")
	Save.buy_cosmetic("trail", "trail_rainbow")
	var owned: Array = Save.data["gadgets_owned"]
	for g in Catalog.GADGET_ORDER:
		if not owned.has(g):
			owned.append(g)
	for i in 6:
		var w := i % 4
		Save.data["world"] = w
		Save.equip_gadget(String(Catalog.GADGET_ORDER[i]))
		print("SMOKE: world %d gadget %s" % [w, Save.equipped_gadget()])
		start_run(w)
		var t := 0.0
		var shots := [0.5, 1.6, 2.6, 4.0, 6.0, 9.0]
		while t < 22.0 and not results.visible:
			await get_tree().create_timer(0.1).timeout
			t += 0.1
			for st in shots:
				if absf(t - float(st)) < 0.05 and i < 4:
					await _shot("%02d_run%d_w%d_t%04.1f" % [10 + i, i, w, t])
			if i == 0 and absf(t - 3.0) < 0.05:
				pause()
				await get_tree().create_timer(0.3, true).timeout
				await _shot("05_pause")
				resume()
		if game:
			print("SMOKE: run %d finished=%s distance=%d score=%d landings=%d perfects=%d combo=%d coins=%d tricks=%d crashes=%d ragdoll=%s" % [
				i, str(results.visible), int(game.distance), game.total_score(), game.landings, game.perfects,
				game.best_combo, game.coins_run, game.tricks, game.crashes, str(game.riley.visual.ragdolling)])
		await get_tree().create_timer(0.8).timeout
		if i < 2:
			await _shot("%02d_results_%d" % [20 + i, i])
	# deliberately bad landings to exercise the crash + ragdoll path
	Save.data["world"] = 0
	start_run(0)
	game.auto_reckless = true
	var tt := 0.0
	var shot_n := 0
	while tt < 22.0 and not results.visible:
		await get_tree().create_timer(0.1).timeout
		tt += 0.1
		if game and game.riley.phase == RileyPlayer.Phase.RAGDOLL and shot_n < 3:
			await _shot("30_ragdoll_%d" % shot_n)
			shot_n += 1
			await get_tree().create_timer(0.25).timeout
	if game:
		print("SMOKE: reckless run distance=%d crashes=%d ragdoll=%s" % [int(game.distance), game.crashes, str(game.riley.visual.ragdolling)])
	show_menu()
	await get_tree().create_timer(0.5).timeout
	print("SMOKE OK")
	get_tree().quit(0)
