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
signal hard_drop_completed(board: Board)

# ── Layout ──────────────────────────────────────────────────────────────────
@export var cols:       int   = 10
@export var rows:       int   = 20
@export var cell_size:  int   = 28     # pixels per cell
@export var board_index: int = 0
@export var is_left_board: bool = true
@export var start_with_offset: bool = false
const LEFT_BOARD_START_OFFSET: int = 9

# ── Timing ──────────────────────────────────────────────────────────────────
@export var gravity_interval: float = 0.8   # seconds between automatic drops
@export var listen_for_drop: bool = false

# ── Cosmetics ───────────────────────────────────────────────────────────────
@export var bg_color:     Color = Color(0.08, 0.08, 0.12)
@export var grid_color:   Color = Color(0.18, 0.18, 0.25)
@export var border_color: Color = Color(0.55, 0.55, 0.70)

@export var show_drop_guide: bool = true
@export var piece_set: PieceSet.Set = PieceSet.Set.TETROMINO

@onready var _locking_particles: GPUParticles2D = $LockingParticles

# ── Internal state ───────────────────────────────────────────────────────────

# _grid[row][col] = Color if locked, else Color(0,0,0,0)
var _grid: Array = []

var _active_piece:    Piece      = null
var _active_pos:      Vector2i   = Vector2i.ZERO  # rotation pivot (offset 0,0) in grid coords
var _next_piece:      Piece      = null
var _piece_bag:       Array[Piece.Type] = []

var _rng:             RandomNumberGenerator = RandomNumberGenerator.new()
var _gravity_timer:   float = 0.0
var _alive:           bool  = true
var _hard_drop_target: bool = false

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_init_grid()
	print("LockingParticles found: ", _locking_particles)
	print("Board Left children: ", get_children())

func _init_grid() -> void:
	_grid = []
	for r in rows:
		var row: Array = []
		for c in cols:
			row.append(Color(0, 0, 0, 0))
		_grid.append(row)

# Call this from GameScreen after both boards are ready, passing a unique seed.
func start(seed_value: int, starting_grid: Array = []) -> void:
	_rng.seed = seed_value
	_alive = true
	_gravity_timer = 0.0
	_init_grid()
	if not starting_grid.is_empty():
		set_grid_state(starting_grid)
	# A reused board must not retain the last round's falling piece while it
	# waits for the scheduler.
	_active_piece = null
	_piece_bag.clear()
	_next_piece = _draw_piece_from_bag()
	if !listen_for_drop:
		spawn_next(LEFT_BOARD_START_OFFSET if is_left_board else 0)
	queue_redraw()

## Replaces the locked-cell grid with a validated saved or generated state.
## Rows and columns outside this board's dimensions are ignored.
func set_grid_state(state: Array) -> void:
	_init_grid()
	for r in range(mini(state.size(), rows)):
		var saved_row = state[r]
		if not saved_row is Array:
			continue
		for c in range(mini(saved_row.size(), cols)):
			var value = saved_row[c]
			if value is Color:
				_grid[r][c] = value
			elif value is String and not value.is_empty():
				_grid[r][c] = Color(value)
	queue_redraw()

## Returns the locked grid as JSON-friendly color strings for playtest saves.
func get_grid_state() -> Array:
	var state: Array = []
	for r in rows:
		var saved_row: Array = []
		for c in cols:
			saved_row.append(_grid[r][c].to_html(true) if _grid[r][c].a > 0.0 else "")
		state.append(saved_row)
	return state

## Returns the number of occupied rows measured upward from the bottom.
func get_stack_height() -> int:
	for r in rows:
		for c in cols:
			if _grid[r][c].a > 0.0:
				return rows - r
	return 0

## Builds a simple randomized garbage state for a newly created board.
## The bottom target_height rows are filled with colored blocks and holes.
func make_random_junk_state(target_height: int, rng: RandomNumberGenerator) -> Array:
	var state: Array = []
	var colors: Array = PieceSet.COLORS.values()
	var clamped_height := clampi(target_height, 0, maxi(rows - 1, 0))
	for r in rows:
		var saved_row: Array = []
		for c in cols:
			if r < rows - clamped_height and r >= 0:
				saved_row.append("")
			elif rng.randf() < 0.18:
				saved_row.append("")
			else:
				var color: Color = colors[rng.randi_range(0, colors.size() - 1)]
				saved_row.append(color.to_html(true))
		state.append(saved_row)
	return state

