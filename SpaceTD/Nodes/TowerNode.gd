## TowerNode.gd — Tower that fires projectiles at enemies
class_name TowerNode
extends Node2D

const TowerDefinition  = preload("res://Models/TowerDefinition.gd")
const EnemyNode        = preload("res://Nodes/EnemyNode.gd")
const ProjectileNode   = preload("res://Nodes/ProjectileNode.gd")

var tower_type: TowerDefinition.TowerType
var damage: float
var range_radius: float
var fire_rate: float
var splash_radius: float
var projectile_speed: float

var _fire_cooldown: float = 0.0
var _stun_timer: float = 0.0
var _projectile_layer: Node2D  # Set by GameScene after placing
var _enemies_ref: Array  # Reference to GameScene's live enemies

var _body: ColorRect
var _normal_color: Color
var _range_ring: Node2D

func setup(type: TowerDefinition.TowerType, enemies: Array, proj_layer: Node2D) -> void:
	tower_type = type
	_enemies_ref = enemies
	_projectile_layer = proj_layer

	var s = TowerDefinition.stats(type)
	damage = float(s["damage"])
	range_radius = float(s["range"])
	fire_rate = float(s["fire_rate"])
	splash_radius = float(s["splash_radius"])
	projectile_speed = float(s["projectile_speed"])

	# Body: colored square
	var colors = {
		TowerDefinition.TowerType.LASER:   Color(0.2, 0.6, 1.0),
		TowerDefinition.TowerType.CANNON:  Color(0.9, 0.5, 0.1),
		TowerDefinition.TowerType.MISSILE: Color(0.8, 0.2, 0.8),
	}
	_body = ColorRect.new()
	_body.color = colors[type]
	_normal_color = colors[type]
	_body.size = Vector2(40, 40)
	_body.position = Vector2(-20, -20)
	add_child(_body)

	# Range ring — visible on hover only
	_range_ring = Node2D.new()
	_range_ring.visible = false
	add_child(_range_ring)
	var ring = _RangeRing.new()
	ring.radius = range_radius
	_range_ring.add_child(ring)
	_body.mouse_entered.connect(func(): _range_ring.visible = true)
	_body.mouse_exited.connect(func(): _range_ring.visible = false)

func apply_stun(duration: float) -> void:
	_stun_timer = max(_stun_timer, duration)
	_body.color = Color(0.4, 0.4, 0.5)

func update_tower(delta: float, enemies: Array) -> void:
	_enemies_ref = enemies
	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_stun_timer = 0.0
			_body.color = _normal_color
		return

	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return

	var target = _pick_target()
	if target == null:
		return

	_fire_cooldown = fire_rate
	_spawn_projectile(target)

func _pick_target() -> EnemyNode:
	var best: EnemyNode = null
	var best_progress: float = -1.0
	for e in _enemies_ref:
		if not is_instance_valid(e) or e.is_dead:
			continue
		if position.distance_to(e.position) <= range_radius:
			if e.path_progress > best_progress:
				best_progress = e.path_progress
				best = e
	return best

func _spawn_projectile(target: EnemyNode) -> void:
	if _projectile_layer == null:
		return
	var proj = ProjectileNode.new()
	proj.position = position
	_projectile_layer.add_child(proj)
	proj.setup(target, damage, projectile_speed, splash_radius, _enemies_ref)


## Inner helper class for drawing the range ring
class _RangeRing extends Node2D:
	var radius: float = 100.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1, 1, 1, 0.15), 1.0)
