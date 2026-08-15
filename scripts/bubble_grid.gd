extends Node2D

var grid = {}

var bubble_spacing = 64.0

var total_rows = 4
var total_columns = 10

@export var danger_row: int = 7
@export var bubble_scene: PackedScene

func _ready() -> void:
	create_test_grid()

func grid_to_world(cell: Vector2i) -> Vector2:
	var x = cell.y * bubble_spacing
	var y = cell.x * bubble_spacing * 0.866

	if cell.x % 2 == 1:
		x += bubble_spacing / 2

	return Vector2(x, y)

func world_to_grid(world_position: Vector2) -> Vector2i:
	var local_position = to_local(world_position)

	var row = int(
		round(
			local_position.y
			/ (bubble_spacing * 0.866)
		)
	)

	var x_offset = 0.0

	if row % 2 == 1:
		x_offset = bubble_spacing / 2

	var col = int(
		round(
			(local_position.x - x_offset)
			/ bubble_spacing
		)
	)

	return Vector2i(row, col)

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var row = cell.x
	var col = cell.y

	var neighbors: Array[Vector2i] = []

	# Left / Right
	neighbors.append(Vector2i(row, col - 1))
	neighbors.append(Vector2i(row, col + 1))

	if row % 2 == 0:
		neighbors.append(Vector2i(row - 1, col - 1))
		neighbors.append(Vector2i(row - 1, col))

		neighbors.append(Vector2i(row + 1, col - 1))
		neighbors.append(Vector2i(row + 1, col))

	else:
		neighbors.append(Vector2i(row - 1, col))
		neighbors.append(Vector2i(row - 1, col + 1))

		neighbors.append(Vector2i(row + 1, col))
		neighbors.append(Vector2i(row + 1, col + 1))

	return neighbors

func attach_bubble(bubble: Area2D,hit_bubble: Area2D) -> void:

	var hit_cell = world_to_grid(
		hit_bubble.global_position
	)

	var neighbors = get_neighbors(hit_cell)

	var best_cell = Vector2i(-1, -1)
	var best_distance = INF

	for neighbor in neighbors:

		if not grid.has(neighbor):

			var world_position = to_global(
				grid_to_world(neighbor)
			)

			var distance = (
				bubble.global_position
				.distance_to(world_position)
			)

			if distance < best_distance:
				best_distance = distance
				best_cell = neighbor

	if best_cell == Vector2i(-1, -1):
		print("No empty neighboring cell found.")
		return

	# Snap bubble to grid.
	bubble.global_position = to_global(
		grid_to_world(best_cell)
	)

	grid[best_cell] = bubble

	print("Bubble attached to cell: ", best_cell)

	finish_bubble_turn(best_cell)

func attach_bubble_to_ceiling(bubble: Area2D) -> void:

	var best_cell = Vector2i(-1, -1)
	var best_distance = INF

	# Find closest empty cell in top row.
	for col in range(total_columns):

		var candidate = Vector2i(0, col)

		if not grid.has(candidate):

			var world_position = to_global(
				grid_to_world(candidate)
			)

			var distance = (
				bubble.global_position
				.distance_to(world_position)
			)

			if distance < best_distance:
				best_distance = distance
				best_cell = candidate

	if best_cell == Vector2i(-1, -1):
		print("No empty ceiling cell found.")
		return

	# Snap bubble into grid.
	bubble.global_position = to_global(
		grid_to_world(best_cell)
	)

	grid[best_cell] = bubble

	print(
		"Bubble attached to ceiling cell: ",
		best_cell
	)

	finish_bubble_turn(best_cell)

