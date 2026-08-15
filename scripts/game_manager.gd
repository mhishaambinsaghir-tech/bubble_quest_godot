extends Node

enum GameState {
	PLAYING,
	WON,
	LOST
}

var game_state = GameState.PLAYING

var score = 0

static var selected_level_index: int = 0

@onready var game_ui = $"../GameUI"
@onready var hud = $"../GameUI/HUD"
@onready var score_label = $"../GameUI/HUD/ScoreLabel"
@onready var level_label = $"../GameUI/HUD/LevelLabel"
@onready var pause_button = $"../GameUI/HUD/PauseButton"

@onready var pause_panel = $"../GameUI/HUD/PausePanel"
@onready var resume_button = $"../GameUI/HUD/PausePanel/VBoxContainer/ResumeButton"
@onready var pause_restart_button = $"../GameUI/HUD/PausePanel/VBoxContainer/RestartButton"
@onready var pause_main_menu_button = $"../GameUI/HUD/PausePanel/VBoxContainer/MainMenuButton"

@onready var win_panel = $"../GameUI/HUD/WinPanel"
@onready var win_score_label = $"../GameUI/HUD/WinPanel/VBoxContainer/WinScoreLabel"
@onready var next_level_button = $"../GameUI/HUD/WinPanel/VBoxContainer/NextLevelButton"
@onready var replay_button = $"../GameUI/HUD/WinPanel/VBoxContainer/ReplayButton"

@onready var lose_panel = $"../GameUI/HUD/LosePanel"
@onready var retry_button = $"../GameUI/HUD/LosePanel/VBoxContainer/RetryButton"
@onready var lose_main_menu_button = $"../GameUI/HUD/LosePanel/VBoxContainer/MainMenuButton"

@onready var final_victory_panel = $"../GameUI/HUD/FinalVictoryPanel"
@onready var victory_score_label = $"../GameUI/HUD/FinalVictoryPanel/VBoxContainer/VictoryScoreLabel"
@onready var victory_main_menu_button = $"../GameUI/HUD/FinalVictoryPanel/VBoxContainer/MainMenuButton"

@onready var launcher = $"../Launcher"
@onready var bubble_spawn_point = $"../Launcher/BubbleSpawnPoint"

var bubble_scene: PackedScene
var current_bubble: Area2D

var bubble_speed: float = 600.0
var speed_increase: float = 25.0
var max_bubble_speed: float = 1000.0

var can_shoot := false

@export var levels: Array[LevelData] = []
var current_level_index: int = 0

func _ready() -> void:

	randomize()

	if levels.is_empty():
		for i in range(1, 11):
			var path: String = "res://data/levels/level_%02d.tres" % i
			var lvl = load(path)
			if lvl != null:
				levels.append(lvl)

	bubble_scene = preload(
		"res://scenes/bubbles/Bubble.tscn"
	)

	setup_ui()

	call_deferred("start_game")

func setup_ui() -> void:
	if game_ui != null:
		game_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	if pause_button != null:
		pause_button.pressed.connect(_on_pause_pressed)

	if resume_button != null:
		resume_button.pressed.connect(_on_resume_pressed)

	if pause_restart_button != null:
		pause_restart_button.pressed.connect(_on_restart_pressed)

	if pause_main_menu_button != null:
		pause_main_menu_button.pressed.connect(_on_main_menu_pressed)

	if next_level_button != null:
		next_level_button.pressed.connect(_on_next_level_pressed)

	if replay_button != null:
		replay_button.pressed.connect(_on_replay_pressed)

	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)

	if lose_main_menu_button != null:
		lose_main_menu_button.pressed.connect(_on_main_menu_pressed)

	if victory_main_menu_button != null:
		victory_main_menu_button.pressed.connect(_on_main_menu_pressed)

var next_bubble_type: int = -1
var next_bubble_preview_node: Polygon2D = null

func update_next_bubble_preview() -> void:
	if launcher == null:
		return
	if next_bubble_preview_node == null or not is_instance_valid(next_bubble_preview_node):
		next_bubble_preview_node = Polygon2D.new()
		var preview_script = load("res://scripts/next_bubble_preview.gd")
		if preview_script != null:
			next_bubble_preview_node.set_script(preview_script)
		next_bubble_preview_node.position = Vector2(-70, 40)
		launcher.add_child(next_bubble_preview_node)

	if next_bubble_type >= 0:
		next_bubble_preview_node.color = BubbleTypes.get_color(next_bubble_type)

func start_game() -> void:
	current_level_index = selected_level_index
	load_active_level()

