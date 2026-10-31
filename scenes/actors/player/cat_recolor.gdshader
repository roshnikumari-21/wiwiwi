shader_type canvas_item;
// Cat Shop colours: the kitten's orange patches are repainted in `patch_color`, keeping their
// light and shade. White fur, outlines, eyes, nose, collar and bell stay as drawn.
// `region` (in UV) limits the change to part of a picture, e.g. the kitten inside the hug art.
uniform vec3 patch_color : source_color = vec3(0.93, 0.62, 0.3);
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);   // x, y, width, height

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

void fragment() {
	vec4 tex = COLOR;   // Godot has already put the picture (times modulate) in COLOR
	vec3 hsv = rgb2hsv(tex.rgb);
	// orange fur: hue 15-43 degrees, clearly coloured and not dark (outlines are dark brown)
	float orange = smoothstep(0.035, 0.05, hsv.x) * (1.0 - smoothstep(0.115, 0.13, hsv.x))
		* smoothstep(0.3, 0.42, hsv.y) * smoothstep(0.5, 0.62, hsv.z);
	vec2 inside = step(region.xy, UV) * step(UV, region.xy + region.zw);
	orange *= inside.x * inside.y;
	vec3 painted = clamp(patch_color * (hsv.z / 0.9), 0.0, 1.0);   // 0.9 = the patches' usual brightness
	COLOR.rgb = mix(tex.rgb, painted, orange);
}
