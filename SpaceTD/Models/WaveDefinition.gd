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

# WaveData holds an array of SpawnGroups and a delay before first spawn
class WaveData:
	var groups: Array  # Array[SpawnGroup]
	var pre_delay: float

	func _init(g: Array, d: float = 0.5) -> void:
		groups = g
		pre_delay = d

static func all_waves() -> Array:
	return [
		# Wave 1: 8 scouts
		WaveData.new([SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 8, 1.0)]),
		# Wave 2: 5 scouts + 3 tanks
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 5, 0.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  3, 2.0),
		]),
		# Wave 3: 4 scouts + 5 tanks + 1 boss
		WaveData.new([
			SpawnGroup.new(EnemyDefinition.EnemyType.SCOUT, 4, 0.8),
			SpawnGroup.new(EnemyDefinition.EnemyType.TANK,  5, 1.5),
			SpawnGroup.new(EnemyDefinition.EnemyType.BOSS,  1, 3.0),
		]),
	]