func load_active_level() -> void:
	get_tree().paused = false
	game_state = GameState.PLAYING
	next_bubble_type = -1

	if pause_panel != null: pause_panel.visible = false
	if win_panel != null: win_panel.visible = false
	if lose_panel != null: lose_panel.visible = false
	if final_victory_panel != null: final_victory_panel.visible = false

	if current_bubble != null and is_instance_valid(current_bubble):
		current_bubble.queue_free()
		current_bubble = null

	var active_level_data: LevelData = null
	if levels.size() > 0 and current_level_index < levels.size():
		active_level_data = levels[current_level_index]

	var bubble_grid = get_tree().current_scene.get_node_or_null("BubbleGrid")
	if bubble_grid != null:
		bubble_grid.load_level(active_level_data)

	if level_label != null:
		if active_level_data != null and active_level_data.level_name != "":
			level_label.text = active_level_data.level_name.to_upper()
		else:
			level_label.text = "LEVEL " + str(current_level_index + 1)

	if score_label != null:
		score_label.text = "Score: " + str(score)

	spawn_current_bubble()
	enable_shooting()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_R:
			restart_game()

func add_score(points: int) -> void:

	score += points

	if score_label != null:
		score_label.text = "Score: " + str(score)

	print("Score: ", score)

func get_random_bubble_type() -> int:
	var bubble_grid = get_tree().current_scene.get_node("BubbleGrid")

	var available_types: Array[int] = []

	for cell in bubble_grid.grid:
		var bubble = bubble_grid.grid[cell]

		if bubble == null:
			continue

		var bubble_type = bubble.bubble_type

		if not available_types.has(bubble_type):
			available_types.append(bubble_type)

	# Safety fallback
	if available_types.is_empty():
		return randi() % BubbleTypes.BubbleType.size()

	return available_types[randi() % available_types.size()]

func spawn_current_bubble() -> void:
	if current_bubble != null and is_instance_valid(current_bubble):
		return

	current_bubble = bubble_scene.instantiate()

	current_bubble.is_attached = false
	current_bubble.speed = bubble_speed

	if next_bubble_type < 0:
		next_bubble_type = get_random_bubble_type()

	var bubble_type = next_bubble_type
	next_bubble_type = get_random_bubble_type()

	current_bubble.set_bubble_type(bubble_type)

	current_bubble.global_position = bubble_spawn_point.global_position

	get_tree().current_scene.add_child(current_bubble)

	update_next_bubble_preview()

	can_shoot = true

	print("New bubble spawned")
	print("Bubble type: ", bubble_type)
	print("Bubble speed: ", bubble_speed)

func shoot_current_bubble(direction: Vector2) -> void:

	if game_state != GameState.PLAYING:
		return

	if not can_shoot:
		print("Cannot shoot right now.")
		return

	if current_bubble == null:
		print("No active bubble.")
		return

	if not is_instance_valid(current_bubble):
		current_bubble = null
		can_shoot = false
		return

	# Lock the shooting system immediately.
	can_shoot = false
	launcher.can_aim = false

	# Launch the current bubble.
	current_bubble.launch(direction)

	print("Bubble launched.")

func get_current_bubble() -> Area2D:

	if (
		current_bubble != null
		and is_instance_valid(current_bubble)
	):
		return current_bubble

	return null

func enable_shooting() -> void:
	can_shoot = true
	launcher.enable_aim()

func is_playing() -> bool:
	return game_state == GameState.PLAYING

func win_game() -> void:
	if game_state != GameState.PLAYING:
		return

	game_state = GameState.WON
	launcher.can_aim = false
	can_shoot = false

	if current_level_index >= levels.size() - 1:
		print("ALL LEVELS COMPLETED! FINAL VICTORY!")
		if final_victory_panel != null:
			if victory_score_label != null:
				victory_score_label.text = "FINAL SCORE: " + str(score)
			final_victory_panel.visible = true
	else:
		print("LEVEL WON!")
		if win_panel != null:
			if win_score_label != null:
				win_score_label.text = "SCORE: " + str(score)
			win_panel.visible = true

func lose_game() -> void:
	if game_state != GameState.PLAYING:
		return

	game_state = GameState.LOST
	launcher.can_aim = false
	can_shoot = false

	print("GAME OVER!")
	if lose_panel != null:
		lose_panel.visible = true

func restart_game() -> void:
	load_active_level()

func _on_pause_pressed() -> void:
	if game_state != GameState.PLAYING:
		return
	get_tree().paused = true
	launcher.can_aim = false
	if pause_panel != null:
		pause_panel.visible = true

func _on_resume_pressed() -> void:
	get_tree().paused = false
	if pause_panel != null:
		pause_panel.visible = false
	if can_shoot:
		launcher.enable_aim()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	if pause_panel != null:
		pause_panel.visible = false
	restart_game()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_next_level_pressed() -> void:
	if win_panel != null:
		win_panel.visible = false
	if current_level_index < levels.size() - 1:
		current_level_index += 1
		selected_level_index = current_level_index
		load_active_level()

func _on_replay_pressed() -> void:
	if win_panel != null:
		win_panel.visible = false
	load_active_level()

func _on_retry_pressed() -> void:
	if lose_panel != null:
		lose_panel.visible = false
	load_active_level()
