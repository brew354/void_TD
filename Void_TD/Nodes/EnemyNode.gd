## EnemyNode.gd — Path-following enemy with HP
class_name EnemyNode
extends Node2D

const GameConfig      = preload("res://Models/GameConfig.gd")
const EnemyDefinition = preload("res://Models/EnemyDefinition.gd")

signal died(enemy)
signal exited(enemy)
signal stun_pulse(pos: Vector2, radius: float, duration: float)

var enemy_type: EnemyDefinition.EnemyType
var max_hp: float
var current_hp: float
var speed: float
var reward: int
var lives_damage: int
var is_boss: bool = false

var path_progress: float = 0.0  # 0.0 = spawn, 1.0 = exit
var is_dead: bool = false

var _stun_range: float = 0.0
var _stun_interval: float = 0.0
var _stun_duration: float = 0.0
var _stun_pulse_timer: float = 0.0

var _waypoints: Array
var _current_waypoint: int = 1
var _total_path_length: float = 0.0
var _distance_traveled: float = 0.0

var _body_rect: ColorRect
var _hp_bar_bg: ColorRect
var _hp_bar_fg: ColorRect

func setup(type: EnemyDefinition.EnemyType, wave_scale: float = 1.0) -> void:
	enemy_type = type
	var s = EnemyDefinition.stats(type)
	max_hp = float(s["hp"]) * wave_scale
	current_hp = max_hp
	speed = float(s["speed"]) * (1.0 + (wave_scale - 1.0) * 0.3)
	reward = int(s["reward"])
	lives_damage = int(s["lives_damage"])

	if s.has("is_boss"):
		is_boss = true
		_stun_range = float(s["stun_range"])
		_stun_interval = float(s["stun_interval"])
		_stun_duration = float(s["stun_duration"])
		_stun_pulse_timer = _stun_interval

	_waypoints = GameConfig.PATH_WAYPOINTS
	position = _waypoints[0]
	_current_waypoint = 1

	# Compute total path length for progress tracking
	_total_path_length = 0.0
	for i in range(_waypoints.size() - 1):
		_total_path_length += _waypoints[i].distance_to(_waypoints[i + 1])

	# Build visuals
	var sz: Vector2 = s["size"]
	_body_rect = ColorRect.new()
	_body_rect.color = s["color"]
	_body_rect.size = sz
	_body_rect.position = -sz / 2.0
	add_child(_body_rect)

	# HP bar background
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.2, 0.0, 0.0)
	_hp_bar_bg.size = Vector2(sz.x, 5)
	_hp_bar_bg.position = Vector2(-sz.x / 2.0, -sz.y / 2.0 - 8)
	add_child(_hp_bar_bg)

	# HP bar foreground
	_hp_bar_fg = ColorRect.new()
	_hp_bar_fg.color = Color(0.0, 1.0, 0.2)
	_hp_bar_fg.size = Vector2(sz.x, 5)
	_hp_bar_fg.position = _hp_bar_bg.position
	add_child(_hp_bar_fg)

func _process(delta: float) -> void:
	if is_dead:
		return
	if _current_waypoint >= _waypoints.size():
		_on_exit()
		return

	var target = _waypoints[_current_waypoint]
	var dir = (target - position).normalized()
	var dist_to_target = position.distance_to(target)
	var move_dist = speed * delta

	if move_dist >= dist_to_target:
		position = target
		_distance_traveled += dist_to_target
		_current_waypoint += 1
	else:
		position += dir * move_dist
		_distance_traveled += move_dist

	path_progress = _distance_traveled / _total_path_length if _total_path_length > 0 else 0.0
	path_progress = clamp(path_progress, 0.0, 1.0)

	if is_boss:
		_stun_pulse_timer -= delta
		if _stun_pulse_timer <= 0.0:
			stun_pulse.emit(position, _stun_range, _stun_duration)
			_stun_pulse_timer = _stun_interval

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= amount
	_update_hp_bar()
	if current_hp <= 0:
		_on_die()

func _update_hp_bar() -> void:
	if _hp_bar_fg:
		var ratio = clamp(current_hp / max_hp, 0.0, 1.0)
		var full_w = _hp_bar_bg.size.x
		_hp_bar_fg.size.x = full_w * ratio
		if ratio > 0.5:
			_hp_bar_fg.color = Color(0.0, 1.0, 0.2).lerp(Color(1.0, 1.0, 0.0), (1.0 - ratio) * 2.0)
		else:
			_hp_bar_fg.color = Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.0, 0.0), (0.5 - ratio) * 2.0)

func _on_die() -> void:
	if is_dead:
		return
	is_dead = true
	_body_rect.color = Color.WHITE
	_hp_bar_bg.visible = false
	_hp_bar_fg.visible = false
	died.emit(self)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(_body_rect, "modulate:a", 0.0, 0.12)
	await tween.finished
	queue_free()

func _on_exit() -> void:
	if is_dead:
		return
	is_dead = true
	exited.emit(self)
	queue_free()
