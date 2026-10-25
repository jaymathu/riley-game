class_name Catalog
extends RefCounted
## Static game data: upgrades, gadgets, cosmetics, worlds and spawn tables.

const UPGRADES := [
	{"id": "power", "name": "Launcher Power", "desc": "Bigger blast from the cannon.", "max": 6, "base": 120},
	{"id": "angle", "name": "Angle Control", "desc": "Slower angle meter for precise aim.", "max": 5, "base": 100},
	{"id": "rotation", "name": "Air Rotation", "desc": "Spin faster and stop spins quicker.", "max": 5, "base": 110},
	{"id": "recovery", "name": "Landing Recovery", "desc": "Wider window for good landings.", "max": 5, "base": 150},
	{"id": "gadget", "name": "Gadget Efficiency", "desc": "Gadgets last longer, hit harder and gain charges.", "max": 5, "base": 160},
	{"id": "magnet", "name": "Coin Magnet", "desc": "Pull in coins from farther away.", "max": 5, "base": 90},
	{"id": "combo", "name": "Combo Duration", "desc": "More time to keep a combo alive.", "max": 5, "base": 130},
]

const GADGETS := {
	"umbrella": {"name": "Umbrella", "desc": "Hold your fall and glide forward.", "cost": 0, "dist": 0,
		"charges": 1, "duration": 3.5, "cooldown": 4.0, "icon": "umbrella"},
	"rocket": {"name": "Rocket Shoes", "desc": "A burst of forward thrust.", "cost": 350, "dist": 0,
		"charges": 2, "duration": 0.45, "cooldown": 0.6, "icon": "rocket_shoe"},
	"balloon": {"name": "Giant Balloon", "desc": "Float with much lower gravity.", "cost": 600, "dist": 250,
		"charges": 1, "duration": 4.5, "cooldown": 5.0, "icon": "balloon"},
	"propeller": {"name": "Propeller Hat", "desc": "Auto-levels you and adds steering.", "cost": 850, "dist": 450,
		"charges": 1, "duration": 5.0, "cooldown": 5.0, "icon": "propeller_hat"},
	"plunger": {"name": "Plunger Gun", "desc": "Grab the next object and yank yourself to it.", "cost": 1150, "dist": 700,
		"charges": 2, "duration": 0.7, "cooldown": 1.0, "icon": "plunger_gun"},
	"mattress": {"name": "Emergency Mattress", "desc": "Drops a bouncy mattress right under you.", "cost": 1500, "dist": 1000,
		"charges": 1, "duration": 4.0, "cooldown": 1.0, "icon": "emergency_mattress"},
}
const GADGET_ORDER := ["umbrella", "rocket", "balloon", "propeller", "plunger", "mattress"]

## Cosmetics never change gameplay numbers.
const COSMETICS := {
	"shirt": [
		{"id": "shirt_blue", "name": "Lightning Blue", "color": "#2D7BE5", "cost": 0},
		{"id": "shirt_red", "name": "Rocket Red", "color": "#E8342C", "cost": 150},
		{"id": "shirt_green", "name": "Lab Green", "color": "#3FB54A", "cost": 150},
		{"id": "shirt_purple", "name": "Galaxy Purple", "color": "#8A55D8", "cost": 250},
		{"id": "shirt_orange", "name": "Traffic Cone", "color": "#FF8A1F", "cost": 250},
		{"id": "shirt_black", "name": "Midnight", "color": "#2A2D38", "cost": 400},
	],
	"shoes": [
		{"id": "shoes_red", "name": "Red Runners", "color": "#E8342C", "cost": 0},
		{"id": "shoes_blue", "name": "Blue Zoomers", "color": "#2D7BE5", "cost": 120},
		{"id": "shoes_green", "name": "Slime Kicks", "color": "#43B649", "cost": 120},
		{"id": "shoes_gold", "name": "Golden Soles", "color": "#F5B921", "cost": 600},
	],
	"goggles": [
		{"id": "goggles_cyan", "name": "Classic Lenses", "color": "#5FC6F0", "cost": 0},
		{"id": "goggles_pink", "name": "Rose Lenses", "color": "#FF7FB0", "cost": 100},
		{"id": "goggles_gold", "name": "Gold Visor", "color": "#FFC928", "cost": 200},
		{"id": "goggles_green", "name": "Night Vision", "color": "#6CFF6C", "cost": 300},
	],
	"hat": [
		{"id": "hat_none", "name": "Just Hair", "scene": "", "cost": 0},
		{"id": "hat_bike", "name": "Bike Helmet", "scene": "hat_bike_helmet", "cost": 200},
		{"id": "hat_pot", "name": "Cooking Pot", "scene": "hat_pot", "cost": 300},
		{"id": "hat_party", "name": "Party Hat", "scene": "hat_party", "cost": 300},
		{"id": "hat_viking", "name": "Viking Helmet", "scene": "hat_viking", "cost": 500},
	],
	"launcher": [
		{"id": "launcher_red", "name": "Classic Red", "color": "#E8342C", "cost": 0},
		{"id": "launcher_blue", "name": "Sky Blue", "color": "#2D7BE5", "cost": 250},
		{"id": "launcher_green", "name": "Garden Green", "color": "#43B649", "cost": 250},
		{"id": "launcher_gold", "name": "Gold Plated", "color": "#F5B921", "cost": 800},
	],
	"trail": [
		{"id": "trail_none", "name": "No Trail", "colors": [], "cost": 0},
		{"id": "trail_sparkle", "name": "Sparkles", "colors": ["#FFFFFF", "#FFF3A0"], "cost": 200},
		{"id": "trail_fire", "name": "Fire", "colors": ["#FFD22E", "#FF6A1F", "#E8342C"], "cost": 400},
		{"id": "trail_rainbow", "name": "Rainbow", "colors": ["#E8342C", "#FF8A1F", "#FFD22E", "#43B649", "#2D7BE5", "#8A55D8"], "cost": 700},
		{"id": "trail_stars", "name": "Star Dust", "colors": ["#5CF2FF", "#C7A6FF", "#FFFFFF"], "cost": 500},
	],
}
const COSMETIC_SLOTS := ["shirt", "shoes", "goggles", "hat", "launcher", "trail"]
const SLOT_NAMES := {"shirt": "Shirt", "shoes": "Shoes", "goggles": "Goggles", "hat": "Headwear",
	"launcher": "Launcher", "trail": "Trail"}

