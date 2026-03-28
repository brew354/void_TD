## GridManager.gd — 2D grid state and tile placement logic
class_name GridManager

const GameConfig = preload("res://Models/GameConfig.gd")

enum TileState { EMPTY, PATH, OCCUPIED }

var grid: Array = []  # grid[row][col] -> TileState

func _init() -> void:
	# Build empty grid
	for r in range(GameConfig.GRID_ROWS):
		var row_arr = []
		for c in range(GameConfig.GRID_COLS):
			row_arr.append(TileState.EMPTY)
		grid.append(row_arr)
	_mark_path_tiles()

func _mark_path_tiles() -> void:
	var waypoints = GameConfig.PATH_WAYPOINTS
	for i in range(waypoints.size() - 1):
		var a: Vector2 = waypoints[i]
		var b: Vector2 = waypoints[i + 1]
		_mark_segment(a, b)

func _mark_segment(a: Vector2, b: Vector2) -> void:
	# Walk along segment in tile steps
	var steps = int(max(abs(b.x - a.x), abs(b.y - a.y)) / GameConfig.TILE_SIZE) + 2
	for s in range(steps + 1):
		var t = float(s) / float(steps)
		var p = a.lerp(b, t)
		var coord = GameConfig.grid_coord(p)
		if coord != null:
			grid[coord.y][coord.x] = TileState.PATH

func get_state(col: int, row: int) -> TileState:
	if col < 0 or col >= GameConfig.GRID_COLS or row < 0 or row >= GameConfig.GRID_ROWS:
		return TileState.PATH  # Treat out-of-bounds as non-placeable
	return grid[row][col]

func can_place(col: int, row: int) -> bool:
	return get_state(col, row) == TileState.EMPTY

func place(col: int, row: int) -> void:
	grid[row][col] = TileState.OCCUPIED

func remove(col: int, row: int) -> void:
	grid[row][col] = TileState.EMPTY
