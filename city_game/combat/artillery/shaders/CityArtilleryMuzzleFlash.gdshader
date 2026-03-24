shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.76, 0.34, 0.95);

void fragment() {
	float strength = clamp(flash_strength, 0.0, 1.0);
	ALBEDO = flash_color.rgb;
	EMISSION = flash_color.rgb * (1.4 + strength * 4.6) * strength;
	ALPHA = flash_color.a * strength;
}
