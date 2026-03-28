## ProjectileNode.gd — Homing projectile
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

var _dot: ColorRect

func setup(t: EnemyNode, dmg: float, spd: float, splash: float, enemies: Array) -> void:
	target = t
	damage = dmg
	projectile_speed = spd
	splash_radius = splash
	_enemies_ref = enemies

	_dot = ColorRect.new()
	_dot.color = Color(1.0, 1.0, 0.2)
	_dot.size = Vector2(8, 8)
	_dot.position = Vector2(-4, -4)
	add_child(_dot)

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return

	var dir = (target.position - position).normalized()
	position += dir * projectile_speed * delta

	if position.distance_to(target.position) < hit_radius:
		_on_hit()

func _on_hit() -> void:
	if splash_radius > 0.0:
		_spawn_splash_ring()
		for enemy in _enemies_ref:
			if is_instance_valid(enemy) and not enemy.is_dead:
				if position.distance_to(enemy.position) <= splash_radius:
					enemy.take_damage(damage)
	else:
		if is_instance_valid(target) and not target.is_dead:
			target.take_damage(damage)

	hit_target.emit()
	queue_free()

func _spawn_splash_ring() -> void:
	var ring = _SplashRing.new()
	ring.radius = splash_radius
	ring.position = position
	if get_parent() != null:
		get_parent().add_child(ring)


## Expanding AoE impact ring
class _SplashRing extends Node2D:
	var radius: float = 60.0
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
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1.0, 0.55, 0.1, alpha), 3.0)
		draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 32, Color(1.0, 0.8, 0.2, alpha * 0.5), 1.5)
