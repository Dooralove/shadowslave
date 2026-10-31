shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 core_color : source_color = vec3(1.0, 0.84, 0.56);
uniform vec3 edge_color : source_color = vec3(0.92, 0.38, 0.14);
uniform vec3 emission_color : source_color = vec3(1.0, 0.55, 0.24);
uniform float energy : hint_range(0.0, 8.0) = 1.8;
uniform float swirl : hint_range(0.0, 1.0) = 0.35;

varying vec3 object_position;

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
	for (int i = 0; i < 3; i++) {
		value += amplitude * value_noise(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	float facing = clamp(dot(normal, view), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);

	vec3 sphere_point = normalize(object_position) * 6.0;
	float filament_a = fbm(sphere_point.xy + vec2(TIME * 0.13, -TIME * 0.09));
	float filament_b = fbm(sphere_point.yz * 1.9 + vec2(-TIME * 0.18, TIME * 0.10));
	float filaments = smoothstep(0.54, 0.78, filament_a) * (0.6 + 0.4 * filament_b);

	vec3 body = mix(edge_color, core_color, pow(facing, 0.55));
	body += emission_color * filaments * swirl * 0.22;

	float highlight = pow(max(dot(normal, normalize(vec3(-0.35, 0.55, 0.75))), 0.0), 20.0);

	ALBEDO = body;
	ROUGHNESS = 0.42;
	METALLIC = 0.0;
	EMISSION = emission_color * energy * (0.22 + 0.78 * pow(facing, 1.35));
	EMISSION += emission_color * filaments * energy * swirl * 0.22;
	EMISSION += core_color * pow(rim, 3.0) * 1.15;
	EMISSION += core_color * highlight * 0.5;
}
