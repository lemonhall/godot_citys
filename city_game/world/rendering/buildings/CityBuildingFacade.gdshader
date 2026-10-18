shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural building facade for the v62 city visual language.
// UV is authored in "facade module" units: one unit == one window bay on X
// and one floor on Y, so window cells stay square-ish at any building size.

uniform vec4 wall_color : source_color = vec4(0.44, 0.45, 0.47, 1.0);
uniform vec4 trim_color : source_color = vec4(0.16, 0.17, 0.19, 1.0);
uniform vec4 glass_color : source_color = vec4(0.035, 0.055, 0.075, 1.0);
uniform vec3 sky_color : source_color = vec3(0.56, 0.72, 0.94);
uniform float facade_style = 0.0;
uniform float detail_seed = 0.0;
uniform float lit_ratio = 0.26;
uniform float grime = 0.45;
uniform sampler2D detail_texture : filter_linear, repeat_enable;
uniform sampler2D facade_atlas : filter_linear, repeat_enable;

varying vec3 v_ao;
varying vec2 v_grid;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float rect_mask(vec2 f, vec2 lo, vec2 hi, float aa) {
	float mx = smoothstep(lo.x - aa, lo.x + aa, f.x) * (1.0 - smoothstep(hi.x - aa, hi.x + aa, f.x));
	float my = smoothstep(lo.y - aa, lo.y + aa, f.y) * (1.0 - smoothstep(hi.y - aa, hi.y + aa, f.y));
	return mx * my;
}

void vertex() {
	v_ao = COLOR.rgb;
	v_grid = UV;
}

