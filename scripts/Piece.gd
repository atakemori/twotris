class_name Piece
# ---------------------------------------------------------------------------
# Piece.gd
# Data class representing a single tetromino piece.
#
# Each piece is defined by an array of Vector2i offsets from a pivot cell.
# Pivot is always (0,0) in local space; the board translates to grid coords.
#
# Rotation is handled by transforming offsets:
#   90° CW:  (x, y) -> (y, -x)
#   90° CCW: (x, y) -> (-y, x)
# ---------------------------------------------------------------------------

# Shape identifiers — used for color lookup and display
enum Type { I, L, J, T, S, Z, O }

var type:    Type
var color:   Color
var offsets: Array[Vector2i]   # Current rotation state
var can_rotate: bool

func _init(p_type: Type, p_color: Color, p_offsets: Array[Vector2i], p_can_rotate: bool = true) -> void:
	type    = p_type
	color   = p_color
	offsets = p_offsets
	can_rotate = p_can_rotate

# Returns a NEW Piece rotated 90° clockwise.
func rotated_cw() -> Piece:
	# The square tetromino rotates around a center between cells, so it stays
	# visually stationary. Other pieces use pivot-based rotation.
	if not can_rotate:
		return duplicate_piece()
	var new_offsets: Array[Vector2i] = []
	for o in offsets:
		new_offsets.append(Vector2i(o.y, -o.x))
	return Piece.new(type, color, new_offsets, can_rotate)

# Returns a NEW Piece rotated 90° counter-clockwise.
func rotated_ccw() -> Piece:
	if not can_rotate:
		return duplicate_piece()
	var new_offsets: Array[Vector2i] = []
	for o in offsets:
		new_offsets.append(Vector2i(-o.y, o.x))
	return Piece.new(type, color, new_offsets, can_rotate)

# Returns a deep copy of this piece.
func duplicate_piece() -> Piece:
	var copied: Array[Vector2i] = []
	for o in offsets:
		copied.append(Vector2i(o.x, o.y))
	return Piece.new(type, color, copied, can_rotate)
