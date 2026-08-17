extends Node2D

@onready var game_manager = $"../GameManager"
@onready var left_wall = $"../Playfield/Boundaries/LeftWall"
@onready var right_wall = $"../Playfield/Boundaries/RightWall"
@onready var ceiling = $"../Playfield/Boundaries/Ceiling"
@onready var bubble_grid = $"../BubbleGrid"
@onready var bubble_spawn_point = $"BubbleSpawnPoint"

var can_aim := true

var aim_distance: float = 2000.0

var min_aim_angle: float = deg_to_rad(-150.0)
var max_aim_angle: float = deg_to_rad(-30.0)

const DEFAULT_BUBBLE_RADIUS: float = 32.0
const TRAJECTORY_STEP: float = 4.0
const COLLISION_DISTANCE: float = DEFAULT_BUBBLE_RADIUS * 2.0

func is_vec_invalid(v: Vector2) -> bool:
	return is_nan(v.x) or is_nan(v.y) or is_inf(v.x) or is_inf(v.y)

func get_aim_direction() -> Vector2:
	var mouse_position = get_global_mouse_position()
	var local_mouse_position = to_local(mouse_position)

	if is_vec_invalid(local_mouse_position):
		return Vector2.UP

	var direction = Vector2.ZERO.direction_to(local_mouse_position)

	if direction.length_squared() < 0.0001 or is_vec_invalid(direction):
		direction = Vector2.UP

	var angle = direction.angle()
	angle = clamp(angle, min_aim_angle, max_aim_angle)

	var result = Vector2.from_angle(angle).normalized()
	if is_vec_invalid(result) or result.length_squared() < 0.0001:
		return Vector2.UP

	return result

var anim_time: float = 0.0

func _ready() -> void:
	if has_node("AimLine"):
		$AimLine.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	if has_node("LauncherBase"):
		var base = get_node("LauncherBase") as Sprite2D
		if base != null:
			base.z_index = 1
			if base.texture == null or not base.texture.resource_path.ends_with("launcher_cannon.png"):
				var cannon_tex = load("res://assets/launcher/launcher_cannon.png")
				if cannon_tex != null:
					base.texture = cannon_tex

var current_aim_angle: float = deg_to_rad(-90.0)
var touch_start_pos: Vector2 = Vector2.ZERO
var is_touch_aiming: bool = false
var is_dragging: bool = false
const DEADZONE_SQ: float = 64.0 # 8px deadzone squared

func _process(delta: float) -> void:
	if not can_aim:
		return

	var raw_direction: Vector2 = get_aim_direction()
	var raw_angle: float = raw_direction.angle()

	if is_touch_aiming and is_dragging:
		current_aim_angle = lerp_angle(current_aim_angle, raw_angle, delta * 30.0)
	else:
		current_aim_angle = raw_angle

	current_aim_angle = clamp(current_aim_angle, min_aim_angle, max_aim_angle)
	var direction: Vector2 = Vector2.from_angle(current_aim_angle).normalized()

	update_aim_line(direction)
	animate_aim_effects(delta)

func _input(event: InputEvent) -> void:
	if not can_aim:
		return

	# Ignore inputs already handled by UI controls (like Pause and Swap buttons)
	if get_viewport().is_input_handled():
		return

	# Right-click instantly swaps bubbles on desktop
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		game_manager.swap_bubbles()
		return

	var is_down: bool = false
	var is_up: bool = false
	var event_pos: Vector2 = Vector2.ZERO

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_down = event.pressed
		is_up = not event.pressed
		event_pos = event.position
	elif event is InputEventScreenTouch:
		is_down = event.pressed
		is_up = not event.pressed
		event_pos = event.position
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and is_touch_aiming:
		var pos = event.position
		if touch_start_pos.distance_squared_to(pos) >= DEADZONE_SQ:
			is_dragging = true

	if is_down:
		is_touch_aiming = true
		touch_start_pos = event_pos
		is_dragging = false

	elif is_up:
		if is_touch_aiming:
			is_touch_aiming = false
			is_dragging = false

			current_aim_angle = clamp(current_aim_angle, min_aim_angle, max_aim_angle)
			var direction: Vector2 = Vector2.from_angle(current_aim_angle).normalized()

			can_aim = false
			$AimLine.visible = false
			if has_node("AimArrow"):
				$AimArrow.visible = false
			if has_node("ImpactRing"):
				$ImpactRing.visible = false

			game_manager.shoot_current_bubble(direction)