## Captures this board without including any game-wide score or scheduler data.
## The returned dictionary can be stored as one element of a larger snapshot.
func capture_state() -> Dictionary:
	var bag_types: Array = []
	for piece_type in _piece_bag:
		bag_types.append(int(piece_type))
	return {
		"grid": get_grid_state(),
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"piece_set": int(piece_set),
		"piece_bag": bag_types,
		"active_piece": _serialize_piece(_active_piece),
		"active_position": [_active_pos.x, _active_pos.y],
		"next_piece": _serialize_piece(_next_piece),
		"gravity_timer": _gravity_timer,
		"alive": _alive,
	}

## Restores only this board's state, allowing callers to compose snapshots from
## independently saved board records without knowing the board internals.
func restore_state(state: Dictionary) -> void:
	set_grid_state(state.get("grid", []))
	piece_set = PieceSet.Set.TRIOMINO if int(state.get("piece_set", int(piece_set))) == int(PieceSet.Set.TRIOMINO) else PieceSet.Set.TETROMINO
	_rng.seed = int(state.get("rng_seed", _rng.seed))
	_rng.state = int(state.get("rng_state", _rng.state))
	_piece_bag.clear()
	for piece_type in state.get("piece_bag", []):
		_piece_bag.append(int(piece_type))
	_active_piece = _deserialize_piece(state.get("active_piece", {}))
	_next_piece = _deserialize_piece(state.get("next_piece", {}))
	if _next_piece == null:
		_next_piece = _draw_piece_from_bag()
	var saved_position = state.get("active_position", [0, 0])
	if saved_position is Array and saved_position.size() >= 2:
		_active_pos = Vector2i(int(saved_position[0]), int(saved_position[1]))
	if _active_piece != null and not _fits(_active_piece, _active_pos):
		# A snapshot from an older format or a manually edited file should not
		# turn into an immediate top-out when it is loaded.
		_active_piece = null
	_gravity_timer = float(state.get("gravity_timer", 0.0))
	_alive = bool(state.get("alive", true))
	queue_redraw()

func _serialize_piece(piece: Piece) -> Dictionary:
	if piece == null:
		return {}
	var saved_offsets: Array = []
	for offset in piece.offsets:
		saved_offsets.append([offset.x, offset.y])
	return {
		"type": int(piece.type),
		"color": piece.color.to_html(true),
		"offsets": saved_offsets,
		"can_rotate": piece.can_rotate,
	}

func _deserialize_piece(data: Dictionary) -> Piece:
	if data.is_empty():
		return null
	var piece_type: Piece.Type = int(data.get("type", int(Piece.Type.I)))
	var offsets: Array[Vector2i] = []
	for offset in data.get("offsets", []):
		if offset is Array and offset.size() >= 2:
			offsets.append(Vector2i(int(offset[0]), int(offset[1])))
	return Piece.new(
		piece_type,
		Color(str(data.get("color", "ffffff"))),
		offsets,
		bool(data.get("can_rotate", true))
	)

# ── Update loop ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _alive:
		return

	if _hard_drop_target:
		queue_redraw()

	_gravity_timer += delta
	if _gravity_timer >= gravity_interval:
		_gravity_timer = 0.0
		_gravity_step()

# Drop the active piece by one row; lock if it can't move.
func _gravity_step() -> void:
	if _active_piece == null:
		return
	if _try_move(Vector2i(0, 1), true):
		queue_redraw()
	else:
		_lock_piece()

# ── Public input API (called by InputRouter) ─────────────────────────────────

func move_left() -> void:
	if not _can_control_active_piece(): return
	if _try_move(Vector2i(-1, 0)):
		queue_redraw()

func move_right() -> void:
	if not _can_control_active_piece(): return
	if _try_move(Vector2i(1, 0)):
		queue_redraw()

func soft_drop() -> void:
	if not _can_control_active_piece(): return
	_gravity_timer = 0.0
	_gravity_step()

func hard_drop() -> void:
	if not _can_control_active_piece(): return
	while _try_move(Vector2i(0, 1)):
		pass
	_lock_piece()
	hard_drop_completed.emit(self)

