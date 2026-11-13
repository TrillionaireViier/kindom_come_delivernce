shader_type canvas_item;

// ====================================================================
// KINGDOM COME: DELIVERANCE - DIRT, MUD & BLOOD ACCUMULATION SHADER
// Multi-layer visual degradation for armor and garments.
// Drives the NPC Smell & Charisma penalty mechanics.
// ====================================================================

uniform float dirt_amount : hint_range(0.0, 1.0) = 0.0;
uniform float blood_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.5;

uniform vec4 mud_base_color : source_color = vec4(0.24, 0.17, 0.11, 1.0);
uniform vec4 mud_dry_color : source_color = vec4(0.42, 0.35, 0.26, 1.0);
uniform vec4 fresh_blood_color : source_color = vec4(0.58, 0.03, 0.03, 1.0);
uniform vec4 dried_blood_color : source_color = vec4(0.24, 0.06, 0.05, 1.0);

float noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float fbm_splatter(vec2 uv) {
	float total = 0.0;
	float amp = 0.5;
	vec2 freq = uv;
	for (int i = 0; i < 4; i++) {
		total += noise_hash(freq) * amp;
		freq *= 2.15;
		amp *= 0.5;
	}
	return total;
}

void fragment() {
	vec4 base_tex = texture(TEXTURE, UV);
	if (base_tex.a < 0.01) {
		discard;
	}

	// 1. Mud / Road Dirt Layer Calculation
	// Natural Bohemian terrain mud accumulates heavier from the ground up
	float vertical_dirt_bias = smoothstep(0.1, 1.0, UV.y);
	float dirt_noise = fbm_splatter(UV * 18.0);
	float mud_coverage = clamp((dirt_noise * 0.65 + vertical_dirt_bias * 0.55) * dirt_amount * 1.8, 0.0, 1.0);

	// Mud color shifts from dark wet clods to powdery dry soil based on wetness
	vec4 current_mud = mix(mud_dry_color, mud_base_color, wetness);
	vec3 rendered_color = mix(base_tex.rgb, current_mud.rgb, mud_coverage * 0.92);

	// 2. Arterial Combat Blood Splatter Layer
	// High-velocity impact spray and directional sword-swipe streaks
	float arterial_spray = fbm_splatter(UV * 36.0 + vec2(dirt_noise, 0.0));
	float slash_angle_streak = abs(sin((UV.x * 2.0 + UV.y) * 45.0));
	float blood_mask = smoothstep(0.48, 0.88, arterial_spray * 0.65 + slash_angle_streak * 0.35);
	float blood_coverage = clamp(blood_mask * blood_amount * 2.2, 0.0, 1.0);

	// Fresh vs dried coagulated crust blood
	vec4 current_blood = mix(dried_blood_color, fresh_blood_color, wetness);
	rendered_color = mix(rendered_color, current_blood.rgb, blood_coverage);

	// Wet specular glint on fresh wet blood and moist mud
	if (wetness > 0.3) {
		float glint = (blood_coverage * 0.7 + mud_coverage * 0.3) * smoothstep(0.7, 0.95, dirt_noise) * wetness;
		rendered_color += vec3(glint * 0.25);
	}

	COLOR = vec4(rendered_color, base_tex.a);
}