func enable_aim() -> void:
	can_aim = true
	is_touch_aiming = false
	is_dragging = false
	$AimLine.visible = true
	if has_node("AimArrow"):
		$AimArrow.visible = true
	if has_node("ImpactRing"):
		$ImpactRing.visible = true

func animate_aim_effects(delta: float) -> void:
	anim_time += delta

	if game_manager != null and is_instance_valid(game_manager.current_bubble):
		var b_type = game_manager.current_bubble.bubble_type
		var target_color = BubbleTypes.get_color(b_type)

		var line_color = target_color.lerp(Color(0.3, 0.9, 1.0), 0.55)
		line_color.a = 0.55

		var arrow_color = target_color.lerp(Color(0.4, 0.95, 1.0), 0.35)
		arrow_color.a = 1.0

		if has_node("AimLine"):
			$AimLine.default_color = $AimLine.default_color.lerp(line_color, delta * 8.0)

		if has_node("AimArrow"):
			$AimArrow.modulate = $AimArrow.modulate.lerp(arrow_color, delta * 8.0)

	if has_node("AimArrow") and $AimArrow.visible:
		var pulse = 0.75 + sin(anim_time * 6.0) * 0.06
		$AimArrow.scale = Vector2(pulse, pulse)

	if has_node("ImpactRing") and $ImpactRing.visible:
		$ImpactRing.rotation += delta * 2.5
		var ring_pulse = 1.0 + sin(anim_time * 8.0) * 0.12
		$ImpactRing.scale = Vector2(ring_pulse, ring_pulse)

func update_aim_line(direction: Vector2) -> void:
	if is_vec_invalid(direction) or direction.length_squared() < 0.0001:
		direction = Vector2.UP

	var left_shape = left_wall.get_node("CollisionShape2D")
	var right_shape = right_wall.get_node("CollisionShape2D")
	var ceiling_shape = ceiling.get_node("CollisionShape2D")

	var left_half_width: float = left_shape.shape.size.x / 2.0
	var right_half_width: float = right_shape.shape.size.x / 2.0
	var ceiling_half_height: float = ceiling_shape.shape.size.y / 2.0

	var left_bound_x: float = (
		left_wall.global_position.x
		+ left_half_width
		+ DEFAULT_BUBBLE_RADIUS
	)
	var right_bound_x: float = (
		right_wall.global_position.x
		- right_half_width
		- DEFAULT_BUBBLE_RADIUS
	)
	var ceiling_bound_y: float = (
		ceiling.global_position.y
		+ ceiling_half_height
		+ DEFAULT_BUBBLE_RADIUS
	)

	var line_points: PackedVector2Array = PackedVector2Array()

	var current_start_global: Vector2 = bubble_spawn_point.global_position
	if is_vec_invalid(current_start_global):
		return

	var current_direction: Vector2 = direction.normalized()
	var remaining_distance: float = aim_distance

	line_points.append(to_local(current_start_global))

	const MAX_BOUNCES: int = 5
	const EPSILON: float = 0.001

	for _bounce_idx in range(MAX_BOUNCES + 1):
		if remaining_distance <= EPSILON:
			break

		if is_vec_invalid(current_direction) or current_direction.length_squared() < 0.0001:
			break

		var distance_to_wall: float = INF
		if current_direction.x < -EPSILON:
			distance_to_wall = (
				left_bound_x - current_start_global.x
			) / current_direction.x
		elif current_direction.x > EPSILON:
			distance_to_wall = (
				right_bound_x - current_start_global.x
			) / current_direction.x

		var distance_to_ceiling: float = INF
		if current_direction.y < -EPSILON:
			distance_to_ceiling = (
				ceiling_bound_y - current_start_global.y
			) / current_direction.y

		var distance_to_bubble: float = find_bubble_collision(
			current_start_global,
			current_direction,
			remaining_distance
		)

		var nearest_distance: float = remaining_distance
		var collision_type: String = "none"

		if (
			distance_to_wall > EPSILON
			and distance_to_wall < nearest_distance
		):
			nearest_distance = distance_to_wall
			collision_type = "wall"

		if (
			distance_to_ceiling > EPSILON
			and distance_to_ceiling < nearest_distance
		):
			nearest_distance = distance_to_ceiling
			collision_type = "ceiling"

		if (
			distance_to_bubble > EPSILON
			and distance_to_bubble < nearest_distance
		):
			nearest_distance = distance_to_bubble
			collision_type = "bubble"

		if collision_type == "none":
			var end_global: Vector2 = (
				current_start_global
				+ current_direction * remaining_distance
			)
			line_points.append(to_local(end_global))
			break
		elif collision_type == "bubble" or collision_type == "ceiling":
			var hit_global: Vector2 = (
				current_start_global
				+ current_direction * nearest_distance
			)
			line_points.append(to_local(hit_global))
			break
		elif collision_type == "wall":
			var bounce_global: Vector2 = (
				current_start_global
				+ current_direction * nearest_distance
			)
			line_points.append(to_local(bounce_global))
			remaining_distance -= nearest_distance
			current_start_global = bounce_global
			var bounced_direction: Vector2 = Vector2(
				-current_direction.x,
				current_direction.y
			)
			if bounced_direction.length_squared() < 0.0001 or is_vec_invalid(bounced_direction):
				break
			current_direction = bounced_direction.normalized()

	$AimLine.points = line_points

	if has_node("AimArrow"):
		var arrow = $AimArrow
		if line_points.size() >= 2:
			var end_pos = line_points[line_points.size() - 1]
			var prev_pos = line_points[line_points.size() - 2]
			var final_dir = (end_pos - prev_pos).normalized()

			arrow.position = end_pos
			arrow.rotation = final_dir.angle() + PI / 2.0
			arrow.visible = can_aim
		else:
			arrow.visible = false

	if has_node("ImpactRing"):
		var impact = $ImpactRing
		if line_points.size() >= 1:
			impact.position = line_points[line_points.size() - 1]
			impact.visible = can_aim
		else:
			impact.visible = false

