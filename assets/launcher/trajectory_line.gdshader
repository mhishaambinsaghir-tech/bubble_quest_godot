shader_type canvas_item;

uniform float scroll_speed : hint_range(0.5, 10.0) = 2.5;

void fragment() {
	vec2 uvs = UV;
	uvs.x += TIME * scroll_speed;
	vec4 tex_color = texture(TEXTURE, uvs);
	COLOR = tex_color * COLOR;
}
