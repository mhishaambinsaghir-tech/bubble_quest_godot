extends Node

enum GameState {
	PLAYING,
	WON,
	LOST
}

var game_state = GameState.PLAYING

var score = 0

static var selected_level_index: int = 0
static var highest_unlocked_level: int = 0
static var best_scores: Dictionary = {}

const SAVE_FILE_PATH: String = "user://save_data.json"

static func load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		highest_unlocked_level = 0
		best_scores = {}
		return

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		highest_unlocked_level = 0
		best_scores = {}
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK or not (json.data is Dictionary):
		print("Save file parse error or invalid format. Fallback to default progression.")
		highest_unlocked_level = 0
		best_scores = {}
		return

	var data: Dictionary = json.data
	highest_unlocked_level = int(data.get("highest_unlocked_level", 0))
	best_scores = data.get("best_scores", {})
	print("SAVE DATA LOADED: Highest Unlocked =", highest_unlocked_level, " Best Scores =", best_scores)

static func save_progression() -> void:
	var data = {
		"highest_unlocked_level": highest_unlocked_level,
		"best_scores": best_scores
	}
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("PROGRESSION SAVED TO FILE.")

static func record_level_completion(level_index: int, final_score: int) -> void:
	var str_idx = str(level_index)
	var current_best = int(best_scores.get(str_idx, 0))
	if final_score > current_best:
		best_scores[str_idx] = final_score
		print("NEW BEST SCORE FOR LEVEL ", level_index + 1, ": ", final_score)

	if level_index + 1 > highest_unlocked_level:
		highest_unlocked_level = level_index + 1
		print("UNLOCKED NEXT LEVEL: Index ", highest_unlocked_level)

	save_progression()

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
	load_save_data()

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

func setup_button_animations(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)

	btn.mouse_entered.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	)
	btn.button_down.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		var tw = btn.create_tween()
		var target = Vector2(1.06, 1.06) if btn.is_hovered() else Vector2(1.0, 1.0)
		tw.tween_property(btn, "scale", target, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

func setup_ui() -> void:
	if game_ui != null:
		game_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	var all_buttons = [
		pause_button, resume_button, pause_restart_button, pause_main_menu_button,
		next_level_button, replay_button, retry_button, lose_main_menu_button,
		victory_main_menu_button
	]
	for btn in all_buttons:
		if btn != null:
			setup_button_animations(btn)

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
var next_bubble_preview_node: Sprite2D = null

func update_next_bubble_preview() -> void:
	if launcher == null:
		return
	if next_bubble_preview_node == null or not is_instance_valid(next_bubble_preview_node):
		next_bubble_preview_node = Sprite2D.new()
		next_bubble_preview_node.position = Vector2(-70, 40)
		launcher.add_child(next_bubble_preview_node)

	if next_bubble_type >= 0:
		var tex = BubbleTypes.get_texture(next_bubble_type)
		if tex != null:
			next_bubble_preview_node.texture = tex
			var tex_size = tex.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var scale_factor = 48.0 / max(tex_size.x, tex_size.y)
				next_bubble_preview_node.scale = Vector2(scale_factor, scale_factor)

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

func shoot_current_bubble(direction: Vector2) -> void:

	if game_state != GameState.PLAYING:
		return

	if not can_shoot:
		return

	if current_bubble == null:
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

	record_level_completion(current_level_index, score)

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
