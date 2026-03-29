## GameConfig.gd — Single source of truth for layout constants
class_name GameConfig

const TILE_SIZE: float = 64.0
const GRID_COLS: int = 20
const GRID_ROWS: int = 11
# Scene size: 1334 x 750 (landscape)
const SCENE_WIDTH: float = 1334.0
const SCENE_HEIGHT: float = 750.0
const STARTING_LIVES: int = 5
const STARTING_CREDITS: int = 300
const TOWER_MAX_TOTAL: int = 30

## Wave-clear bonus scales with wave number so late-game survival is rewarded.
static func wave_bonus(wave_number: int) -> int:
	return wave_number * 8

# Path waypoints in scene coordinates — centered on path tiles
# Tile center formula: (col*64+32, GRID_ORIGIN.y + row*64+32) = (col*64+32, row*64+78)
# Horizontal segments use row center y; vertical segments use col center x
const PATH_WAYPOINTS: Array = [
	Vector2(32,   398),   # col 0,  row 5
	Vector2(288,  398),   # col 4,  row 5
	Vector2(288,  590),   # col 4,  row 8
	Vector2(672,  590),   # col 10, row 8
	Vector2(672,  206),   # col 10, row 2
	Vector2(1056, 206),   # col 16, row 2
	Vector2(1056, 590),   # col 16, row 8
	Vector2(1302, 590),   # exit,   row 8
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
