class_name DropRhythmIndicator
extends Control

## A small metronome between the boards. Its fill and pulse come directly from
## DropScheduler's timer, so the visual cannot drift out of rhythm with drops.

@export var scheduler: DropScheduler
@export var accent_color := Color(0.95, 0.82, 0.28)

var _next_is_left := true

func _ready() -> void:
	if scheduler:
		scheduler.turn_changed.connect(_on_turn_changed)
		_on_turn_changed(scheduler.left_board)

func _process(_delta: float) -> void:
	queue_redraw()

func _on_turn_changed(next_board: Board) -> void:
	_next_is_left = next_board == scheduler.left_board

func _draw() -> void:
	var center := size * 0.5
	var progress := scheduler.get_progress() if scheduler else 0.0
	var pulse := sin(progress * PI) * 5.0
	var direction := -1.0 if _next_is_left else 1.0
	var arrow_center := center + Vector2(direction * pulse, 0.0)

	# Rail fills toward the next beat; the arrow says which board is up.
	draw_line(Vector2(5, size.y - 9), Vector2(size.x - 5, size.y - 9), Color(1, 1, 1, 0.18), 2.0)
	draw_line(Vector2(5, size.y - 9), Vector2(5 + (size.x - 10) * progress, size.y - 9), accent_color, 3.0)

	var tip := arrow_center + Vector2(direction * 12, 0)
	var tail_top := arrow_center + Vector2(-direction * 8, -9)
	var tail_bottom := arrow_center + Vector2(-direction * 8, 9)
	draw_colored_polygon(PackedVector2Array([tip, tail_top, tail_bottom]), accent_color)
	draw_circle(arrow_center, 4.0 + pulse * 0.18, Color(accent_color, 0.55))
