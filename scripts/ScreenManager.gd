extends Node
# ---------------------------------------------------------------------------
# ScreenManager.gd
# Add as an Autoload singleton: Project > Project Settings > Autoload
# Name it "ScreenManager" so all scripts can call ScreenManager.go_to(...)
#
# Screens are registered by name. Each screen is a CanvasLayer (or Control)
# that lives under Main.tscn's root node.
#
# Usage from any script:
#   ScreenManager.go_to("StartScreen")
#   ScreenManager.go_to("GameScreen")
#   ScreenManager.go_to("EndScreen", { "score": 420 })
# ---------------------------------------------------------------------------

signal screen_changed(screen_name: String)

# Filled by Main.gd on _ready via register()
var _screens: Dictionary = {}
var _current: String = ""

# Register a screen node under a name.
# Call this from Main.gd for each top-level screen node.
func register(name: String, node: Node) -> void:
	_screens[name] = node
	node.visible   = false

# Switch to the named screen, optionally passing data to an init() method.
func go_to(screen_name: String, data: Dictionary = {}) -> void:
	print("ScreenManager.go_to: ", screen_name)
	if screen_name == _current:
		return

	# Hide current
	if _current != "" and _screens.has(_current):
		_screens[_current].visible = false

	# Show next
	if not _screens.has(screen_name):
		push_error("ScreenManager: unknown screen '%s'" % screen_name)
		return

	var next: Node = _screens[screen_name]
	next.visible = true

	# If the screen has an init() method, call it with the data dict
	if next.has_method("init"):
		next.init(data)

	_current = screen_name
	screen_changed.emit(screen_name)

func current_screen() -> String:
	return _current
