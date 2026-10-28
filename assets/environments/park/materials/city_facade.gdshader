shader_type spatial;
// Фасады квартала у участка (бриф S3, этап S3.4: «модули светлых фасадов со стеклом»; SECONDARY).
// Объёмы блок-аута S3.1 получают сетку этажей и пролётов по мировым координатам: стеклянный
// витраж с импостами и межэтажными поясами (mode 0) или светлая стена с проёмами окон (mode 1).
// Первый этаж — выше и прозрачнее (витрины). Кровля — матовая. Без текстур: только параметры.

uniform int mode : hint_range(0, 1) = 0;
uniform float floor_h = 3.6;
uniform float bay_w = 1.6;
uniform float ground_h = 5.0;
uniform vec3 wall_color : source_color = vec3(0.80, 0.81, 0.82);
uniform vec3 glass_color : source_color = vec3(0.16, 0.22, 0.27);
uniform vec3 frame_color : source_color = vec3(0.56, 0.59, 0.62);
uniform float window_w : hint_range(0.1, 0.95) = 0.62;
uniform float window_h : hint_range(0.1, 0.95) = 0.56;
uniform float glass_variation : hint_range(0.0, 1.0) = 0.35;
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.1;
uniform vec3 lit_color : source_color = vec3(1.0, 0.88, 0.66);
uniform float lit_energy = 0.0;
uniform float roof_dark = 0.7;

varying vec3 wpos;
varying vec3 wnrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnrm);
	if (n.y > 0.7) {
		// Кровля: матовый композит, лёгкая неравномерность.
		float k = 0.92 + 0.08 * hash12(floor(wpos.xz * 0.5));
		ALBEDO = wall_color * roof_dark * k;
		ROUGHNESS = 0.92;
	} else {
		float u = n.x > n.z ? wpos.z : wpos.x;
		float v = wpos.y;
		bool ground = v < ground_h;
		float fh = ground ? ground_h : floor_h;
		float vv = ground ? v : v - ground_h;
		vec2 cell = vec2(floor(u / bay_w), ground ? -1.0 : floor(vv / floor_h));
		vec2 f = vec2(fract(u / bay_w), ground ? v / ground_h : fract(vv / floor_h));
		float rnd = hash12(cell + floor(wpos.xz * 0.02) * 17.0);
		vec3 glass = glass_color * (1.0 - glass_variation * 0.5 + glass_variation * rnd);
		float lit = step(1.0 - lit_ratio, hash12(cell * 1.7 + 3.1)) * (ground ? 0.0 : 1.0);
		if (mode == 0) {
			// Витраж: стекло всюду, тонкие импосты, межэтажный пояс внизу каждого этажа.
			float mull = step(f.x, 0.035) + step(0.965, f.x);
			float band = ground ? step(f.y, 0.04) : step(f.y, 0.16);
			float frame = clamp(mull + band, 0.0, 1.0);
			ALBEDO = mix(glass, frame_color, frame);
			METALLIC = mix(0.55, 0.2, frame);
			ROUGHNESS = mix(0.07, 0.55, frame);
			EMISSION = lit_color * lit * lit_energy * (1.0 - frame);
		} else {
			// Стена с проёмами: окно — стекло в глубине рамы, вокруг — светлый композит.
			float ww = ground ? 0.86 : window_w;
			float wh = ground ? 0.78 : window_h;
			float wx = step(abs(f.x - 0.5), ww * 0.5);
			float wy = step(abs(f.y - (ground ? 0.42 : 0.55)), wh * 0.5);
			float win = wx * wy;
			float rim = (step(abs(f.x - 0.5), ww * 0.5 + 0.03) * step(abs(f.y - (ground ? 0.42 : 0.55)), wh * 0.5 + 0.03)) - win;
			vec3 wall = wall_color * (0.95 + 0.05 * hash12(floor(vec2(u, v) * 0.7)));
			ALBEDO = mix(mix(wall, frame_color, rim), glass, win);
			METALLIC = 0.45 * win;
			ROUGHNESS = mix(0.85, 0.08, win);
			EMISSION = lit_color * lit * lit_energy * win;
		}
	}
}
