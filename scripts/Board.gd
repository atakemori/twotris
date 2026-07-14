class_name Board
extends Node2D
# ---------------------------------------------------------------------------
# Board.gd
# Attach to Board.tscn (Node2D root).
#
# Responsibilities:
#   - Owns its own RandomNumberGenerator (seeded independently)
#   - Maintains the 2D grid of locked cells
#   - Manages the active falling piece
#   - Handles gravity tick, input moves, rotation, locking, line clears
#   - Draws itself via _draw()
#
# Signals:
#   lines_cleared(count)  — emitted whenever one or more rows are cleared
#   game_over             — emitted when a new piece cannot spawn
#
# Exported vars let you tune each board in the Inspector without code changes.
# ---------------------------------------------------------------------------

signal lines_cleared(count: int)
signal game_over

# ── Layout ──────────────────────────────────────────────────────────────────
@export var cols:       int   = 10
@export var rows:       int   = 20
@export var cell_size:  int   = 28     # pixels per cell

# ── Timing ──────────────────────────────────────────────────────────────────
@export var gravity_interval: float = 0.6   # seconds between automatic drops

# ── Cosmetics ───────────────────────────────────────────────────────────────
@export var bg_color:     Color = Color(0.08, 0.08, 0.12)
@export var grid_color:   Color = Color(0.18, 0.18, 0.25)
@export var border_color: Color = Color(0.55, 0.55, 0.70)

@export var show_drop_guide: bool = true

# ── Internal state ───────────────────────────────────────────────────────────

# _grid[row][col] = Color if locked, else Color(0,0,0,0)
var _grid: Array = []

var _active_piece:    Piece      = null
var _active_pos:      Vector2i   = Vector2i.ZERO  # top-left of bounding box in grid coords
var _next_piece:      Piece      = null

var _rng:             RandomNumberGenerator = RandomNumberGenerator.new()
var _gravity_timer:   float = 0.0
var _alive:           bool  = true

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_init_grid()

func _init_grid() -> void:
	_grid = []
	for r in rows:
		var row: Array = []
		for c in cols:
			row.append(Color(0, 0, 0, 0))
		_grid.append(row)

# Call this from GameScreen after both boards are ready, passing a unique seed.
func start(seed_value: int) -> void:
	_rng.seed = seed_value
	_alive = true
	_gravity_timer = 0.0
	_init_grid()
	_next_piece = PieceSet.random(_rng)
	_spawn_next()
	queue_redraw()

# ── Update loop ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _alive:
		return

	_gravity_timer += delta
	if _gravity_timer >= gravity_interval:
		_gravity_timer = 0.0
		_gravity_step()

# Drop the active piece by one row; lock if it can't move.
func _gravity_step() -> void:
	if _active_piece == null:
		return
	if _try_move(Vector2i(0, 1)):
		queue_redraw()
	else:
		_lock_piece()

# ── Public input API (called by InputRouter) ─────────────────────────────────

func move_left() -> void:
	if not _alive: return
	if _try_move(Vector2i(-1, 0)):
		queue_redraw()

func move_right() -> void:
	if not _alive: return
	if _try_move(Vector2i(1, 0)):
		queue_redraw()

func soft_drop() -> void:
	if not _alive: return
	_gravity_timer = 0.0
	_gravity_step()

func hard_drop() -> void:
	if not _alive: return
	while _try_move(Vector2i(0, 1)):
		pass
	_lock_piece()

func rotate_cw() -> void:
	if not _alive: return
	_try_rotate(true)

func rotate_ccw() -> void:
	if not _alive: return
	_try_rotate(false)

# ── Movement helpers ─────────────────────────────────────────────────────────

# Attempts to shift _active_pos by delta. Returns true on success.
func _try_move(delta: Vector2i) -> bool:
	var new_pos := _active_pos + delta
	if _fits(_active_piece, new_pos):
		_active_pos = new_pos
		return true
	return false

# Attempts to rotate the active piece; uses simple wall-kick offsets.
func _try_rotate(clockwise: bool) -> void:
	var rotated := _active_piece.rotated_cw() if clockwise else _active_piece.rotated_ccw()

	# Wall-kick candidates: no kick, nudge left, nudge right
	var kicks := [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(-2,0), Vector2i(2,0)]
	for kick in kicks:
		if _fits(rotated, _active_pos + kick):
			_active_piece = rotated
			_active_pos   = _active_pos + kick
			queue_redraw()
			return

# Returns true if all offsets of piece at pos are within bounds and unoccupied.
func _fits(piece: Piece, pos: Vector2i) -> bool:
	for o in piece.offsets:
		var c := pos.x + o.x
		var r := pos.y + o.y
		if c < 0 or c >= cols:
			return false
		if r >= rows:
			return false
		# Allow piece to exist above the top of the grid (during spawn)
		if r < 0:
			continue
		if _grid[r][c].a > 0.0:
			return false
	return true

# ── Locking & line clears ────────────────────────────────────────────────────

func _lock_piece() -> void:
	# Write active piece into the grid
	for o in _active_piece.offsets:
		var c := _active_pos.x + o.x
		var r := _active_pos.y + o.y
		if r >= 0 and r < rows and c >= 0 and c < cols:
			_grid[r][c] = _active_piece.color

	var cleared := _check_clears()
	if cleared > 0:
		lines_cleared.emit(cleared)

	_spawn_next()

