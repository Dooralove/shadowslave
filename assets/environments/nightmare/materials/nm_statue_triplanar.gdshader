// Камень колосса: трипланар, мокрый слой у воды, соль в трещинах, холодный камень.
// COLOR: R — AO/грязь, G — соль/налёт, B — базовая мокрота, A — тёмный шов.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

group_uniforms base;
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform float base_tile_m = 3.6;
uniform float base_normal_strength = 1.2;
uniform float base_roughness_scale = 0.95;
uniform float base_roughness_offset = 0.02;
uniform float base_metallic = 0.0;

group_uniforms macro;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float macro_tile_m = 18.0;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.30;

group_uniforms sea;
// Мировая высота воды: ниже неё камень тёмный и мокрый.
uniform float wet_height = -72.0;
uniform float wet_softness : hint_range(0.1, 12.0) = 4.0;
uniform float wet_strength : hint_range(0.0, 1.0) = 0.55;
// Соль: чем ниже/ближе к воде, тем сильнее; выше salt_fade — сухой камень.
uniform float salt_fade_start = -40.0;
uniform float salt_fade_end = 60.0;
uniform float salt_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec4 salt_color : source_color = vec4(0.55, 0.58, 0.62, 1.0);

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
	albedo *= mix(1.0, 0.72 + 0.56 * macro, macro_strength);

	float wet = 1.0 - smoothstep(wet_height - wet_softness, wet_height + wet_softness, v_world_y);
	wet = clamp(max(wet, COLOR.b), 0.0, 1.0) * wet_strength;
	albedo *= mix(1.0, 0.48, wet);
	float rough = clamp(orm.g * base_roughness_scale + base_roughness_offset, 0.0, 1.0);
	rough = mix(rough, rough * 0.55, wet);

	// Соль: статическая маска из вершин, гаснет выше salt_fade_end.
	float salt = clamp(COLOR.g * salt_strength, 0.0, 1.0);
	salt *= 1.0 - smoothstep(salt_fade_start, salt_fade_end, v_world_y);
	albedo = mix(albedo, salt_color.rgb * (0.7 + 0.3 * macro), salt);
	rough = mix(rough, 0.82, salt * 0.7);

	albedo *= mix(1.0, COLOR.r, dirt_strength);
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = orm.b * base_metallic;
	SPECULAR = mix(0.38, 0.55, wet);
	AO = clamp(orm.r * mix(0.62, 1.0, COLOR.r), 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.4;

	vec3 nw = normalize(MODEL_NORMAL_MATRIX * nrm);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
