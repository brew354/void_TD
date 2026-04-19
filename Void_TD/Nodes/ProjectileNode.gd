## ProjectileNode.gd — Homing projectile with per-tower-type visuals
class_name ProjectileNode
extends Node2D

const EnemyNode = preload("res://Nodes/EnemyNode.gd")

signal hit_target

var target: EnemyNode = null
var damage: float = 0.0
var projectile_speed: float = 400.0
var splash_radius: float = 0.0
var hit_radius: float = 20.0

var _enemies_ref: Array  # Reference to GameScene's enemies array for splash
var _tower_type: int = 0  # int of TowerDefinition.TowerType
var _slow_factor: float = 1.0
var _slow_duration: float = 0.0

var _visual: _ProjectileVisual

func setup(t: EnemyNode, dmg: float, spd: float, splash: float, enemies: Array, ttype: int = 0,
		slow_factor: float = 1.0, slow_duration: float = 0.0) -> void:
	target = t
	damage = dmg
	projectile_speed = spd
	splash_radius = splash
	_enemies_ref = enemies
	_tower_type = ttype
	_slow_factor = slow_factor
	_slow_duration = slow_duration

	_visual = _ProjectileVisual.new()
	_visual.tower_type = ttype
	add_child(_visual)

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return

	var dir = (target.position - position).normalized()
	position += dir * projectile_speed * delta

	# Direction-sensitive visuals face travel direction
	if _tower_type == 0 or _tower_type == 2:  # LASER or MISSILE
		_visual.rotation = dir.angle()

	if position.distance_to(target.position) < hit_radius:
		_on_hit()

func _on_hit() -> void:
	if splash_radius > 0.0:
		_spawn_splash_ring()
		for enemy in _enemies_ref:
			if is_instance_valid(enemy) and not enemy.is_dead:
				if position.distance_to(enemy.position) <= splash_radius:
					enemy.take_damage(damage)
					if _slow_duration > 0.0:
						enemy.apply_slow(_slow_factor, _slow_duration)
	else:
		if is_instance_valid(target) and not target.is_dead:
			target.take_damage(damage)
			if _slow_duration > 0.0:
				target.apply_slow(_slow_factor, _slow_duration)

	hit_target.emit()
	queue_free()

func _spawn_splash_ring() -> void:
	var ring = _SplashRing.new()
	ring.radius = splash_radius
	ring.position = position
	ring.tower_type = _tower_type  # 1=Cannon, 3=Mecha, 4=Freeze
	if get_parent() != null:
		get_parent().add_child(ring)


## Per-tower-type projectile visual
class _ProjectileVisual extends Node2D:
	var tower_type: int = 0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		match tower_type:
			0:  # LASER — thin elongated cyan bolt (node rotated to face direction)
				# Outer glow
				draw_rect(Rect2(0, -3.0, 20, 6), Color(0.15, 0.6, 1.0, 0.35))
				# Mid bolt
				draw_rect(Rect2(0, -1.5, 20, 3), Color(0.35, 0.85, 1.0, 0.85))
				# Bright white core
				draw_rect(Rect2(0, -0.6, 20, 1.2), Color(0.9, 0.98, 1.0, 1.0))
				# Leading tip flare
				draw_circle(Vector2(21, 0), 1.8, Color(1.0, 1.0, 1.0, 0.9))

			1:  # CANNON — dark iron cannonball with orange fire ring
				# Iron core
				draw_circle(Vector2.ZERO, 7.0, Color(0.10, 0.09, 0.07))
				# Glowing orange ring
				draw_arc(Vector2.ZERO, 7.0, 0, TAU, 24, Color(0.95, 0.48, 0.08), 2.5)
				# Hot specular highlight
				draw_circle(Vector2(-2.5, -2.5), 2.5, Color(1.0, 0.72, 0.25, 0.65))

			2:  # MISSILE — silver body, purple nose, orange flame tail (node rotated)
				# Flame trail behind
				var flame = PackedVector2Array([
					Vector2(-10, 0), Vector2(-16, -3.5), Vector2(-16, 3.5)
				])
				draw_colored_polygon(flame, Color(1.0, 0.45, 0.05, 0.75))
				# Inner flame
				var inner_flame = PackedVector2Array([
					Vector2(-10, 0), Vector2(-14, -1.8), Vector2(-14, 1.8)
				])
				draw_colored_polygon(inner_flame, Color(1.0, 0.9, 0.3, 0.9))
				# Silver body
				draw_rect(Rect2(-9, -3.0, 19, 6), Color(0.82, 0.83, 0.88))
				# Dark panel line
				draw_line(Vector2(-9, 0), Vector2(10, 0), Color(0.5, 0.5, 0.55, 0.4), 0.8)
				# Purple nose cone
				var nose = PackedVector2Array([
					Vector2(10, -3.0), Vector2(16, 0), Vector2(10, 3.0)
				])
				draw_colored_polygon(nose, Color(0.68, 0.18, 0.88))
				# Nose tip highlight
				draw_circle(Vector2(15, 0), 1.2, Color(0.9, 0.6, 1.0, 0.8))

			3:  # MECHA SOLDIER — spinning red plasma cross with bright core
				var t := Time.get_ticks_msec() * 0.007
				# Outer slow-spinning halo
				draw_arc(Vector2.ZERO, 9.5, t, t + TAU * 0.65, 24,
						Color(1.0, 0.18, 0.0, 0.35), 2.0)
				# Spinning cross arms
				draw_set_transform(Vector2.ZERO, t * 1.5)
				draw_rect(Rect2(-3.5, -10, 7, 20), Color(1.0, 0.18, 0.0, 0.88))
				draw_rect(Rect2(-10, -3.5, 20, 7), Color(1.0, 0.18, 0.0, 0.88))
				draw_set_transform(Vector2.ZERO, 0.0)
				# Bright plasma core
				draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.85, 0.3))
				draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 0.9))


## Expanding AoE impact ring
class _SplashRing extends Node2D:
	var radius: float = 60.0
	var tower_type: int = 1  # 1=Cannon, 3=Mecha, 4=Freeze
	var _t: float = 0.0
	const DURATION: float = 0.35

	func _process(delta: float) -> void:
		_t += delta
		if _t >= DURATION:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := _t / DURATION
		var alpha := (1.0 - progress) * 0.75
		var r := radius * (0.4 + progress * 0.6)
		if tower_type == 3:  # Mecha — red
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1.0, 0.15, 0.0, alpha), 3.0)
			draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 32, Color(1.0, 0.5, 0.2, alpha * 0.5), 1.5)
		elif tower_type == 4:  # Freeze — ice blue, slower expand
			var rf := radius * (0.3 + progress * 0.7)
			draw_arc(Vector2.ZERO, rf, 0, TAU, 32, Color(0.4, 0.85, 1.0, alpha), 3.0)
			draw_arc(Vector2.ZERO, rf * 0.65, 0, TAU, 32, Color(0.8, 0.96, 1.0, alpha * 0.6), 1.5)
		else:  # Cannon — orange
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1.0, 0.55, 0.1, alpha), 3.0)
			draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 32, Color(1.0, 0.8, 0.2, alpha * 0.5), 1.5)


