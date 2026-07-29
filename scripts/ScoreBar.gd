class_name ScoreBar
extends Control

@export var max_score: int = 10000
@export var fill_color: Color = Color(0.5, 0.47, 0.87)
@export var stripe_color: Color = Color(0.65, 0.62, 0.95)
@export var fill_duration: float = 0.6

const IDLE_STRIPE_SPEED: float = 0.15
const ACTIVE_STRIPE_SPEED: float = 1.2

@onready var _fill: ColorRect = $Fill
@onready var _material: ShaderMaterial = ShaderMaterial.new()

var _current_score: int = 0
var _tween: Tween

func _ready() -> void:
	_material.shader = load("res://shaders/score_fill.gdshader")
	_material.set_shader_parameter("base_color", fill_color)
	_material.set_shader_parameter("stripe_color", stripe_color)
	_material.set_shader_parameter("stripe_speed", IDLE_STRIPE_SPEED)
	_fill.material = _material
	_update_fill(true)

func set_score(new_score: int) -> void:
	var gained := new_score > _current_score
	_current_score = new_score
	_update_fill(false)
	if gained:
		_pulse()

func _update_fill(instant: bool) -> void:
	var pct := clampf(float(_current_score) / max_score, 0.0, 1.0)
	var target_height := size.y * pct
	var target_y := size.y - target_height
	print_debug("target_height:", target_height, "\ntarget_y: ", target_y, "\nscore: ", _current_score)

	if _tween:
		_tween.kill()

	if instant:
		_fill.size.y = target_height
		_fill.position.y = target_y
		return

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_fill, "size:y", target_height, fill_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_fill, "position:y", target_y, fill_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Ramp shader speed up, then back down to idle once fill settles
	_tween.tween_method(_set_stripe_speed, IDLE_STRIPE_SPEED, ACTIVE_STRIPE_SPEED, 0.15)
	_tween.chain().tween_method(_set_stripe_speed, ACTIVE_STRIPE_SPEED, IDLE_STRIPE_SPEED, fill_duration)

func _set_stripe_speed(value: float) -> void:
	_material.set_shader_parameter("stripe_speed", value)

func _pulse() -> void:
	var pulse_tween := create_tween()
	_fill.modulate = Color(1.3, 1.3, 1.3)
	pulse_tween.tween_property(_fill, "modulate", Color.WHITE, 0.3)
