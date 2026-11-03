shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// Distant city blocks for the winter academy and the Dark City rim.
// Window grid is generated in world space, so a MultiMesh of unit boxes gets
// believable facades without textures or extra draw calls. Distance haze is
// applied manually because the material opts out of scene fog.

uniform vec3 building_color : source_color = vec3(0.055, 0.065, 0.080);
uniform vec3 window_color : source_color = vec3(1.0, 0.82, 0.55);
uniform float window_density : hint_range(0.0, 1.0) = 0.38;
uniform float window_scale : hint_range(0.5, 12.0) = 3.2;
uniform vec3 haze_color : source_color = vec3(0.42, 0.47, 0.54);
uniform float haze_start = 110.0;
uniform float haze_end = 900.0;
uniform float haze_amount : hint_range(0.0, 1.0) = 0.86;

varying vec3 world_pos;
varying vec3 world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float vertical = 1.0 - abs(n.y);
	vec2 grid = vec2(world_pos.x + world_pos.z, world_pos.y) / max(window_scale, 0.001);
	vec2 cell = floor(grid);
	vec2 f = fract(grid);
	float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.30, f.y) * step(f.y, 0.76);
	float lit = step(1.0 - window_density, hash21(cell));
	// Instance colour is used as variation, not as the only base colour.
	// This keeps the skyline dark even if the backend does not forward the
	// MultiMesh instance colour on a particular platform.
	vec3 base = building_color * (0.70 + COLOR.rgb * 0.60);
	vec3 col = mix(base, window_color, win * lit * vertical * 0.9);
	float dist = distance(world_pos, CAMERA_POSITION_WORLD);
	float haze = smoothstep(haze_start, haze_end, dist) * haze_amount;
	col = mix(col, haze_color, haze);
	ALBEDO = col;
}
