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

@export var board_scene: PackedScene
@export var board_score_interval: int = 1000
@export var restore_saved_board_states: bool = false

@onready var board_left:   Board  = $Control/BoardL
@onready var board_right:  Board  = $Control/BoardR
@onready var input_router: InputRouter = $InputRouter
@onready var score_bar: ScoreBar = $Control/ScoreBar

@onready var left_panel: Control = $Control/LeftPanel
@onready var right_panel: Control = $Control/RightPanel
@onready var piece_set_label: Label = $Control/PieceSetLabel

@onready var pause_overlay: ColorRect = $Control/PauseOverlay

@onready var _audio_listener: AudioListener2D = $Control/AudioListener2D

@onready var _drop_scheduler: DropScheduler = $Control/DropScheduler
@onready var _drop_rhythm_indicator: DropRhythmIndicator = $Control/DropRhythmIndicator

var _gravity_timer: Timer = null

var _boards: Array[Board] = []
var _score_labels: Array[Label] = []
var _scores: Array[int] = []
var _paused:      bool = false
var _game_active: bool = false
var _piece_set: PieceSet.Set = PieceSet.Set.TETROMINO
var _next_board_score_threshold: int = 1000
var _layout_tween: Tween = null
var _pending_scheduler_state: Dictionary = {}
var _active_saved_state_name: String = DEFAULT_SAVED_STATE_NAME

const SCORE_BAR_WIDTH: float = 28.0
const SCORE_BAR_MARGIN: float = 30.0
const BOARD_LAYOUT_TWEEN_SECONDS: float = 0.35
const BOARD_ENTRY_TWEEN_SECONDS: float = 0.7
const BOARD_ENTRY_OFFSET: Vector2 = Vector2(180, 0)
const DEFAULT_BOARD_CELL_SIZE: int = 28
const MAX_BOARD_ROWS: int = 2
const BOARD_GAP: float = 40.0
const BOARD_ROW_GAP: float = 44.0
const BOARD_LAYOUT_MARGIN: float = 42.0
const BOARD_LAYOUT_TOP_MARGIN: float = 64.0
const BOARD_LAYOUT_BOTTOM_MARGIN: float = 34.0
const BOARD_SCORE_LABEL_WIDTH: float = 58.0
const BOARD_SCORE_LABEL_GAP: float = 10.0

# Points awarded per number of lines cleared in a single drop
const LINE_POINTS := [0, 100, 300, 400, 500]
const SAVED_STATE_DIRECTORY := "user://saved_games"
const DEFAULT_SAVED_STATE_NAME := "quicksave"

func _ready() -> void:
	print("GameScreen _ready() called")
	if board_scene == null:
		board_scene = preload("res://scenes/Board.tscn")

	left_panel.visible = false
	right_panel.visible = false

	_register_board(board_left)
	_register_board(board_right)

	call_deferred("_position_boards")
	#get_viewport().size_changed.connect(_position_boards)
	#_position_boards()

	# Wire shared systems to every board.
	input_router.boards = _boards
	input_router.pause_requested.connect(_on_pause_requested)
	input_router.piece_set_toggle_requested.connect(_on_piece_set_toggle_requested)
	input_router.save_state_requested.connect(_on_save_state_requested)
	input_router.load_state_requested.connect(_on_load_state_requested)
	_drop_scheduler.set_boards(_boards)

	_drop_scheduler.drop_requested.connect(_on_drop_requested)
	_gravity_timer = Timer.new()
	_gravity_timer.name = "SharedGravityTimer"
	_gravity_timer.wait_time = board_left.gravity_interval
	_gravity_timer.one_shot = false
	_gravity_timer.timeout.connect(_on_shared_gravity_tick)
	add_child(_gravity_timer)