func rotate_cw() -> void:
	if not _can_control_active_piece(): return
	_try_rotate(true)

func rotate_ccw() -> void:
	if not _can_control_active_piece(): return
	_try_rotate(false)

# ── Movement helpers ─────────────────────────────────────────────────────────

# Attempts to shift _active_pos by delta. Returns true on success.
func _try_move(delta: Vector2i, gravity_step: bool = false) -> bool:
	if _active_piece == null:
		return false
	var new_pos := _active_pos + delta
	if _fits(_active_piece, new_pos):
		_active_pos = new_pos
		if not gravity_step:
			SFXPlayer.play("move", global_position)
		return true
	return false

# Attempts to rotate the active piece; uses simple wall-kick offsets.
func _try_rotate(clockwise: bool) -> void:
	if _active_piece == null:
		return
	var rotated := _active_piece.rotated_cw() if clockwise else _active_piece.rotated_ccw()

	# Wall-kick candidates: no kick, nudge left, nudge right
	var kicks := [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(-2,0), Vector2i(2,0)]
	for kick in kicks:
		if _fits(rotated, _active_pos + kick):
			_active_piece = rotated
			_active_pos   = _active_pos + kick
			if clockwise:
				SFXPlayer.play("left_rotate", global_position)
			else:
				SFXPlayer.play("right_rotate", global_position)
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
	# Input is broadcast to both boards, including one waiting for its next
	# scheduled piece. Empty boards must never be locked.
	if _active_piece == null:
		return
	# A piece that can no longer descend while any of its cells are still above
	# the visible grid has topped out. Previously those cells were skipped below,
	# allowing play to continue after the stack reached the ceiling.
	for o in _active_piece.offsets:
		if _active_pos.y + o.y < 0:
			_active_piece = null
			_alive = false
			game_over.emit()
			SFXPlayer.play("game_over", global_position)
			queue_redraw()
			return
	# Write active piece into the grid
	for o in _active_piece.offsets:
		var c := _active_pos.x + o.x
		var r := _active_pos.y + o.y
		if r >= 0 and r < rows and c >= 0 and c < cols:
			_grid[r][c] = _active_piece.color

	SFXPlayer.play("lock", global_position)

	var lock_location := _lowest_locking_position()

	#Change the shape of the particle emitter.
	var mat: ParticleProcessMaterial = _locking_particles.process_material
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(lock_location["width"] / 2.0, 2.0, 0.0)
	
	_locking_particles.global_position = lock_location["position"]  # see note below
	_locking_particles.modulate = _active_piece.color.lerp(Color(.5, .5, .5), .25) # slightly muted version of piece color
	_locking_particles.restart()  # resets and re-emits from the start
	_locking_particles.emitting = true

	var cleared := _check_clears()
	if cleared > 0:
		lines_cleared.emit(cleared)
		SFXPlayer.play("line_clear", global_position)

	_active_piece = null
	# This board is custom-drawn. Locking changes both the grid and active-piece
	# state, so redraw now even when the scheduler will not spawn another piece yet.
	queue_redraw()

	if !listen_for_drop:
		spawn_next()

## Computes the world-space position and pixel width of the locked piece's
## bottom edge, for positioning/sizing the lock particle burst.
## Returns a Dictionary with:
##   "position": Vector2 — world position of the bottom-edge midpoint
##   "width": float — pixel width spanning the piece's bottom-row cells
func _lowest_locking_position() -> Dictionary:
	var max_row: int = _active_piece.offsets[0].y
	for o in _active_piece.offsets:
		max_row = max(max_row, o.y)

	var bottom_offsets: Array[Vector2i] = []
	for o in _active_piece.offsets:
		if o.y == max_row:
			bottom_offsets.append(o)

	var min_x := bottom_offsets[0].x
	var max_x := bottom_offsets[0].x
	for o in bottom_offsets:
		min_x = min(min_x, o.x)
		max_x = max(max_x, o.x)

	var avg_x := float(min_x + max_x) / 2.0
	var grid_pos := Vector2(_active_pos.x + avg_x, _active_pos.y + max_row)
	var pixel_pos := global_position + grid_pos * cell_size
	pixel_pos.y += cell_size

	# Width spans from min_x to max_x (inclusive), so add 1 cell for the span itself
	var width_in_cells := (max_x - min_x) + 1
	var pixel_width := width_in_cells * cell_size

	return {"position": pixel_pos, "width": pixel_width}


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

