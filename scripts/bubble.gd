extends Area2D

var bubble_type: int = BubbleTypes.BubbleType.RED

var points = range(0, 32)
var step_size = 360.0 / 32.0
var radius = 32.0
var circle_points = []

var velocity = Vector2.ZERO
var speed: float = 600.0

var is_attached = false

func _ready() -> void:
	print("BUBBLE CREATED: ", global_position)

	# Create temporary circular visual
	for point in points:
		var angle = deg_to_rad(point * step_size)

		var x = cos(angle) * radius
		var y = sin(angle) * radius

		circle_points.append(Vector2(x, y))

	$Visual.polygon = circle_points

	set_bubble_type(bubble_type)

	# Connect signals only if they aren't already connected
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func launch(direction: Vector2) -> void:
	if is_attached:
		return

	velocity = direction * speed

func _physics_process(delta: float) -> void:
	if not is_attached:
		global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	print("BODY HIT: ", body.name)

	# Bounce from walls
	if body.name == "LeftWall" or body.name == "RightWall":
		velocity.x = -velocity.x
		return

	# Attach to ceiling
	if body.name == "Ceiling":
		print("CEILING DETECTED!")

		if is_attached:
			return

		velocity = Vector2.ZERO
		is_attached = true

		var bubble_grid = get_tree().current_scene.get_node("BubbleGrid")

		bubble_grid.attach_bubble_to_ceiling(self)

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("bubble"):
		return

	if is_attached:
		return

	if velocity.length() <= 0.0:
		return

	velocity = Vector2.ZERO
	is_attached = true

	var bubble_grid = get_tree().current_scene.get_node("BubbleGrid")

	bubble_grid.attach_bubble(self, area)

func set_bubble_type(new_type: int) -> void:
	bubble_type = new_type

	$Visual.color = BubbleTypes.get_color(bubble_type)
