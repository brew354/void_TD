## EnemyNode.gd — Path-following enemy with HP
class_name EnemyNode
extends Node2D

const GameConfig      = preload("res://Models/GameConfig.gd")
const EnemyDefinition = preload("res://Models/EnemyDefinition.gd")

signal died(enemy)
signal exited(enemy)
signal stun_pulse(pos: Vector2, radius: float, duration: float)
signal armor_broken
signal hp_changed(ratio: float)

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

# Shield (Shielded enemy type)
var _is_shielded: bool = false
var _shield_phase_timer: float = 0.0
var _shield_interval_val: float = 0.0
var _shield_duration_val: float = 0.0
var _shield_ring_node: Node2D = null

# Slow (applied by Void Stunner)
var _slow_factor: float = 1.0   # 1.0 = full speed; 0.45 = heavily slowed
var _slow_timer: float = 0.0

# Void Rupture (applied by Void Stunner on bosses — take 2× damage)
var _is_ruptured: bool = false
var _rupture_timer: float = 0.0
var _rupture_ring_node: Node2D = null

# Base sprite tint — changes permanently on armor break
var _base_tint: Color = Color.WHITE

# Armor phases (Mega Boss)
var _is_armored: bool = false
var _armor_threshold: float = 0.0
var _armor_phase2_speed: float = 0.0
var _armor_ring_node: Node2D = null

var _waypoints: Array
var _current_waypoint: int = 1
var _total_path_length: float = 0.0
var _distance_traveled: float = 0.0

var _sprite: Sprite2D
var _hp_bar_bg: ColorRect
var _hp_bar_fg: ColorRect
var _shard_color: Color = Color.WHITE

# Sprite paths indexed by EnemyType int
const _SPRITE_PATHS = {
	0: "res://Assets/enemies/spaceships/spaceshipset32x32/enemy_1.png",     # SCOUT
	1: "res://Assets/enemies/spaceships/spaceshipset32x32/enemy_3.png",     # TANK
	2: "res://Assets/enemies/spaceships/spaceshipset32x32/boss1.png",       # BOSS (Void Herald)
	3: "res://Assets/enemies/spaceships/spaceshipset32x32/player_ship.png", # SPEEDER
	4: "res://Assets/enemies/spaceships/spaceshipset32x32/enemy_2.png",     # SHIELDED
	5: "res://Assets/enemies/spaceships/spaceshipset32x32/boss1.png",       # MEGA_BOSS
}
# Natural pixel size of each sprite (boss1 is 128×128, all others 32×32)
const _NATURAL_PX = {0: 32, 1: 32, 2: 128, 3: 32, 4: 32, 5: 128}

func setup(type: EnemyDefinition.EnemyType, wave_scale: float = 1.0, speed_scale: float = 1.0) -> void:
	enemy_type = type
	var s = EnemyDefinition.stats(type)
	max_hp = float(s["hp"]) * wave_scale
	current_hp = max_hp
	speed = float(s["speed"]) * speed_scale
	reward = int(s["reward"])
	lives_damage = int(s["lives_damage"])

	if s.has("is_boss"):
		is_boss = true
		_stun_range = float(s["stun_range"])
		_stun_interval = float(s["stun_interval"])
		_stun_duration = float(s["stun_duration"])
		_stun_pulse_timer = _stun_interval

	if s.has("shield_interval"):
		_shield_interval_val = float(s["shield_interval"])
		_shield_duration_val = float(s["shield_duration"])
		_shield_phase_timer = _shield_interval_val

	if s.has("armor_threshold"):
		_armor_threshold = float(s["armor_threshold"])
		_armor_phase2_speed = speed * 2.0
		_is_armored = true

	# Shard color: lighten the enemy color; fall back to void purple if too dark
	var raw: Color = s["color"]
	_shard_color = raw.lightened(0.45) if (raw.r + raw.g + raw.b) > 0.25 else Color(0.65, 0.15, 1.0)

	_waypoints = GameConfig.PATH_WAYPOINTS
	position = _waypoints[0]
	_current_waypoint = 1

	# Compute total path length for progress tracking
	_total_path_length = 0.0
	for i in range(_waypoints.size() - 1):
		_total_path_length += _waypoints[i].distance_to(_waypoints[i + 1])

	# Build sprite
	var sz: Vector2 = s["size"]
	var ti: int = int(type)
	var natural_px: float = float(_NATURAL_PX[ti])
	var sf: float = sz.x / natural_px

	_sprite = Sprite2D.new()
	_sprite.texture = load(_SPRITE_PATHS[ti])
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(sf, sf)
	add_child(_sprite)

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

	# Shield ring (only for SHIELDED type)
	if _shield_interval_val > 0.0:
		_shield_ring_node = Node2D.new()
		_shield_ring_node.visible = false
		add_child(_shield_ring_node)
		var ring = _ShieldRing.new()
		ring.ring_radius = sz.x / 2.0 + 7.0
		_shield_ring_node.add_child(ring)

	# Armor ring (only for MEGA_BOSS)
	if _is_armored:
		_armor_ring_node = Node2D.new()
		add_child(_armor_ring_node)
		var aring = _ArmorRing.new()
		aring.ring_radius = sz.x / 2.0 + 10.0
		_armor_ring_node.add_child(aring)

	# Rupture ring (all bosses — visible when Void Ruptured)
	if is_boss:
		_rupture_ring_node = Node2D.new()
		_rupture_ring_node.visible = false
		add_child(_rupture_ring_node)
		var rring = _RuptureRing.new()
		rring.ring_radius = sz.x / 2.0 + 16.0
		_rupture_ring_node.add_child(rring)

