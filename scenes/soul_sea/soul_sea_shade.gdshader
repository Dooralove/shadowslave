shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Неподвижные тени убитых существ. Почти чёрный силуэт, который выдаёт
// себя только бледным контуром со стороны чёрного солнца.

uniform vec3 shadow_color : source_color = vec3(0.008, 0.01, 0.015);
uniform vec3 rim_color : source_color = vec3(0.18, 0.23, 0.32);
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.28;
uniform float edge_noise : hint_range(0.0, 1.0) = 0.3;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float noise_breakup = mix(1.0, 0.55 + 0.45 * hash12(FRAGCOORD.xy * 0.5), edge_noise);
	ALBEDO = shadow_color;
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	EMISSION = rim_color * rim * rim_strength * noise_breakup;
}
