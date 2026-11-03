// Коралловый материал Забытого берега: трипланар + мокрота/прилив + кончики + SSS.
//
// Отличия от nm_layered_triplanar:
// - нет снега; вместо него мокрый слой и соль;
// - COLOR: R — AO/грязь, G — градиент кончика, B — базовая мокрота, A — мёртвый коралл;
// - мировая высота v_world_y задаёт линию прилива (wet_height), поэтому одна и та же
//   модель выглядит сухой наверху и мокрой у воды без дублей материалов.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

group_uniforms base;
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform float base_tile_m = 1.6;
uniform float base_normal_strength = 1.0;
uniform float base_roughness_scale = 1.0;
uniform float base_roughness_offset = 0.0;
uniform float base_metallic = 0.0;

group_uniforms macro;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float macro_tile_m = 8.0;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.25;

group_uniforms coral;
uniform vec4 tip_color : source_color = vec4(0.72, 0.43, 0.40, 1.0);
uniform float tip_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 dead_color : source_color = vec4(0.42, 0.33, 0.31, 1.0);
uniform float dead_strength : hint_range(0.0, 1.0) = 0.55;
uniform float sss_strength : hint_range(0.0, 1.0) = 0.2;

group_uniforms tide;
uniform float wet_height = -8.0;
uniform float wet_softness : hint_range(0.01, 4.0) = 1.2;
uniform float wet_strength : hint_range(0.0, 1.0) = 0.45;

group_uniforms mask;
uniform float dirt_strength : hint_range(0.0, 1.0) = 1.0;
uniform float triplanar_sharpness = 6.0;

varying vec3 v_pos;
varying vec3 v_nrm;
varying float v_world_y;
varying float v_up;

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_pos = VERTEX * s;
	v_nrm = NORMAL;
	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(triplanar_sharpness));
	return w / max(w.x + w.y + w.z, 1e-5);
}

vec4 tri_color(sampler2D t, vec3 p, vec3 w) {
	return texture(t, vec2(p.z, -p.y)) * w.x + texture(t, vec2(p.x, -p.z)) * w.y
		+ texture(t, vec2(p.x, -p.y)) * w.z;
}

vec4 tri_data(sampler2D t, vec3 p, vec3 w) {
	return texture(t, vec2(p.z, -p.y)) * w.x + texture(t, vec2(p.x, -p.z)) * w.y
		+ texture(t, vec2(p.x, -p.y)) * w.z;
}

vec3 unpack_normal(vec4 c, float k) {
	vec2 xy = (c.xy * 2.0 - 1.0) * k;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

vec3 tri_normal(sampler2D t, vec3 p, vec3 n, vec3 w, float k) {
	vec3 tx = unpack_normal(texture(t, vec2(p.z, -p.y)), k);
	vec3 ty = unpack_normal(texture(t, vec2(p.x, -p.z)), k);
	vec3 tz = unpack_normal(texture(t, vec2(p.x, -p.y)), k);
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 w = tri_weights(n);
	vec3 pb = v_pos / base_tile_m;
	vec3 albedo = tri_color(base_albedo, pb, w).rgb * base_tint.rgb;
	vec3 orm = tri_data(base_orm, pb, w).rgb;
	vec3 nrm = tri_normal(base_normal, pb, n, w, base_normal_strength);
	float macro = tri_data(macro_noise, v_pos / macro_tile_m, w).r;
	albedo *= mix(1.0, 0.70 + 0.60 * macro, macro_strength);

	float tip = clamp(COLOR.g, 0.0, 1.0);
	albedo = mix(albedo, tip_color.rgb * (0.85 + 0.30 * macro), tip * tip_strength);
	float dead = clamp(COLOR.a, 0.0, 1.0) * dead_strength;
	albedo = mix(albedo, dead_color.rgb * (0.65 + 0.45 * macro), dead);

	// Мокрота: линия прилива по мировой высоте + базовый вес из вершин.
	float tide = 1.0 - smoothstep(wet_height - wet_softness, wet_height + wet_softness, v_world_y);
	float wet = clamp(max(COLOR.b, tide) * wet_strength, 0.0, 1.0);
	albedo *= mix(1.0, 0.52, wet);
	albedo *= mix(1.0, COLOR.r, dirt_strength);

	float rough = clamp(orm.g * base_roughness_scale + base_roughness_offset, 0.0, 1.0);
	rough = mix(rough, rough * 0.52, wet);
	float ao = clamp(orm.r * mix(0.70, 1.0, COLOR.r), 0.0, 1.0);
	float metal = orm.b * base_metallic;

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.35, 0.52, wet);
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
	SSS_STRENGTH = sss_strength * (1.0 - wet * 0.55) * smoothstep(0.15, 0.85, tip);

	vec3 nw = normalize(MODEL_NORMAL_MATRIX * nrm);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
