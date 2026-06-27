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

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	# Grab focus so Enter/Space also starts the game
	play_button.grab_focus()

func _on_play_pressed() -> void:
	ScreenManager.go_to("GameScreen")

# Called by ScreenManager.go_to() whenever this screen becomes active.
func init(_data: Dictionary = {}) -> void:
	play_button.grab_focus()
