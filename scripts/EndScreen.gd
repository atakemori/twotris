extends CanvasLayer
# ---------------------------------------------------------------------------
# EndScreen.gd
# Attach to the root CanvasLayer of EndScreen.tscn.
#
# Scene tree for EndScreen.tscn:
#   EndScreen  (CanvasLayer)              ← this script
#   └── Control  (Control, anchors full-rect)
#       └── VBoxContainer  (centered)
#           ├── GameOverLabel    (Label)  — "GAME OVER"
#           ├── LeftScoreLabel   (Label)  — "Left board:  420"
#           ├── RightScoreLabel  (Label)  — "Right board: 300"
#           ├── TotalLabel       (Label)  — "Total: 720"
#           ├── WinnerLabel      (Label)  — "Left board wins!" / "It's a tie!"
#           ├── Spacer           (Control, min size 32px)
#           ├── PlayAgainButton  (Button) — "PLAY AGAIN"
#           └── MenuButton       (Button) — "MAIN MENU"
# ---------------------------------------------------------------------------

@onready var left_score_label:  Label  = $Control/VBoxContainer/LeftScoreLabel
@onready var right_score_label: Label  = $Control/VBoxContainer/RightScoreLabel
@onready var total_label:       Label  = $Control/VBoxContainer/TotalLabel
@onready var winner_label:      Label  = $Control/VBoxContainer/WinnerLabel
@onready var play_again_button: Button = $Control/VBoxContainer/PlayAgainButton
@onready var menu_button:       Button = $Control/VBoxContainer/MenuButton

func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_menu)

# Called by ScreenManager.go_to("EndScreen", data) with score data.
func init(data: Dictionary = {}) -> void:
	var sl: int = data.get("score_left",  0)
	var sr: int = data.get("score_right", 0)

	left_score_label.text  = "Left board:   %d" % sl
	right_score_label.text = "Right board:  %d" % sr
	total_label.text       = "Total:        %d" % (sl + sr)

	if sl > sr:
		winner_label.text = "Left board wins!"
	elif sr > sl:
		winner_label.text = "Right board wins!"
	else:
		winner_label.text = "It's a tie!"

	play_again_button.grab_focus()

func _on_play_again() -> void:
	ScreenManager.go_to("GameScreen")

func _on_menu() -> void:
	ScreenManager.go_to("StartScreen")
