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

@export var das_delay:  float = 0.17   # seconds before auto-repeat kicks in
@export var das_repeat: float = 0.05   # seconds between repeats once DAS is active

var board_left:  Board = null
var board_right: Board = null

var _das_direction: int   = 0     # -1 left, 0 none, 1 right
var _das_timer:     float = 0.0
var _das_active:    bool  = false

func _process(delta: float) -> void:
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
		_both("soft_drop")

	if event.is_action_pressed("hard_drop"):
		_both("hard_drop")

	# ── Rotation ─────────────────────────────────────────────────────────────
	if event.is_action_pressed("rotate_cw"):
		_both("rotate_cw")

	if event.is_action_pressed("rotate_ccw"):
		_both("rotate_ccw")

	# ── Meta ──────────────────────────────────────────────────────────────────
	if event.is_action_pressed("pause"):
		pause_requested.emit()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _shift(direction: int) -> void:
	if direction < 0:
		_both("move_left")
	else:
		_both("move_right")

# Calls the named method on both boards if they are assigned.
func _both(method: StringName) -> void:
	if board_left  and board_left.has_method(method):
		board_left.call(method)
	if board_right and board_right.has_method(method):
		board_right.call(method)
