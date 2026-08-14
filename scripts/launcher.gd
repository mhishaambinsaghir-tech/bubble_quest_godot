extends Node2D

@onready var game_manager = $"../GameManager"

var aim_distance := 300.0

var min_aim_angle := deg_to_rad(-150.0)
var max_aim_angle := deg_to_rad(-30.0)

func get_aim_direction() -> Vector2:
	var mouse_position = get_global_mouse_position()
	var local_mouse_position = to_local(mouse_position)

	var direction = Vector2.ZERO.direction_to(local_mouse_position)

	var angle = direction.angle()
	angle = clamp(angle, min_aim_angle, max_aim_angle)

	return Vector2.from_angle(angle)

func _process(_delta: float) -> void:
	var direction = get_aim_direction()

	var aim_endpoint = direction * aim_distance

	$AimLine.points[1] = aim_endpoint

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			if not game_manager.is_playing():
				print("Game is not active.")
				return

			var direction = get_aim_direction()

			game_manager.shoot_current_bubble(direction)
