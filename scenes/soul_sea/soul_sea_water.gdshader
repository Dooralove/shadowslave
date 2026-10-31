shader_type spatial;
render_mode unshaded, cull_disabled;
// Стилизованная неподвижная вода Моря Души. Не пытается быть физическим
// отражением: поверхность остаётся почти чёрной, а свет Памяти и горизонт
// дают ей минимальную глубину и направление взгляда.

uniform vec3 deep_color : source_color = vec3(0.055, 0.075, 0.10);
uniform vec3 horizon_color : source_color = vec3(0.16, 0.20, 0.26);
uniform vec3 ripples_color : source_color = vec3(0.38, 0.48, 0.58);
uniform vec3 memory_color : source_color = vec3(0.95, 0.67, 0.35);
uniform vec2 memory_pool_center = vec2(0.0, -0.9);
uniform float memory_pool_strength = 1.0;
uniform float horizon_strength = 0.8;

varying vec3 world_position;
varying vec2 plane_position;

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

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * value_noise(p);
		p = p * 2.03 + vec2(11.7, 5.3);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	plane_position = VERTEX.xz;
}

void fragment() {
	vec2 p = plane_position;
	float slow = TIME * 0.012;
	float broad = fbm(p * 0.075 + vec2(slow * 0.40, slow * 0.17));
	float fine = fbm(p * 0.36 - vec2(slow * 0.65, slow * 0.28));
	float ripple = broad * 0.62 + fine * 0.38;

	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_position);
	float grazing = pow(1.0 - clamp(abs(to_camera.y), 0.0, 1.0), 3.4);

	// Почти чёрная вода: к горизонту появляется холодная дымка, а по
	// поверхности идут еле заметные длинные волны.
	vec3 color = mix(deep_color, horizon_color, grazing * horizon_strength);
	float wave = smoothstep(0.40, 0.80, ripple);
	color += ripples_color * wave * (0.06 + grazing * 0.055);

	// Длинные спокойные гребни: вода должна читаться даже в почти чёрном
	// кадре, но не превращаться в шум или рябь.
	float broad_glint = fbm(vec2(p.x * 0.12, p.y * 0.45) + vec2(slow * 0.18, -slow * 0.10));
	float crest = sin(p.y * 1.15 + broad_glint * 5.0 + p.x * 0.08);
	float line = smoothstep(0.55, 0.97, crest) * smoothstep(0.42, 0.68, broad_glint);
	float near_water = 1.0 - grazing;
	color += ripples_color * line * (0.025 + near_water * 0.055);

	// Тёплый след Памяти: маленький бассейн света у островка и узкая
	// мерцающая дорожка к зрителю. Это не SSR, а осознанно собранный знак.
	float pool_distance = length(p - memory_pool_center);
	float pool = exp(-pool_distance * 1.25) * 0.060;
	pool += exp(-pool_distance * 0.20) * 0.010;
	float streak_mask = smoothstep(-1.3, 0.1, p.y) * smoothstep(8.5, 0.1, p.y);
	float streak = exp(-abs(p.x) * 2.1) * streak_mask;
	float shimmer = 0.58 + 0.42 * smoothstep(0.30, 0.82, ripple);
	color += memory_color * (pool + streak * 0.024) * shimmer * memory_pool_strength;

	// Бледные блики на дальней воде помогают читать глубину без звёзд.
	float far_fleck = smoothstep(3.0, 14.0, length(p)) * smoothstep(0.68, 0.92, fine);
	color += ripples_color * far_fleck * 0.04;

	ALBEDO = color;
}