void fragment() {
	vec2 grid = v_grid;
	vec2 cell = floor(grid);
	vec2 f = fract(grid);
	float aa = clamp(max(fwidth(grid.x), fwidth(grid.y)) * 1.15, 0.004, 0.30);

	float r_cell = hash12(cell + vec2(detail_seed * 3.71, detail_seed * 1.93));
	float r_panel = hash12(cell * 1.37 + vec2(5.3, detail_seed * 2.17));
	float r_blind = hash12(cell * 2.11 + vec2(9.1, 4.7));

	// Per-style window rectangle.
	vec2 lo = vec2(0.14, 0.24);
	vec2 hi = vec2(0.86, 0.82);
	float spandrel_band = 0.0;
	float vertical_ribs = 0.0;
	float mullion_count = 0.0;

	if (facade_style < 0.5) {
		lo = vec2(0.15, 0.25);
		hi = vec2(0.85, 0.81);
	} else if (facade_style < 1.5) {
		lo = vec2(0.015, 0.33);
		hi = vec2(0.985, 0.83);
		spandrel_band = 0.14;
		mullion_count = 1.0;
	} else if (facade_style < 2.5) {
		lo = vec2(0.01, 0.06);
		hi = vec2(0.99, 0.985);
		spandrel_band = 0.12;
		mullion_count = 1.0;
	} else if (facade_style < 3.5) {
		lo = vec2(0.20, 0.27);
		hi = vec2(0.80, 0.80);
	} else if (facade_style < 4.5) {
		lo = vec2(0.17, 0.27);
		hi = vec2(0.83, 0.80);
	} else if (facade_style < 5.5) {
		lo = vec2(0.02, 0.10);
		hi = vec2(0.98, 0.92);
		mullion_count = 1.0;
	} else {
		lo = vec2(0.03, 0.58);
		hi = vec2(0.97, 0.86);
		spandrel_band = 0.32;
		vertical_ribs = 1.0;
	}

	float glass = rect_mask(f, lo, hi, aa);
	float outer = rect_mask(f, lo - vec2(0.030, 0.028), hi + vec2(0.030, 0.028), aa);
	float frame = clamp(outer - glass, 0.0, 1.0);

	// Mullion inside wide windows (ribbon / curtain wall / industrial strip).
	if (mullion_count > 0.5) {
		float mullion_x = 1.0 - smoothstep(0.005, 0.011 + aa, abs(f.x - 0.5));
		float inside_x = smoothstep(lo.x - aa, lo.x + aa, f.x) * (1.0 - smoothstep(hi.x - aa, hi.x + aa, f.x));
		float inside_y = smoothstep(lo.y - aa, lo.y + aa, f.y) * (1.0 - smoothstep(hi.y - aa, hi.y + aa, f.y));
		float mullion = mullion_x * inside_x * inside_y;
		glass *= 1.0 - mullion;
		frame = max(frame, mullion);
	}

	// Masonry wall: subtle per-cell tone, floor joint and vertical grime.
	vec3 wall = wall_color.rgb * v_ao * 0.72;
	wall *= 0.90 + 0.18 * r_cell;
	float blotch = texture(detail_texture, grid * 0.13).r;
	float grain = texture(detail_texture, grid * 0.61).r;
	// Material atlas: concrete / brick / stone / metal, selected by facade style.
	float tile_index = 0.0;
	if (facade_style > 3.5 && facade_style < 4.5) {
		tile_index = 1.0;
	} else if (facade_style > 2.5 && facade_style < 3.5) {
		tile_index = 2.0;
	} else if (facade_style > 5.5) {
		tile_index = 3.0;
	}
	vec2 tile = vec2(mod(tile_index, 2.0), floor(tile_index * 0.5));
	vec2 atlas_uv = (tile + fract(grid * 0.45)) * 0.5;
	float material_pattern = texture(facade_atlas, atlas_uv).r;
	wall *= 0.80 + 0.38 * material_pattern;
	wall *= 0.80 + 0.34 * blotch + 0.14 * (grain - 0.5);
	float joint = smoothstep(0.0, 0.010 + aa, f.y) * (1.0 - smoothstep(0.010, 0.030 + aa, f.y));
	wall *= 1.0 - 0.20 * joint;
	wall *= 1.0 - grime * 0.12 * smoothstep(0.70, 1.0, fract(grid.x * 5.0 + detail_seed * 0.37));

	// Stone ashlar courses / brick bonds.
	if (facade_style > 2.5 && facade_style < 3.5) {
		float course = fract(grid.y * 2.0);
		wall *= 0.93 + 0.12 * smoothstep(0.86, 1.0, course);
		wall *= 1.0 - 0.08 * (1.0 - smoothstep(0.0, 0.05, course));
	} else if (facade_style > 3.5 && facade_style < 4.5) {
		float row = floor(grid.y * 3.0);
		float bond = fract(grid.x * 2.0 + row * 0.5);
		wall *= 0.90 + 0.16 * smoothstep(0.88, 1.0, bond);
	}

	// Frames and spandrel panels use the dark trim tone.
	vec3 trim = trim_color.rgb * (0.86 + 0.24 * r_panel);
	// Spandrel panels read as dark metal, not as a black void.
	vec3 spandrel_color = mix(trim * 1.6 + vec3(0.012), wall * 0.62, 0.30);
	vec3 col = mix(wall, trim, frame);
	if (spandrel_band > 0.001) {
		float spandrel = 1.0 - smoothstep(spandrel_band, spandrel_band + 0.035, f.y);
		col = mix(col, spandrel_color, spandrel);
	}

	// Glass: deep interior tone, sky reflection concentrated at grazing angles.
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float grazing = pow(1.0 - ndv, 3.2);
	vec3 reflection = sky_color * (0.46 + 0.85 * grazing);
	reflection *= mix(0.80, 1.14, f.y);
	float interior = 0.55 + 0.55 * r_panel;
	vec3 glass_surface = mix(glass_color.rgb * interior, reflection, clamp(0.14 + 0.78 * grazing, 0.0, 0.86));
	// Recess shadow: the window head is always darker than the sill.
	glass_surface *= mix(0.55, 1.06, smoothstep(lo.y, hi.y, f.y));
	// Occasional blinds / interior partitions break up the repetition.
	float blind = step(0.62, r_blind);
	float blind_band = 1.0 - smoothstep(0.0, 0.05 + aa, abs(f.y - mix(0.35, 0.75, r_cell)));
	glass_surface = mix(glass_surface, vec3(0.34, 0.33, 0.31), blind * blind_band * 0.55);
	col = mix(col, glass_surface, glass);

	// Distance fade: collapse the window grid into an average tone before it moires.
	float deriv = max(fwidth(grid.x), fwidth(grid.y));
	float fade = smoothstep(0.20, 0.85, deriv);
	col = mix(col, mix(wall, glass_surface, 0.58), fade * 0.92);
	glass = mix(glass, 0.58, fade);

	ALBEDO = col;
	ROUGHNESS = mix(0.82, 0.035, glass);
	METALLIC = mix(0.02, 0.46, glass);
	SPECULAR = 0.55;

	float lit = step(1.0 - lit_ratio, hash12(cell * 1.91 + vec2(detail_seed, 7.7)));
	EMISSION = vec3(1.0, 0.78, 0.52) * glass * lit * 0.14 + wall * 0.10 + glass_color.rgb * 0.04;
}
