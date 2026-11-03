shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Мягкая карта тумана: края гаснут, внутри — медленная неоднородность.
// Не отбрасывает тени и не пишет глубину; это VFX-карта, а не геометрия.

uniform vec3 tint : source_color = vec3(0.34, 0.44, 0.58);
uniform float opacity : hint_range(0.0, 1.0) = 0.10;
uniform float edge_softness : hint_range(0.01, 0.5) = 0.38;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.35;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	float edge = smoothstep(0.0, edge_softness, uv.x)
			* smoothstep(1.0, 1.0 - edge_softness, uv.x)
			* smoothstep(0.0, edge_softness, uv.y)
			* smoothstep(1.0, 1.0 - edge_softness, uv.y);
	float n = value_noise(uv * vec2(6.0, 4.0) + vec2(TIME * 0.015, -TIME * 0.010));
	n = 0.55 + 0.45 * n;
	ALBEDO = tint;
	ALPHA = opacity * edge * mix(1.0, n, noise_strength);
}
