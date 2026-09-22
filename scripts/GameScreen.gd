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
@onready var board_center: Board  = $Control/BoardC
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

var _boards: Array[Board] = []
var _score_labels: Array[Label] = []
var _scores: Array[int] = []
var _paused:      bool = false
var _game_active: bool = false
var _piece_set: PieceSet.Set = PieceSet.Set.TETROMINO

const SCORE_BAR_WIDTH: float = 28.0
const SCORE_BAR_MARGIN: float = 30.0

# Points awarded per number of lines cleared in a single drop
const LINE_POINTS := [0, 100, 300, 700, 1500]

func _ready() -> void:
	print("GameScreen _ready() called")
	_boards = [board_left, board_center, board_right]
	_score_labels = [left_score_label, _make_score_label(), right_score_label]
	_scores.resize(_boards.size())

	call_deferred("_position_boards")
	#get_viewport().size_changed.connect(_position_boards)
	#_position_boards()

	# Wire shared systems to every board.
	input_router.boards = _boards
	input_router.pause_requested.connect(_on_pause_requested)
	input_router.piece_set_toggle_requested.connect(_on_piece_set_toggle_requested)
	_drop_scheduler.set_boards(_boards)

	for i in _boards.size():
		var board := _boards[i]
		board.board_index = i
		board.lines_cleared.connect(_on_board_lines_cleared.bind(i))
		board.game_over.connect(_on_game_over)
	_drop_scheduler.drop_requested.connect(_on_drop_requested)

# Called by ScreenManager.go_to("GameScreen") — resets and starts a fresh game.
func init(_data: Dictionary = {}) -> void:
	print("GameScreen.init() called")
	for i in _scores.size():
		_scores[i] = 0
	_paused      = false
	_game_active = true

	_update_score_labels()
	_update_piece_set_label()
	pause_overlay.visible = false

	# Seed each board independently with a random int
	var base_seed := randi()
	for i in _boards.size():
		_boards[i].start(base_seed + i * 99999)

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

func _on_board_lines_cleared(count: int, board_index: int) -> void:
	if board_index < 0 or board_index >= _scores.size():
		return
	_scores[board_index] += _points_for(count)
	_update_score_labels()

func _points_for(lines: int) -> int:
	if lines >= LINE_POINTS.size():
		return LINE_POINTS[LINE_POINTS.size() - 1]
	return LINE_POINTS[lines]

func _update_score_labels() -> void:
	for i in _score_labels.size():
		_score_labels[i].text = "%d: %d" % [i + 1, _scores[i]]
	
	score_bar.set_score(_total_score())

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
	for board in _boards:
		board.set_piece_set(_piece_set)
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
		"scores": _scores.duplicate(),
	})

func _position_boards() -> void:
	if _boards.is_empty():
		return

	# Board dimensions: 10 cols × 20 rows × 28px = 280 × 560
	var board_w := board_left.cols * board_left.cell_size    # 280
	var board_h := board_left.rows * board_left.cell_size    # 560
	var gap     := 40
	var total_w := board_w * _boards.size() + gap * (_boards.size() - 1)
	var screen_w: float = get_viewport().get_visible_rect().size.x
	var screen_h: float = get_viewport().get_visible_rect().size.y

	var start_x := (screen_w - total_w) / 2.0
	var start_y := (screen_h - board_h) / 2.0

	for i in _boards.size():
		_boards[i].position = Vector2(start_x + i * (board_w + gap), start_y)
	_drop_rhythm_indicator.position = Vector2(start_x + board_w, start_y + board_h * 0.00 - _drop_rhythm_indicator.size.y * 0.5)
	#_drop_rhythm_indicator.visible = false

	# Score labels above each board
	for i in _score_labels.size():
		_score_labels[i].position = Vector2(start_x + i * (board_w + gap), start_y - 30)
	piece_set_label.position = Vector2(start_x, start_y - 58)
	
	# Place the shared score bar to the left of everything
	score_bar.position = Vector2(
		start_x - SCORE_BAR_MARGIN - SCORE_BAR_WIDTH,
		start_y
	)
	score_bar.size = Vector2(SCORE_BAR_WIDTH, board_h * 1)
	score_bar.set_score(_total_score())

func _make_score_label() -> Label:
	var label := Label.new()
	label.name = "CenterScoreLabel"
	label.layout_mode = 0
	$Control.add_child(label)
	return label

func _total_score() -> int:
	var total := 0
	for score in _scores:
		total += score
	return total
