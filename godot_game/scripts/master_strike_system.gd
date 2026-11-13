class_name MasterStrikeSystem
extends RefCounted

# ====================================================================
# KINGDOM COME: DELIVERANCE - MASTER STRIKE & ADVANCED COMBAT ENGINE
# 5-Point Directional Rose, Liechtenauer Meisterhau Counters,
# Blade Binding / Clash Physics, and Multi-Layered Armor Mitigation.
# ====================================================================

enum Direction {
	TOP = 0,
	TOP_RIGHT = 1,
	BOTTOM_RIGHT = 2,
	BOTTOM_LEFT = 3,
	TOP_LEFT = 4,
	THRUST = 5
}

enum DamageType {
	SLASH = 0,
	PIERCE = 1,
	BLUNT = 2
}

enum MasterStrikeType {
	NONE = 0,
	ZORNHAU = 1,     # Wrath-strike vs Top / Angle
	KRUMPHAU = 2,    # Crooked cut vs Top-Right
	ZWERCHHAU = 3,   # Thwart strike vs Top-Left
	SCHIELHAU = 4,   # Squinting strike vs Low attacks
	ABSETZEN = 5     # Setting-aside deflection vs Thrust
}

# --------------------------------------------------------------------
# 1. HISTORICAL MEISTERHAU COUNTER MATRIX
# --------------------------------------------------------------------
const COUNTER_MATRIX: Dictionary = {
	Direction.TOP: MasterStrikeType.ZORNHAU,
	Direction.TOP_RIGHT: MasterStrikeType.KRUMPHAU,
	Direction.BOTTOM_RIGHT: MasterStrikeType.SCHIELHAU,
	Direction.BOTTOM_LEFT: MasterStrikeType.SCHIELHAU,
	Direction.TOP_LEFT: MasterStrikeType.ZWERCHHAU,
	Direction.THRUST: MasterStrikeType.ABSETZEN
}

const MASTER_STRIKE_NAMES: Dictionary = {
	MasterStrikeType.ZORNHAU: "Zornhau (Wrath Cut to Throat)",
	MasterStrikeType.KRUMPHAU: "Krumphau (Crooked Wrist Break)",
	MasterStrikeType.ZWERCHHAU: "Zwerchhau (Thwart Crossguard Slice)",
	MasterStrikeType.SCHIELHAU: "Schielhau (Plunging Crown Strike)",
	MasterStrikeType.ABSETZEN: "Absetzen (Blade-Glide Face Thrust)"
}

# --------------------------------------------------------------------
# 2. EVALUATE DEFENSIVE REACTION (PERFECT BLOCK vs MASTER STRIKE)
# --------------------------------------------------------------------
static func evaluate_defense(
	incoming_dir: int,
	incoming_is_thrust: bool,
	defender_stance: int,
	elapsed_since_windup: float,
	defender_warfare_skill: float = 10.0 # 0 to 20
) -> Dictionary:
	var result := {
		"success": false,
		"is_master_strike": false,
		"counter_type": MasterStrikeType.NONE,
		"counter_name": "",
		"stagger_duration": 0.0,
		"counter_damage_mult": 1.0,
		"stamina_cost_mult": 0.0,
		"slowmo_duration": 0.0
	}

	# Timing Windows (Warfare skill widens the windows slightly)
	var skill_bonus: float = clampf(defender_warfare_skill / 40.0, 0.0, 0.08)
	var master_strike_window: float = 0.15 + skill_bonus # First 150-230ms
	var perfect_block_window: float = 0.36 + skill_bonus # Up to 360-440ms

	if elapsed_since_windup <= master_strike_window:
		# Check stance compatibility:
		# Mirroring or matching the incoming attack angle allows fluid master strike
		var match_dir := Direction.THRUST if incoming_is_thrust else incoming_dir
		var is_aligned := (defender_stance == match_dir or defender_stance == Direction.TOP)

		if is_aligned or randf() < 0.65:
			result.success = true
			result.is_master_strike = true
			result.counter_type = COUNTER_MATRIX.get(match_dir, MasterStrikeType.ZORNHAU)
			result.counter_name = MASTER_STRIKE_NAMES.get(result.counter_type, "Master Strike")
			result.stagger_duration = 1.85 # High attacker stagger
			result.counter_damage_mult = 1.95 # Devastating riposte damage
			result.stamina_cost_mult = 0.0 # Free stamina on Master Strike
			result.slowmo_duration = 0.34 # KCD signature slow-mo frame trap
			return result

	if elapsed_since_windup <= perfect_block_window:
		# Perfect Block (Green Shield timing)
		result.success = true
		result.is_master_strike = false
		result.stagger_duration = 0.9 # Light attacker stagger
		result.counter_damage_mult = 0.0
		result.stamina_cost_mult = 0.0 # No stamina lost on perfect block
		result.slowmo_duration = 0.18
		return result

	return result

