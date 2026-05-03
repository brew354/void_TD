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
	2: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/missile_launcher_base.png",
	3: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/autocannon/autocannon2.png",
	4: "res://Assets/towers/kenney_sci-fi-rts/PNG/Default size/Environment/scifiEnvironment_04.png",
	5: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/flak_cannon/flak_turret.png",
}
const _BARREL_PATHS = {
	0: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/laser_cannon/laser_cannon_barrel.png",
	1: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/plasma_cannon/plasma_cannon_barrel.png",
	2: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/autocannon/autocannon_barrel.png",
	3: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/mecha_soldier_base.png",
	5: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/flak_cannon/flak_barrel.png",
}
# Uniform scale applied to both base and barrel to reach ~48 px display size
const _BASE_SCALE   = {0: 1.5,  1: 1.5, 2: 0.75, 3: 1.5, 4: 2.0, 5: 1.5}
const _BARREL_SCALE = {0: 0.8,  1: 1.5, 2: 2.0,  3: 0.85, 5: 1.0}
const _BARREL_OFFSET_Y = {0: -16.0, 1: -16.0, 2: -8.0, 3: 0.0, 5: -16.0}

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
	var default_tint := Color.WHITE
	if type == TowerDefinition.TowerType.FREEZE:
		default_tint = Color(0.35, 0.78, 1.0)   # ice blue
	elif type == TowerDefinition.TowerType.TESLA:
		default_tint = Color(0.3, 0.7, 1.0)     # electric blue
	_normal_modulate = TowerSkins.get_color(ti, default_tint)

	# Base sprite (stationary)
	_base_sprite = Sprite2D.new()
	_base_sprite.texture = load(_BASE_PATHS[ti])
	_base_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_sprite.scale = Vector2(_BASE_SCALE[ti], _BASE_SCALE[ti])
	_base_sprite.modulate = _normal_modulate
	add_child(_base_sprite)

	# Barrel sprite (rotates to face target) — Void Stunner has no barrel
	_barrel_sprite = Sprite2D.new()
	if type != TowerDefinition.TowerType.FREEZE:
		_barrel_sprite.texture = load(_BARREL_PATHS[ti])
		_barrel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_barrel_sprite.scale = Vector2(_BARREL_SCALE[ti], _BARREL_SCALE[ti])
		_barrel_sprite.offset = Vector2(0.0, _BARREL_OFFSET_Y[ti])
		_barrel_sprite.modulate = _normal_modulate
		add_child(_barrel_sprite)

	# Transparent ColorRect (kept for layout; hover handled in _process)
	_mouse_rect = ColorRect.new()
	_mouse_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_mouse_rect.size = Vector2(48, 48)
	_mouse_rect.position = Vector2(-24, -24)
	_mouse_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mouse_rect)

	# Range ring — hover-only for all towers including Void Stunner
	_range_ring = Node2D.new()
	_range_ring.visible = false
	add_child(_range_ring)
	var ring = _RangeRing.new()
	ring.radius = range_radius
	ring.is_freeze = (type == TowerDefinition.TowerType.FREEZE)
	_range_ring.add_child(ring)

	# Ducky face overlay (only for Laser Turret with ducky skin)
	if type == TowerDefinition.TowerType.LASER and TowerSkins.named_skins.get(ti, "") == "ducky":
		var ducky = _DuckyOverlay.new()
		_base_sprite.add_child(ducky)

	# Void skin overlay — crack with split purple/black and diamond
	if TowerSkins.named_skins.get(ti, "") == "void":
		var void_ov = _VoidSkinOverlay.new()
		void_ov.sprite_scale = _BASE_SCALE[ti]
		void_ov.tower_type = type
		_base_sprite.add_child(void_ov)

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

	# Void Stunner: faster pulse frequency per upgrade level
	if tower_type == TowerDefinition.TowerType.FREEZE:
		fire_rate = 5.0 if upgrade_level == 2 else 3.0

	# Laser turret: swap sprites to reflect upgrade level
	if tower_type == TowerDefinition.TowerType.LASER:
		const _LASER_BASE_PATHS = {
			2: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/dual_laser_cannon/dual_laser_cannon_turret.png",
			3: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/heavy_laser_cannon/heavy_laser_cannon.png",
		}
		const _LASER_BARREL_PATHS = {
			2: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/dual_laser_cannon/laser_cannon_barrel.png",
			3: "res://Assets/towers/felmir_turrets/Sci-Fi Turret Pack/heavy_laser_cannon/heavy_laser_cannon_barrel.png",
		}
		# dual/heavy base sprites are 48×48 vs laser's 32×32, so scale down to 1.0
		const _LASER_BASE_SCALES  = {2: 1.0, 3: 1.0}
		const _LASER_BARREL_SCALES = {2: 0.8, 3: 1.0}
		if upgrade_level in _LASER_BASE_PATHS:
			_base_sprite.texture   = load(_LASER_BASE_PATHS[upgrade_level])
			_barrel_sprite.texture = load(_LASER_BARREL_PATHS[upgrade_level])
			_base_sprite.scale   = Vector2(_LASER_BASE_SCALES[upgrade_level],   _LASER_BASE_SCALES[upgrade_level])
			_barrel_sprite.scale = Vector2(_LASER_BARREL_SCALES[upgrade_level], _LASER_BARREL_SCALES[upgrade_level])
			_base_sprite.modulate   = _normal_modulate
			_barrel_sprite.modulate = _normal_modulate