func _process(delta: float) -> void:
	if is_dead:
		return
	if _current_waypoint >= _waypoints.size():
		_on_exit()
		return

	# Tick slow timer
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_slow_factor = 1.0
			_update_tint()

	# Tick void rupture
	if _rupture_timer > 0.0:
		_rupture_timer -= delta
		if _rupture_timer <= 0.0:
			_rupture_timer = 0.0
			_is_ruptured = false
			if _rupture_ring_node != null:
				_rupture_ring_node.visible = false

	var target = _waypoints[_current_waypoint]
	var dir = (target - position).normalized()
	var dist_to_target = position.distance_to(target)
	var move_dist = speed * _slow_factor * delta

	# Rotate sprite to face movement direction (sprites point up by default)
	_sprite.rotation = dir.angle() + PI / 2.0

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

	# Shield phase cycling
	if _shield_interval_val > 0.0:
		_shield_phase_timer -= delta
		if _shield_phase_timer <= 0.0:
			_is_shielded = not _is_shielded
			_shield_phase_timer = _shield_duration_val if _is_shielded else _shield_interval_val
			if _shield_ring_node != null:
				_shield_ring_node.visible = _is_shielded

func apply_slow(factor: float, duration: float) -> void:
	if is_dead:
		return
	_slow_factor = min(_slow_factor, factor)
	_slow_timer  = max(_slow_timer, duration)
	_update_tint()

func apply_rupture(duration: float) -> void:
	if is_dead or not is_boss:
		return
	_is_ruptured = true
	_rupture_timer = max(_rupture_timer, duration)
	if _rupture_ring_node != null:
		_rupture_ring_node.visible = true

func _update_tint() -> void:
	if is_dead:
		return
	if _slow_timer > 0.0:
		_sprite.modulate = Color(0.55, 0.85, 1.0)  # ice blue
	else:
		_sprite.modulate = _base_tint

func take_damage(amount: float) -> void:
	if is_dead:
		return
	if _is_shielded:
		# Flash shield ring to indicate blocked damage
		if _shield_ring_node != null:
			for child in _shield_ring_node.get_children():
				if child is _ShieldRing:
					child.flash()
		return
	# Armored phase: absorb 80% of damage
	var effective := amount * (0.2 if _is_armored else 1.0)
	# Void Rupture: boss takes 2× damage while ruptured
	if _is_ruptured:
		effective *= 2.0
	current_hp -= effective
	_update_hp_bar()
	if _is_armored and current_hp <= _armor_threshold:
		_break_armor()
	if current_hp <= 0:
		_on_die()

func _break_armor() -> void:
	_is_armored = false
	speed = _armor_phase2_speed
	# Remove armor ring
	if _armor_ring_node != null:
		_armor_ring_node.queue_free()
		_armor_ring_node = null
	# Permanently tint orange-red to show exposed state
	_base_tint = Color(1.0, 0.3, 0.06)
	_update_tint()
	armor_broken.emit()

