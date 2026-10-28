shader_type spatial;
render_mode unshaded, cull_disabled;
// Слой облаков в бездне (ART-DIRECTION; спецификация S11: «карниз над облаками»).
// Закрывает дно пропасти и подножия дальних хребтов: вместо пустоты — медленно плывущая
// облачная пелена в лунном свете. Плоскость на сцене, туман окружения гасит её к горизонту.

uniform vec3 shadow_color : source_color = vec3(0.065, 0.08, 0.115);
uniform vec3 lit_color : source_color = vec3(0.30, 0.335, 0.41);
uniform float brightness = 1.0;
uniform float scale = 0.0065;
uniform vec2 wind = vec2(0.6, 0.25);
uniform float coverage : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.01, 1.0) = 0.6;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return v;
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale;
	float base = fbm(p + wind * TIME * 0.004);
	float detail = fbm(p * 3.1 - wind * TIME * 0.007);
	float n = base * 0.75 + detail * 0.25;
	float c = smoothstep(1.0 - coverage - softness * 0.5, 1.0 - coverage + softness * 0.5, n);
	// Валы облаков светлее на гребнях, тёмные «провалы» между ними.
	vec3 col = mix(shadow_color, lit_color, c);
	ALBEDO = col * brightness;
}
