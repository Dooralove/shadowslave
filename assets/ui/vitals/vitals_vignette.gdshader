shader_type canvas_item;
// Low-health coral vignette. It lives on its own full-screen ColorRect inside
// CombatHud, below the HUD widgets, so it never covers the bar itself.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.52, 0.055, 0.045, 1.0);
uniform vec2 viewport_size = vec2(1600.0, 900.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	// Keep the vignette circular on 16:9 without washing the whole frame red.
	centered.x *= mix(1.0, viewport_size.x / max(viewport_size.y, 1.0), 0.35);
	float radius = length(centered);
	float edge = smoothstep(0.46, 0.82, radius);
	float alpha = edge * intensity * (0.68 + 0.32 * pulse);
	alpha += smoothstep(0.30, 0.72, radius) * intensity * 0.045;
	COLOR = vec4(tint.rgb, clamp(alpha, 0.0, 1.0) * tint.a);
}
