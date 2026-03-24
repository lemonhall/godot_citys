shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_strength : hint_range(0.0, 0.15) = 0.035;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;
uniform float red_hot_strength : hint_range(0.0, 1.0) = 0.72;
uniform float overlay_mode : hint_range(0.0, 1.0) = 0.0;
uniform float signal_loss_strength : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 viewport_size = 1.0 / max(SCREEN_PIXEL_SIZE, vec2(0.0001));
	vec4 source = texture(screen_texture, SCREEN_UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float scanline = sin(SCREEN_UV.y * viewport_size.y * 1.15) * scanline_strength;
	float grain = (hash(SCREEN_UV * viewport_size + TIME) - 0.5) * grain_strength;
	float grayscale = clamp(luminance + scanline + grain, 0.0, 1.0);
	float hot_mask = smoothstep(0.58, 0.96, grayscale);
	vec3 monochrome = vec3(grayscale);
	vec3 tinted = mix(monochrome, vec3(1.0, 0.18, 0.18), hot_mask * red_hot_strength);
	if (overlay_mode < 0.5) {
		COLOR = vec4(tinted, 0.52);
	} else {
		float tear_band = smoothstep(0.0, 0.015, 1.0 - abs(SCREEN_UV.y - fract(TIME * 0.63)));
		float coarse_noise = hash(floor((SCREEN_UV + vec2(TIME * 0.73, TIME * 2.91)) * viewport_size * vec2(0.18, 0.26)));
		float fine_noise = hash(floor((SCREEN_UV.yx + vec2(TIME * 11.0, -TIME * 13.0)) * viewport_size * 1.15));
		float horizontal_glitch = sin((SCREEN_UV.y + TIME * 7.5) * 92.0) * 0.08;
		float rolling_scan = sin((SCREEN_UV.y * viewport_size.y * 0.58) + TIME * 54.0) * 0.12;
		float static_snow = mix(fine_noise, coarse_noise, 0.38);
		float washout = (coarse_noise - 0.5) * 0.28 + horizontal_glitch + tear_band * 0.22;
		vec3 signal_loss_color = vec3(clamp(static_snow + rolling_scan + washout, 0.0, 1.0));
		COLOR = vec4(signal_loss_color, 1.0);
	}
}
