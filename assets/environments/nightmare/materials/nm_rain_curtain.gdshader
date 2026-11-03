shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, unshaded;
// Distant rain curtain for the western storm wall. One large quad instead of
// a particle field; cheap, reads from 200+ m, and does not touch collision.

uniform vec4 rain_color : source_color = vec4(0.34, 0.40, 0.48, 1.0);
uniform vec4 mist_color : source_color = vec4(0.20, 0.25, 0.31, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.38;
uniform float streak_density : hint_range(50.0, 1200.0) = 420.0;
uniform float fall_speed : hint_range(0.0, 8.0) = 2.4;

varying vec2 uv;

void vertex() {
	uv = UV;
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	float column = floor(uv.x * streak_density);
	float h = hash11(column);
	float phase = fract(uv.y * 1.7 - TIME * fall_speed * (0.55 + h * 0.9) + h * 7.0);
	float streak = smoothstep(0.0, 0.20, phase) * smoothstep(0.72, 0.98, phase);
	float column_mask = step(0.45, hash11(column + 3.7));
	float base = mix(0.15, 1.0, smoothstep(0.0, 0.35, uv.y));
	float alpha = (streak * column_mask * 0.75 + 0.10) * opacity * base;
	ALBEDO = mix(mist_color.rgb, rain_color.rgb, streak * column_mask);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
