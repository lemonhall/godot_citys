shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_prepass_alpha;

uniform vec4 blur_color : source_color = vec4(0.78, 0.8, 0.84, 0.5);
uniform float disc_radius = 0.94;
uniform float hub_radius = 0.12;
uniform float edge_softness = 0.08;
uniform float streak_count = 4.0;
uniform float streak_speed = 34.0;
uniform float streak_strength = 0.34;
uniform float ring_glow = 0.18;

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radius = length(centered_uv);
	float inside_disc = 1.0 - step(1.0, radius);
	float disc_mask = 1.0 - smoothstep(disc_radius, disc_radius + edge_softness, radius);
	float hub_mask = smoothstep(hub_radius, hub_radius + edge_softness, radius);
	float angle = atan(centered_uv.y, centered_uv.x);
	float streak_wave = sin(angle * streak_count + TIME * streak_speed) * 0.5 + 0.5;
	float streak_mask = smoothstep(0.18, 1.0, streak_wave);
	float radial_band = smoothstep(hub_radius, 0.34, radius) * (1.0 - smoothstep(0.34, disc_radius, radius));
	float glow_ring = smoothstep(0.46, 0.76, radius) * (1.0 - smoothstep(0.76, 0.96, radius));
	float base_alpha = blur_color.a + 0.08;
	float alpha = inside_disc * disc_mask * hub_mask * (base_alpha + streak_mask * streak_strength * radial_band);

	ALBEDO = blur_color.rgb;
	EMISSION = blur_color.rgb * inside_disc * (0.12 + glow_ring * ring_glow + streak_mask * 0.08);
	ALPHA = alpha;
}
