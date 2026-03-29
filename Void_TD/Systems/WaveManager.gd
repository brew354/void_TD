## WaveManager.gd — Reads WaveDefinitions and spawns enemies via timers
class_name WaveManager

const WaveDefinition  = preload("res://Models/WaveDefinition.gd")
const EnemyDefinition = preload("res://Models/EnemyDefinition.gd")

signal wave_complete
signal enemy_spawned(enemy_type, wave_scale: float)

var _scene: Node  # GameScene reference for running timers
var _waves: Array
var _current_wave_index: int = 0
var _active_enemy_count: int = 0
var _spawning: bool = false
var _current_wave_scale: float = 1.0

var is_endless: bool = false
var _endless_wave_count: int = 0

func _init(scene: Node, endless: bool = false) -> void:
	_scene = scene
	is_endless = endless
	# Campaign: 19 scripted waves + Final Boss (wave 20)
	# Endless: same 19 scripted waves, then procedural forever (no Final Boss, no win)
	_waves = WaveDefinition.all_waves()
	if not endless:
		_waves.append(WaveDefinition.final_boss_wave())

func current_wave_number() -> int:
	return _current_wave_index + 1

func total_waves() -> int:
	return _waves.size()

func has_more_waves() -> bool:
	if is_endless:
		return true
	return _current_wave_index < _waves.size()

## Returns the groups array for the next wave (empty when past scripted waves)
func get_next_wave_groups() -> Array:
	if _current_wave_index >= _waves.size():
		return []
	return _waves[_current_wave_index].groups

func start_wave() -> void:
	if not has_more_waves() or _spawning:
		return
	_spawning = true
	var wave_data
	if _current_wave_index < _waves.size():
		wave_data = _waves[_current_wave_index]
	else:
		wave_data = WaveDefinition.generate_endless_wave(_endless_wave_count)
		_endless_wave_count += 1
	_current_wave_scale = wave_data.difficulty_scale
	_current_wave_index += 1
	_schedule_wave(wave_data)

func _schedule_wave(wave_data) -> void:
	var delay = wave_data.pre_delay
	for group in wave_data.groups:
		for i in range(group.count):
			var t = _scene.get_tree().create_timer(delay)
			var captured_type = group.type
			t.timeout.connect(func(): _do_spawn(captured_type), CONNECT_ONE_SHOT)
			_active_enemy_count += 1
			delay += group.interval
	# After all spawns, check after a buffer
	var end_timer = _scene.get_tree().create_timer(delay + 0.5)
	end_timer.timeout.connect(_check_wave_end, CONNECT_ONE_SHOT)

func _do_spawn(enemy_type: EnemyDefinition.EnemyType) -> void:
	enemy_spawned.emit(enemy_type, _current_wave_scale)

func on_enemy_resolved() -> void:
	# Called by GameScene when an enemy dies or exits
	_active_enemy_count = max(_active_enemy_count - 1, 0)
	if _active_enemy_count == 0 and _spawning:
		_spawning = false
		wave_complete.emit()

func _check_wave_end() -> void:
	if _active_enemy_count <= 0 and _spawning:
		_spawning = false
		wave_complete.emit()
