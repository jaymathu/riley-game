class_name WorldEnv
extends Node3D
## Sky, sun, fog, the endless ground (one plane that follows the camera with a world-space shader)
## and the infinite ground collider for a world.

const GROUND_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform int world_type = 0;
uniform vec3 c1 : source_color = vec3(0.32, 0.72, 0.30);
uniform vec3 c2 : source_color = vec3(0.27, 0.64, 0.26);
uniform vec3 c3 : source_color = vec3(0.6, 0.6, 0.62);
uniform vec3 c4 : source_color = vec3(1.0, 1.0, 1.0);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 col = c1;
	float n = noise(wpos.xz * 0.35) * 0.08 + noise(wpos.xz * 2.1) * 0.05;
	if (world_type == 0) {
		float stripe = step(0.5, fract(wpos.x / 6.0));
		col = mix(c1, c2, stripe) * (0.95 + n);
	} else if (world_type == 1) {
		float road = step(abs(wpos.z), 4.2);
		float walk = step(abs(wpos.z + 5.3), 1.1) + step(abs(wpos.z - 5.3), 1.1);
		float dash = step(abs(wpos.z), 0.15) * step(0.5, fract(wpos.x / 5.0));
		col = mix(c1 * (0.95 + n), c3 * (0.92 + n * 0.5), road);
		col = mix(col, c4 * 0.85, clamp(walk, 0.0, 1.0));
		col = mix(col, vec3(1.0, 0.85, 0.2), dash);
	} else if (world_type == 2) {
		vec2 t = floor(wpos.xz / 2.0);
		float chk = mod(t.x + t.y, 2.0);
		col = mix(c1, c2, chk) * (0.96 + n * 0.6);
		float path = step(abs(wpos.z), 3.0);
		col = mix(col, c3, path * 0.85);
	} else {
		float crater = smoothstep(0.62, 0.7, noise(wpos.xz * 0.18)) - smoothstep(0.7, 0.78, noise(wpos.xz * 0.18));
		col = mix(c1, c2, noise(wpos.xz * 0.4)) * (0.9 + n * 1.5) - crater * 0.12;
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""

const SPACE_SKY := """
shader_type sky;
uniform vec3 top : source_color = vec3(0.02, 0.02, 0.1);
uniform vec3 horizon : source_color = vec3(0.17, 0.12, 0.36);
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void sky() {
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon, top, pow(h, 0.5));
	vec3 cell = floor(EYEDIR * 220.0);
	float s = hash(cell);
	col += vec3(step(0.9975, s)) * (0.6 + 0.4 * hash(cell + 3.0));
	COLOR = col;
}
"""

var world := 0
var ground: MeshInstance3D
var sun: DirectionalLight3D
var env_node: WorldEnvironment
var follow: Node3D


func setup(world_idx: int, quality: int) -> void:
	world = world_idx
	var w: Dictionary = Catalog.WORLDS[world]
	env_node = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	if world == 3:
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SPACE_SKY
		sm.shader = sh
		sm.set_shader_parameter("top", Color(String(w["sky_top"])))
		sm.set_shader_parameter("horizon", Color(String(w["sky_horizon"])))
		sky.sky_material = sm
	else:
		var ps := ProceduralSkyMaterial.new()
		ps.sky_top_color = Color(String(w["sky_top"]))
		ps.sky_horizon_color = Color(String(w["sky_horizon"]))
		ps.ground_horizon_color = Color(String(w["sky_horizon"]))
		ps.ground_bottom_color = Color(String(w["sky_horizon"])).darkened(0.3)
		ps.sun_angle_max = 20.0
		sky.sky_material = ps
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9 if world != 3 else 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = quality > 0
	env.fog_light_color = Color(String(w["fog"]))
	env.fog_density = 0.0035 if world != 3 else 0.002
	env.fog_sky_affect = 0.0
	env.glow_enabled = quality >= 2
	env.glow_intensity = 0.4
	env_node.environment = env
	add_child(env_node)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.25 if world != 3 else 1.0
	sun.light_color = Color(1.0, 0.96, 0.9) if world != 3 else Color(0.85, 0.85, 1.0)
	sun.shadow_enabled = quality >= 1
	sun.directional_shadow_max_distance = 45.0 if quality == 1 else 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if quality == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(640, 220)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	var gs := Shader.new()
	gs.code = GROUND_SHADER
	gm.shader = gs
	var cols := [
		[Color("#58B84A"), Color("#4CA642"), Color("#8C93A0"), Color("#FFFFFF")],
		[Color("#5CBF55"), Color("#52B04C"), Color("#5C6270"), Color("#E9E2D6")],
		[Color("#F7C6D9"), Color("#C9E7FF"), Color("#FFE59A"), Color("#FFFFFF")],
		[Color("#8E8AA6"), Color("#6E6A88"), Color("#55516E"), Color("#FFFFFF")],
	]
	var c: Array = cols[world]
	gm.set_shader_parameter("world_type", world)
	gm.set_shader_parameter("c1", c[0])
	gm.set_shader_parameter("c2", c[1])
	gm.set_shader_parameter("c3", c[2])
	gm.set_shader_parameter("c4", c[3])
	ground.material_override = gm
	ground.position = Vector3(0, 0, -45)
	add_child(ground)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.9
	body.physics_material_override = pmat
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	body.set_meta("ground", true)
	add_child(body)


func _process(_dt: float) -> void:
	if follow and ground:
		ground.position.x = snappedf(follow.global_position.x, 12.0)