func finish_bubble_turn(cell: Vector2i) -> void:

	var matches = find_matching_bubbles(cell)

	print(
		"Matching bubbles found: ",
		matches.size()
	)

	var game_manager = (
		get_tree()
		.current_scene
		.get_node("GameManager")
	)

	# ------------------------------------------------
	# MATCH CHECK
	# ------------------------------------------------

	if matches.size() >= 3:

		remove_bubbles(matches)

		var floating_count = (
			remove_floating_bubbles()
		)

		var match_score = matches.size() * 10
		var floating_score = floating_count * 20

		var total_score = (
			match_score
			+ floating_score
		)

		game_manager.add_score(total_score)

		print(
			"Matched bubbles: ",
			matches.size()
		)

		print(
			"Floating bubbles: ",
			floating_count
		)

		print(
			"Score gained: ",
			total_score
		)

	else:
		print("No match.")

	# ------------------------------------------------
	# WIN CONDITION
	# ------------------------------------------------

	if is_grid_empty():

		game_manager.win_game()

		game_manager.current_bubble = null

		return

	# ------------------------------------------------
	# LOSE CONDITION
	# ------------------------------------------------

	if has_reached_danger_row():

		game_manager.lose_game()

		game_manager.current_bubble = null

		return

	# ------------------------------------------------
	# FINISH CURRENT SHOT
	# ------------------------------------------------

	game_manager.current_bubble = null

	# ------------------------------------------------
	# SPAWN NEXT BUBBLE
	# ------------------------------------------------

	game_manager.spawn_current_bubble()

	# ------------------------------------------------
	# ENABLE NEXT SHOT
	# ------------------------------------------------

	game_manager.enable_shooting()

func create_test_grid() -> void:

	var test_cells = [
		Vector2i(0, 3),
		Vector2i(0, 4),
		Vector2i(0, 5),

		Vector2i(1, 3),
		Vector2i(1, 4),

		Vector2i(3, 7),
		Vector2i(3, 8),
		Vector2i(4, 7)
	]

	for cell in test_cells:

		var bubble = (
			bubble_scene
			.instantiate()
		)

		bubble.position = grid_to_world(cell)

		bubble.is_attached = true

		add_child(bubble)

		var bubble_type = (
			(cell.x + cell.y)
			% BubbleTypes.BubbleType.size()
		)

		bubble.set_bubble_type(
			bubble_type
		)

		grid[cell] = bubble

func find_matching_bubbles(start_cell: Vector2i) -> Array:

	var matches = []

	var to_check = [
		start_cell
	]

	var checked = {}

	var start_bubble = grid.get(
		start_cell
	)

	if start_bubble == null:
		return matches

	var target_type = (
		start_bubble.bubble_type
	)

	while to_check.size() > 0:

		var current_cell = (
			to_check.pop_back()
		)

		if checked.has(current_cell):
			continue

		checked[current_cell] = true

		if not grid.has(current_cell):
			continue

		var current_bubble = (
			grid[current_cell]
		)

		if current_bubble.bubble_type != target_type:
			continue

		matches.append(
			current_bubble
		)

		var neighbors = (
			get_neighbors(current_cell)
		)

		for neighbor in neighbors:

			if not checked.has(neighbor):
				to_check.append(neighbor)

	return matches

func remove_bubbles(bubbles: Array) -> void:

	for bubble in bubbles:

		var cell = world_to_grid(
			bubble.global_position
		)

		if grid.has(cell):
			grid.erase(cell)

		bubble.queue_free()

func find_ceiling_connected() -> Dictionary:

	var connected = {}

	var to_check = []

	# Start from row 0.
	for col in range(total_columns):

		var cell = Vector2i(0, col)

		if grid.has(cell):
			to_check.append(cell)

	while to_check.size() > 0:

		var current_cell = (
			to_check.pop_back()
		)

		if connected.has(current_cell):
			continue

		if not grid.has(current_cell):
			continue

		connected[current_cell] = true

		var neighbors = (
			get_neighbors(current_cell)
		)

		for neighbor in neighbors:

			if (
				not connected.has(neighbor)
				and grid.has(neighbor)
			):
				to_check.append(neighbor)

	return connected

func remove_floating_bubbles() -> int:

	var connected = (
		find_ceiling_connected()
	)

	var floating = []

	for cell in grid:

		if not connected.has(cell):
			floating.append(cell)

	for cell in floating:

		var bubble = grid[cell]

		grid.erase(cell)

		bubble.queue_free()

	return floating.size()

func is_grid_empty() -> bool:
	return grid.is_empty()

func has_reached_danger_row() -> bool:

	for cell in grid:

		if cell.x >= danger_row:
			return true

	return false
