extends Node
# ---------------------------------------------------------------------------
# Main.gd
# Attach to the root Node of Main.tscn.
#
# Scene tree for Main.tscn:
#   Main  (Node)                     ← this script
#   ├── StartScreen  (CanvasLayer)   ← StartScreen.tscn instanced here
#   ├── GameScreen   (CanvasLayer)   ← GameScreen.tscn instanced here
#   └── EndScreen    (CanvasLayer)   ← EndScreen.tscn instanced here
#
# ScreenManager is an Autoload — it does not need to be a child of Main.
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Register each screen with the manager
	ScreenManager.register("StartScreen", $StartScreen)
	ScreenManager.register("GameScreen",  $GameScreen)
	ScreenManager.register("EndScreen",   $EndScreen)

	# Boot into the start screen
	ScreenManager.go_to("StartScreen")
