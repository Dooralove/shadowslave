shader_type canvas_item;
// Cuts the SubViewport minimap into a clean circle with a soft edge.
// The bronze compass ring is drawn by HUDMinimap above this texture.

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered);
	float mask = smoothstep(0.5, 0.485, radius);
	COLOR = vec4(tex.rgb, tex.a * mask);
}
