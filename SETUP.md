# Dual Tris — Godot Setup Guide

Godot version: **4.x** (tested with 4.2+). All scripts use GDScript 2.0.

---

## 1. Project Settings

### Input Map
Open **Project → Project Settings → Input Map** and add these actions:

| Action name  | Keys to assign              |
|--------------|-----------------------------|
| `move_left`  | A, Left Arrow               |
| `move_right` | D, Right Arrow              |
| `soft_drop`  | S, Down Arrow               |
| `hard_drop`  | Space, W                    |
| `rotate_cw`  | Up Arrow, X                 |
| `rotate_ccw` | Z                           |
| `pause`      | Escape, P                   |

### Autoload
Open **Project → Project Settings → Autoload** and add:

| Path                          | Name            |
|-------------------------------|-----------------|
| `res://scripts/ScreenManager.gd` | `ScreenManager` |

---

## 2. Script Files

Copy all `.gd` files from the `scripts/` folder into `res://scripts/` in your project.

```
res://scripts/
├── Piece.gd          ← class_name Piece
├── PieceSet.gd       ← class_name PieceSet
├── Board.gd          ← class_name Board, extends Node2D
├── InputRouter.gd    ← class_name InputRouter, extends Node
├── ScreenManager.gd  ← Autoload, extends Node
├── Main.gd           ← extends Node
├── StartScreen.gd    ← extends CanvasLayer
├── GameScreen.gd     ← extends CanvasLayer
└── EndScreen.gd      ← extends CanvasLayer
```

---

## 3. Build the Scenes

### Board.tscn

1. Create a new scene. Root node: **Node2D**. Rename it `BoardLeft` (you will reuse this scene for the right board too — the name doesn't matter at the scene level, only in the parent).
2. Attach `Board.gd` to the root Node2D.
3. Save as `res://scenes/Board.tscn`.

That's all Board.tscn needs — it draws itself entirely via `_draw()`.

> **Inspector tweaks (optional):** Select the root node and in the Inspector you can adjust `cols`, `rows`, `cell_size`, `gravity_interval`, and colors without touching the script.

---

### StartScreen.tscn

1. Root node: **CanvasLayer**. Rename to `StartScreen`. Attach `StartScreen.gd`.
2. Add child: **Control** (anchors: Full Rect).
3. Inside Control, add **VBoxContainer**. Set its anchors to center the box:
   - Anchor preset: **Center**
   - In the VBoxContainer's theme/alignment settings, set **Alignment = Center**.
4. Inside VBoxContainer, add:
   - **Label** — name `TitleLabel`, text `DUAL TRIS`, font size 64 (or use a theme).
   - **Label** — name `SubLabel`, text `One input. Two boards. No mercy.`
   - **Control** — name `Spacer`, set Minimum Size Y to 40.
   - **Button** — name `PlayButton`, text `PLAY`.
5. Add another **Label** below the VBoxContainer (child of Control, not VBox) — name `ControlsLabel`:
   ```
   ← → move   ↑ rotate CW   Z rotate CCW   Space hard drop   P pause
   ```
6. Save as `res://scenes/StartScreen.tscn`.

---

### EndScreen.tscn

1. Root node: **CanvasLayer**. Rename to `EndScreen`. Attach `EndScreen.gd`.
2. Add child: **Control** (anchors: Full Rect).
3. Inside Control, add **VBoxContainer** (anchor preset: Center).
4. Inside VBoxContainer, add these nodes in order:
   - **Label** — `GameOverLabel`, text `GAME OVER`, large font.
   - **Label** — `LeftScoreLabel`, text `Left board: 0`
   - **Label** — `RightScoreLabel`, text `Right board: 0`
   - **Label** — `TotalLabel`, text `Total: 0`
   - **Label** — `WinnerLabel`, text `—`
   - **Control** — `Spacer`, Minimum Size Y = 32
   - **Button** — `PlayAgainButton`, text `PLAY AGAIN`
   - **Button** — `MenuButton`, text `MAIN MENU`
5. Save as `res://scenes/EndScreen.tscn`.

---

### GameScreen.tscn

This is the most involved scene.

1. Root node: **CanvasLayer**. Rename to `GameScreen`. Attach `GameScreen.gd`.
2. Add child: **Control** (anchors: Full Rect).
3. Inside Control, add **HBoxContainer**:
   - Anchor preset: **Center**
   - Separation: 24px (or as desired)

4. Inside HBoxContainer, add these children **in order**:

   **a) LeftPanel** — VBoxContainer
   - **Label** `LeftScoreLabel` — text `L: 0`
   - **Label** `LeftNextLabel` — text `NEXT`
   - *(optional) Control `LeftNextDisplay` — you can add a next-piece preview here later*

   **b) BoardLeft** — instance `Board.tscn`
   - In the Inspector, set `cell_size = 28`, `cols = 10`, `rows = 20`.

   **c) VSeparator or ColorRect** (just visual spacing)

   **d) BoardRight** — instance `Board.tscn` again
   - Same settings as BoardLeft.

   **e) RightPanel** — VBoxContainer
   - **Label** `RightScoreLabel` — text `R: 0`
   - **Label** `RightNextLabel` — text `NEXT`