## unlock = best distance (m) needed in the previous world.
const WORLDS := [
	{"name": "Backyard Disaster", "short": "Backyard", "unlock": 0, "gravity": 1.0, "music": "music_game",
		"blurb": "Trampolines, pools and bounce houses. Learn to stick the landing.",
		"sky_top": "#3E8EF0", "sky_horizon": "#BFE6FF", "ground": 0, "fog": "#CDEBFF"},
	{"name": "Neighborhood Mayhem", "short": "Neighborhood", "unlock": 300, "gravity": 1.0, "music": "music_game",
		"blurb": "Slide down rooftops, ride moving trucks and bank off satellite dishes.",
		"sky_top": "#4A86E8", "sky_horizon": "#FFE3C2", "ground": 1, "fog": "#FFE9D2"},
	{"name": "Amusement Park", "short": "Amusement Park", "unlock": 400, "gravity": 1.0, "music": "music_game",
		"blurb": "Giant springs, pinball bumpers and fans that blow you sky high.",
		"sky_top": "#7A5CE0", "sky_horizon": "#FFC2DE", "ground": 2, "fog": "#FFD6EA"},
	{"name": "Space Experiments", "short": "Space", "unlock": 500, "gravity": 0.55, "music": "music_space",
		"blurb": "Low gravity, rocket boosters and floating platforms over the moon.",
		"sky_top": "#05061A", "sky_horizon": "#2B1E5C", "ground": 3, "fog": "#1B1640"},
]

## kind: [weight, min_distance]
const SPAWN := [
	{"trampoline": [1.0, 0], "mattress": [0.55, 0], "bounce_house": [0.75, 0], "pool": [0.45, 40], "duck": [0.4, 90],
		"tire": [0.45, 60], "seesaw": [0.35, 150], "slide": [0.35, 200], "cushion": [0.3, 120], "spring": [0.25, 300],
		"rotating": [0.25, 450], "conveyor": [0.2, 350], "ramp": [0.25, 500], "wind": [0.2, 800]},
	{"house": [1.3, 0], "truck": [0.6, 60], "dish": [0.55, 30], "ramp": [0.45, 100], "trampoline": [0.45, 0],
		"mattress": [0.35, 0], "cushion": [0.3, 0], "conveyor": [0.3, 200], "spring": [0.3, 250], "seesaw": [0.25, 300],
		"rotating": [0.2, 500], "wind": [0.25, 700]},
	{"spring": [1.0, 0], "bumper": [0.8, 0], "fan": [0.6, 40], "rotating": [0.5, 150], "wind_tunnel": [0.45, 100],
		"cushion": [0.5, 0], "bounce_house": [0.5, 0], "trampoline": [0.45, 0], "conveyor": [0.3, 200], "tire": [0.3, 150],
		"duck": [0.25, 250], "wind": [0.3, 600]},
	{"floating": [1.3, 0], "booster": [0.6, 0], "thruster": [0.5, 60], "lowgrav": [0.35, 100], "spring": [0.4, 0],
		"bumper": [0.45, 80], "rotating": [0.3, 250], "cushion": [0.3, 0], "wind": [0.25, 600]},
]
const RECOVERY_KINDS := ["trampoline", "mattress", "cushion", "floating", "bounce_house", "spring"]


static func upgrade_cost(base: int, level: int) -> int:
	return int(round(base * pow(1.65, level) / 5.0)) * 5


static func upgrade_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


static func cosmetic_def(slot: String, id: String) -> Dictionary:
	for c in COSMETICS.get(slot, []):
		if c["id"] == id:
			return c
	return {}
