## WaveDefinition.gd — Wave data structures
class_name WaveDefinition

const EnemyDefinition = preload("res://Models/EnemyDefinition.gd")

# SpawnGroup: spawn `count` enemies of `type` with `interval` seconds between each
class SpawnGroup:
	var type: EnemyDefinition.EnemyType
	var count: int
	var interval: float

	func _init(t: EnemyDefinition.EnemyType, c: int, i: float = 1.0) -> void:
		type = t
		count = c
		interval = i

# WaveData holds spawn groups, a pre-delay, and a difficulty scale multiplier
class WaveData:
	var groups: Array  # Array[SpawnGroup]
	var pre_delay: float
	var difficulty_scale: float  # Multiplies enemy HP and partially scales speed

	func _init(g: Array, d: float = 0.5, s: float = 1.0) -> void:
		groups = g
		pre_delay = d
		difficulty_scale = s

# Difficulty scale per wave index (0-based). Gentler curve, caps at 5.5 instead of 8.0.
# 1.0 → 1.08 → ... → 2.18 → 2.42 → ... → 5.50
static func _scale(wave_idx: int) -> float:
	var scales: Array = [
		1.00, 1.08, 1.16, 1.26, 1.36, 1.48, 1.62, 1.78, 1.96, 2.18,  # waves 1-10
		2.42, 2.68, 2.96, 3.26, 3.58, 3.92, 4.28, 4.66, 5.06, 5.50,  # waves 11-20
	]
	return scales[clamp(wave_idx, 0, scales.size() - 1)]

## Returns the 19 scripted campaign waves (wave 20 is the Final Boss — see final_boss_wave())
static func all_waves() -> Array:
	return [
		# Wave 1 — intro: scouts only, very forgiving
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 6, 1.2),
		], 0.5, _scale(0)),
		# Wave 2 — more scouts, still no tanks
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 9, 1.0),
		], 0.5, _scale(1)),
		# Wave 3 — tanks + first speeders
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,   10, 0.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     4, 1.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,  2, 0.6),
		], 0.5, _scale(2)),
		# Wave 4 — tanks and speeders, no boss yet
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,   8,  1.0),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,    4,  2.2),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER, 3,  0.7),
		], 0.5, _scale(3)),
		# Wave 5 — first boss, light escort
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,   8,  0.85),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,    4,  1.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER, 2,  0.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,    1,  4.0),
		], 0.5, _scale(4)),
		# Wave 6 — boss with escort + speeder harass
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,   7, 0.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,    6, 1.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,    1, 4.0),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER, 3, 0.55),
		], 0.5, _scale(5)),
		# Wave 7 — attrition wave + shielded debut
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    10, 0.75),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,      8, 1.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   3, 0.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  2, 3.5),
		], 0.5, _scale(6)),
		# Wave 8 — tank wall + shielded pressure
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    10, 0.7),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     10, 1.3),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  2, 2.8),
		], 0.5, _scale(7)),
		# Wave 9 — two bosses + escort + shielded
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    9,  0.65),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     10, 1.25),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      2, 5.0),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  2, 3.0),
		], 0.5, _scale(8)),
		# Wave 10 — all types
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    11, 0.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     11, 1.15),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      2, 4.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   4, 0.45),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  2, 2.5),
		], 0.5, _scale(9)),
		# Wave 11 — escalation begins
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    11, 0.58),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     11, 1.1),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      2, 4.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   3, 0.4),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  2, 2.5),
		], 0.5, _scale(10)),
		# Wave 12 — tanks + shielded wall
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    11, 0.55),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     11, 1.05),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      2, 4.2),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   3, 0.38),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  3, 2.2),
		], 0.5, _scale(11)),
		# Wave 13 — boss pressure
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    12, 0.52),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     11, 1.0),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      3, 4.2),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   3, 0.36),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  3, 2.0),
		], 0.5, _scale(12)),
		# Wave 14 — tank wall
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    12, 0.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     12, 0.98),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      3, 4.0),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   3, 0.34),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  3, 2.0),
		], 0.5, _scale(13)),
		# Wave 15 — four bosses + everything
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    13, 0.48),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     12, 0.95),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      3, 4.0),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   4, 0.32),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  3, 1.9),
		], 0.5, _scale(14)),
		# Wave 16 — rising density
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    13, 0.46),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     13, 0.92),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      3, 3.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   4, 0.30),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  4, 1.9),
		], 0.5, _scale(15)),
		# Wave 17 — shielded surge
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    14, 0.44),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     13, 0.90),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      4, 3.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   4, 0.28),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  4, 1.8),
		], 0.5, _scale(16)),
		# Wave 18 — boss storm
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    14, 0.42),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     14, 0.88),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      4, 3.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   5, 0.27),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  5, 1.8),
		], 0.5, _scale(17)),
		# Wave 19 — penultimate siege
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    15, 0.40),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     14, 0.85),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,      4, 3.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,   5, 0.26),
			SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,  5, 1.7),
		], 0.5, _scale(18)),
	]

## Wave 20 — Final Boss siege (campaign only)
static func final_boss_wave() -> WaveData:
	return WaveData.new([
		SpawnGroup.new(EnemyDefinition.EnemyType.MEGA_BOSS,  1, 0.0),
		SpawnGroup.new(EnemyDefinition.EnemyType.TANK,       8, 1.5),
		SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED,   4, 3.0),
		SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,    3, 0.4),
	], 2.0, _scale(19))

## Procedurally scaling endless wave (n=0 is first endless wave).
## Exponential difficulty: starts gentle, eventually impossible.
## Mega Boss appears from n=30 onward.
static func generate_endless_wave(n: int) -> WaveData:
	var scale := pow(1.12, n)
	var mult := 1.0 + n * 0.12
	var scouts   := int(14 * mult)
	var tanks    := int(15 * mult)
	var bosses   := 3 + n / 3
	var speeders := int(3 * mult)
	var shielded := 2 + n / 4
	var groups = [
		SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT,    scouts,   max(0.45 - n * 0.008, 0.20)),
		SpawnGroup.new(EnemyDefinition.EnemyType.TANK,     tanks,    max(0.90 - n * 0.012, 0.40)),
		SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,     bosses,   3.5),
		SpawnGroup.new(EnemyDefinition.EnemyType.SPEEDER,  speeders, max(0.30 - n * 0.005, 0.15)),
		SpawnGroup.new(EnemyDefinition.EnemyType.SHIELDED, shielded, 2.0),
	]
	if n >= 30:
		groups.append(SpawnGroup.new(EnemyDefinition.EnemyType.MEGA_BOSS, 1 + n / 10, 5.0))
	return WaveData.new(groups, 0.5, scale)
