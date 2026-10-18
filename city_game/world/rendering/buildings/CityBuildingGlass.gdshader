shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Shared storefront / lobby glazing. Vertex color is a linear tint; the sky
// reflection is computed from the view angle so no reflection probe is needed.

uniform vec3 sky_color : source_color = vec3(0.46, 0.60, 0.78);

varying vec3 v_tint;

void vertex() {
	v_tint = COLOR.rgb;
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float grazing = pow(1.0 - ndv, 3.0);
	vec3 reflection = sky_color * (0.28 + 0.80 * grazing);
	vec3 col = mix(v_tint, reflection, clamp(0.06 + 0.80 * grazing, 0.0, 0.82));
	ALBEDO = col;
	ROUGHNESS = 0.06;
	METALLIC = 0.55;
	SPECULAR = 0.7;
}
