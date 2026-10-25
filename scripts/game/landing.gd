class_name Landing
extends RefCounted
## Landing quality classes and shared physics tuning.

const PERFECT := 0
const GOOD := 1
const MESSY := 2
const CRASH := 3
const NAMES := ["Perfect", "Good", "Messy", "Crash"]

## Normal-speed multiplier and tangential keep, per quality.
const BOUNCE_MUL := [1.15, 1.0, 0.62, 0.35]
const TANGENT_KEEP := [1.0, 0.92, 0.72, 0.5]

const GRAVITY_SCALE := 2.0      # world gravity 9.8 * 2 = snappy arcade arcs
const AIR_DRAG := 0.018         # fraction of velocity lost per second
const MAX_SPEED := 62.0

## Effective downward acceleration for trajectory estimates.
static func g_eff(world_gravity: float) -> float:
	return 9.8 * GRAVITY_SCALE * world_gravity


## Generic bounce: reflect the normal component with restitution and keep progress moving forward.
static func bounce(v_in: Vector3, n: Vector3, q: int, restitution: float, min_out: float, forward_min: float,
		max_speed := MAX_SPEED) -> Vector3:
	var vn := -v_in.dot(n)
	var vt := v_in + n * vn
	var out_n := maxf(vn * restitution, min_out) * float(BOUNCE_MUL[q])
	var out := vt * float(TANGENT_KEEP[q]) + n * out_n
	if q <= GOOD:
		out.x = maxf(out.x, forward_min)
	else:
		out.x = maxf(out.x, forward_min * 0.5)
	out.z = 0.0
	return out.limit_length(max_speed)
