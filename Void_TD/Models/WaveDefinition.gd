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

# Non-linear curve: gentle early game, steep late game
# 1.0 → 1.12 → 1.25 → 1.40 → 1.58 → 1.78 → 2.02 → 2.30 → 2.62 → 3.00
static func _scale(wave_idx: int) -> float:
	var scales: Array = [1.0, 1.12, 1.25, 1.40, 1.58, 1.78, 2.02, 2.30, 2.62, 3.00]
	return scales[clamp(wave_idx, 0, scales.size() - 1)]

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
		# Wave 3 — first boss with light escort (boss is the real threat)
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 5, 0.9),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  2, 2.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,  1, 3.0),
		], 0.5, _scale(2)),
		# Wave 4 — proper tank introduction, pressure building
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 10, 0.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,   4, 1.8),
		], 0.5, _scale(3)),
		# Wave 5 — heavier mix, Mecha Soldier becomes very useful
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 10, 0.75),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,   6, 1.5),
		], 0.5, _scale(4)),
		# Wave 6 — boss with full escort, real challenge begins
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 8, 0.7),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  8, 1.4),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,  1, 3.5),
		], 0.5, _scale(5)),
		# Wave 7 — attrition: scale hits 2.0, requires upgraded towers
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 13, 0.65),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  10, 1.3),
		], 0.5, _scale(6)),
		# Wave 8 — tank wall: splash and Mecha essential
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 12, 0.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  12, 1.15),
		], 0.5, _scale(7)),
		# Wave 9 — two bosses plus brutal escort
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 10, 0.55),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  13, 1.1),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,   2, 4.0),
		], 0.5, _scale(8)),
		# Wave 10 — finale: maximum everything
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 14, 0.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  15, 1.0),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,   3, 4.0),
		], 0.5, _scale(9)),
	]
