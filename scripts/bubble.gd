extends Area2D

@export var radius: float = 32.0

var bubble_type: int = BubbleTypes.BubbleType.RED

var points = range(0, 32)
var step_size = 360.0 / 32.0

var circle_points = []

var velocity = Vector2.ZERO
var speed: float = 600.0

var is_attached = false

func _ready() -> void:

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

	if body.name == "LeftWall":
		var collision_shape = body.get_node("CollisionShape2D")
		var half_width = collision_shape.shape.size.x / 2.0

		global_position.x = body.global_position.x + half_width + radius
		velocity.x = abs(velocity.x)

	elif body.name == "RightWall":
		var collision_shape = body.get_node("CollisionShape2D")
		var half_width = collision_shape.shape.size.x / 2.0

		global_position.x = body.global_position.x - half_width - radius
		velocity.x = -abs(velocity.x)

	elif body.name == "Ceiling":

		if is_attached:
			return

		var collision_shape = body.get_node("CollisionShape2D")
		var half_height = collision_shape.shape.size.y / 2.0

		global_position.y = body.global_position.y + half_height + radius

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

	var tex = BubbleTypes.get_texture(bubble_type)
	if tex != null and has_node("Visual"):
		$Visual.texture = tex
		var tex_size = tex.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var target_diameter = radius * 2.0
			var scale_factor = target_diameter / max(tex_size.x, tex_size.y)
			$Visual.scale = Vector2(scale_factor, scale_factor)

	var bubble_color = BubbleTypes.get_color(bubble_type)
	if has_node("GPUParticles2D"):
		$GPUParticles2D.modulate = bubble_color

var is_popping: bool = false

func pop() -> void:
	if is_popping:
		return
	is_popping = true
	monitoring = false
	monitorable = false

	if has_node("GPUParticles2D"):
		$GPUParticles2D.emitting = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

func play_attach_feedback() -> void:
	if is_popping or is_falling:
		return
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

var is_falling: bool = false

func fall_and_free() -> void:
	if is_popping or is_falling:
		return
	is_falling = true
	monitoring = false
	monitorable = false

	var random_x = randf_range(-60.0, 60.0)
	var random_rotation = randf_range(-PI, PI)
	var target_pos = global_position + Vector2(random_x, 1400.0)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", random_rotation, 0.7)
	tween.tween_property(self, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
