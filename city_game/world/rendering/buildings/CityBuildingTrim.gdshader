shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Shared trim / prop material for procedurally generated buildings.
// Instance custom data carries linear RGB albedo in .rgb and an emissive
// mask in .a (>= 0.35 means "self lit": signage, aviation lights).

varying vec4 v_data;
varying vec3 v_world_normal;
varying vec3 v_world_position;

uniform sampler2D detail_texture : filter_linear, repeat_enable;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_data = INSTANCE_CUSTOM;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 albedo = v_data.rgb;

	// Concrete / metal grain, faded out with distance to avoid shimmer.
	float distance_to_camera = length(CAMERA_POSITION_WORLD - v_world_position);
	float grain_fade = 1.0 - smoothstep(24.0, 90.0, distance_to_camera);
	vec2 grain_uv = vec2(v_world_position.x + v_world_position.z, v_world_position.y) * 0.045;
	float blotch = texture(detail_texture, grain_uv).r;
	float grain = texture(detail_texture, grain_uv * 4.0).r;
	albedo *= mix(1.0, 0.80 + 0.36 * blotch + 0.10 * (grain - 0.5), grain_fade);
	// Ground-level dirt gradient.
	albedo *= mix(0.86, 1.04, smoothstep(0.0, 14.0, v_world_position.y));

	ALBEDO = albedo;
	ROUGHNESS = 0.68;
	METALLIC = 0.16;
	SPECULAR = 0.5;

	// Cheap hemispheric bounce so downward cornice undersides read as shade
	// instead of dead black, and upward faces pick up the sky tint.
	float up = clamp(v_world_normal.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 bounce = mix(vec3(0.075, 0.070, 0.062), vec3(0.115, 0.145, 0.185), up);
	EMISSION = albedo * 0.08 + bounce * 0.55 + albedo * step(0.35, v_data.a) * 2.6;
}
