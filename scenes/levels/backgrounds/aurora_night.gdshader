shader_type canvas_item;
// World 4's "aurora" night (level 4-9): turns the daytime snow background's far layer (sky + mountains)
// into a night scene and draws slowly waving aurora curtains in it. The aurora only shows where the
// picture is sky (saturated light blue), not on the white snow of the mountains or the clouds.

uniform vec3 night_tint = vec3(0.30, 0.34, 0.62);   // multiplies the picture: dark blue night
uniform float strength = 1.0;                        // aurora brightness
uniform vec3 green = vec3(0.35, 1.0, 0.6);
uniform vec3 teal = vec3(0.25, 0.8, 1.0);
uniform vec3 violet = vec3(0.8, 0.45, 1.0);

// One curtain, like real northern lights: a bright, wavy lower edge at height `edge`, thin vertical
// rays rising from it and fading out over `rise`; the rays shimmer and the edge drifts slowly.
float curtain(vec2 uv, float edge, float rise, float rays, float t) {
	float bottom = edge + 0.04 * sin(uv.x * TAU * 2.0 + t * 0.22) + 0.02 * sin(uv.x * TAU * 5.0 - t * 0.35);
	float above = bottom - uv.y;   // > 0 above the edge
	float glow = above > 0.0 ? exp(-above / rise) : exp(-pow(above / 0.012, 2.0));
	float phase = sin(uv.x * TAU * 3.0 + t * 0.15) * 3.0;
	float ray = 0.5 + 0.5 * sin(uv.x * TAU * rays + phase + t * 0.6);
	ray = 0.35 + 0.65 * ray * ray;
	float breathe = 0.75 + 0.25 * sin(uv.x * TAU + t * 0.3);
	return glow * ray * breathe;
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec2 uv = vec2(UV.x, fract(UV.y));
	// how "sky" this pixel is: light blue sky has much more blue than red; snow and clouds don't
	float sky = smoothstep(0.16, 0.36, pic.b - pic.r) * smoothstep(0.6, 0.2, uv.y);
	float t = TIME;
	float a1 = curtain(uv, 0.36, 0.2, 38.0, t);
	float a2 = curtain(uv + vec2(0.31, 0.0), 0.27, 0.12, 52.0, t * 1.2);
	vec3 aurora = green * a1 + mix(teal, violet, 0.5 + 0.5 * sin(uv.x * TAU * 2.0 + t * 0.2)) * a2 * 0.7;
	vec3 night = pic.rgb * night_tint;
	COLOR = vec4(night + aurora * sky * strength * 0.8, pic.a);
}
