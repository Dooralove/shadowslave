shader_type sky;
// Ночное небо горных локаций Первого Кошмара (CANON гл. 2: «яркая луна, бледный свет»).
// Градиент зенит → горизонт, звёзды (гаснут к горизонту), диск луны с ореолом.
// Направление луны задаётся явно (moon_direction — к луне, мировые оси) и совпадает с лучом
// DirectionalLight сцены: так не важно, какой из направленных светов движок назовёт LIGHT0.
// day_mix — дневное небо (видение B14 «дни идут вспять»), 0 — ночь.

uniform vec3 zenith_color : source_color = vec3(0.010, 0.016, 0.036);
uniform vec3 horizon_color : source_color = vec3(0.055, 0.072, 0.11);
uniform vec3 day_zenith : source_color = vec3(0.30, 0.42, 0.62);
uniform vec3 day_horizon : source_color = vec3(0.62, 0.68, 0.76);
uniform float day_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_direction = vec3(-0.35, 0.45, -0.82);
uniform vec3 moon_color : source_color = vec3(0.93, 0.95, 1.0);
uniform float moon_radius : hint_range(0.005, 0.1) = 0.028;
uniform float moon_energy = 3.5;
uniform float halo_energy = 0.18;
uniform float star_density : hint_range(0.0, 1.0) = 0.55;
uniform float star_energy = 2.2;
uniform float below_horizon_dark = 0.6;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float stars(vec3 d) {
	vec3 p = d * 260.0;
	vec3 cell = floor(p);
	float h = hash13(cell);
	if (h < 1.0 - star_density * 0.06) {
		return 0.0;
	}
	vec3 c = cell + 0.5 + (hash33(cell) - 0.5) * 0.7;
	float r = length(p - c);
	float size = mix(0.05, 0.16, hash13(cell + 7.0));
	float tw = 0.75 + 0.25 * sin(TIME * (1.0 + 3.0 * hash13(cell + 3.0)) + h * 40.0);
	return smoothstep(size, 0.0, r) * tw * mix(0.3, 1.0, hash13(cell + 11.0));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, -1.0, 1.0);
	float t = pow(clamp(up, 0.0, 1.0), 0.45);
	vec3 night = mix(horizon_color, zenith_color, t);
	vec3 day = mix(day_horizon, day_zenith, t);
	vec3 col = mix(night, day, day_mix);
	if (up < 0.0) {
		col *= mix(1.0, below_horizon_dark, clamp(-up * 4.0, 0.0, 1.0));
	}
	if (AT_CUBEMAP_PASS) {
		COLOR = col;
	} else {
		float horizon_fade = smoothstep(0.02, 0.25, up);
		col += vec3(0.85, 0.9, 1.0) * stars(d) * star_energy * horizon_fade * (1.0 - day_mix);
		vec3 md = normalize(moon_direction);
		float cosang = dot(d, md);
		float ang = acos(clamp(cosang, -1.0, 1.0));
		float disc = smoothstep(moon_radius, moon_radius * 0.92, ang);
		// Лёгкие «моря» на диске — без текстуры, шум по направлению.
		vec3 q = (d - md) / moon_radius;
		float maria = 0.82 + 0.18 * sin(q.x * 3.1 + q.y * 2.3) * sin(q.y * 2.7 - q.z * 1.9);
		col = mix(col, moon_color * moon_energy * maria, disc * (1.0 - 0.6 * day_mix));
		col += moon_color * halo_energy * exp(-ang / (moon_radius * 4.0)) * (1.0 - day_mix);
		COLOR = col;
	}
}
