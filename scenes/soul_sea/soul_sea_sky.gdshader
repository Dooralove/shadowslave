shader_type sky;
// Внутреннее небо Моря Души: почти чёрная бездна без звёзд и одинокое
// чёрное солнце — визуальное прочтение Теневого Ядра. Это художественная
// интерпретация, а не буквальная модель неба из текста.

uniform vec3 zenith_color : source_color = vec3(0.006, 0.009, 0.018);
uniform vec3 horizon_color : source_color = vec3(0.055, 0.075, 0.11);
uniform vec3 nadir_color : source_color = vec3(0.002, 0.003, 0.006);
uniform vec3 sun_direction = vec3(0.0, 0.19, -1.0);
uniform vec3 sun_disc_color : source_color = vec3(0.0006, 0.0008, 0.0014);
uniform vec3 corona_color : source_color = vec3(0.25, 0.34, 0.48);
uniform float sun_radius : hint_range(0.01, 0.30) = 0.082;
uniform float corona_strength : hint_range(0.0, 0.5) = 0.18;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.24;
uniform float horizon_glow : hint_range(0.0, 0.2) = 0.04;

void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = clamp(dir.y, -1.0, 1.0);
	float up = pow(clamp(height, 0.0, 1.0), 0.52);
	vec3 color = mix(horizon_color, zenith_color, up);
	color = mix(nadir_color, color, smoothstep(-0.28, 0.015, height));

	// Едва заметная полоса дымки на горизонте отделяет воду от пустоты.
	float band = exp(-abs(height) * 24.0);
	color += vec3(0.14, 0.19, 0.27) * band * horizon_glow;

	vec3 sun_dir = normalize(sun_direction);
	float angle = acos(clamp(dot(dir, sun_dir), -1.0, 1.0));
	float disc = smoothstep(sun_radius, sun_radius * 0.93, angle);

	// Чёрное солнце не светит: оно читается провалом в небе, тонкой
	// короной и бледным кольцом на границе диска.
	vec3 sky_with_void = mix(color, sun_disc_color, disc);
	float corona = exp(-max(angle - sun_radius, 0.0) / 0.09);
	corona *= smoothstep(sun_radius * 0.86, sun_radius * 1.02, angle);
	float rim = exp(-pow((angle - sun_radius) / 0.01, 2.0));
	sky_with_void += corona_color * corona * corona_strength;
	sky_with_void += corona_color * rim * rim_strength;

	COLOR = sky_with_void;
}