# --------------------------------------------------------------------
# 3. MULTI-LAYERED ARMOR DAMAGE MITIGATION
# Layer 1: Plate Armor (Curved Milanese/Nuremberg steel)
# Layer 2: Riveted Chainmail Hauberk
# Layer 3: Padded Wool & Linen Gambeson
# Layer 4: Living Flesh & Bone
# --------------------------------------------------------------------
static func calculate_armor_mitigation(
	incoming_damage: float,
	damage_type: int,
	has_plate: bool = true,
	has_mail: bool = true,
	has_gambeson: bool = true,
	is_half_swording: bool = false
) -> Dictionary:
	var rem_dmg: float = incoming_damage
	var stamina_trauma: float = 0.0
	var caused_bleeding: bool = false

	# Layer 1: Outer Steel Plate
	if has_plate:
		match damage_type:
			DamageType.SLASH:
				# Steel plate stops 96% of slashing blades completely
				rem_dmg *= 0.04
				stamina_trauma += incoming_damage * 0.3
			DamageType.PIERCE:
				if is_half_swording:
					# Half-swording directs immense leverage into plate seams
					rem_dmg *= 0.60
					stamina_trauma += incoming_damage * 0.45
				else:
					rem_dmg *= 0.35 # Glancing deflection
					stamina_trauma += incoming_damage * 0.25
			DamageType.BLUNT:
				# Blunt kinetic energy punches straight through plate into body
				rem_dmg *= 0.72
				stamina_trauma += incoming_damage * 1.45 # Massive concussive shock

	# Layer 2: Riveted Mail Hauberk
	if has_mail and rem_dmg > 1.0:
		match damage_type:
			DamageType.SLASH:
				rem_dmg *= 0.25 # Mail resists cutting
			DamageType.PIERCE:
				rem_dmg *= 0.75 # Points burst open wire links
			DamageType.BLUNT:
				rem_dmg *= 0.90 # Mail provides zero blunt cushioning
				stamina_trauma += incoming_damage * 0.3

	# Layer 3: Padded Textile Gambeson
	if has_gambeson and rem_dmg > 1.0:
		match damage_type:
			DamageType.SLASH:
				rem_dmg = maxf(0.0, rem_dmg - 12.0)
			DamageType.PIERCE:
				rem_dmg = maxf(0.0, rem_dmg - 8.0)
			DamageType.BLUNT:
				rem_dmg *= 0.55 # Thick quilted batting dampens blunt impact

	# Layer 4: Final Flesh & Bleeding Evaluation
	if damage_type == DamageType.SLASH and rem_dmg > 15.0:
		caused_bleeding = true
	elif damage_type == DamageType.PIERCE and rem_dmg > 12.0:
		caused_bleeding = true

	return {
		"final_health_damage": maxf(1.0, rem_dmg),
		"stamina_trauma": stamina_trauma,
		"caused_bleeding": caused_bleeding
	}

# --------------------------------------------------------------------
# 4. BLADE-ON-BLADE CLASH & BINDING PHYSICS (KLINGENBINDEN)
# --------------------------------------------------------------------
static func resolve_blade_clash(
	attacker_stamina: float,
	defender_stamina: float,
	leverage_progress: float # -1.0 (defender win) to +1.0 (attacker win)
) -> Dictionary:
	var attacker_power: float = attacker_stamina * (1.0 + leverage_progress * 0.5)
	var defender_power: float = defender_stamina * (1.0 - leverage_progress * 0.5)

	var winner_is_attacker: bool = (attacker_power >= defender_power)
	var break_margin: float = absf(attacker_power - defender_power)

	return {
		"is_resolved": break_margin > 25.0,
		"winner_is_attacker": winner_is_attacker,
		"loser_stagger_duration": 1.25,
		"loser_stamina_penalty": 28.0
	}