func _check_clears() -> int:
	var cleared := 0
	var r := rows - 1
	while r >= 0:
		if _row_full(r):
			_remove_row(r)
			cleared += 1
			# Don't decrement r; the row above has shifted down into this slot
		else:
			r -= 1
	return cleared

func _row_full(r: int) -> bool:
	for c in cols:
		if _grid[r][c].a == 0.0:
			return false
	return true

func _remove_row(r: int) -> void:
	_grid.remove_at(r)
	# Insert a fresh empty row at the top
	var empty_row: Array = []
	for c in cols:
		empty_row.append(Color(0, 0, 0, 0))
	_grid.insert(0, empty_row)

# ── Piece spawning ───────────────────────────────────────────────────────────

func _spawn_next() -> void:
	_active_piece = _next_piece
	_next_piece   = PieceSet.random(_rng)

	# Center horizontally, start one row above the top
	_active_pos = Vector2i((cols / 2) - 1, -1)

	if not _fits(_active_piece, _active_pos):
		_alive = false
		game_over.emit()
		queue_redraw()
		return

	queue_redraw()

# ── Preview helper ────────────────────────────────────────────────────────────

# Returns the next piece (used by GameScreen to draw a preview panel).
func get_next_piece() -> Piece:
	return _next_piece

# Returns the ghost (shadow) position for the active piece.
func _ghost_pos() -> Vector2i:
	var ghost := _active_pos
	while _fits(_active_piece, ghost + Vector2i(0, 1)):
		ghost.y += 1
	return ghost
	
# Returns the lowest grid row currently occupied by the active piece
func _piece_bottom_row() -> int:
	var lowest := -999
	for o in _active_piece.offsets:
		var r := _active_pos.y + o.y
		if r > lowest:
			lowest = r
	return lowest

# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var board_w := cols * cell_size
	var board_h := rows * cell_size

	# Background
	draw_rect(Rect2(0, 0, board_w, board_h), bg_color)

	# Grid lines
	for c in cols + 1:
		draw_line(Vector2(c * cell_size, 0), Vector2(c * cell_size, board_h), grid_color, 1.0)
	for r in rows + 1:
		draw_line(Vector2(0, r * cell_size), Vector2(board_w, r * cell_size), grid_color, 1.0)

	# Locked cells
	for r in rows:
		for c in cols:
			var cell_color: Color = _grid[r][c]
			if cell_color.a > 0.0:
				_draw_cell(c, r, cell_color)

	# Ghost piece
	if _alive and _active_piece:
		var ghost := _ghost_pos()
		for o in _active_piece.offsets:
			var gc := ghost.x + o.x
			var gr := ghost.y + o.y
			if gr >= 0:
				_draw_cell_ghost(gc, gr, _active_piece.color)
				
	# Drop guide — dotted line + distance counter
	if show_drop_guide and _alive and _active_piece:
		var ghost := _ghost_pos()
		var piece_bottom := _piece_bottom_row()
		var distance := ghost.y - _active_pos.y   # tiles until landing

		if distance > 0:
			# Find the x centre of the active piece in pixels
			var piece_center_x := 0.0
			for o in _active_piece.offsets:
				piece_center_x += (_active_pos.x + o.x) * cell_size + cell_size * 0.5
			piece_center_x /= _active_piece.offsets.size()

			# Bottom edge of the active piece in pixels
			var line_top_y := float((piece_bottom + 1) * cell_size)
			# Top edge of ghost piece in pixels
			var line_bot_y := float(ghost.y * cell_size)

			# Draw dotted line segment by segment
			var dot_len  := 4.0
			var gap_len  := 6.0
			var guide_color := Color(_active_piece.color.r,
									 _active_piece.color.g,
									 _active_piece.color.b, 0.5)
			var y := line_top_y
			while y < line_bot_y:
				var y_end :float = min(y + dot_len, line_bot_y)
				draw_line(Vector2(piece_center_x, y),
						  Vector2(piece_center_x, y_end),
						  guide_color, 1.5)
				y += dot_len + gap_len

			# Distance label just below the active piece
			var label_pos := Vector2(piece_center_x + 4.0, line_top_y + 2.0)
			draw_string(ThemeDB.fallback_font,
						label_pos,
						str(distance),
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						12,
						guide_color)

	# Active piece
	if _active_piece:
		for o in _active_piece.offsets:
			var pc := _active_pos.x + o.x
			var pr := _active_pos.y + o.y
			if pr >= 0:
				_draw_cell(pc, pr, _active_piece.color)

	# Border
	draw_rect(Rect2(0, 0, board_w, board_h), border_color, false, 2.0)

	# Game-over overlay
	if not _alive:
		draw_rect(Rect2(0, 0, board_w, board_h), Color(0, 0, 0, 0.6))

func _draw_cell(c: int, r: int, color: Color) -> void:
	var rect := Rect2(c * cell_size + 1, r * cell_size + 1, cell_size - 2, cell_size - 2)
	draw_rect(rect, color)
	# Highlight edge
	draw_rect(rect, Color(1, 1, 1, 0.18), false, 1.0)

func _draw_cell_ghost(c: int, r: int, color: Color) -> void:
	var rect := Rect2(c * cell_size + 1, r * cell_size + 1, cell_size - 2, cell_size - 2)
	var ghost_color := Color(color.r, color.g, color.b, 0.22)
	draw_rect(rect, ghost_color)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.45), false, 1.0)
