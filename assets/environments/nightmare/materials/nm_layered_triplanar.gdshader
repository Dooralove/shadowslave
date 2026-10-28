// Природные материалы Первого Кошмара: трипланарный слой + снег сверху + маска вершин.
//
// Используется материалами kind = "layered" из source/nm_materials.py (порода, обработанный
// камень, снег, лёд, чёрный мрамор, кость). UV не нужны: проекция по трём осям в координатах
// объекта с учётом масштаба экземпляра (плотность текселей не зависит от масштаба).
// Цвет вершин (атрибут nm_mask из Blender): RGB — множитель грязи/AO для альбедо,
// A — склонность к снегу (0 — под навесом снег не ложится). Без цветов вершин COLOR = 1.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

group_uniforms base;
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_tint : source_color = vec4(1.0);
// Реальный размер тайла текстуры, м.
uniform float base_tile_m = 2.0;
uniform float base_normal_strength = 1.0;
uniform float base_roughness_scale = 1.0;
uniform float base_roughness_offset = 0.0;
uniform float base_metallic = 0.0;

group_uniforms macro;
// Низкочастотная вариация тона: ломает повтор тайла на больших поверхностях.
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float macro_tile_m = 8.0;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.25;

group_uniforms snow;
uniform bool snow_enabled = true;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 snow_tint : source_color = vec4(1.0);
uniform float snow_tile_m = 2.0;
// Доля обращённых вверх поверхностей под снегом: 0 — нет снега, 1 — почти всё.
uniform float snow_coverage : hint_range(0.0, 1.0) = 0.35;
uniform float snow_softness : hint_range(0.01, 0.5) = 0.12;
uniform float snow_breakup : hint_range(0.0, 1.0) = 0.35;
// Насколько учитывать склонность к снегу из вершин (1 — полностью).
uniform float snow_vertex_weight : hint_range(0.0, 1.0) = 1.0;

group_uniforms mask;
uniform float dirt_strength : hint_range(0.0, 1.0) = 1.0;
uniform float triplanar_sharpness = 6.0;

varying vec3 v_pos;
varying vec3 v_nrm;
varying float v_up;

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_pos = VERTEX * s;
	v_nrm = NORMAL;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(triplanar_sharpness));
	return w / max(w.x + w.y + w.z, 1e-5);
}

// Проекции: X — (z, −y), Y — (x, −z), Z — (x, −y). Минус по V — чтобы «вверх» карты
// нормалей OpenGL совпадал с осью объекта. Две копии выборки: Godot требует одинаковых
// подсказок у сэмплеров, передаваемых в один параметр функции (цвет sRGB и данные).
vec4 tri_color(sampler2D t, vec3 p, vec3 w) {
	return texture(t, vec2(p.z, -p.y)) * w.x + texture(t, vec2(p.x, -p.z)) * w.y + texture(t, vec2(p.x, -p.y)) * w.z;
}

vec4 tri_data(sampler2D t, vec3 p, vec3 w) {
	return texture(t, vec2(p.z, -p.y)) * w.x + texture(t, vec2(p.x, -p.z)) * w.y + texture(t, vec2(p.x, -p.y)) * w.z;
}

vec3 unpack_normal(vec4 c, float k) {
	vec2 xy = (c.xy * 2.0 - 1.0) * k;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

// Смешение нормалей «whiteout» (Ben Golus): касательные карты → нормаль объекта.
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
	albedo *= mix(1.0, 0.7 + 0.6 * macro, macro_strength);
	albedo *= mix(vec3(1.0), COLOR.rgb, dirt_strength);
	float rough = clamp(orm.g * base_roughness_scale + base_roughness_offset, 0.0, 1.0);
	float ao = orm.r;
	float metal = orm.b * base_metallic;
	if (snow_enabled) {
		vec3 ps = v_pos / snow_tile_m;
		vec3 s_alb = tri_color(snow_albedo, ps, w).rgb * snow_tint.rgb;
		vec3 s_orm = tri_data(snow_orm, ps, w).rgb;
		vec3 s_nrm = tri_normal(snow_normal, ps, n, w, 1.0);
		float up = v_up + (macro - 0.5) * snow_breakup;
		float thr = 1.0 - snow_coverage;
		float m = smoothstep(thr - snow_softness, thr + snow_softness, up);
		m *= mix(1.0, COLOR.a, snow_vertex_weight);
		albedo = mix(albedo, s_alb, m);
		rough = mix(rough, s_orm.g, m);
		ao = mix(ao, s_orm.r, m);
		metal = mix(metal, 0.0, m);
		nrm = normalize(mix(nrm, s_nrm, m));
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	vec3 nw = normalize(MODEL_NORMAL_MATRIX * nrm);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