func _update_hp_bar() -> void:
	if _hp_bar_fg:
		var ratio = clamp(current_hp / max_hp, 0.0, 1.0)
		var full_w = _hp_bar_bg.size.x
		_hp_bar_fg.size.x = full_w * ratio
		if ratio > 0.5:
			_hp_bar_fg.color = Color(0.0, 1.0, 0.2).lerp(Color(1.0, 1.0, 0.0), (1.0 - ratio) * 2.0)
		else:
			_hp_bar_fg.color = Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.0, 0.0), (0.5 - ratio) * 2.0)
		hp_changed.emit(ratio)

func _on_die() -> void:
	if is_dead:
		return
	is_dead = true
	_hp_bar_bg.visible = false
	_hp_bar_fg.visible = false
	died.emit(self)
	_spawn_death_shards()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.12)
	await tween.finished
	queue_free()

func _spawn_death_shards() -> void:
	var parent = get_parent()
	if parent == null:
		return
	var num := 7 if not is_boss else 12
	for i in num:
		var angle := randf() * TAU
		var spd   := randf_range(55.0, 130.0)
		var sz    := randf_range(3.0, 7.0)
		var dur   := randf_range(0.28, 0.48)

		var shard = ColorRect.new()
		shard.color = _shard_color
		shard.size = Vector2(sz, sz)
		shard.position = position + Vector2(-sz * 0.5, -sz * 0.5)
		parent.add_child(shard)

		var end_pos: Vector2 = shard.position + Vector2(cos(angle), sin(angle)) * spd * dur
		var tw := parent.create_tween().set_parallel(true)
		tw.tween_property(shard, "position", end_pos, dur)
		tw.tween_property(shard, "color:a",  0.0,     dur)
		tw.tween_property(shard, "scale",    Vector2(0.1, 0.1), dur)
		tw.finished.connect(shard.queue_free)

func _on_exit() -> void:
	if is_dead:
		return
	is_dead = true
	exited.emit(self)
	queue_free()


## Rotating armor ring for Mega Boss (phase 1)
class _ArmorRing extends Node2D:
	var ring_radius: float = 25.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.7 + 0.3 * sin(_t * 2.5)
		draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 48, Color(0.55, 0.55, 0.6, pulse), 4.0, true)
		draw_arc(Vector2.ZERO, ring_radius - 6.0, 0, TAU, 48, Color(0.8, 0.8, 0.85, pulse * 0.5), 1.5, true)
		for i in 4:
			var angle := _t * 0.4 + i * TAU / 4.0
			var bp := Vector2(cos(angle), sin(angle)) * ring_radius
			draw_circle(bp, 3.0, Color(0.9, 0.9, 1.0, pulse))


## Pulsing blue shield ring for Shielded enemy
class _ShieldRing extends Node2D:
	var ring_radius: float = 20.0
	var _t: float = 0.0
	var _flash_t: float = 0.0

	func flash() -> void:
		_flash_t = 0.2

	func _process(delta: float) -> void:
		_t += delta
		if _flash_t > 0.0:
			_flash_t -= delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var base_alpha := 0.55 + pulse * 0.25
		var extra := (_flash_t / 0.2) * 0.45 if _flash_t > 0.0 else 0.0
		var a := base_alpha + extra
		draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 32, Color(0.3, 0.6, 1.0, a), 2.5, true)
		draw_arc(Vector2.ZERO, ring_radius - 4.0, 0, TAU, 32, Color(0.7, 0.9, 1.0, a * 0.4), 1.0, true)


## Pulsing magenta rupture ring — visible while Void Ruptured
class _RuptureRing extends Node2D:
	var ring_radius: float = 30.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.6 + 0.4 * sin(_t * 7.0)
		draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 32, Color(1.0, 0.15, 0.8, pulse), 3.5, true)
		draw_arc(Vector2.ZERO, ring_radius - 5.0, 0, TAU, 32, Color(1.0, 0.6, 0.9, pulse * 0.45), 1.5, true)
		# Corner spikes to make it feel volatile
		for i in 4:
			var angle := _t * 1.2 + i * TAU / 4.0
			var tip := Vector2(cos(angle), sin(angle)) * (ring_radius + 5.0)
			var base1 := Vector2(cos(angle + 0.25), sin(angle + 0.25)) * (ring_radius - 3.0)
			var base2 := Vector2(cos(angle - 0.25), sin(angle - 0.25)) * (ring_radius - 3.0)
			draw_colored_polygon(PackedVector2Array([tip, base1, base2]),
					Color(1.0, 0.2, 0.85, pulse * 0.8))
