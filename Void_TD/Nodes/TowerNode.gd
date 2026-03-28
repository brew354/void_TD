## TowerNode.gd — Tower that fires projectiles at enemies
class_name TowerNode
extends Node2D

const TowerDefinition  = preload("res://Models/TowerDefinition.gd")
const EnemyNode        = preload("res://Nodes/EnemyNode.gd")
const ProjectileNode   = preload("res://Nodes/ProjectileNode.gd")

signal fired(tower_type: TowerDefinition.TowerType)

var tower_type: TowerDefinition.TowerType
var damage: float
var range_radius: float
var fire_rate: float
var splash_radius: float
var projectile_speed: float

var upgrade_level: int = 1
var base_damage: float
var base_range: float
var total_invested: int
var _level_label: Label

var _fire_cooldown: float = 0.0
var _stun_timer: float = 0.0
var _projectile_layer: Node2D  # Set by GameScene after placing
var _enemies_ref: Array  # Reference to GameScene's live enemies

var _body: ColorRect
var _normal_color: Color
var _range_ring: Node2D
var _fire_tween: Tween

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
	base_damage = damage
	base_range = range_radius
	total_invested = s["cost"]

	# Body: colored square
	var colors = {
		TowerDefinition.TowerType.LASER:         Color(0.2, 0.6, 1.0),
		TowerDefinition.TowerType.CANNON:        Color(0.9, 0.5, 0.1),
		TowerDefinition.TowerType.MISSILE:       Color(0.8, 0.2, 0.8),
		TowerDefinition.TowerType.MECHA_SOLDIER: Color(1.0, 0.15, 0.0),
	}
	_body = ColorRect.new()
	_body.color = colors[type]
	_normal_color = colors[type]
	_body.size = Vector2(40, 40)
	_body.position = Vector2(-20, -20)
	_body.pivot_offset = Vector2(20, 20)
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
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

	# Level label (bottom-right of body, hidden at L1)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 10)
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	_level_label.position = Vector2(12, 12)
	_level_label.visible = false
	add_child(_level_label)

func upgrade() -> void:
	upgrade_level += 1
	var m = TowerDefinition.upgrade_multipliers(upgrade_level)
	damage = base_damage * m["damage"]
	range_radius = base_range * m["range"]
	for child in _range_ring.get_children():
		if child is _RangeRing:
			child.radius = range_radius
			child.queue_redraw()
	total_invested += TowerDefinition.upgrade_cost(tower_type, upgrade_level)
	_level_label.text = "L%d" % upgrade_level
	_level_label.visible = true

func apply_stun(duration: float) -> void:
	if _fire_tween:
		_fire_tween.kill()
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

	var target = _pick_target()
	if target != null:
		_body.rotation = (target.position - position).angle()

	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return
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
	# Fire flash
	if _fire_tween:
		_fire_tween.kill()
	_body.color = _normal_color.lightened(0.7)
	_fire_tween = create_tween()
	_fire_tween.tween_property(_body, "color", _normal_color, 0.12)
	fired.emit(tower_type)


## Inner helper class for drawing the range ring
class _RangeRing extends Node2D:
	var radius: float = 100.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1, 1, 1, 0.15), 1.0)
