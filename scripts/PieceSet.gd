class_name PieceSet
# ---------------------------------------------------------------------------
# PieceSet.gd
# Factory for all triomino (3-block) piece definitions.
#
# The 5 one-sided triominoes:
#
#   I:  [■][■][■]
#
#   L:  [■][ ]
#       [■][■]
#
#   J:  [ ][■]
#       [■][■]
#
#   T:  [■][■]    (only 2-wide; pivot is left cell)
#       [ ][■]
#
#   O:  [■][■]    (2×2 minus one corner; always same orientation)
#       [■][ ]
#
# Pivot cell is always included in the offsets at (0,0).
# ---------------------------------------------------------------------------

const COLORS := {
	Piece.Type.I: Color(0.29, 0.78, 0.90),   # cyan
	Piece.Type.L: Color(0.93, 0.57, 0.13),   # orange
	Piece.Type.J: Color(0.25, 0.42, 0.88),   # blue
	Piece.Type.T: Color(0.65, 0.25, 0.85),   # purple
	Piece.Type.O: Color(0.92, 0.82, 0.13),   # yellow
}

# Returns a fresh Piece for the given type.
static func make(type: Piece.Type) -> Piece:
	var color := COLORS[type]
	var offsets: Array[Vector2i]

	match type:
		Piece.Type.I:
			# Horizontal: pivot at left
			offsets = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]
		Piece.Type.L:
			# Pivot top-left
			# [■][ ]
			# [■][■]
			offsets = [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1)]
		Piece.Type.J:
			# Pivot top-right
			# [ ][■]
			# [■][■]
			offsets = [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]
		Piece.Type.T:
			# Pivot top-left
			# [■][■]
			# [ ][■]
			offsets = [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1)]
		Piece.Type.O:
			# Pivot top-left
			# [■][■]
			# [■][ ]
			offsets = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1)]

	return Piece.new(type, color, offsets)

# Returns a random Piece using the provided RandomNumberGenerator.
static func random(rng: RandomNumberGenerator) -> Piece:
	var all_types := [
		Piece.Type.I,
		Piece.Type.L,
		Piece.Type.J,
		Piece.Type.T,
		Piece.Type.O,
	]
	var idx := rng.randi_range(0, all_types.size() - 1)
	return make(all_types[idx])