func find_bubble_collision(
	start_position: Vector2,
	direction: Vector2,
	max_distance: float
) -> float:

	var closest_distance: float = INF

	if (
		bubble_grid == null
		or bubble_grid.grid == null
		or bubble_grid.grid.is_empty()
		or max_distance <= 0.001
		or is_vec_invalid(start_position)
		or is_vec_invalid(direction)
	):
		return closest_distance

	var normalized_direction: Vector2 = direction.normalized()
	if is_vec_invalid(normalized_direction) or normalized_direction.length_squared() < 0.0001:
		return closest_distance

	var collision_radius_squared: float = (
		COLLISION_DISTANCE * COLLISION_DISTANCE
	)
	const TANGENT_TOLERANCE: float = 0.00001
	const MIN_CONTACT_DIST: float = 0.001

	for cell in bubble_grid.grid:
		var bubble = bubble_grid.grid[cell]

		if (
			bubble == null
			or not is_instance_valid(bubble)
			or bubble.is_queued_for_deletion()
		):
			continue

		var bubble_position: Vector2 = bubble.global_position
		if is_vec_invalid(bubble_position):
			continue

		var relative_position: Vector2 = bubble_position - start_position

		var projection: float = relative_position.dot(normalized_direction)

		if projection <= 0.0:
			continue

		if projection > max_distance:
			continue

		var dist_sq: float = relative_position.length_squared()
		var perpendicular_distance_squared: float = max(
			0.0,
			dist_sq - projection * projection
		)

		if perpendicular_distance_squared > collision_radius_squared + TANGENT_TOLERANCE:
			continue

		var offset_squared: float = max(
			0.0,
			collision_radius_squared - perpendicular_distance_squared
		)

		var offset: float = sqrt(offset_squared)

		var collision_distance: float = projection - offset

		if collision_distance < MIN_CONTACT_DIST or collision_distance > max_distance:
			continue

		if collision_distance < closest_distance:
			closest_distance = collision_distance

	return closest_distance
