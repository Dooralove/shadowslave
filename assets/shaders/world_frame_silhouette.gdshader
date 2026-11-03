shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// Distant ridge / reef silhouettes.
// Colour is authored per vertex: horizon haze at the base, ridge tone at the
// top. Fog is disabled so the ring stays readable past the depth-fog end, and
// the baked vertex gradient supplies the atmospheric perspective instead.

void fragment() {
	ALBEDO = COLOR.rgb;
}
