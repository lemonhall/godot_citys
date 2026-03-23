shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float effect_strength : hint_range(0.0, 1.2) = 0.0;
uniform float freshness : hint_range(0.0, 1.0) = 0.0;
uniform vec2 impact_uv = vec2(0.5, 0.5);
uniform float event_token = 0.0;
uniform vec4 blood_tint : source_color = vec4(0.34, 0.02, 0.01, 0.86);

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float blob_mask(vec2 uv, vec2 center, vec2 radii) {
	vec2 delta = (uv - center) / max(radii, vec2(0.001));
	float distance_sq = dot(delta, delta);
	return smoothstep(1.18, 0.32, distance_sq);
}

void fragment() {
	vec2 uv = UV;
	float strength = clamp(effect_strength, 0.0, 1.2);
	if (strength <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		float wetness = mix(0.68, 1.0, freshness);
		vec2 to_impact = uv - impact_uv;
		float impact_distance = length(to_impact);
		float edge_vignette = smoothstep(0.18, 0.92, length((uv - vec2(0.5)) * vec2(1.08, 0.88)));
		float impact_splatter = smoothstep(0.56, 0.08, impact_distance);

		vec2 leading_dir = normalize(to_impact + vec2(0.0001, 0.0001));
		float directional_smear = smoothstep(0.0, 1.0, dot(normalize(impact_uv - vec2(0.5) + vec2(0.0001, 0.0001)), leading_dir) * 0.5 + 0.5);
		float smear = smoothstep(0.44, 0.02, impact_distance + (1.0 - directional_smear) * 0.11);

		float blotches = 0.0;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float seed = hash12(vec2(fi + event_token * 0.17, event_token * 0.11 + 4.0));
			float angle = seed * 6.28318530718;
			float radius = mix(0.08, 0.28, hash12(vec2(seed + 9.0, fi + 12.0)));
			vec2 center = impact_uv + vec2(cos(angle), sin(angle)) * radius;
			center += vec2(
				(seed - 0.5) * 0.08,
				(hash12(vec2(fi + 31.0, seed + 7.0)) - 0.5) * 0.08
			);
			vec2 radii = vec2(
				mix(0.06, 0.13, hash12(vec2(fi + 18.0, seed + 2.0))),
				mix(0.04, 0.11, hash12(vec2(fi + 22.0, seed + 6.0)))
			);
			blotches += blob_mask(uv, center, radii);
		}
		blotches = clamp(blotches, 0.0, 1.6);

		float edge_spray = edge_vignette * smoothstep(0.92, 0.28, abs(dot(normalize(impact_uv - vec2(0.5) + vec2(0.0001, 0.0001)), normalize(uv - vec2(0.5) + vec2(0.0001, 0.0001)))));
		float mist = smoothstep(0.92, 0.24, impact_distance + hash12(uv * 19.0 + event_token) * 0.09);

		float alpha = 0.0;
		alpha += impact_splatter * 0.34;
		alpha += smear * 0.22;
		alpha += blotches * 0.31;
		alpha += edge_spray * 0.24;
		alpha += mist * 0.08;
		alpha = clamp(alpha * strength * wetness, 0.0, 0.88);

		vec3 color = mix(vec3(0.07, 0.0, 0.0), blood_tint.rgb, clamp(alpha * 1.35, 0.0, 1.0));
		COLOR = vec4(color, alpha * blood_tint.a);
	}
}