# Called by ScreenManager.go_to("GameScreen") — resets and starts a fresh game.
func init(_data: Dictionary = {}) -> void:
	print("GameScreen.init() called")
	_reset_to_starting_boards()
	for i in _scores.size():
		_scores[i] = 0
	_paused      = false
	_game_active = true
	_next_board_score_threshold = board_score_interval

	_update_score_labels()
	_update_piece_set_label()
	pause_overlay.visible = false

	# Seed each board independently with a random int
	var requested_state := str(_data.get("saved_state_name", ""))
	if (not requested_state.is_empty() and load_named_state(requested_state)) \
		or (restore_saved_board_states and load_named_state(DEFAULT_SAVED_STATE_NAME)):
		pass
	else:
		_active_saved_state_name = DEFAULT_SAVED_STATE_NAME
		var base_seed := randi()
		for i in _boards.size():
			_boards[i].start(base_seed + i * 99999)

	var viewport_size := get_viewport().get_visible_rect().size
	_audio_listener.global_position = viewport_size / 2
	_audio_listener.make_current()

	# Start external timers for synchronization.
	_drop_scheduler.begin()
	_gravity_timer.start()

	if not _pending_scheduler_state.is_empty():
		_drop_scheduler.restore_state(_pending_scheduler_state)
		_pending_scheduler_state.clear()

func _on_save_state_requested() -> void:
	save_named_state(_active_saved_state_name)

func _on_load_state_requested() -> void:
	if load_named_state(_active_saved_state_name):
		_drop_scheduler.begin()
		if not _pending_scheduler_state.is_empty():
			_drop_scheduler.restore_state(_pending_scheduler_state)
			_pending_scheduler_state.clear()

## Advances every active board from one shared timer event so a newly added
## board joins the same gravity phase instead of starting its own clock.
func _on_shared_gravity_tick() -> void:
	if not _game_active:
		return
	for board in _boards:
		board.gravity_tick()

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
	_check_board_unlocks()

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
	if not _game_active and not _paused:
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
	if _gravity_timer:
		_gravity_timer.stop()
	get_tree().paused = false   # Make sure tree isn't stuck paused

	# Short delay so the player sees the game-over board state before the screen switches
	await get_tree().create_timer(1.2).timeout

	ScreenManager.go_to("EndScreen", {
		"scores": _scores.duplicate(),
	})

