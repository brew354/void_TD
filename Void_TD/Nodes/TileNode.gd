## TileNode.gd — Visual tile on the grid (ColorRect-based)
class_name TileNode
extends ColorRect

const GameConfig  = preload("res://Models/GameConfig.gd")
const GridManager = preload("res://Systems/GridManager.gd")

signal tile_clicked(col, row)

var col: int = 0
var row: int = 0
var tile_state: GridManager.TileState = GridManager.TileState.EMPTY

const COLOR_EMPTY    = Color(0.08, 0.10, 0.18, 0.6)
const COLOR_PATH     = Color(1.0, 1.0, 1.0, 0.8)
const COLOR_OCCUPIED = Color(0.10, 0.30, 0.10, 0.8)
const COLOR_HOVER    = Color(0.20, 0.50, 0.80, 0.7)
const COLOR_INVALID  = Color(0.80, 0.10, 0.10, 0.7)

var _flash_timer: float = 0.0
var _flashing_invalid: bool = false
var _base_color: Color = COLOR_EMPTY

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
