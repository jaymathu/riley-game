extends Node
## Sound effects pool, looping ambience and music with independent volume buses. Autoload "Audio".

const SFX := ["launch_boom", "crank", "tick", "lock", "whoosh", "wind_loop", "boing", "sproing", "splash", "bumper",
	"crash_bonk", "coin", "combo", "perfect", "rocket", "balloon", "umbrella", "plunger", "inflate", "fan_loop", "horn",
	"squeak", "wood_break", "ui_click", "ui_back", "purchase", "new_record", "thud", "soft_land", "roof_land",
	"gadget_whoosh", "voice_woohoo", "voice_whoa", "voice_yay", "voice_oof", "voice_aah", "voice_yeah", "voice_ouch"]
const MUSIC := ["music_menu", "music_game", "music_space"]

var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _loops := {}
var _voice_cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for n in SFX:
		var s: Resource = load("res://assets/audio/%s.wav" % n)
		if s:
			streams[n] = s
	for n in MUSIC:
		var m: Resource = load("res://assets/audio/%s.ogg" % n)
		if m:
			if m is AudioStreamOggVorbis:
				(m as AudioStreamOggVorbis).loop = true
			streams[n] = m
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volumes()
	Save.settings_changed.connect(apply_volumes)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	_set_bus("Music", float(Save.setting("music")))
	_set_bus("SFX", float(Save.setting("sfx")))


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0001, 1.0)))


func _process(dt: float) -> void:
	_voice_cooldown = maxf(0.0, _voice_cooldown - dt)


## Plays a one-shot effect with a little random pitch so repeats don't sound identical.
func play(sfx_name: String, volume_db := 0.0, pitch := 1.0, variation := 0.07) -> void:
	if not streams.has(sfx_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = streams[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-variation, variation)))
	p.play()


func voice(sfx_name: String, chance := 1.0) -> void:
	if _voice_cooldown > 0.0 or randf() > chance:
		return
	_voice_cooldown = 1.2
	play(sfx_name, -2.0, 1.0, 0.05)


func start_loop(sfx_name: String, volume_db := -8.0) -> void:
	if _loops.has(sfx_name) or not streams.has(sfx_name):
		return
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = streams[sfx_name]
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.play)
	p.play()
	_loops[sfx_name] = p


func set_loop(sfx_name: String, volume_db: float, pitch := 1.0) -> void:
	if _loops.has(sfx_name):
		var p: AudioStreamPlayer = _loops[sfx_name]
		p.volume_db = volume_db
		p.pitch_scale = pitch


func stop_loop(sfx_name: String) -> void:
	if _loops.has(sfx_name):
		var p: AudioStreamPlayer = _loops[sfx_name]
		p.queue_free()
		_loops.erase(sfx_name)


func stop_all_loops() -> void:
	for k in _loops.keys():
		stop_loop(k)


func music(music_name: String) -> void:
	if music_name == _music_name and _music.playing:
		return
	_music_name = music_name
	if not streams.has(music_name):
		_music.stop()
		return
	_music.stream = streams[music_name]
	_music.volume_db = -4.0
	_music.play()


func click() -> void:
	play("ui_click", -3.0, 1.0, 0.03)


func back() -> void:
	play("ui_back", -3.0, 1.0, 0.03)
