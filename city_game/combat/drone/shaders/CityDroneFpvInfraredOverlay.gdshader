shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_strength : hint_range(0.0, 0.15) = 0.035;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;
uniform float red_hot_strength : hint_range(0.0, 1.0) = 0.72;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec2 viewport_size = 1.0 / max(SCREEN_PIXEL_SIZE, vec2(0.0001));
	float scanline = sin(SCREEN_UV.y * viewport_size.y * 1.15) * scanline_strength;
	float grain = (hash(SCREEN_UV * viewport_size + TIME) - 0.5) * grain_strength;
	float grayscale = clamp(luminance + scanline + grain, 0.0, 1.0);
	float hot_mask = smoothstep(0.58, 0.96, grayscale);
	vec3 monochrome = vec3(grayscale);
	vec3 tinted = mix(monochrome, vec3(1.0, 0.18, 0.18), hot_mask * red_hot_strength);
	COLOR = vec4(tinted, 0.52);
}
