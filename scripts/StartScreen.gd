extends CanvasLayer
# ---------------------------------------------------------------------------
# StartScreen.gd
# Attach to the root CanvasLayer of StartScreen.tscn.
#
# Minimal scene tree for StartScreen.tscn:
#   StartScreen  (CanvasLayer)       ← this script
#   └── Control  (Control, anchors full-rect)
#       ├── VBoxContainer
#       │   ├── TitleLabel   (Label)   — "DUAL TRIS"
#       │   ├── SubLabel     (Label)   — "One input. Two boards. No mercy."
#       │   ├── Spacer       (Control, min size 40px)
#       │   └── PlayButton   (Button)  — "PLAY"
#       └── ControlsLabel    (Label)   — shows key bindings
# ---------------------------------------------------------------------------

@onready var play_button: Button = $Control/VBoxContainer/PlayButton
@onready var saved_states: VBoxContainer = $Control/VBoxContainer/SavedStates
@onready var resume_button: Button = $Control/VBoxContainer/ResumeButton

var _selected_state_name: String = ""

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	# Grab focus so Enter/Space also starts the game
	play_button.grab_focus()
	_refresh_saved_states()

func _on_play_pressed() -> void:
	ScreenManager.go_to("GameScreen")

func _on_resume_pressed() -> void:
	if not _selected_state_name.is_empty():
		ScreenManager.go_to("GameScreen", {"saved_state_name": _selected_state_name})

# Called by ScreenManager.go_to() whenever this screen becomes active.
func init(_data: Dictionary = {}) -> void:
	play_button.grab_focus()
	_refresh_saved_states()

## Builds menu buttons from the named snapshots saved by GameScreen.
## Files are sorted by their recorded creation time, newest first.
func _refresh_saved_states() -> void:
	_selected_state_name = ""
	resume_button.disabled = true
	resume_button.visible = false
	for child in saved_states.get_children():
		child.queue_free()
	var entries: Array = []
	var directory := DirAccess.open("user://saved_games")
	if directory:
		var filename := directory.get_next()
		while not filename.is_empty():
			if not directory.current_is_dir() and filename.get_extension() == "json":
				var file := FileAccess.open("user://saved_games/" + filename, FileAccess.READ)
				if file:
					var parsed = JSON.parse_string(file.get_as_text())
					if parsed is Dictionary:
						entries.append({
							"name": str(parsed.get("name", filename.get_basename())),
							"created_unix": int(parsed.get("created_unix", 0)),
						})
				filename = directory.get_next()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["created_unix"]) > int(b["created_unix"])
	)
	saved_states.visible = not entries.is_empty()
	for entry in entries:
		var button := Button.new()
		button.text = str(entry["name"])
		button.toggle_mode = true
		button.pressed.connect(_select_saved_state.bind(str(entry["name"]), button))
		saved_states.add_child(button)
	if not entries.is_empty():
		resume_button.visible = true

## Selects a saved session without starting it; Resume performs the navigation.
func _select_saved_state(state_name: String, selected_button: Button) -> void:
	_selected_state_name = state_name
	resume_button.disabled = false
	for sibling in saved_states.get_children():
		if sibling is Button and sibling != selected_button:
			sibling.button_pressed = false
	selected_button.button_pressed = true

func _on_resume_focus() -> void:
	resume_button.grab_focus()
