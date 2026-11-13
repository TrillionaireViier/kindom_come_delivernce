shader_type canvas_item;

// ====================================================================
// KINGDOM COME: DELIVERANCE - BASSET / VISOR OBSTRUCTION SHADER
// Authentic 15th-century Klappvisier eye-slit vision restriction.
// ====================================================================

uniform float visor_lowered : hint_range(0.0, 1.0) = 1.0;
uniform float eye_slit_height : hint_range(0.05, 0.45) = 0.16;
uniform float breathing_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 metal_interior_color : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform vec4 rim_highlight_color : source_color = vec4(0.24, 0.22, 0.20, 1.0);

void fragment() {
	if (visor_lowered <= 0.01) {
		COLOR = vec4(0.0);
		return;
	}

	vec2 uv = UV;
	float center_y = 0.5 + sin(breathing_pulse * 6.28) * 0.008;
	float dist_y = abs(uv.y - center_y);

	// Curved eye-slit geometry with central bar divider
	float slit_half_h = eye_slit_height * 0.5;
	float slit_curve = cos((uv.x - 0.5) * 2.8) * 0.025;
	float effective_half_h = slit_half_h + slit_curve;

	// Breathing condensation blur along inner visor edges
	float condensation = sin(breathing_pulse * 3.14) * 0.02 * (1.0 - smoothstep(effective_half_h, effective_half_h + 0.06, dist_y));

	// Inside eye-slit opening (100% transparent to view battlefield)
	if (dist_y < effective_half_h) {
		// Subtle breath fog vignette on the edges of the slit
		float edge_fog = smoothstep(effective_half_h - 0.025, effective_half_h, dist_y) * condensation;
		COLOR = vec4(0.85, 0.90, 0.95, edge_fog * 0.45 * visor_lowered);
		return;
	}

	// Iron plate obstruction
	float rim = 1.0 - smoothstep(effective_half_h, effective_half_h + 0.02, dist_y);
	vec4 iron_plate = mix(metal_interior_color, rim_highlight_color, rim * 0.65);

	COLOR = vec4(iron_plate.rgb, visor_lowered * iron_plate.a);
}
