shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform float smoke_strength : hint_range(0.0, 1.0) = 0.0;
uniform float smoke_heat : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float strength = clamp(smoke_strength, 0.0, 1.0);
	float heat = clamp(smoke_heat, 0.0, 1.0);
	vec3 hot_color = vec3(0.92, 0.56, 0.28);
	vec3 cool_color = vec3(0.33, 0.34, 0.36);
	vec3 smoke_color = mix(cool_color, hot_color, heat * 0.78);
	ALBEDO = smoke_color;
	EMISSION = hot_color * heat * strength * 1.1;
	ALPHA = strength * mix(0.18, 0.52, heat);
}
