shader_type canvas_item;
// Холод и шум показываются только краями кадра: без полосок и цифр.

uniform float cold : hint_range(0.0, 1.0) = 0.0;
uniform float noise : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cold_tint : source_color = vec4(0.52, 0.66, 0.88, 1.0);
uniform vec4 noise_tint : source_color = vec4(0.62, 0.58, 0.48, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float edge = smoothstep(0.28, 0.72, length(centered));
	float warm_edge = smoothstep(0.40, 0.80, length(centered * vec2(1.0, 1.25)));
	float cold_alpha = edge * cold * 0.58;
	float noise_alpha = warm_edge * noise * 0.18;
	vec3 tint = mix(cold_tint.rgb, noise_tint.rgb, noise * 0.35);
	COLOR = vec4(tint, cold_alpha + noise_alpha);
}
