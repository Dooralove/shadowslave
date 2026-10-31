shader_type spatial;
render_mode unshaded;
// Городской экран с пейзажем за скамейкой (SECONDARY: «экраны с пейзажами и пропагандой»).
// Процедурная заглушка блок-аута S3.1: тёплое небо, холмы, медленный дрейф, строки развёртки.

// Прямоугольник экрана в координатах меша: x, y левого нижнего угла, ширина, высота.
uniform vec4 rect = vec4(-7.0, 2.05, 8.0, 4.5);
uniform float brightness = 1.0;

varying vec2 screen_uv;

void vertex() {
	// Экран смотрит в сторону −Z, поэтому для зрителя ось X зеркальна.
	screen_uv = vec2((rect.x + rect.z - VERTEX.x) / rect.z, (VERTEX.y - rect.y) / rect.w);
}

float ridge(float x, float freq, float amp, float base) {
	return base + amp * (sin(x * freq) * 0.5 + sin(x * freq * 2.3 + 1.7) * 0.25 + sin(x * freq * 5.1 + 0.4) * 0.1);
}

void fragment() {
	vec2 p = screen_uv;
	float t = TIME * 0.004;
	vec3 color = mix(vec3(0.92, 0.80, 0.64), vec3(0.42, 0.62, 0.90), smoothstep(0.35, 1.0, p.y));
	color += vec3(1.0, 0.88, 0.66) * smoothstep(0.07, 0.0, distance(p, vec2(0.7, 0.6)));
	color = mix(color, vec3(0.52, 0.64, 0.74), step(p.y, ridge(p.x + t, 6.0, 0.08, 0.44)));
	color = mix(color, vec3(0.22, 0.48, 0.24), step(p.y, ridge(p.x * 1.3 + t * 2.0 + 3.0, 4.0, 0.1, 0.28)));
	color *= 0.93 + 0.07 * sin(p.y * 420.0);
	ALBEDO = color * brightness;
}
