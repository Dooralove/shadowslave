shader_type spatial;
// Лёгкий контур для Inspectable: светится только край силуэта, не заливая объект.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(0.72, 0.86, 1.0, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.0;
uniform float pulse_speed = 2.2;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed);
	ALBEDO = rim_color.rgb;
	ALPHA = clamp(rim * strength * pulse, 0.0, 1.0);
}
