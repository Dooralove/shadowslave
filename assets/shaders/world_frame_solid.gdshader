shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// Flat distant prop silhouette (sea stacks, spires, giant fins).
// A single colour plus a manual haze mix keeps the object readable beyond the
// scene fog without a texture or per-vertex colour stream.

uniform vec4 base_color : source_color = vec4(0.10, 0.12, 0.15, 1.0);
uniform vec4 haze_color : source_color = vec4(0.45, 0.50, 0.56, 1.0);
uniform float haze_mix : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	ALBEDO = mix(base_color.rgb, haze_color.rgb, haze_mix);
}