func spawn_next(row_offset: int = 0) -> void:
	_active_piece = _next_piece
	_next_piece   = _draw_piece_from_bag()

	# Center horizontally, start one row above the top
	_active_pos = Vector2i((cols / 2) - 1, -1 + row_offset)

	if not _fits(_active_piece, _active_pos):
		_alive = false
		game_over.emit()
		SFXPlayer.play("game_over", global_position)
		queue_redraw()
		return

	queue_redraw()

func has_active_piece() -> bool:
	return _active_piece != null

## Changes the pool used for the next piece onward; the falling piece is kept.
func set_piece_set(new_piece_set: PieceSet.Set) -> void:
	if piece_set == new_piece_set:
		return
	piece_set = new_piece_set
	_piece_bag.clear()
	_next_piece = _draw_piece_from_bag()

## Draws one piece from a shuffled-without-replacement bag, refilling it only
## after every type in the active piece set has been used once.
func _draw_piece_from_bag() -> Piece:
	if _piece_bag.is_empty():
		_piece_bag = PieceSet.types_for_set(piece_set)
	var bag_index := _rng.randi_range(0, _piece_bag.size() - 1)
	var piece_type: Piece.Type = _piece_bag.pop_at(bag_index)
	return PieceSet.make_for_set(piece_type, piece_set)

func set_hard_drop_target(is_target: bool) -> void:
	if _hard_drop_target == is_target:
		return
	_hard_drop_target = is_target
	queue_redraw()

func _can_control_active_piece() -> bool:
	return _alive and _active_piece != null

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
	
# Returns the lowest grid row currently occupied by the active piece.
# Rows increase downward, so a higher return value means a lower visual position.
func get_active_piece_bottom_row() -> int:
	if _active_piece == null:
		return -1
	var lowest := -999
	for o in _active_piece.offsets:
		var r := _active_pos.y + o.y
		if r > lowest:
			lowest = r
	return lowest

## The position of offset (0, 0), which is the piece's rotation pivot.
## Unlike its bottom edge, this is unchanged by rotation.
func get_active_piece_pivot_row() -> int:
	if _active_piece == null:
		return -1
	return _active_pos.y
	


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
		var piece_bottom := get_active_piece_bottom_row()
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
				
			var font_size : int = max(28, 52 - distance * 6)
				
			# Draw label of countdown until bottom
			var label_on_left := board_index == 0
			var label_x := -40.0 if label_on_left else board_w + 10.0
			var label_align := HORIZONTAL_ALIGNMENT_LEFT if label_on_left else HORIZONTAL_ALIGNMENT_RIGHT
			var label_pos := Vector2(label_x, font_size + 10)
			draw_string_outline(ThemeDB.fallback_font,
						label_pos,
						str(distance),
						label_align,
						-1,
						font_size)

	# Active piece
	if _active_piece:
		for o in _active_piece.offsets:
			var pc := _active_pos.x + o.x
			var pr := _active_pos.y + o.y
			if pr >= 0:
				_draw_cell(pc, pr, _active_piece.color)

	# Border
	draw_rect(Rect2(0, 0, board_w, board_h), border_color, false, 2.0)
	if _hard_drop_target and _active_piece:
		_draw_border_glow(board_w, board_h, 9.0)

	# Game-over overlay
	if not _alive:
		draw_rect(Rect2(0, 0, board_w, board_h), Color(0, 0, 0, 0.6))
		
func _draw_border_glow(board_w: int, board_h: int, thickness: float) -> void:
	#var pulse := (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
	var pulse := (sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.2) + 1.0) * 0.5
	var glow_color := _active_piece.color
	#var glow_color := Color.WHITE
	glow_color.a = 0.45 + pulse * 0.45
	# glows inward
	#draw_rect(Rect2(thickness, thickness, board_w - 2*thickness, board_h - 2*thickness), glow_color, false, thickness + pulse * 2.0)
	# glows outwards
	var thi := thickness / 3.0
	draw_rect(Rect2(-thi, -thi, board_w + 2*thi, board_h + 2*thi), glow_color, false, thickness)
	# redraw border in white for emphasis
	draw_rect(Rect2(0, 0, board_w, board_h), Color.WHITE, false, 2.0)

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
