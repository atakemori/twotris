extends CanvasLayer
# ---------------------------------------------------------------------------
# GameScreen.gd
# Attach to the root CanvasLayer of GameScreen.tscn.
#
# Scene tree for GameScreen.tscn:
#   GameScreen  (CanvasLayer)              ← this script
#   └── Control  (Control, anchors full-rect)
#       ├── HBoxContainer  (centered)
#       │   ├── LeftPanel   (VBoxContainer)
#       │   │   ├── LeftScoreLabel  (Label)
#       │   │   ├── LeftNextLabel   (Label) "NEXT"
#       │   │   └── LeftNextDisplay (Control, custom draw for preview)
#       │   ├── BoardLeft   (Node2D)  ← Board.tscn instanced, Board.gd attached
#       │   ├── Divider     (VSeparator or ColorRect)
#       │   ├── BoardRight  (Node2D)  ← Board.tscn instanced, Board.gd attached
#       │   └── RightPanel  (VBoxContainer)
#       │       ├── RightScoreLabel (Label)
#       │       ├── RightNextLabel  (Label) "NEXT"
#       │       └── RightNextDisplay (Control)
#       └── PauseOverlay    (ColorRect, full-rect, hidden by default)
#           └── PauseLabel  (Label) "PAUSED — press P to resume"
#
# InputRouter is a child Node of GameScreen (not in the visual tree).
# ---------------------------------------------------------------------------

@onready var board_left:   Board  = $Control/BoardL
@onready var board_right:  Board  = $Control/BoardR
@onready var input_router: InputRouter = $InputRouter

@onready var left_score_label:  Label   = $Control/LeftPanel/LeftScoreLabel
@onready var right_score_label: Label   = $Control/RightPanel/RightScoreLabel

@onready var pause_overlay: ColorRect = $Control/PauseOverlay

@onready var _audio_listener: AudioListener2D = $Control/AudioListener2D

var _score_left:  int = 0
var _score_right: int = 0
var _paused:      bool = false
var _game_active: bool = false

# Points awarded per number of lines cleared in a single drop
const LINE_POINTS := [0, 100, 300, 700, 1500]

func _ready() -> void:
	print("GameScreen _ready() called")
	_position_boards()
	
	# Wire the InputRouter to both boards
	input_router.board_left  = board_left
	input_router.board_right = board_right
	input_router.pause_requested.connect(_on_pause_requested)

	# Wire board signals
	board_left.lines_cleared.connect(_on_left_lines_cleared)
	board_right.lines_cleared.connect(_on_right_lines_cleared)
	board_left.game_over.connect(_on_game_over)
	board_right.game_over.connect(_on_game_over)

# Called by ScreenManager.go_to("GameScreen") — resets and starts a fresh game.
func init(_data: Dictionary = {}) -> void:
	print("GameScreen.init() called")
	_score_left  = 0
	_score_right = 0
	_paused      = false
	_game_active = true

	_update_score_labels()
	pause_overlay.visible = false

	# Seed each board independently with a random int
	var base_seed := randi()
	board_left.start(base_seed)
	board_right.start(base_seed + 99999)   # Different seed = different piece sequence

	var viewport_size := get_viewport().get_visible_rect().size
	_audio_listener.global_position = viewport_size / 2
	_audio_listener.make_current()

# ── Scoring ───────────────────────────────────────────────────────────────────

func _on_left_lines_cleared(count: int) -> void:
	_score_left += _points_for(count)
	_update_score_labels()

func _on_right_lines_cleared(count: int) -> void:
	_score_right += _points_for(count)
	_update_score_labels()

func _points_for(lines: int) -> int:
	if lines >= LINE_POINTS.size():
		return LINE_POINTS[LINE_POINTS.size() - 1]
	return LINE_POINTS[lines]

func _update_score_labels() -> void:
	left_score_label.text  = "L: %d" % _score_left
	right_score_label.text = "R: %d" % _score_right

# ── Pause ─────────────────────────────────────────────────────────────────────

func _on_pause_requested() -> void:
	if not _game_active:
		return
	_paused = not _paused
	get_tree().paused   = _paused
	pause_overlay.visible = _paused

# ── Game over ─────────────────────────────────────────────────────────────────

# Either board ending ends the round (called once is enough — guard with _game_active).
func _on_game_over() -> void:
	if not _game_active:
		return
	_game_active = false
	get_tree().paused = false   # Make sure tree isn't stuck paused

	# Short delay so the player sees the game-over board state before the screen switches
	await get_tree().create_timer(1.2).timeout

	ScreenManager.go_to("EndScreen", {
		"score_left":  _score_left,
		"score_right": _score_right,
	})

func _position_boards() -> void:
	# Board dimensions: 10 cols × 20 rows × 28px = 280 × 560
	var board_w := board_left.cols * board_left.cell_size    # 280
	var board_h := board_left.rows * board_left.cell_size    # 560
	var gap     := 40
	var total_w := board_w * 2 + gap
	var screen_w: float = get_viewport().get_visible_rect().size.x
	var screen_h: float = get_viewport().get_visible_rect().size.y

	var start_x := (screen_w - total_w) / 2.0
	var start_y := (screen_h - board_h) / 2.0

	board_left.position  = Vector2(start_x, start_y)
	board_right.position = Vector2(start_x + board_w + gap, start_y)
	print(board_left.position, board_right.position)

	# Score labels above each board
	left_score_label.position  = Vector2(start_x, start_y - 30)
	right_score_label.position = Vector2(start_x + board_w + gap, start_y - 30)
