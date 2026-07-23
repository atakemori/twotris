extends Node

const SOUNDS := {
	"move": preload("res://audio/move.wav"),
	"right_rotate": preload("res://audio/right_rotate.wav"),
	"left_rotate": preload("res://audio/left_rotate.wav"),
	"lock": preload("res://audio/lock.wav"),
	"line_clear": preload("res://audio/line_clear.wav"),
	"game_over": preload("res://audio/game_over.wav"),
}

const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer2D] = []
var _next_index := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.panning_strength = 6.0
		add_child(player)
		_pool.append(player)

func play(sound_name: String, world_position: Vector2, volume_db: float = 0.0) -> void:
	if not SOUNDS.has(sound_name):
		push_warning("SFXPlayer: unknown sound '%s'" % sound_name)
		return

	var player := _pool[_next_index]
	_next_index = (_next_index + 1) % POOL_SIZE

	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	player.global_position = world_position + Vector2(200, 0) # adding like half a board width temp fix
	player.play()
