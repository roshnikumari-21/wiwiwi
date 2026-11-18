shader_type canvas_item;
// World 5's sunset (5-5, 5-6, 5-10): the daytime far layer turned into a golden evening. Its blue
// sky (saturated light blue) is repainted as a sunset gradient — soft pink-purple at the top, peach,
// then glowing gold at the horizon — keeping the clouds' shading; the dunes and ruins are warmed.

uniform vec3 top = vec3(0.86, 0.56, 0.72);       // pink-purple high up
uniform vec3 middle = vec3(1.0, 0.66, 0.52);     // peach
uniform vec3 horizon = vec3(1.0, 0.84, 0.52);    // gold, where the sun sets
uniform vec3 warm = vec3(1.0, 0.78, 0.62);       // multiplies the land

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec3 c = pic.rgb;
	float y = fract(UV.y);
	float sky = smoothstep(0.12, 0.3, c.b - c.r);            // blue sky (not the white clouds or the sand)
	float cloud = smoothstep(0.82, 0.95, min(c.r, c.b)) * step(y, 0.55);   // white clouds up in the sky
	vec3 grad = y < 0.3 ? mix(top, middle, y / 0.3) : mix(middle, horizon, clamp((y - 0.3) / 0.25, 0.0, 1.0));
	float light = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 painted = grad * (0.75 + 0.35 * light);              // keep a little of the sky's own shading
	vec3 clouds = mix(vec3(1.0, 0.86, 0.8), vec3(1.0, 0.95, 0.88), light) * 1.02;   // clouds lit pink-gold
	vec3 land = c * warm;
	vec3 outc = mix(land, painted, sky);
	outc = mix(outc, clouds, cloud * (1.0 - sky));
	COLOR = vec4(outc, pic.a);
}
