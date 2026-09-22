class_name PieceSet
# ---------------------------------------------------------------------------
# PieceSet.gd
# Factory for the seven standard Tetris tetromino (4-block) definitions.
#
# The seven one-sided tetrominoes:
#
#   I:  [■][■][■][■]
#
#   L:  [ ][ ][■]
#       [■][■][■]
#
#   J:  [■][ ][ ]
#       [■][■][■]
#
#   T:  [ ][■][ ]
#       [■][■][■]
#
#   S:  [ ][■][■]
#       [■][■][ ]
#
#   Z:  [■][■][ ]
#       [ ][■][■]
#
#   O:  [■][■]
#       [■][■]
#
# Pivot cell is always included in the offsets at (0,0).
# ---------------------------------------------------------------------------

enum Set { TRIOMINO, TETROMINO }

const COLORS := {
	Piece.Type.I: Color(0.29, 0.78, 0.90),   # cyan
	Piece.Type.L: Color(0.93, 0.57, 0.13),   # orange
	Piece.Type.J: Color(0.25, 0.42, 0.88),   # blue
	Piece.Type.T: Color(0.65, 0.25, 0.85),   # purple
	Piece.Type.S: Color(0.32, 0.78, 0.35),   # green
	Piece.Type.Z: Color(0.90, 0.28, 0.28),   # red
	Piece.Type.O: Color(0.92, 0.82, 0.13),   # yellow
}

# Returns a fresh Piece for the given type.
static func make(type: Piece.Type) -> Piece:
	var color: Color = COLORS[type]
	var offsets: Array[Vector2i]

	match type:
		Piece.Type.I:
			# [■][■][■][■]
			offsets = [Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]
		Piece.Type.L:
			# [ ][ ][■]
			# [■][■][■]
			offsets = [Vector2i(0,0), Vector2i(1,-1), Vector2i(-1,0), Vector2i(1,0)]
		Piece.Type.J:
			# [■][ ][ ]
			# [■][■][■]
			offsets = [Vector2i(0,0), Vector2i(-1,-1), Vector2i(-1,0), Vector2i(1,0)]
		Piece.Type.T:
			# [ ][■][ ]
			# [■][■][■]
			offsets = [Vector2i(0,0), Vector2i(0,-1), Vector2i(-1,0), Vector2i(1,0)]
		Piece.Type.S:
			# [ ][■][■]
			# [■][■][ ]
			offsets = [Vector2i(0,0), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0)]
		Piece.Type.Z:
			# [■][■][ ]
			# [ ][■][■]
			offsets = [Vector2i(0,0), Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,0)]
		Piece.Type.O:
			# [■][■]
			# [■][■]
			offsets = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(1,-1)]

	# Rotating a square around an integer cell would make it shift; leave it fixed.
	return Piece.new(type, color, offsets, type != Piece.Type.O)

# Returns the project's original 3-cell piece variants.
static func make_triomino(type: Piece.Type) -> Piece:
	var color: Color = COLORS[type]
	var offsets: Array[Vector2i]

	match type:
		Piece.Type.I:
			offsets = [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]
		Piece.Type.L:
			offsets = [Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, 0)]
		Piece.Type.J:
			offsets = [Vector2i(0, 0), Vector2i(0, -1), Vector2i(-1, 0)]
		Piece.Type.T:
			offsets = [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, 1)]
		Piece.Type.O:
			offsets = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
		_:
			# S and Z do not exist in the original 3-cell pool.
			return make_triomino(Piece.Type.I)

	return Piece.new(type, color, offsets)

# Returns a random Piece using the provided RandomNumberGenerator.
static func random(rng: RandomNumberGenerator, piece_set: Set = Set.TETROMINO) -> Piece:
	var all_types: Array[Piece.Type] = [
		Piece.Type.I,
		Piece.Type.L,
		Piece.Type.J,
		Piece.Type.T,
		Piece.Type.O,
	]
	if piece_set == Set.TETROMINO:
		all_types.append(Piece.Type.S)
		all_types.append(Piece.Type.Z)
	var idx := rng.randi_range(0, all_types.size() - 1)
	return make(all_types[idx]) if piece_set == Set.TETROMINO else make_triomino(all_types[idx])
