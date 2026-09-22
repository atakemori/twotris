class_name InputRouter
extends Node
# ---------------------------------------------------------------------------
# InputRouter.gd
# Attach to a Node inside GameScreen.tscn.
#
# Listens for all game input actions and forwards each to BOTH boards.
# Because Board.gd ignores input when not alive, no extra guards are needed.
#
# Also handles DAS (Delayed Auto-Shift) for left/right — the standard
# Tetris feel where holding a direction has a short delay then repeats fast.
#
# Input Actions to define in Project > Input Map:
#   move_left     — A / Left Arrow
#   move_right    — D / Right Arrow
#   soft_drop     — S / Down Arrow
#   hard_drop     — W / Up Arrow  (or Space)
#   rotate_cw     — Up Arrow / X
#   rotate_ccw    — Z
#   pause         — Escape / P
# ---------------------------------------------------------------------------

signal pause_requested
signal piece_set_toggle_requested

@export var das_delay:  float = 0.17   # seconds before auto-repeat kicks in
@export var das_repeat: float = 0.05   # seconds between repeats once DAS is active

var boards: Array[Board] = []

var _das_direction: int   = 0     # -1 left, 0 none, 1 right
var _das_timer:     float = 0.0
var _das_active:    bool  = false

func _process(delta: float) -> void:
	_update_hard_drop_target()

	if _das_direction == 0:
		return

	_das_timer += delta

	if not _das_active:
		if _das_timer >= das_delay:
			_das_active = true
			_das_timer  = 0.0
			_shift(_das_direction)
	else:
		if _das_timer >= das_repeat:
			_das_timer = 0.0
			_shift(_das_direction)

func _unhandled_input(event: InputEvent) -> void:
	# ── Horizontal movement (with DAS) ──────────────────────────────────────
	if event.is_action_pressed("move_left"):
		_das_direction = -1
		_das_timer     = 0.0
		_das_active    = false
		_shift(-1)

	elif event.is_action_released("move_left") and _das_direction == -1:
		_das_direction = 0

	if event.is_action_pressed("move_right"):
		_das_direction = 1
		_das_timer     = 0.0
		_das_active    = false
		_shift(1)

	elif event.is_action_released("move_right") and _das_direction == 1:
		_das_direction = 0

	# ── Vertical ─────────────────────────────────────────────────────────────
	if event.is_action_pressed("soft_drop", true):   # allow echo
		_all_boards("soft_drop")

	if event.is_action_pressed("hard_drop"):
		_hard_drop_lowest_piece()

	# ── Rotation ─────────────────────────────────────────────────────────────
	if event.is_action_pressed("rotate_cw"):
		_all_boards("rotate_cw")

	if event.is_action_pressed("rotate_ccw"):
		_all_boards("rotate_ccw")

	# ── Meta ──────────────────────────────────────────────────────────────────
	if event.is_action_pressed("pause"):
		pause_requested.emit()

	if event.is_action_pressed("toggle_piece_set"):
		piece_set_toggle_requested.emit()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _shift(direction: int) -> void:
	if direction < 0:
		_all_boards("move_left")
	else:
		_all_boards("move_right")

## Grid rows increase downward, so the piece with the larger pivot-row value
## has fallen farther. The pivot does not move when the piece rotates.
## If pieces share a row, the lowest board index wins the tie.
func _hard_drop_lowest_piece() -> void:
	_update_hard_drop_target()
	var target := _hard_drop_target_board()
	if target:
		target.hard_drop()

	_update_hard_drop_target()

func _update_hard_drop_target() -> void:
	var target := _hard_drop_target_board()
	for board in boards:
		if board:
			board.set_hard_drop_target(board == target)

func _hard_drop_target_board() -> Board:
	var target: Board = null
	var target_row := -999999

	for board in boards:
		if not board or not board.has_active_piece():
			continue
		var row := board.get_active_piece_pivot_row()
		if target == null or row > target_row:
			target = board
			target_row = row

	return target

# Calls the named method on every assigned board.
func _all_boards(method: StringName) -> void:
	for board in boards:
		if board and board.has_method(method):
			board.call(method)
