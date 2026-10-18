shader_type spatial;
render_mode depth_draw_opaque, cull_back;

// v62 ground surface: mottled grass / dirt shoulders / asphalt with grain,
// driven by the per-chunk road + stripe mask textures.

uniform vec4 ground_color : source_color = vec4(0.21, 0.29, 0.16, 1.0);
uniform vec4 road_color : source_color = vec4(0.12, 0.13, 0.14, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.82, 0.80, 0.72, 1.0);
uniform sampler2D road_mask_texture : filter_linear, repeat_disable;
uniform sampler2D stripe_mask_texture : filter_linear, repeat_disable;
uniform sampler2D detail_texture : filter_linear, repeat_enable;
uniform bool stripe_enabled = true;
uniform float chunk_size_m = 256.0;
uniform vec2 surface_uv_offset = vec2(0.0, 0.0);
uniform vec2 surface_uv_scale = vec2(1.0, 1.0);
uniform vec2 chunk_center_world = vec2(0.0, 0.0);

varying vec2 overlay_uv;
varying vec2 world_xz;

void vertex() {
	overlay_uv = VERTEX.xz / max(chunk_size_m, 1.0) + vec2(0.5);
	world_xz = chunk_center_world + VERTEX.xz;
}

void fragment() {
	vec2 surface_uv = surface_uv_offset + overlay_uv * surface_uv_scale;
	float road_mask = clamp(texture(road_mask_texture, surface_uv).r, 0.0, 1.0);
	float stripe_mask = stripe_enabled ? clamp(texture(stripe_mask_texture, surface_uv).r, 0.0, 1.0) : 0.0;
	float paved = smoothstep(0.08, 0.90, road_mask);
	float stripe = smoothstep(0.12, 0.90, stripe_mask) * paved;

	// Multi-scale surface variation.
	float patch = texture(detail_texture, world_xz * 0.0026 + vec2(0.11, 0.43)).r;
	float patch_mid = texture(detail_texture, world_xz * 0.018 + vec2(0.37, 0.11)).r;
	float grain = texture(detail_texture, world_xz * 0.11 + vec2(0.13, 0.71)).r;

	// Grass: desaturated urban lawn with broad dry/dirt patches.
	vec3 grass = ground_color.rgb * mix(0.45, 1.35, patch);
	grass = mix(grass, vec3(0.19, 0.17, 0.105), smoothstep(0.42, 0.86, patch_mid) * 0.55);
	grass *= 0.82 + 0.28 * grain;
	float shoulder = paved * (1.0 - paved) * 4.0;
	grass = mix(grass, vec3(0.16, 0.14, 0.09), clamp(shoulder, 0.0, 1.0) * 0.6);

	// Asphalt: cool dark grey with aggregate grain and tar patches.
	vec3 asphalt = road_color.rgb * mix(0.90, 1.35, grain);
	asphalt = mix(asphalt, road_color.rgb * 1.8, smoothstep(0.72, 0.98, patch_mid) * 0.35);

	vec3 col = mix(grass, asphalt, paved);

	// Worn lane paint.
	float paint_wear = smoothstep(0.10, 0.45, stripe_mask) * (0.72 + 0.28 * grain);
	col = mix(col, stripe_color.rgb * (0.80 + 0.25 * grain), stripe * paint_wear);

	ALBEDO = col;
	ROUGHNESS = mix(0.96, 0.80, paved);
	METALLIC = 0.0;
	SPECULAR = 0.08;
}
