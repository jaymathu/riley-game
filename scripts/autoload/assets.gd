extends Node
## Loads and caches imported 3D scenes, icons and fonts. Autoload "Assets".

const PROPS := ["launcher", "trampoline", "bounce_house", "pool", "spring", "mattress", "emergency_mattress",
	"satellite_dish", "fan", "truck", "duck", "seesaw", "tire", "slide", "rotating_platform", "conveyor", "cushion",
	"bumper", "wind_tunnel", "ramp", "coin", "floating_platform", "booster_ring", "thruster", "umbrella",
	"rocket_shoe", "balloon", "propeller_hat", "plunger_gun", "plunger_head", "hat_bike_helmet", "hat_viking",
	"hat_pot", "hat_party", "tree_round", "tree_round_big", "tree_pine", "bush", "fence", "shed", "swing_set",
	"cloud", "streetlamp", "road_sign", "hydrant", "mailbox", "ferris_wheel", "coaster", "tent", "planet",
	"space_station", "moon_rock", "flag", "house_a", "house_b", "house_c", "house_d"]

var _scenes := {}
var _textures := {}
var font_display: Font
var font_body: Font
var font_black: Font
var riley_scene: PackedScene


func _ready() -> void:
	font_display = _font("res://assets/fonts/LilitaOne.woff")
	font_body = _font("res://assets/fonts/Nunito-ExtraBold.woff")
	font_black = _font("res://assets/fonts/Nunito-Black.woff")
	riley_scene = load("res://assets/characters/riley/riley.glb") as PackedScene


func _font(path: String) -> Font:
	var f: Resource = load(path)
	if f is Font:
		return f
	return ThemeDB.fallback_font


## Returns a new instance of a prop model, or an empty Node3D if missing.
func prop(prop_name: String) -> Node3D:
	if not _scenes.has(prop_name):
		var path := "res://assets/props/%s.glb" % prop_name
		var res: Resource = load(path) if ResourceLoader.exists(path) else null
		_scenes[prop_name] = res
	var ps: PackedScene = _scenes[prop_name] as PackedScene
	if ps == null:
		push_warning("Missing prop model: " + prop_name)
		return Node3D.new()
	return ps.instantiate() as Node3D


func preload_all() -> void:
	for p in PROPS:
		if not _scenes.has(p):
			var path := "res://assets/props/%s.glb" % p
			_scenes[p] = load(path) if ResourceLoader.exists(path) else null


func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path] as Texture2D


func icon(icon_name: String) -> Texture2D:
	return texture("res://assets/icons/items/%s.png" % icon_name)


## Recolors every surface whose material is named `material_name` inside a model.
static func recolor(root: Node, material_name: String, color: Color) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(i)
			if mat is BaseMaterial3D and mat.resource_name == material_name:
				var copy := mat.duplicate() as BaseMaterial3D
				copy.albedo_color = color
				m.set_surface_override_material(i, copy)


static func set_shadows(root: Node, on: bool) -> void:
	for mi in root.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
