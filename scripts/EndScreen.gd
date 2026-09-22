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
	var scores: Array = data.get("scores", [])
	if scores.is_empty():
		scores = [data.get("score_left", 0), data.get("score_right", 0)]

	var total := 0
	var high_score := -1
	var winner_index := -1
	var tied := false
	for i in scores.size():
		var score: int = scores[i]
		total += score
		if score > high_score:
			high_score = score
			winner_index = i
			tied = false
		elif score == high_score:
			tied = true

	left_score_label.text = "Board 1:      %d" % int(scores[0] if scores.size() > 0 else 0)
	right_score_label.text = "Board 2:      %d" % int(scores[1] if scores.size() > 1 else 0)
	if scores.size() > 2:
		right_score_label.text += "\nBoard 3:      %d" % int(scores[2])
	total_label.text = "Total:        %d" % total

	if tied:
		winner_label.text = "It's a tie!"
	else:
		winner_label.text = "Board %d wins!" % (winner_index + 1)

	play_again_button.grab_focus()

func _on_play_again() -> void:
	ScreenManager.go_to("GameScreen")

func _on_menu() -> void:
	ScreenManager.go_to("StartScreen")
