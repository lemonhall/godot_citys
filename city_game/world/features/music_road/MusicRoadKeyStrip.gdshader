shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 white_color : source_color = vec4(0.96, 0.95, 0.91, 1.0);
uniform vec4 black_color : source_color = vec4(0.14, 0.15, 0.19, 1.0);
uniform vec4 approach_color : source_color = vec4(0.98, 0.84, 0.38, 1.0);
uniform vec4 active_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform vec4 decay_color : source_color = vec4(0.52, 0.88, 1.0, 1.0);
uniform float key_kind = 0.0;
uniform float phase_index = 0.0;
uniform float phase_strength = 0.0;

varying flat vec4 instance_custom_data;

void vertex() {
	instance_custom_data = INSTANCE_CUSTOM;
}

void fragment() {
	float resolved_key_kind = key_kind;
	float resolved_phase_index = phase_index;
	float resolved_phase_strength = phase_strength;
	if (instance_custom_data.a > 0.5) {
		resolved_key_kind = instance_custom_data.r;
		resolved_phase_index = instance_custom_data.g * 3.0;
		resolved_phase_strength = instance_custom_data.b;
	}
	vec3 base_color = mix(white_color.rgb, black_color.rgb, step(0.5, resolved_key_kind));
	vec3 tint_color = base_color;
	float glow = 0.12 + (1.0 - resolved_key_kind) * 0.1;
	if (resolved_phase_index > 2.5) {
		tint_color = mix(base_color, decay_color.rgb, clamp(resolved_phase_strength, 0.0, 1.0));
		glow = 0.72 * resolved_phase_strength;
	} else if (resolved_phase_index > 1.5) {
		tint_color = mix(base_color, active_color.rgb, 0.95);
		glow = 1.45;
	} else if (resolved_phase_index > 0.5) {
		tint_color = mix(base_color, approach_color.rgb, clamp(resolved_phase_strength, 0.0, 1.0));
		glow = 0.95 * resolved_phase_strength;
	}
	ALBEDO = tint_color;
	EMISSION = tint_color * glow;
	ALPHA = 1.0;
}
