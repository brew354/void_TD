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

# Scale increases 0.18 per wave: wave 1 = 1.0, wave 5 = 1.72, wave 10 = 2.62
static func _scale(wave_idx: int) -> float:
	return 1.0 + wave_idx * 0.18

static func all_waves() -> Array:
	return [
		# Wave 1 — intro
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 8, 1.0),
		], 0.5, _scale(0)),
		# Wave 2
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 5, 0.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  3, 2.0),
		], 0.5, _scale(1)),
		# Wave 3 — first boss
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 4, 0.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  5, 1.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,  1, 3.0),
		], 0.5, _scale(2)),
		# Wave 4
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 10, 0.7),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,   3, 1.8),
		], 0.5, _scale(3)),
		# Wave 5
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 8, 0.7),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  5, 1.5),
		], 0.5, _scale(4)),
		# Wave 6 — boss
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 6, 0.7),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  6, 1.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,  1, 3.0),
		], 0.5, _scale(5)),
		# Wave 7
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 12, 0.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,   7, 1.4),
		], 0.5, _scale(6)),
		# Wave 8
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 10, 0.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,   8, 1.3),
		], 0.5, _scale(7)),
		# Wave 9 — boss
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 8, 0.6),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  9, 1.3),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,  1, 3.0),
		], 0.5, _scale(8)),
		# Wave 10 — finale
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 12, 0.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  12, 1.2),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,   2, 3.0),
		], 0.5, _scale(9)),
	]
