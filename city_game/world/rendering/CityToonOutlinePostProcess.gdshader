shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.02, 0.025, 0.035, 0.74);
uniform float depth_threshold = 0.018;
uniform float normal_threshold = 0.42;
uniform float normal_smoothing = 0.18;
uniform float max_thickness = 1.45;
uniform float min_thickness = 0.45;
uniform float max_distance = 180.0;
uniform float min_distance = 4.0;
uniform float grazing_fresnel_power = 5.0;
uniform float grazing_angle_mask_power = 1.0;
uniform float grazing_angle_modulation_factor = 42.0;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);

float sample_depth(vec2 uv) {
	return texture(depth_texture, uv).r;
}

void fragment() {
	vec2 pixel = 1.0 / max(viewport_size, vec2(1.0));
	float center_depth = sample_depth(SCREEN_UV);
	float distance_factor = smoothstep(min_distance, max_distance, center_depth * max_distance);
	float thickness = mix(max_thickness, min_thickness, distance_factor);
	vec2 offset = pixel * thickness;

	float depth_l = sample_depth(SCREEN_UV + vec2(-offset.x, 0.0));
	float depth_r = sample_depth(SCREEN_UV + vec2(offset.x, 0.0));
	float depth_u = sample_depth(SCREEN_UV + vec2(0.0, -offset.y));
	float depth_d = sample_depth(SCREEN_UV + vec2(0.0, offset.y));

	float depth_delta = max(abs(center_depth - depth_l), abs(center_depth - depth_r));
	depth_delta = max(depth_delta, abs(center_depth - depth_u));
	depth_delta = max(depth_delta, abs(center_depth - depth_d));

	vec2 gradient = vec2(depth_r - depth_l, depth_d - depth_u);
	float normalish = smoothstep(normal_threshold - normal_smoothing, normal_threshold + normal_smoothing, length(gradient) * grazing_angle_modulation_factor);
	float depth_edge = smoothstep(depth_threshold * 0.35, depth_threshold, depth_delta);
	float grazing = pow(clamp(length(gradient) * grazing_angle_modulation_factor, 0.0, 1.0), grazing_fresnel_power);
	float edge = max(depth_edge, max(normalish, grazing * grazing_angle_mask_power));

	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * edge;
}
