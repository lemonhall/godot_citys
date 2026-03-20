shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled;

instance uniform float flame_length = 1.8;
instance uniform float flame_width = 0.18;
instance uniform float flame_intensity = 1.0;
instance uniform float flame_speed = 1.0;
instance uniform float flame_phase = 0.0;

uniform vec4 flame_outer_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 flame_inner_color : source_color = vec4(1.0, 0.94, 0.72, 1.0);
uniform float noise_scale = 9.0;
uniform float scroll_speed = 6.0;
uniform float flicker_speed = 14.0;

varying float v_tail_alpha;
varying float v_lateral_alpha;
varying vec2 v_uv;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
	float safe_half_length = max(flame_length * 0.5, 0.001);
	float safe_half_width = max(flame_width * 0.5, 0.001);
	v_tail_alpha = clamp((safe_half_length - VERTEX.z) / flame_length, 0.0, 1.0);
	v_lateral_alpha = clamp(abs(VERTEX.x) / safe_half_width, 0.0, 1.0);
	v_uv = UV;
}

void fragment() {
	float tail_factor = v_tail_alpha;
	float nozzle_factor = 1.0 - tail_factor;
	float width_profile = mix(1.08, 0.08, tail_factor);
	vec2 flow_uv = vec2(v_uv.x * noise_scale, tail_factor * noise_scale * 1.8 - TIME * scroll_speed * flame_speed + flame_phase * 7.13);
	float edge_noise = (value_noise(flow_uv) - 0.5) * 0.28;
	float body_mask = 1.0 - smoothstep(width_profile - 0.18 + edge_noise, width_profile + 0.08 + edge_noise, v_lateral_alpha);
	float flicker = 0.86 + 0.14 * sin(TIME * flicker_speed * flame_speed + flame_phase + tail_factor * 16.0);
	float shimmer = 0.92 + 0.08 * sin(TIME * (flicker_speed * 1.7) + flame_phase * 2.3 + v_uv.y * 23.0);
	float axial_fade = pow(max(nozzle_factor, 0.0), 0.34);
	float tail_fade = 1.0 - smoothstep(0.9, 1.0, tail_factor);
	float alpha = clamp(body_mask * axial_fade * tail_fade * flicker * shimmer * flame_intensity, 0.0, 1.0);
	float core_mask = clamp((1.0 - v_lateral_alpha * 1.18) * pow(max(nozzle_factor, 0.0), 0.62), 0.0, 1.0);
	vec3 flame_color = mix(flame_outer_color.rgb, flame_inner_color.rgb, core_mask);
	ALBEDO = flame_color * alpha;
	EMISSION = flame_color * (1.2 + core_mask * 2.0) * flame_intensity;
	ALPHA = alpha;
}
