class_name BubbleTypes

enum BubbleType {
	RED,
	BLUE,
	GREEN,
	YELLOW,
	PURPLE
}

static func get_color(bubble_type: int) -> Color:
	match bubble_type:
		BubbleType.RED:
			return Color(1.0, 0.0, 0.0)

		BubbleType.BLUE:
			return Color(0.0, 0.4, 1.0)

		BubbleType.GREEN:
			return Color(0.0, 1.0, 0.2)

		BubbleType.YELLOW:
			return Color(1.0, 0.9, 0.0)

		BubbleType.PURPLE:
			return Color(0.7, 0.1, 1.0)

	return Color.WHITE
