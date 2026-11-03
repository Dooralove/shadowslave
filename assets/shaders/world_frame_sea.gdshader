shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// Cheap far-sea plane. It carries the colour from the playable water edge to
// the horizon, so a 5 km plane does not shimmer with near-field wave normals.

uniform vec4 near_color : source_color = vec4(0.02, 0.03, 0.045, 1.0);
uniform vec4 far_color : source_color = vec4(0.30, 0.34, 0.38, 1.0);
uniform float fade_start = 180.0;
uniform float fade_end = 1600.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = distance(world_pos, CAMERA_POSITION_WORLD);
	float t = smoothstep(fade_start, fade_end, dist);
	ALBEDO = mix(near_color.rgb, far_color.rgb, t);
}
