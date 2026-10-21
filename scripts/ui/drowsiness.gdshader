shader_type canvas_item;
// Сонливость: края кадра темнеют сильнее центра; при 1.0 центр тоже заметно затемнён.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float edge = smoothstep(0.2, 0.75, length(UV - vec2(0.5)));
	float darkness = intensity * mix(0.35, 1.0, edge);
	COLOR = vec4(0.0, 0.0, 0.0, clamp(darkness, 0.0, 1.0));
}
