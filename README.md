# Twotris

Twotris is a single-player, two-board falling-block game made in Godot 4. One
set of controls affects both boards. The game is designed around choosing which
board needs attention while its pieces arrive on a staggered rhythm.

## Run the project

Open `project.godot` with Godot 4.6 (or a compatible Godot 4 release) and run
the configured main scene, `scenes/Main.tscn`.

## Controls

| Action | Keys |
| --- | --- |
| Move both active pieces left/right | A / D or Left / Right Arrow |
| Soft drop both active pieces | S or Down Arrow |
| Hard drop the lower active piece | W, Up Arrow, or Space |
| Rotate both active pieces clockwise | X |
| Rotate both active pieces counter-clockwise | Z |
| Pause | Escape or P |

## Scene hierarchy

```text
Main.tscn (Node, Main.gd)
├── StartScreen.tscn (CanvasLayer, StartScreen.gd)
├── GameScreen.tscn (CanvasLayer, GameScreen.gd)
│   ├── Control
│   │   ├── ScoreBar (ScoreBar.tscn, ScoreBar.gd)
│   │   ├── BoardL (Board.tscn, Board.gd)
│   │   ├── BoardR (Board.tscn, Board.gd)
│   │   ├── score labels and pause overlay
│   │   ├── DropScheduler (DropScheduler.gd)
│   │   └── DropRhythmIndicator (DropRhythmIndicator.gd)
│   └── InputRouter (InputRouter.gd)
└── EndScreen.tscn (CanvasLayer, EndScreen.gd)

Autoloads
├── ScreenManager — changes between the three screens
└── SFXPlayer — plays pooled positional sound effects
```

`Board.tscn` is instanced twice. Each board has its own grid, active piece,
random-number generator, gravity timer, particles, and draw pass.

## Folder organization

```text
scenes/     Godot scene files and node layout
scripts/    Gameplay, UI, and orchestration GDScript
audio/      Sound effects
textures/   Particle and future art textures
shaders/    Score-bar fill shader
addons/     Godot editor plugins
SETUP.md    Original Godot setup notes
```

## System map

```text
InputRouter ──controls──> BoardL + BoardR
     │                         │
     │                  lines_cleared / game_over
     │                         ▼
     └──hard-drop target──> GameScreen ──> score, pause, screen changes
                                   ▲
DropScheduler ──drop_requested────┘
     │
     └──turn_changed──> DropRhythmIndicator
```

### Main scripts

| File | Responsibility |
| --- | --- |
| `Board.gd` | Grid collision, piece movement and rotation, locking, line clears, custom drawing, ghost/drop guide, hard-drop glow, and lock particles. |
| `Piece.gd` / `PieceSet.gd` | Piece data, pivot-based rotation, colors, and weighted random piece selection. |
| `InputRouter.gd` | Sends shared movement/rotation/soft-drop controls to both boards and chooses the hard-drop target. |
| `DropScheduler.gd` | Alternates left/right spawn opportunities on a timer; only requests a spawn when the selected board is empty. |
| `DropRhythmIndicator.gd` | Draws the timer-synchronized arrow and progress rail between boards. |
| `GameScreen.gd` | Starts rounds, gives boards independent RNG seeds, connects signals, tracks score, positions UI, and handles pause/game-over flow. |
| `ScoreBar.gd` | Animates the combined-score progress bar toward the 10,000-point goal. |
| `ScreenManager.gd` | Autoload that shows one screen at a time and calls its `init()` method. |
| `SFXPlayer.gd` | Autoloaded pool of 2D audio players for movement, rotation, locks, line clears, and game over. |

## Implemented gameplay

- Two independently randomized 10×20 boards using triomino-style pieces.
- Shared movement, rotation, and soft-drop controls.
- Alternating one-second spawn scheduler: a scheduled board gets a new piece
  only when it has no active piece.
- Synchronized gravity: both boards keep the same gravity beat even though
  they receive pieces at different times.
- Hard drop affects only the piece whose **rotation pivot** has fallen farther.
  This deliberately avoids target switching when a long piece rotates. Ties
  go to the left board.
- A pulsing border shows the current hard-drop target; the center indicator
  shows which board has the next scheduler opportunity.
- Hard-dropped pieces visually lock immediately, then wait empty for the
  scheduler to provide their next piece.
- Ghost piece, drop-distance guide, lock particles, sound effects, line
  clears, per-board scoring, pause, game-over, restart, and animated 10,000
  point score bar.

## Important rules to preserve

1. **Only `DropScheduler` causes scheduled piece spawns.** `Board` reports
   whether it has an active piece; `GameScreen` responds to
   `drop_requested` by calling `spawn_next()`.
2. **A locked scheduled board must set `_active_piece` to `null` and call
   `queue_redraw()`.** The latter is required because boards use custom
   `_draw()` rendering; without it, a locked piece can look frozen in midair.
3. **Use the piece pivot, not its lowest block, for hard-drop targeting.** A
   piece's bottom edge changes when it rotates; its pivot represents stable
   fall progress.
4. **Keep gravity timers running continuously.** Do not reset gravity when a
   new scheduled piece spawns, or the boards lose their shared fall rhythm.
5. `hard_drop_completed` is available on `Board` for future effects, but it
   does not currently spawn a replacement piece.

## Next milestones

- Add a next-piece preview to each side.
- Add a clear visual/audio cue when a scheduler turn is skipped.
- Playtest the base loop and tune gravity, scheduler interval, scoring, and
  the hard-drop targeting rule before adding chaos effects.
- Add a structured effect system with short, readable effects first (for
  example: fog, wind, bombs, garbage, or board swaps).
- Add unlocks/skins and a post-run effect survey once the core loop feels fun.

## Development notes

Keep this README current when a gameplay rule changes. For a new feature,
record its player-facing behavior under **Implemented gameplay** and any
non-obvious architectural constraint under **Important rules to preserve**.
This makes commits, future chats, and debugging much easier to follow.