5. Back under **Control** (sibling of HBoxContainer), add:
   - **ColorRect** — name `PauseOverlay`
     - Anchors: Full Rect
     - Color: `Color(0, 0, 0, 0.6)`
     - Visible: **false** (unchecked in Inspector)
   - Inside PauseOverlay, add **Label** — name `PauseLabel`:
     - Text: `PAUSED — press P to resume`
     - Anchor: Center

6. Back under **GameScreen** root (sibling of Control), add:
   - **Node** — name `InputRouter`. Attach `InputRouter.gd`.

7. Save as `res://scenes/GameScreen.tscn`.

---

### Main.tscn

1. Root node: **Node**. Rename to `Main`. Attach `Main.gd`.
2. Add three children by **instancing** the scenes you just built:
   - Instance `StartScreen.tscn` → rename child to `StartScreen`
   - Instance `GameScreen.tscn` → rename child to `GameScreen`
   - Instance `EndScreen.tscn` → rename child to `EndScreen`
3. Set **Main.tscn as the main scene**: Project → Project Settings → Application → Run → Main Scene.
4. Save as `res://scenes/Main.tscn`.

---

## 4. Run Order Checklist

Before pressing Play, confirm:

- [ ] `ScreenManager.gd` is in the Autoload list as `ScreenManager`
- [ ] All 7 Input Map actions are defined
- [ ] `Main.tscn` is set as the main scene
- [ ] `BoardLeft` and `BoardRight` in GameScreen.tscn are instances of `Board.tscn`
- [ ] `InputRouter` node in GameScreen has `InputRouter.gd` attached
- [ ] The `@onready` node paths in each `*.gd` match the actual node names in the scene tree

---

## 5. Common Errors & Fixes

| Error | Likely cause | Fix |
|-------|-------------|-----|
| `Invalid get index 'board_left' on base 'null'` | InputRouter not found | Check `$InputRouter` path in GameScreen.gd matches your node name |
| Boards not responding to input | Input Map actions not defined | Add them in Project Settings → Input Map |
| `ScreenManager` not found | Autoload not set up | Add ScreenManager.gd in Project Settings → Autoload |
| Board renders at wrong position | HBoxContainer sizing | Set `custom_minimum_size` on the Board's root to `cols * cell_size` × `rows * cell_size` |
| Piece appears off-screen on spawn | Gravity too fast or board off-center | Check Board position in HBoxContainer; reduce `gravity_interval` in Inspector |

---

## 6. Extending the Game (Future Work)

The architecture is designed for easy expansion:

- **Gravity scaling** — increase `Board.gravity_interval` based on total lines cleared (hook into `lines_cleared` signal in GameScreen)
- **Next-piece preview** — read `board.get_next_piece()` in GameScreen and draw it in a small Control node
- **Hold piece** — add `hold()` to Board.gd and a new input action
- **Scoring multipliers** — modify `LINE_POINTS` in GameScreen or add a combo counter per board
- **Sound** — connect the `lines_cleared` and `game_over` signals to an AudioStreamPlayer
- **Theme / UI polish** — add a Theme resource to the root Control nodes and set fonts/colors globally
- **High score persistence** — use `FileAccess` to save/load from user data in EndScreen