func _process(_delta: float) -> void:
	_range_ring.visible = to_local(get_global_mouse_position()).length() <= 32.0

func apply_stun(duration: float) -> void:
	if _fire_tween:
		_fire_tween.kill()
	_stun_timer = max(_stun_timer, duration)
	var stun_col := Color(0.4, 0.4, 0.5)
	_base_sprite.modulate = stun_col
	if tower_type != TowerDefinition.TowerType.FREEZE:
		_barrel_sprite.modulate = stun_col

func update_tower(delta: float, enemies: Array) -> void:
	_enemies_ref = enemies
	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_stun_timer = 0.0
			_base_sprite.modulate = _normal_modulate
			if tower_type != TowerDefinition.TowerType.FREEZE:
				_barrel_sprite.modulate = _normal_modulate
		return

	# Void Stunner: area pulse instead of targeted projectile
	if tower_type == TowerDefinition.TowerType.FREEZE:
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown = fire_rate
			_do_freeze_pulse()
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

func _do_freeze_pulse() -> void:
	var s = TowerDefinition.stats(tower_type)
	var slow_f: float = float(s.get("slow_factor", 0.40))
	var slow_d: float = float(s.get("slow_duration", 2.0))
	for e in _enemies_ref:
		if is_instance_valid(e) and not e.is_dead:
			if position.distance_to(e.position) <= range_radius:
				e.apply_slow(slow_f, slow_d)
				# Void Rupture: bosses take 2× damage while pulsed
				if e.is_boss:
					e.apply_rupture(slow_d)
	# Spawn expanding pulse ring at tower position in parent layer
	if get_parent() != null:
		var is_void: bool = TowerSkins.named_skins.get(int(tower_type), "") == "void"
		var pulse = _FreezePulseRing.new()
		pulse.radius = range_radius
		pulse.is_void = is_void
		pulse.position = position
		get_parent().add_child(pulse)
	# Brief white flash on the tower body
	_base_sprite.modulate = Color(0.85, 0.97, 1.0)
	if _fire_tween:
		_fire_tween.kill()
	_fire_tween = create_tween()
	_fire_tween.tween_property(_base_sprite, "modulate", _normal_modulate, 0.3)
	fired.emit(tower_type)

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
	var s = TowerDefinition.stats(tower_type)
	var slow_f: float = float(s.get("slow_factor", 1.0))
	var slow_d: float = float(s.get("slow_duration", 0.0))
	var burn_dps: float = float(s.get("burn_dps", 0.0)) if upgrade_level >= 2 else 0.0
	var burn_dur: float = float(s.get("burn_duration", 0.0)) if upgrade_level >= 2 else 0.0
	var stun_dur: float = float(s.get("stun_duration", 0.0)) if upgrade_level >= 3 else 0.0
	var smite: float = float(s.get("smite_pct", 0.0)) if upgrade_level >= 2 else 0.0
	proj.setup(target, damage, projectile_speed, splash_radius, _enemies_ref, int(tower_type),
			slow_f, slow_d, burn_dps, burn_dur, stun_dur, smite)
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
	var is_freeze: bool = false

	func _draw() -> void:
		if is_freeze:
			# Dashed ice blue ring for freeze area
			draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.35, 0.78, 1.0, 0.30), 1.5)
			draw_arc(Vector2.ZERO, radius - 2.0, 0, TAU, 64, Color(0.7, 0.92, 1.0, 0.12), 1.0)
		else:
			draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1, 1, 1, 0.15), 1.0)

## Expanding pulse ring spawned at pulse time — uses tween instead of per-frame redraw
class _FreezePulseRing extends Node2D:
	var radius: float = 100.0
	var is_void: bool = false
	var _progress: float = 0.0
	const DURATION: float = 0.6

	func _ready() -> void:
		var tw = create_tween()
		tw.tween_property(self, "_progress", 1.0, DURATION)
		tw.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var alpha := (1.0 - _progress) * 0.7
		var r := radius * (0.15 + _progress * 0.85)
		var col_outer: Color
		var col_inner: Color
		if is_void:
			col_outer = Color(0.45, 0.0, 0.8, alpha)
			col_inner = Color(0.2, 0.0, 0.4, alpha * 0.5)
		else:
			col_outer = Color(0.4, 0.85, 1.0, alpha)
			col_inner = Color(0.8, 0.96, 1.0, alpha * 0.5)
		draw_arc(Vector2.ZERO, r, 0, TAU, 24, col_outer, 3.0)
		draw_arc(Vector2.ZERO, r * 0.75, 0, TAU, 16, col_inner, 1.5)

