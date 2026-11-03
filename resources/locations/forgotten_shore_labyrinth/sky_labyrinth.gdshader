shader_type sky;
render_mode use_debanding;
// Pale, overcast reef sky with a soft cloud deck and a low sun glow.
// Replaces the flat ProceduralSkyMaterial so the horizon, ambient colour and
// distant silhouettes share one palette.

uniform vec3 sky_top : source_color = vec3(0.30, 0.36, 0.44);
uniform vec3 sky_horizon : source_color = vec3(0.64, 0.65, 0.64);
uniform vec3 ground_color : source_color = vec3(0.22, 0.21, 0.20);
uniform vec3 cloud_color : source_color = vec3(0.69, 0.70, 0.71);
uniform vec3 sun_color : source_color = vec3(1.0, 0.93, 0.82);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_scale : hint_range(0.1, 4.0) = 1.15;
uniform float cloud_speed : hint_range(0.0, 0.05) = 0.004;
uniform float sun_energy : hint_range(0.0, 4.0) = 1.6;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * noise2(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.52;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon, sky_top, pow(up, 0.48));

	float sun_dot = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	// Broad atmospheric glow plus a small, soft disc.
	col += LIGHT0_COLOR * pow(sun_dot, 14.0) * 0.09;
	col += sun_color * pow(sun_dot, 1800.0) * sun_energy;

	if (dir.y > 0.002) {
		vec2 uv = dir.xz / (dir.y + 0.14) * cloud_scale;
		uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.55);
		float n = fbm(uv + fbm(uv * 0.7) * 0.8);
		float cover = smoothstep(0.58 - cloud_cover * 0.28, 0.82, n);
		float horizon_fade = smoothstep(0.02, 0.30, dir.y);
		col = mix(col, cloud_color, cover * horizon_fade * 0.82);
	} else {
		col = mix(sky_horizon, ground_color, clamp(-dir.y * 5.0, 0.0, 1.0));
	}
	COLOR = col;
}
