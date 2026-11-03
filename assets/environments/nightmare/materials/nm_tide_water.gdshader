shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Stylised tide water for the Forgotten Shore.
// The plane itself is moved by TideController; this shader only adds
// wave normals, fresnel colour and crest foam. It avoids screen-depth
// reads so it stays cheap on 6 GB laptop GPUs.

uniform vec4 deep_color : source_color = vec4(0.010, 0.016, 0.026, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.055, 0.085, 0.105, 1.0);
uniform vec4 sky_color : source_color = vec4(0.46, 0.50, 0.55, 1.0);
uniform vec4 foam_color : source_color = vec4(0.78, 0.82, 0.84, 1.0);
uniform float wave_strength : hint_range(0.0, 2.0) = 0.38;
uniform float wave_scale : hint_range(0.05, 2.0) = 0.26;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.55;
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.0;
uniform float foam_strength : hint_range(0.0, 1.0) = 0.34;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.16;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float wave_height(vec2 p, float t) {
	float a = sin(p.x * 0.62 + t * 0.9) * cos(p.y * 0.48 - t * 0.7);
	float b = sin((p.x + p.y) * 0.31 - t * 1.3);
	float c = sin(p.x * 0.19 - p.y * 0.23 + t * 0.45);
	return (a * 0.55 + b * 0.30 + c * 0.15) * wave_strength;
}

void fragment() {
	vec2 p = world_pos.xz * wave_scale;
	float t = TIME * wave_speed;
	float e = 0.22;
	float h = wave_height(p, t);
	float hx = wave_height(p + vec2(e, 0.0), t);
	float hz = wave_height(p + vec2(0.0, e), t);
	vec3 wn = normalize(vec3(-(hx - h) / e, 1.0, -(hz - h) / e));
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fres = pow(1.0 - clamp(dot(wn, view_dir), 0.0, 1.0), fresnel_power);

	float crest = smoothstep(0.38, 0.78, h / max(wave_strength, 0.001));
	float ripple = smoothstep(0.66, 0.98, sin(p.x * 2.8 + p.y * 1.9 + TIME * 1.7) * 0.5 + 0.5);
	float foam = crest * ripple * foam_strength;

	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(fres * 1.3 + 0.18, 0.0, 1.0));
	col = mix(col, sky_color.rgb, fres * 0.72);
	col = mix(col, foam_color.rgb, foam);

	ALBEDO = col;
	ROUGHNESS = mix(roughness_base, 0.72, foam);
	METALLIC = 0.0;
	SPECULAR = specular_amount;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
