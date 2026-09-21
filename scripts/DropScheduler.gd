class_name DropScheduler
extends Node

## Emitted when a board should spawn its next piece.
signal drop_requested(board: Board)

## Emitted whenever the turn pointer switches, whether or not a drop actually fired.
## Useful for driving the visual indicator.
signal turn_changed(next_board: Board)

@export var interval_seconds: float = 4.0
@export var left_board: Board
@export var right_board: Board

@onready var _timer: Timer = Timer.new()

var _current_board: Board

func _ready() -> void:
	_timer.wait_time = interval_seconds
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_current_board = left_board

## Starts a fresh left/right rhythm for a new round. Keeping this separate
## from _ready prevents the hidden GameScreen from issuing drops before the
## boards have received their seeds.
func begin() -> void:
	_current_board = left_board
	_timer.start()
	turn_changed.emit(_current_board)

func stop() -> void:
	_timer.stop()

func _on_timer_timeout() -> void:
	if not _current_board.has_active_piece():
		drop_requested.emit(_current_board)

	_current_board = right_board if _current_board == left_board else left_board
	turn_changed.emit(_current_board)

## 0.0-1.0 progress toward the next tick. Drives the visual indicator without
## needing a separate animation loop, so it can't drift out of sync with the timer.
func get_progress() -> float:
	if _timer.wait_time <= 0.0:
		return 0.0
	return 1.0 - (_timer.time_left / _timer.wait_time)
