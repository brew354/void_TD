## GameConfig.gd — Single source of truth for layout constants
class_name GameConfig

const TILE_SIZE: float = 64.0
const GRID_COLS: int = 20
const GRID_ROWS: int = 11
# Scene size: 1334 x 750 (landscape)
const SCENE_WIDTH: float = 1334.0
const SCENE_HEIGHT: float = 750.0
const STARTING_LIVES: int = 5

# Path waypoints in scene coordinates
const PATH_WAYPOINTS: Array = [
	Vector2(32,   384),
	Vector2(256,  384),
	Vector2(256,  576),
	Vector2(640,  576),
	Vector2(640,  192),
	Vector2(1024, 192),
	Vector2(1024, 576),
	Vector2(1302, 576),
]

# Grid origin (top-left corner of tile [0,0])
const GRID_ORIGIN: Vector2 = Vector2(0.0, 750.0 - 11 * 64.0)  # y=46

static func scene_position(col: int, row: int) -> Vector2:
	return GRID_ORIGIN + Vector2(col * TILE_SIZE + TILE_SIZE * 0.5, row * TILE_SIZE + TILE_SIZE * 0.5)

static func grid_coord(pos: Vector2):
	var local = pos - GRID_ORIGIN
	var col = int(local.x / TILE_SIZE)
	var row = int(local.y / TILE_SIZE)
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return null
	return Vector2i(col, row)
