shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;

instance uniform float trace_length = 5.6;
instance uniform float trace_width = 0.14;
instance uniform float trace_alpha = 1.0;
instance uniform float trace_phase = 0.0;

uniform vec4 smoke_outer_color : source_color = vec4(0.76, 0.75, 0.72, 1.0);
uniform vec4 smoke_inner_color : source_color = vec4(0.96, 0.93, 0.86, 1.0);
uniform float noise_scale = 5.2;
uniform float scroll_speed = 1.45;
uniform float flicker_speed = 7.5;

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
	float safe_half_length = max(trace_length * 0.5, 0.001);
	float safe_half_width = max(trace_width * 0.5, 0.001);
	v_tail_alpha = clamp((safe_half_length - VERTEX.z) / trace_length, 0.0, 1.0);
	v_lateral_alpha = clamp(abs(VERTEX.x) / safe_half_width, 0.0, 1.0);
	v_uv = UV;
}

void fragment() {
	float tail_factor = v_tail_alpha;
	float head_factor = 1.0 - tail_factor;
	float width_profile = mix(1.04, 0.18, tail_factor);
	vec2 flow_uv = vec2(v_uv.x * noise_scale, tail_factor * noise_scale * 1.65 - TIME * scroll_speed + trace_phase * 5.31);
	float edge_noise = (value_noise(flow_uv) - 0.5) * 0.32;
	float body_mask = 1.0 - smoothstep(width_profile - 0.26 + edge_noise, width_profile + 0.1 + edge_noise, v_lateral_alpha);
	float flicker = 0.88 + 0.12 * sin(TIME * flicker_speed + trace_phase + tail_factor * 11.0);
	float shimmer = 0.9 + 0.1 * sin(TIME * (flicker_speed * 1.7) + trace_phase * 2.0 + v_uv.y * 19.0);
	float axial_alpha = pow(max(head_factor, 0.0), 0.52);
	float tail_fade = 1.0 - smoothstep(0.84, 1.0, tail_factor);
	float alpha = clamp(body_mask * axial_alpha * tail_fade * flicker * shimmer * trace_alpha, 0.0, 1.0);
	float head_glow = smoothstep(0.0, 0.34, head_factor);
	float core_mask = clamp((1.0 - v_lateral_alpha * 1.12) * pow(max(head_factor, 0.0), 0.74), 0.0, 1.0);
	vec3 smoke_color = mix(smoke_outer_color.rgb, smoke_inner_color.rgb, core_mask);
	ALBEDO = smoke_color;
	EMISSION = smoke_color * head_glow * 0.65 * trace_alpha;
	ALPHA = alpha * 0.78;
}
