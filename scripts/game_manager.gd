extends Node

enum GameState {
	PLAYING,
	WON,
	LOST
}

var game_state = GameState.PLAYING

var score = 0

@onready var score_label = $"../UI/ScoreLabel"
@onready var launcher = $"../Launcher"
@onready var bubble_spawn_point = $"../Launcher/BubbleSpawnPoint"

var bubble_scene: PackedScene
var current_bubble: Area2D

var bubble_speed: float = 600.0
var speed_increase: float = 25.0
var max_bubble_speed: float = 1000.0

var can_shoot := false

func _ready() -> void:

	randomize()

	score_label.text = "Score: 0"
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 32)

	bubble_scene = preload(
		"res://scenes/bubbles/Bubble.tscn"
	)

	call_deferred("start_game")

func start_game() -> void:
	spawn_current_bubble()
	enable_shooting()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_R:
			restart_game()

func add_score(points: int) -> void:

	score += points

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

	var bubble_type = get_random_bubble_type()

	current_bubble.set_bubble_type(bubble_type)

	current_bubble.global_position = bubble_spawn_point.global_position

	get_tree().current_scene.add_child(current_bubble)

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

	print("GAME WON!")

func lose_game() -> void:
	if game_state != GameState.PLAYING:
		return

	game_state = GameState.LOST

	print("GAME OVER!")

func restart_game() -> void:
	get_tree().reload_current_scene()
