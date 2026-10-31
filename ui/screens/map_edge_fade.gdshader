shader_type canvas_item;
// Fades the map picture's top and bottom edges into the dimmed copy behind it (squarer screens).
uniform float fade = 0.0;   // share of the height that fades, 0 = hard edges

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (fade > 0.0) {
		c.a *= smoothstep(0.0, fade, UV.y) * smoothstep(0.0, fade, 1.0 - UV.y);
	}
	COLOR = c;
}