## Applies the latest calculated board layout.
## Boards redraw at an integer cell size instead of using Node2D scale, keeping
## grid lines and custom drawing crisp. When a board has just been added,
## entering_board_index gives that board a slower slide/fade entry while all
## existing boards move in the same parallel tween.
func _position_boards(animated: bool = false, entering_board_index: int = -1) -> void:
	if _boards.is_empty():
		return

	var layout := _get_board_layout()
	var board_positions: Array[Vector2] = layout["board_positions"]
	var label_positions: Array[Vector2] = layout["label_positions"]
	var board_cell_size: int = layout["board_cell_size"]
	var score_bar_position: Vector2 = layout["score_bar_position"]
	var score_bar_size: Vector2 = layout["score_bar_size"]

	for board in _boards:
		board.cell_size = board_cell_size
		board.scale = Vector2.ONE
		board.queue_redraw()

	if _layout_tween:
		_layout_tween.kill()
		_layout_tween = null

	if animated:
		_layout_tween = create_tween()
		_layout_tween.set_parallel(true)
		for i in _boards.size():
			var duration := BOARD_ENTRY_TWEEN_SECONDS if i == entering_board_index else BOARD_LAYOUT_TWEEN_SECONDS
			if i == entering_board_index:
				_boards[i].position = board_positions[i] + BOARD_ENTRY_OFFSET
				_set_canvas_item_alpha(_boards[i], 0.0)
				_layout_tween.tween_property(_boards[i], "modulate:a", 1.0, duration) \
					.set_trans(Tween.TRANS_CUBIC) \
					.set_ease(Tween.EASE_OUT)
			else:
				_set_canvas_item_alpha(_boards[i], 1.0)
			_layout_tween.tween_property(_boards[i], "position", board_positions[i], duration) \
				.set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)
		for i in _score_labels.size():
			var duration := BOARD_ENTRY_TWEEN_SECONDS if i == entering_board_index else BOARD_LAYOUT_TWEEN_SECONDS
			if i == entering_board_index:
				_score_labels[i].position = label_positions[i] + BOARD_ENTRY_OFFSET
				_set_canvas_item_alpha(_score_labels[i], 0.0)
				_layout_tween.tween_property(_score_labels[i], "modulate:a", 1.0, duration) \
					.set_trans(Tween.TRANS_CUBIC) \
					.set_ease(Tween.EASE_OUT)
			else:
				_set_canvas_item_alpha(_score_labels[i], 1.0)
			_layout_tween.tween_property(_score_labels[i], "position", label_positions[i], duration) \
				.set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)
		_layout_tween.tween_property(score_bar, "position", score_bar_position, BOARD_LAYOUT_TWEEN_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	else:
		for i in _boards.size():
			_boards[i].position = board_positions[i]
			_set_canvas_item_alpha(_boards[i], 1.0)
		for i in _score_labels.size():
			_score_labels[i].position = label_positions[i]
			_score_labels[i].size = Vector2(BOARD_SCORE_LABEL_WIDTH, 24)
			_set_canvas_item_alpha(_score_labels[i], 1.0)
		score_bar.position = score_bar_position

	_drop_rhythm_indicator.position = layout["rhythm_indicator_position"]
	piece_set_label.position = layout["piece_set_label_position"]
	score_bar.size = score_bar_size
	score_bar.set_score(_total_score())

## Calculates a readable board layout for the current viewport.
## Each slot reserves horizontal space for a score label to the left of its
## board, then chooses an integer board cell size that fits every slot in at
## most MAX_BOARD_ROWS rows.
func _get_board_layout() -> Dictionary:
	var board_w := float(board_left.cols * DEFAULT_BOARD_CELL_SIZE)
	var board_h := float(board_left.rows * DEFAULT_BOARD_CELL_SIZE)
	var slot_w := board_w + BOARD_SCORE_LABEL_WIDTH + BOARD_SCORE_LABEL_GAP
	var screen_w: float = get_viewport().get_visible_rect().size.x
	var screen_h: float = get_viewport().get_visible_rect().size.y
	var available_w := screen_w - BOARD_LAYOUT_MARGIN * 2.0 - SCORE_BAR_WIDTH - SCORE_BAR_MARGIN
	var available_h := screen_h - BOARD_LAYOUT_TOP_MARGIN - BOARD_LAYOUT_BOTTOM_MARGIN
	var layout_grid := _best_board_grid(_boards.size(), slot_w, board_h, available_w, available_h)
	var column_count: int = layout_grid["columns"]
	var row_count: int = layout_grid["rows"]
	var scale_factor: float = layout_grid["scale"]
	var board_cell_size := maxi(1, floori(float(DEFAULT_BOARD_CELL_SIZE) * scale_factor))
	var scaled_board_w := float(board_left.cols * board_cell_size)
	var scaled_board_h := float(board_left.rows * board_cell_size)
	var scaled_slot_w := scaled_board_w + BOARD_SCORE_LABEL_WIDTH + BOARD_SCORE_LABEL_GAP
	var total_w := scaled_slot_w * float(column_count) + BOARD_GAP * float(column_count - 1)
	var total_h := scaled_board_h * float(row_count) + BOARD_ROW_GAP * float(row_count - 1)

	var start_x := (screen_w - total_w) / 2.0
	var start_y := BOARD_LAYOUT_TOP_MARGIN + maxf(0.0, (available_h - total_h) / 2.0)

	var board_positions: Array[Vector2] = []
	var label_positions: Array[Vector2] = []
	for i in _boards.size():
		var col := i % column_count
		var row := i / column_count
		var slot_x := start_x + float(col) * (scaled_slot_w + BOARD_GAP)
		var x := slot_x + BOARD_SCORE_LABEL_WIDTH + BOARD_SCORE_LABEL_GAP
		var y := start_y + float(row) * (scaled_board_h + BOARD_ROW_GAP)
		board_positions.append(Vector2(x, y))
		label_positions.append(Vector2(slot_x, y + 4.0))

	return {
		"board_positions": board_positions,
		"label_positions": label_positions,
		"board_cell_size": board_cell_size,
		"rhythm_indicator_position": Vector2(start_x + scaled_board_w, start_y - _drop_rhythm_indicator.size.y * 0.5),
		"piece_set_label_position": Vector2(start_x, start_y - 58),
		"score_bar_position": Vector2(
		start_x - SCORE_BAR_MARGIN - SCORE_BAR_WIDTH,
		start_y
		),
		"score_bar_size": Vector2(SCORE_BAR_WIDTH, total_h),
	}

## Finds the largest readable grid using at most MAX_BOARD_ROWS rows.
## The returned scale is the largest uniform fit for the slot width and board
## height. A score label is included in slot width but is not vertically scaled.
func _best_board_grid(board_count: int, slot_w: float, board_h: float, available_w: float, available_h: float) -> Dictionary:
	var best_columns := board_count
	var best_rows := 1
	var best_scale := 0.0

	var min_columns := ceili(float(board_count) / float(MAX_BOARD_ROWS))
	for columns in range(min_columns, board_count + 1):
		var rows := ceili(float(board_count) / float(columns))
		var width_scale := (available_w - BOARD_GAP * float(columns - 1)) / (slot_w * float(columns))
		var height_scale := (available_h - BOARD_ROW_GAP * float(rows - 1)) / (board_h * float(rows))
		var scale := minf(1.0, minf(width_scale, height_scale))

		if scale > best_scale:
			best_columns = columns
			best_rows = rows
			best_scale = scale

	return {
		"columns": best_columns,
		"rows": best_rows,
		"scale": maxf(best_scale, 0.1),
	}

## Creates the score label used for every board, including the two scene boards.
## Keeping generated labels consistent avoids the old split between legacy
## left/right panels and runtime-added boards.
func _make_score_label() -> Label:
	var label := Label.new()
	label.name = "Board%dScoreLabel" % (_score_labels.size() + 1)
	label.layout_mode = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.size = Vector2(BOARD_SCORE_LABEL_WIDTH, 24)
	$Control.add_child(label)
	pause_overlay.move_to_front()
	return label

## Sets opacity without changing the existing color/modulate value.
func _set_canvas_item_alpha(item: CanvasItem, alpha: float) -> void:
	var color := item.modulate
	color.a = alpha
	item.modulate = color

## Returns the shared total score used for the score bar and board unlocks.
func _total_score() -> int:
	var total := 0
	for score in _scores:
		total += score
	return total

## Adds a board to all shared game systems.
## This wires scoring, input routing, scheduler participation, piece set, and a
## standardized score label. position_now is false for runtime board additions
## so the caller can apply an animated layout after registration.
func _register_board(board: Board, position_now: bool = true) -> void:
	var board_index := _boards.size()
	board.board_index = board_index
	board.listen_for_drop = true
	board.use_external_gravity = true
	board.piece_set = _piece_set

	_boards.append(board)
	_scores.append(0)
	_score_labels.append(_make_score_label())

	board.lines_cleared.connect(_on_board_lines_cleared.bind(board_index))
	board.game_over.connect(_on_game_over)

	input_router.boards = _boards
	_drop_scheduler.set_boards(_boards)
	_update_score_labels()
	if position_now:
		_position_boards()

## Unlocks one additional board whenever total score reaches the next interval.
## This intentionally adds at most one board per scoring event so an entry tween
## cannot be interrupted by another newly-added board before it fades in.
func _check_board_unlocks() -> void:
	if board_score_interval <= 0:
		return
	if _total_score() >= _next_board_score_threshold:
		_next_board_score_threshold += board_score_interval
		_add_board()

## Instantiates one new board and lets it enter from the right of its final slot.
func _add_board() -> void:
	var board := board_scene.instantiate() as Board
	board.name = "Board%d" % (_boards.size() + 1)
	var junk_rng := RandomNumberGenerator.new()
	junk_rng.seed = randi()
	var average_height := 0.0
	for existing_board in _boards:
		average_height += existing_board.get_stack_height()
	if not _boards.is_empty():
		average_height /= float(_boards.size())
	var junk_state := board.make_random_junk_state(roundi(average_height * 0.5), junk_rng)
	$Control.add_child(board)
	_register_board(board, false)
	pause_overlay.move_to_front()
	_position_boards(true, _boards.size() - 1)
	board.start(randi(), junk_state)

## Saves every independently captured board plus scheduler metadata under a
## human-readable name in the shared saved-game directory.
func save_named_state(state_name: String) -> bool:
	var safe_name := _safe_state_name(state_name)
	if safe_name.is_empty():
		return false
	var user_directory := DirAccess.open("user://")
	if user_directory:
		user_directory.make_dir_recursive("saved_games")
	var board_states: Array = []
	for i in _boards.size():
		board_states.append({"score": _scores[i], "board": _boards[i].capture_state()})
	var payload := {
		"version": 2,
		"name": safe_name,
		"created_unix": Time.get_unix_time_from_system(),
		"piece_set": int(_piece_set),
		"next_board_score_threshold": _next_board_score_threshold,
		"boards": board_states,
		"scheduler": _drop_scheduler.capture_state(),
	}
	var file := FileAccess.open(_state_path(safe_name), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	print("Saved game state to: ", ProjectSettings.globalize_path(_state_path(safe_name)))
	return true

## Compatibility wrapper for older callers that passed a complete file path.
func save_board_states(path: String = "") -> bool:
	var state_name := DEFAULT_SAVED_STATE_NAME if path.is_empty() else path.get_file().get_basename()
	return save_named_state(state_name)

## Loads a named snapshot, recreating the required number of boards and asking
## each board to restore its own serialized state record.
func load_named_state(state_name: String) -> bool:
	_drop_scheduler.stop()
	var file := FileAccess.open(_state_path(_safe_state_name(state_name)), FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("boards"):
		return false
	var saved_boards: Array = parsed["boards"]
	if saved_boards.is_empty():
		return false
	_active_saved_state_name = _safe_state_name(state_name)
	var saved_piece_set := int(parsed.get("piece_set", int(_piece_set)))
	_piece_set = PieceSet.Set.TRIOMINO if saved_piece_set == int(PieceSet.Set.TRIOMINO) else PieceSet.Set.TETROMINO
	_reset_to_starting_boards()
	while _boards.size() < saved_boards.size():
		_add_board()
	for i in saved_boards.size():
		var saved = saved_boards[i]
		if not saved is Dictionary:
			continue
		_scores[i] = int(saved.get("score", 0))
		var board_state: Dictionary = saved.get("board", saved)
		_boards[i].restore_state(board_state)
	var saved_threshold := int(parsed.get("next_board_score_threshold", 0))
	if saved_threshold > 0:
		_next_board_score_threshold = saved_threshold
	else:
		# Older snapshots did not store this counter. Reconstruct the next
		# interval from the restored score total instead of restarting at zero.
		var total_score := _total_score()
		_next_board_score_threshold = max(
			board_score_interval,
			(floori(float(total_score) / float(maxi(board_score_interval, 1))) + 1) * board_score_interval
		)
	_pending_scheduler_state = parsed.get("scheduler", {})
	_update_score_labels()
	_update_piece_set_label()
	_position_boards()
	return true

## Compatibility wrapper for the previous default save path API.
func load_board_states(_path: String = "") -> bool:
	return load_named_state(DEFAULT_SAVED_STATE_NAME)

## Returns saved-state metadata sorted from newest to oldest for a menu list.
func list_saved_states() -> Array:
	var results: Array = []
	var directory := DirAccess.open(SAVED_STATE_DIRECTORY)
	if directory == null:
		return results
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.get_extension() == "json":
			var file := FileAccess.open(SAVED_STATE_DIRECTORY.path_join(filename), FileAccess.READ)
			if file:
				var parsed = JSON.parse_string(file.get_as_text())
				if parsed is Dictionary:
					results.append({
						"name": parsed.get("name", filename.get_basename()),
						"created_unix": int(parsed.get("created_unix", 0)),
						"board_count": parsed.get("boards", []).size(),
					})
		filename = directory.get_next()
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["created_unix"]) > int(b["created_unix"])
	)
	return results

## Returns the OS-visible folder containing named game-state files.
func get_saved_states_directory() -> String:
	return ProjectSettings.globalize_path(SAVED_STATE_DIRECTORY)

func _safe_state_name(state_name: String) -> String:
	return state_name.strip_edges().validate_filename()

func _state_path(state_name: String) -> String:
	return SAVED_STATE_DIRECTORY.path_join(_safe_state_name(state_name) + ".json")

## Restores a fresh round to the two scene-authored boards.
## Runtime boards and their generated score labels are removed; the remaining
## boards keep the current piece-set choice and are re-registered with systems.
func _reset_to_starting_boards() -> void:
	while _boards.size() > 2:
		var board: Board = _boards.pop_back()
		_scores.pop_back()
		var label: Label = _score_labels.pop_back()
		label.queue_free()
		board.queue_free()

	for i in _boards.size():
		_boards[i].board_index = i
		_boards[i].piece_set = _piece_set

	input_router.boards = _boards
	_drop_scheduler.set_boards(_boards)
	_position_boards()
