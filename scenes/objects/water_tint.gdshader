shader_type canvas_item;
// Recolours the meadow water for other worlds: its blues become a gradient from `deep` (dark parts)
// to `light`, and the brightest bits (wave crests, bubbles) turn into `glint` — e.g. warm sunset
// reflections on the World 2 canal.

uniform vec3 deep : source_color = vec3(0.30, 0.28, 0.52);
uniform vec3 light : source_color = vec3(0.56, 0.54, 0.80);
uniform vec3 glint : source_color = vec3(1.0, 0.82, 0.62);

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(deep, light, smoothstep(0.25, 0.8, lum));
	col = mix(col, glint, smoothstep(0.8, 0.95, lum));
	COLOR.rgb = col;
}
