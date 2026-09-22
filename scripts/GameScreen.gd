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
@onready var score_bar: ScoreBar = $Control/ScoreBar

@onready var left_score_label:  Label   = $Control/LeftPanel/LeftScoreLabel
@onready var right_score_label: Label   = $Control/RightPanel/RightScoreLabel
@onready var piece_set_label: Label = $Control/PieceSetLabel

@onready var pause_overlay: ColorRect = $Control/PauseOverlay

@onready var _audio_listener: AudioListener2D = $Control/AudioListener2D

@onready var _drop_scheduler: DropScheduler = $Control/DropScheduler
@onready var _drop_rhythm_indicator: DropRhythmIndicator = $Control/DropRhythmIndicator

var _score_left:  int = 0
var _score_right: int = 0
var _paused:      bool = false
var _game_active: bool = false
var _piece_set: PieceSet.Set = PieceSet.Set.TETROMINO

const SCORE_BAR_WIDTH: float = 28.0
const SCORE_BAR_MARGIN: float = 30.0

# Points awarded per number of lines cleared in a single drop
const LINE_POINTS := [0, 100, 300, 700, 1500]

func _ready() -> void:
	print("GameScreen _ready() called")
	call_deferred("_position_boards")
	#get_viewport().size_changed.connect(_position_boards)
	#_position_boards()

	# Wire the InputRouter to both boards
	input_router.board_left  = board_left
	input_router.board_right = board_right
	input_router.pause_requested.connect(_on_pause_requested)
	input_router.piece_set_toggle_requested.connect(_on_piece_set_toggle_requested)

	# Wire board signals
	board_left.lines_cleared.connect(_on_left_lines_cleared)
	board_right.lines_cleared.connect(_on_right_lines_cleared)
	board_left.game_over.connect(_on_game_over)
	board_right.game_over.connect(_on_game_over)
	_drop_scheduler.drop_requested.connect(_on_drop_requested)

# Called by ScreenManager.go_to("GameScreen") — resets and starts a fresh game.
func init(_data: Dictionary = {}) -> void:
	print("GameScreen.init() called")
	_score_left  = 0
	_score_right = 0
	_paused      = false
	_game_active = true

	_update_score_labels()
	_update_piece_set_label()
	pause_overlay.visible = false

	# Seed each board independently with a random int
	var base_seed := randi()
	board_left.start(base_seed)
	board_right.start(base_seed + 99999)   # Different seed = different piece sequence

	var viewport_size := get_viewport().get_visible_rect().size
	_audio_listener.global_position = viewport_size / 2
	_audio_listener.make_current()

	_drop_scheduler.begin()

func _on_drop_requested(board: Board) -> void:
	# Retain the condition here so an accidental duplicate signal cannot replace
	# a piece that is still falling.
	if _game_active and not board.has_active_piece():
		board.spawn_next()

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
	
	score_bar.set_score(_score_left + _score_right)

# ── Pause ─────────────────────────────────────────────────────────────────────

func _on_pause_requested() -> void:
	if not _game_active:
		return
	_paused = not _paused
	get_tree().paused   = _paused
	pause_overlay.visible = _paused

func _on_piece_set_toggle_requested() -> void:
	if not _game_active:
		return
	_piece_set = PieceSet.Set.TRIOMINO if _piece_set == PieceSet.Set.TETROMINO else PieceSet.Set.TETROMINO
	board_left.set_piece_set(_piece_set)
	board_right.set_piece_set(_piece_set)
	_update_piece_set_label()

func _update_piece_set_label() -> void:
	var set_name := "4-CELL TETROMINOES" if _piece_set == PieceSet.Set.TETROMINO else "3-CELL PIECES"
	piece_set_label.text = "PIECES: %s  [TAB TO SWITCH]" % set_name

# ── Game over ─────────────────────────────────────────────────────────────────

# Either board ending ends the round (called once is enough — guard with _game_active).
func _on_game_over() -> void:
	if not _game_active:
		return
	_game_active = false
	_drop_scheduler.stop()
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
	_drop_rhythm_indicator.position = Vector2(start_x + board_w, start_y + board_h * 0.00 - _drop_rhythm_indicator.size.y * 0.5)
	print(board_left.position, board_right.position)

	# Score labels above each board
	left_score_label.position  = Vector2(start_x, start_y - 30)
	right_score_label.position = Vector2(start_x + board_w + gap, start_y - 30)
	piece_set_label.position = Vector2(start_x, start_y - 58)
	
	# Place the shared score bar to the left of everything
	score_bar.position = Vector2(
		start_x - SCORE_BAR_MARGIN - SCORE_BAR_WIDTH,
		start_y
	)
	score_bar.size = Vector2(SCORE_BAR_WIDTH, board_h * 1)
	score_bar.set_score(_score_left + _score_right)
