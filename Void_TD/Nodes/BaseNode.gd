## BaseNode.gd — Visual base structure at end of enemy track
class_name BaseNode
extends Node2D

var upgrade_level: int = 1
var damage_reduction: int = 0   # Lives subtracted from each hit
var total_invested: int = 0

var _visual: _BaseVisual

func setup(pos: Vector2) -> void:
	position = pos
	_visual = _BaseVisual.new()
	add_child(_visual)

func upgrade_cost(to_level: int) -> int:
	if to_level == 2: return 100
	if to_level == 3: return 200
	return 0

func upgrade() -> void:
	upgrade_level += 1
	damage_reduction = upgrade_level - 1
	total_invested += upgrade_cost(upgrade_level)
	if _visual:
		_visual.level = upgrade_level


## Procedural command-center visual — reacts to upgrade level
class _BaseVisual extends Node2D:
	var level: int = 1
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# ── Outer platform octagon ────────────────────────────────────────────
		var oct := _poly(8, 34.0, 0.0)
		draw_colored_polygon(oct, Color(0.10, 0.04, 0.18))
		var oct_c := PackedVector2Array(oct); oct_c.append(oct[0])
		draw_polyline(oct_c, Color(0.50, 0.18, 0.80, 0.9), 2.0, true)

		# Accent notches at the four cardinal vertices of the octagon
		for i in [0, 2, 4, 6]:
			var p: Vector2 = _poly_pt(8, 34.0, i, 0.0)
			var p2: Vector2 = _poly_pt(8, 40.0, i, 0.0)
			draw_line(p, p2, Color(0.75, 0.3, 1.0, 0.85), 2.0, true)

		# ── Inner hull hexagon ────────────────────────────────────────────────
		var hex := _poly(6, 20.0, PI / 6.0)
		draw_colored_polygon(hex, Color(0.06, 0.02, 0.14))
		var hex_c := PackedVector2Array(hex); hex_c.append(hex[0])
		draw_polyline(hex_c, Color(0.65, 0.25, 1.0, 0.95), 1.5, true)

		# ── Shield ring (slow pulse, always present) ──────────────────────────
		var shield_a := 0.22 + sin(_t * 1.4) * 0.08
		var shield_r := 38.0 + sin(_t * 1.4) * 1.5
		draw_arc(Vector2.ZERO, shield_r, 0.0, TAU, 64,
				Color(0.55, 0.10, 1.0, shield_a * float(level)), 2.5, true)

		# ── Orbiting energy nodes (L1: 6 nodes, 1 ring) ──────────────────────
		var ring1_speed := 0.55 + float(level - 1) * 0.25
		for i in 6:
			var angle := _t * ring1_speed + i * (TAU / 6.0)
			var p := Vector2(cos(angle), sin(angle)) * 22.0
			var glow := 0.7 + sin(_t * 3.0 + i) * 0.25
			draw_circle(p, 3.5, Color(0.70, 0.20, 1.0, glow))
			draw_circle(p, 1.8, Color(1.0, 0.85, 1.0, glow))

		# ── L2: second counter-rotating ring + brighter shield ────────────────
		if level >= 2:
			for i in 8:
				var angle := -_t * 0.9 + i * (TAU / 8.0)
				var p := Vector2(cos(angle), sin(angle)) * 29.0
				var glow := 0.65 + sin(_t * 2.5 + i * 0.8) * 0.25
				draw_circle(p, 3.0, Color(1.0, 0.50, 0.15, glow))
				draw_circle(p, 1.5, Color(1.0, 0.95, 0.7, glow))
			# Second tighter shield arc
			draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 64,
					Color(1.0, 0.45, 0.10, 0.18 + sin(_t * 1.8) * 0.06), 2.0, true)

		# ── L3: outer corona nodes + energy burst lines ───────────────────────
		if level >= 3:
			for i in 4:
				var angle := _t * 0.35 + i * (TAU / 4.0)
				var p := Vector2(cos(angle), sin(angle)) * 36.0
				draw_circle(p, 5.0, Color(0.90, 0.35, 1.0, 0.85))
				draw_circle(p, 2.5, Color(1.0, 1.0, 1.0, 0.95))
				# Spoke from hull to corona node
				var inner := Vector2(cos(angle), sin(angle)) * 20.0
				draw_line(inner, p, Color(0.75, 0.25, 1.0, 0.30), 1.2, true)

		# ── Pulsing energy core (always on top) ───────────────────────────────
		var core_pulse := sin(_t * 2.2) * 0.5 + 0.5
		var core_r := 7.0 + core_pulse * 2.5 + float(level - 1) * 1.5
		draw_circle(Vector2.ZERO, core_r, Color(0.75, 0.20, 1.0, 0.85))
		draw_circle(Vector2.ZERO, core_r * 0.55, Color(0.95, 0.75, 1.0, 0.95))
		draw_circle(Vector2.ZERO, core_r * 0.25, Color(1.0, 1.0, 1.0, 1.0))

	# Build a regular polygon as PackedVector2Array
	static func _poly(sides: int, radius: float, offset: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in sides:
			pts.append(Vector2(cos(offset + i * TAU / sides),
							   sin(offset + i * TAU / sides)) * radius)
		return pts

	static func _poly_pt(sides: int, radius: float, idx: int, offset: float) -> Vector2:
		return Vector2(cos(offset + idx * TAU / sides),
					   sin(offset + idx * TAU / sides)) * radius
