shader_type canvas_item;
// Recolours the green slime for other slime kinds: only its green body changes hue (by hue_shift,
// 0..1 = a full turn of the colour wheel); the brown outline, eyes, mouth and pink blush stay.

uniform float hue_shift = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = COLOR;   // the picture times modulate
	vec3 hsv = rgb2hsv(c.rgb);
	// green body: hue 55-150 degrees and clearly coloured (the outline is brown, ~25 degrees)
	float green = smoothstep(0.14, 0.17, hsv.x) * (1.0 - smoothstep(0.40, 0.43, hsv.x)) * smoothstep(0.15, 0.3, hsv.y);
	vec3 shifted = hsv2rgb(vec3(fract(hsv.x + hue_shift), hsv.y, hsv.z));
	COLOR.rgb = mix(c.rgb, shifted, green);
}