## Ducky face overlay — draws eyes and beak on top of the tower base sprite
class _DuckyOverlay extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2(-5.0, -5.0), 3.5, Color.WHITE)
		draw_circle(Vector2(-5.0, -5.0), 1.8, Color.BLACK)
		draw_circle(Vector2(5.0, -5.0), 3.5, Color.WHITE)
		draw_circle(Vector2(5.0, -5.0), 1.8, Color.BLACK)
		var beak = PackedVector2Array([
			Vector2(-4.0, 1.0),
			Vector2(4.0, 1.0),
			Vector2(0.0, 6.0),
		])
		draw_colored_polygon(beak, Color(1.0, 0.55, 0.0))


class _VoidSkinOverlay extends Node2D:
	var sprite_scale: float = 1.0
	var tower_type: TowerDefinition.TowerType = TowerDefinition.TowerType.LASER

	func _ready() -> void:
		set_process(false)

	func _draw() -> void:
		match tower_type:
			TowerDefinition.TowerType.LASER:
				_draw_circle_shape()
			TowerDefinition.TowerType.FREEZE:
				_draw_gem_shape()
			_:
				_draw_rect_shape()

	func _draw_circle_shape() -> void:
		var r := 14.0 / sprite_scale
		var segs := 24
		var left := PackedVector2Array()
		for i in range(segs / 2 + 1):
			var angle := PI / 2.0 + i * PI / float(segs / 2)
			left.append(Vector2(cos(angle) * r, sin(angle) * r))
		draw_colored_polygon(left, Color(0.55, 0.0, 0.85, 0.7))
		var right := PackedVector2Array()
		for i in range(segs / 2 + 1):
			var angle := -PI / 2.0 + i * PI / float(segs / 2)
			right.append(Vector2(cos(angle) * r, sin(angle) * r))
		draw_colored_polygon(right, Color(0.0, 0.0, 0.0, 0.7))
		_draw_crack(r)
		_draw_diamond(r * 0.45, 0.0, r * 0.3)

	func _draw_gem_shape() -> void:
		# Pixel-traced from 64x64 sprite (center 32,32)
		var left := PackedVector2Array([
			Vector2(0, -14),
			Vector2(-4, -14),
			Vector2(-8, -12),
			Vector2(-12, -10),
			Vector2(-13, -8),
			Vector2(-14, -5),
			Vector2(-15, -2),
			Vector2(-16, 1),
			Vector2(-16, 6),
			Vector2(-15, 7),
			Vector2(-14, 8),
			Vector2(-12, 10),
			Vector2(-11, 11),
			Vector2(-9, 13),
			Vector2(0, 13),
		])
		draw_colored_polygon(left, Color(0.55, 0.0, 0.85, 0.8))
		var right := PackedVector2Array([
			Vector2(0, -14),
			Vector2(4, -14),
			Vector2(8, -12),
			Vector2(12, -10),
			Vector2(12, -8),
			Vector2(13, -5),
			Vector2(14, -2),
			Vector2(15, 1),
			Vector2(15, 6),
			Vector2(14, 7),
			Vector2(13, 8),
			Vector2(11, 10),
			Vector2(10, 11),
			Vector2(8, 13),
			Vector2(0, 13),
		])
		draw_colored_polygon(right, Color(0.0, 0.0, 0.0, 0.8))
		_draw_crack(14.0)
		_draw_diamond(7.0, 0.0, 5.5)

	func _draw_rect_shape() -> void:
		var sz := 32.0 / sprite_scale
		var half := sz / 2.0
		var left_poly := PackedVector2Array([
			Vector2(-half, -half), Vector2(0, -half),
			Vector2(0, half), Vector2(-half, half),
		])
		draw_colored_polygon(left_poly, Color(0.55, 0.0, 0.85, 0.6))
		var right_poly := PackedVector2Array([
			Vector2(0, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(0, half),
		])
		draw_colored_polygon(right_poly, Color(0.0, 0.0, 0.0, 0.6))
		_draw_crack(half)
		_draw_diamond(half * 0.5, 0.0, half * 0.35)

	func _draw_crack(half: float) -> void:
		var s := sprite_scale
		var crack_pts := PackedVector2Array([
			Vector2(0, -half),
			Vector2(-2.0 / s, -half * 0.6),
			Vector2(1.5 / s, -half * 0.25),
			Vector2(-1.0 / s, half * 0.1),
			Vector2(2.0 / s, half * 0.45),
			Vector2(-1.5 / s, half * 0.7),
			Vector2(0, half),
		])
		draw_polyline(crack_pts, Color(0.7, 0.2, 1.0, 0.9), 1.5 / s, true)

	func _draw_diamond(cx: float, cy: float, d_sz: float) -> void:
		var diamond := PackedVector2Array([
			Vector2(cx, cy - d_sz),
			Vector2(cx + d_sz, cy),
			Vector2(cx, cy + d_sz),
			Vector2(cx - d_sz, cy),
		])
		draw_colored_polygon(diamond, Color(0.5, 0.0, 0.85, 0.85))
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(0.75, 0.3, 1.0), 1.0 / sprite_scale, true)
