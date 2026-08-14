extends Polygon2D

var radius = 24.0
var points = 32


func _ready() -> void:
	var circle_points = PackedVector2Array()

	for point in range(points):
		var angle = deg_to_rad(point * (360.0 / points))

		var x = cos(angle) * radius
		var y = sin(angle) * radius

		circle_points.append(Vector2(x, y))

	polygon = circle_points
