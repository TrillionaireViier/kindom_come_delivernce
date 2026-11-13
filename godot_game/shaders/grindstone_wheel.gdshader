shader_type canvas_item;

// ====================================================================
// KINGDOM COME: DELIVERANCE - SANDSTONE GRINDSTONE WHEEL SHADER
// Simulates rotating Bohemian sandstone with grit, moisture sheen,
// water trough pickup, and thermal friction heat-glow under blade contact.
// ====================================================================

uniform float wheel_rotation : hint_range(0.0, 628.3) = 0.0;
uniform float wheel_speed : hint_range(0.0, 30.0) = 0.0;
uniform vec2 contact_point_uv = vec2(0.5, 0.15);
uniform float contact_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float water_wetness : hint_range(0.0, 1.0) = 0.85;

uniform vec4 stone_base_color : source_color = vec4(0.58, 0.54, 0.48, 1.0);
uniform vec4 stone_dark_color : source_color = vec4(0.36, 0.33, 0.28, 1.0);
uniform vec4 wet_sheen_color : source_color = vec4(0.75, 0.82, 0.90, 1.0);
uniform vec4 heat_glow_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 center_rel = UV - vec2(0.5);
	float dist = length(center_rel);

	// Outer circular wheel boundary
	if (dist > 0.485) {
		discard;
	}

	// Iron central axle hole
	if (dist < 0.085) {
		float axle_inner = smoothstep(0.03, 0.085, dist);
		COLOR = mix(vec4(0.12, 0.12, 0.12, 1.0), vec4(0.28, 0.28, 0.30, 1.0), axle_inner);
		return;
	}

	// Rotating Polar coordinates
	float angle = atan(center_rel.y, center_rel.x) + wheel_rotation;

	// Procedural concentric chisel striations & mineral grains
	float concentric_rings = sin(dist * 75.0 + hash12(vec2(dist, 1.0)) * 1.5);
	float radial_flutes = sin(angle * 16.0);
	float grain_noise = hash12(vec2(dist * 40.0, floor(angle * 24.0)));

	// Blend sandstone base color
	float stone_fac = clamp(0.4 + 0.25 * concentric_rings + 0.15 * radial_flutes + 0.2 * grain_noise, 0.0, 1.0);
	vec4 col = mix(stone_base_color, stone_dark_color, stone_fac);

	// Centrifugal motion blur streak effect based on RPM
	float blur_alpha = clamp(wheel_speed * 0.05, 0.0, 0.6);
	col.rgb = mix(col.rgb, mix(stone_base_color.rgb, stone_dark_color.rgb, 0.5), blur_alpha);

	// Water trough moisture pickup & drying sheen
	// Moisture concentrates on lower hemisphere and fades on top
	float trough_pickup = clamp(-sin(angle) * 0.5 + 0.5, 0.0, 1.0);
	float wetness = water_wetness * (0.6 + 0.4 * trough_pickup);
	float specular = wetness * smoothstep(0.12, 0.46, dist) * (0.2 + 0.15 * sin(angle * 4.0));
	col.rgb = mix(col.rgb, col.rgb + wet_sheen_color.rgb * specular, wetness * 0.7);

	// Outer rim bevel shadow
	float rim_bevel = smoothstep(0.485, 0.45, dist);
	col.rgb *= (0.7 + 0.3 * rim_bevel);

	// Thermal friction heat-glow at blade contact point
	if (contact_intensity > 0.01) {
		float dist_to_blade = distance(UV, contact_point_uv);
		if (dist_to_blade < 0.14) {
			float heat = (1.0 - smoothstep(0.0, 0.14, dist_to_blade)) * contact_intensity;
			// Incandescent thermal core (yellow-hot center, orange outer)
			vec3 incandescence = mix(heat_glow_color.rgb, vec3(1.0, 0.95, 0.6), heat * heat);
			col.rgb = mix(col.rgb, incandescence, heat * 0.9);
			col.rgb += incandescence * (heat * 0.75);
		}
	}

	COLOR = col;
}
