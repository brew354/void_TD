## TileNode.gd — Visual tile on the grid (ColorRect-based)
class_name TileNode
extends ColorRect

const GameConfig  = preload("res://Models/GameConfig.gd")
const GridManager = preload("res://Systems/GridManager.gd")

signal tile_clicked(col, row)

var col: int = 0
var row: int = 0
var tile_state: GridManager.TileState = GridManager.TileState.EMPTY

const COLOR_EMPTY    = Color(0.04, 0.0, 0.06, 0.35)
const COLOR_PATH     = Color(0.12, 0.06, 0.18, 0.92)
const COLOR_OCCUPIED = Color(0.10, 0.30, 0.10, 0.8)
const COLOR_HOVER    = Color(0.20, 0.50, 0.80, 0.7)
const COLOR_INVALID  = Color(0.80, 0.10, 0.10, 0.7)

var _flash_timer: float = 0.0
var _flashing_invalid: bool = false
var _base_color: Color = COLOR_EMPTY
var _path_chevron: Node2D = null

func setup(c: int, r: int, state: GridManager.TileState) -> void:
	col = c
	row = r
	set_state(state)
	size = Vector2(GameConfig.TILE_SIZE - 1, GameConfig.TILE_SIZE - 1)
	position = GameConfig.GRID_ORIGIN + Vector2(c * GameConfig.TILE_SIZE, r * GameConfig.TILE_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func set_state(state: GridManager.TileState) -> void:
	tile_state = state
	match state:
		GridManager.TileState.EMPTY:
			_base_color = COLOR_EMPTY
		GridManager.TileState.PATH:
			_base_color = COLOR_PATH
		GridManager.TileState.OCCUPIED:
			_base_color = COLOR_OCCUPIED
	color = _base_color

func flash_invalid() -> void:
	_flashing_invalid = true
	_flash_timer = 0.4
	color = COLOR_INVALID

func _process(delta: float) -> void:
	if _flashing_invalid:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flashing_invalid = false
			color = _base_color

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_clicked.emit(col, row)

func set_path_direction(dir: Vector2, phase_offset: float) -> void:
	if _path_chevron != null:
		_path_chevron.queue_free()
	var chev = _PathChevron.new()
	chev.direction = dir
	chev.base_phase = phase_offset
	add_child(chev)
	_path_chevron = chev


class _PathChevron extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var base_phase: float = 0.0
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var wave := fmod(_time * 1.4 - base_phase, 1.0)
		if wave < 0.0:
			wave += 1.0
		var alpha := maxf(0.0, sin(wave * PI)) * 0.92
		if alpha < 0.04:
			return
		var center := Vector2(32.0, 32.0)
		var perp := Vector2(-direction.y, direction.x)
		var tip   := center + direction * 12.0
		var left  := center - direction * 6.0 + perp * 10.0
		var right := center - direction * 6.0 - perp * 10.0
		draw_polyline(PackedVector2Array([left, tip, right]),
			Color(0.80, 0.25, 1.0, alpha), 2.5, true)
