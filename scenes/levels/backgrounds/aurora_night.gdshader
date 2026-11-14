shader_type canvas_item;
// World 4's "aurora" night (level 4-9): the far layer is the owners' painted night picture
// (bg_far_night.png: moon, aurora behind the peaks). This only makes its aurora feel alive: the
// green / teal / violet aurora colours slowly ripple brighter and dimmer along the curtains.
// The moon, the snow and the mountains are left exactly as painted.

uniform float strength = 0.22;   // how much the aurora brightens / dims at most

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec3 c = pic.rgb;
	// aurora colours: clearly green (more green than red and blue) or clearly violet (red + blue, low green)
	float green = smoothstep(0.08, 0.25, c.g - max(c.r, c.b * 0.85));
	float violet = smoothstep(0.08, 0.22, min(c.r, c.b) - c.g) * step(0.3, c.b);
	float aurora = max(green, violet);
	float x = UV.x * TAU;
	float ripple = sin(x * 9.0 + TIME * 0.7 + sin(x * 2.0 + TIME * 0.25) * 2.5)
		* (0.6 + 0.4 * sin(x * 3.0 - TIME * 0.4));
	COLOR = vec4(c * (1.0 + aurora * ripple * strength), pic.a);
}
