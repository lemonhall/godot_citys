shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform vec4 ground_color : source_color = vec4(0.12549, 0.333333, 0.168627, 1.0);
uniform vec4 road_color : source_color = vec4(0.16, 0.17, 0.19, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.9, 0.8, 0.5, 1.0);
uniform sampler2D road_mask_texture : filter_linear, repeat_disable;
uniform sampler2D stripe_mask_texture : filter_linear, repeat_disable;
uniform float chunk_size_m = 256.0;

varying vec2 overlay_uv;

void vertex() {
	overlay_uv = VERTEX.xz / max(chunk_size_m, 1.0) + vec2(0.5);
}

void fragment() {
	float road_mask = clamp(texture(road_mask_texture, overlay_uv).r, 0.0, 1.0);
	float stripe_mask = clamp(texture(stripe_mask_texture, overlay_uv).r, 0.0, 1.0);
	float paved = smoothstep(0.08, 0.9, road_mask);
	float stripe = smoothstep(0.12, 0.9, stripe_mask) * paved;
	vec3 base_albedo = mix(ground_color.rgb, road_color.rgb, paved);
	ALBEDO = mix(base_albedo, stripe_color.rgb, stripe);
	ROUGHNESS = mix(1.0, 0.94, paved);
	METALLIC = 0.0;
	SPECULAR = 0.08;
}
