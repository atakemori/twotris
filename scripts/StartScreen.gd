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
@onready var saved_states: VBoxContainer = $Control/SavedStatesPanel/SavedStates
@onready var saved_states_label: Label = $Control/SavedStatesPanel/SavedStates/SavedStatesLabel
@onready var saved_state_buttons: VBoxContainer = $Control/SavedStatesPanel/SavedStates/SavedStatesScroll/SavedStateButtons
@onready var resume_button: Button = $Control/SavedStatesPanel/SavedStates/ResumeButton
@onready var open_folder_button: Button = $Control/SavedStatesPanel/SavedStates/OpenFolderButton

var _selected_state_name: String = ""

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	open_folder_button.pressed.connect(_on_open_folder_pressed)
	# Grab focus so Enter/Space also starts the game
	play_button.grab_focus()
	_refresh_saved_states()

func _on_play_pressed() -> void:
	ScreenManager.go_to("GameScreen")

func _on_resume_pressed() -> void:
	if not _selected_state_name.is_empty():
		ScreenManager.go_to("GameScreen", {"saved_state_name": _selected_state_name})

func _on_open_folder_pressed() -> void:
	var user_directory := DirAccess.open("user://")
	if user_directory:
		user_directory.make_dir_recursive("saved_games")
	OS.shell_open(ProjectSettings.globalize_path("user://saved_games"))

# Called by ScreenManager.go_to() whenever this screen becomes active.
func init(_data: Dictionary = {}) -> void:
	play_button.grab_focus()
	_refresh_saved_states()

## Builds menu buttons from the named snapshots saved by GameScreen.
## Files are sorted by their recorded creation time, newest first.
func _refresh_saved_states() -> void:
	_selected_state_name = ""
	resume_button.disabled = true
	resume_button.visible = true
	for child in saved_state_buttons.get_children():
		child.queue_free()
	var entries: Array = []
	for filename in DirAccess.get_files_at("user://saved_games"):
		if filename.get_extension().to_lower() != "json":
			continue
		var file_path := "user://saved_games".path_join(filename)
		entries.append({
			"name": filename.get_basename(),
			"modified_unix": FileAccess.get_modified_time(file_path),
		})
	print("StartScreen found ", entries.size(), " saved game(s) in ", ProjectSettings.globalize_path("user://saved_games"))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["modified_unix"]) > int(b["modified_unix"])
	)
	saved_states.visible = true
	saved_states_label.text = "Saved sessions" if not entries.is_empty() else "Saved sessions: none found"
	for entry in entries:
		var button := Button.new()
		button.text = "%s\n%s" % [entry["name"], Time.get_datetime_string_from_unix_time(int(entry["modified_unix"]))]
		button.custom_minimum_size = Vector2(0, 32)
		button.toggle_mode = true
		button.pressed.connect(_select_saved_state.bind(str(entry["name"]), button))
		saved_state_buttons.add_child(button)

## Selects a saved session without starting it; Resume performs the navigation.
func _select_saved_state(state_name: String, selected_button: Button) -> void:
	_selected_state_name = state_name
	resume_button.disabled = false
	for sibling in saved_state_buttons.get_children():
		if sibling is Button and sibling != selected_button:
			sibling.button_pressed = false
	selected_button.button_pressed = true

func _on_resume_focus() -> void:
	resume_button.grab_focus()
