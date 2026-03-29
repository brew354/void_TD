## TowerNode.gd — Tower that fires projectiles at enemies
class_name TowerNode
extends Node2D

const TowerDefinition  = preload("res://Models/TowerDefinition.gd")
const EnemyNode        = preload("res://Nodes/EnemyNode.gd")
const ProjectileNode   = preload("res://Nodes/ProjectileNode.gd")
const TowerSkins       = preload("res://Models/TowerSkins.gd")

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
var _projectile_layer: Node2D
var _enemies_ref: Array

var _base_sprite: Sprite2D
var _barrel_sprite: Sprite2D
var _mouse_rect: ColorRect      # transparent overlay for hover/click detection
var _normal_modulate: Color
var _range_ring: Node2D
var _fire_tween: Tween

# Sprite asset paths indexed by TowerType int
const _BASE_PATHS = {
	0: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/laser_cannon/laser_cannon_turret.png",
	1: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/plasma_cannon/plasma_cannon.png",
	2: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/flak_cannon/flak_turret.png",
	3: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/heavy_laser_cannon/heavy_laser_cannon.png",
}
const _BARREL_PATHS = {
	0: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/laser_cannon/laser_cannon_barrel.png",
	1: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/plasma_cannon/plasma_cannon_barrel.png",
	2: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/flak_cannon/flak_barrel.png",
	3: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/heavy_laser_cannon/heavy_laser_cannon_barrel.png",
}
# Uniform scale applied to both base and barrel to reach ~48 px display size
const _SPRITE_SCALE = {0: 1.5, 1: 1.5, 2: 1.0, 3: 1.0}
# Barrel offset.y (local, pre-scale) so the barrel's bottom aligns with the node origin
const _BARREL_OFFSET_Y = {0: -16.0, 1: -16.0, 2: -24.0, 3: -16.0}

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

	var ti: int = int(type)
	# Color.WHITE = show natural sprite; any override = tint the sprite that color
	_normal_modulate = TowerSkins.overrides.get(ti, Color.WHITE)

	# Base sprite (stationary)
	_base_sprite = Sprite2D.new()
	_base_sprite.texture = load(_BASE_PATHS[ti])
	_base_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_sprite.scale = Vector2(_SPRITE_SCALE[ti], _SPRITE_SCALE[ti])
	_base_sprite.modulate = _normal_modulate
	add_child(_base_sprite)

	# Barrel sprite (rotates to face target; offset so bottom is at node origin)
	_barrel_sprite = Sprite2D.new()
	_barrel_sprite.texture = load(_BARREL_PATHS[ti])
	_barrel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_barrel_sprite.scale = Vector2(_SPRITE_SCALE[ti], _SPRITE_SCALE[ti])
	_barrel_sprite.offset = Vector2(0.0, _BARREL_OFFSET_Y[ti])
	_barrel_sprite.modulate = _normal_modulate
	add_child(_barrel_sprite)

	# Transparent ColorRect for hover detection (Control nodes have mouse signals)
	_mouse_rect = ColorRect.new()
	_mouse_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_mouse_rect.size = Vector2(48, 48)
	_mouse_rect.position = Vector2(-24, -24)
	_mouse_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_mouse_rect.mouse_entered.connect(func(): _range_ring.visible = true)
	_mouse_rect.mouse_exited.connect(func(): _range_ring.visible = false)
	add_child(_mouse_rect)

	# Range ring — visible on hover only
	_range_ring = Node2D.new()
	_range_ring.visible = false
	add_child(_range_ring)
	var ring = _RangeRing.new()
	ring.radius = range_radius
	_range_ring.add_child(ring)

	# Level label (bottom-right, hidden at L1)
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
	var stun_col := Color(0.4, 0.4, 0.5)
	_base_sprite.modulate   = stun_col
	_barrel_sprite.modulate = stun_col

func update_tower(delta: float, enemies: Array) -> void:
	_enemies_ref = enemies
	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_stun_timer = 0.0
			_base_sprite.modulate   = _normal_modulate
			_barrel_sprite.modulate = _normal_modulate
		return

	var target = _pick_target()
	if target != null:
		_barrel_sprite.rotation = (target.position - position).angle() + PI / 2.0

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
	proj.setup(target, damage, projectile_speed, splash_radius, _enemies_ref, int(tower_type))
	# Fire flash — briefly brighten then fade back
	if _fire_tween:
		_fire_tween.kill()
	var flash_col := Color(_normal_modulate.r * 2.5, _normal_modulate.g * 2.5,
						   _normal_modulate.b * 2.5, 1.0)
	_base_sprite.modulate   = flash_col
	_barrel_sprite.modulate = flash_col
	_fire_tween = create_tween().set_parallel(true)
	_fire_tween.tween_property(_base_sprite,   "modulate", _normal_modulate, 0.12)
	_fire_tween.tween_property(_barrel_sprite, "modulate", _normal_modulate, 0.12)
	fired.emit(tower_type)


## Inner helper class for drawing the range ring
class _RangeRing extends Node2D:
	var radius: float = 100.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1, 1, 1, 0.15), 1.0)
