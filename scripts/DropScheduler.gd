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

var boards: Array[Board] = []
var _current_board_index: int = 0

func _ready() -> void:
	_timer.wait_time = interval_seconds
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	if boards.is_empty():
		set_boards([left_board, right_board])

## Starts a fresh left/right rhythm for a new round. Keeping this separate
## from _ready prevents the hidden GameScreen from issuing drops before the
## boards have received their seeds.
func begin() -> void:
	if boards.is_empty():
		return
	_current_board_index = 0
	_timer.start()
	turn_changed.emit(boards[_current_board_index])

func stop() -> void:
	_timer.stop()

func set_boards(new_boards: Array[Board]) -> void:
	boards = []
	for board in new_boards:
		if board:
			boards.append(board)
	_current_board_index = 0

func _on_timer_timeout() -> void:
	if boards.is_empty():
		return

	var current_board := boards[_current_board_index]
	if not current_board.has_active_piece():
		drop_requested.emit(current_board)

	_current_board_index = (_current_board_index + 1) % boards.size()
	turn_changed.emit(boards[_current_board_index])

## 0.0-1.0 progress toward the next tick. Drives the visual indicator without
## needing a separate animation loop, so it can't drift out of sync with the timer.
func get_progress() -> float:
	if _timer.wait_time <= 0.0:
		return 0.0
	return 1.0 - (_timer.time_left / _timer.wait_time)
