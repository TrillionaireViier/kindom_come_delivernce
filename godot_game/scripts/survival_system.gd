class_name SurvivalSystem
extends Node

# ====================================================================
# KINGDOM COME: DELIVERANCE - HISTORICAL SURVIVAL & HYGIENE ENGINE
# Dirt, Mud, Blood, NPC Smell, Charisma Checks, Hunger, Alcohol BAC,
# Sleep Deprivation, Bleeding State Machine, and Bathhouse Laundering.
# ====================================================================

signal hygiene_changed(dirt: float, blood: float, charisma: float)
signal hunger_changed(nourishment: float, state_desc: String)
signal drunkenness_changed(bac: float, state_desc: String)
signal fatigue_changed(exhaustion: float, state_desc: String)
signal wound_inflicted(limb: String, is_bleeding: bool)
signal wound_healed(limb: String)

# --------------------------------------------------------------------
# 1. HYGIENE, DIRT & SMELL (0.0 to 1.0)
# --------------------------------------------------------------------
@export var dirt_amount: float = 0.05
@export var blood_amount: float = 0.0
@export var base_charisma: float = 12.0 # 1 to 20

# --------------------------------------------------------------------
# 2. NOURISHMENT / HUNGER (0 to 120)
# 100 = Satisfied, 50 = Mild hunger, 0 = Starving, >100 = Overstuffed
# --------------------------------------------------------------------
@export var nourishment: float = 85.0
var nourishment_decay_rate: float = 1.6 # per minute

# --------------------------------------------------------------------
# 3. ALCOHOL INTOXICATION (BAC: 0.0% to 0.45%)
# --------------------------------------------------------------------
var blood_alcohol_content: float = 0.0 # BAC %
var hangover_timer: float = 0.0

# --------------------------------------------------------------------
# 4. SLEEP DEPRIVATION & FATIGUE (0 to 100)
# 100 = Fully rested, 25 = Exhausted, 0 = Collapse
# --------------------------------------------------------------------
@export var energy: float = 90.0
var energy_decay_rate: float = 2.0 # per minute

# --------------------------------------------------------------------
# 5. LOCALIZED WOUND STATE MACHINE
# --------------------------------------------------------------------
var wounds: Dictionary = {
	"head": {"injured": false, "bleeding": false, "bandage_count": 0},
	"torso": {"injured": false, "bleeding": false, "bandage_count": 0},
	"arms": {"injured": false, "bleeding": false, "bandage_count": 0},
	"legs": {"injured": false, "bleeding": false, "bandage_count": 0}
}

var infection_level: float = 0.0 # 0.0 to 100.0 (septic fever)

func _process(delta: float) -> void:
	var delta_minutes := delta / 60.0

	# 1. Hunger & Energy decay over Bohemian time
	nourishment = maxf(0.0, nourishment - nourishment_decay_rate * delta_minutes)
	energy = maxf(0.0, energy - energy_decay_rate * delta_minutes)

	# 2. Alcohol metabolism (liver cleanses approx 0.015% BAC per hour)
	if blood_alcohol_content > 0.0:
		blood_alcohol_content = maxf(0.0, blood_alcohol_content - (0.015 / 60.0) * delta_minutes)
		if blood_alcohol_content == 0.0 and hangover_timer <= 0.0:
			hangover_timer = 180.0 # 3 min headache hangover

	if hangover_timer > 0.0:
		hangover_timer -= delta

	# 3. Active Bleeding drain
	var active_bleeds := 0
	for limb in wounds.keys():
		if wounds[limb]["bleeding"]:
			active_bleeds += 1

	if active_bleeds > 0:
		# Health drain handled by player binding
		infection_level = minf(100.0, infection_level + delta * 0.15 * float(active_bleeds))

	# 4. Gradual trail dirt accumulation while walking
	dirt_amount = minf(1.0, dirt_amount + delta_minutes * 0.02)

# --------------------------------------------------------------------
# HYGIENE & CHARISMA CALCULATION
# --------------------------------------------------------------------
func get_effective_charisma() -> float:
	var penalty: float = 0.0
	# Dirt penalty: up to -5 Charisma
	penalty += dirt_amount * 5.0
	# Blood penalty: up to -7 Charisma (people think you're a bloodthirsty brigand)
	penalty += blood_amount * 7.0

	# Alcohol courage buff (mild buzz adds +2 Charisma)
	var alcohol_bonus: float = 0.0
	if blood_alcohol_content >= 0.04 and blood_alcohol_content <= 0.14:
		alcohol_bonus = 2.0
	elif blood_alcohol_content > 0.22:
		penalty += 4.0 # Drunken slurring penalty

	return clampf(base_charisma - penalty + alcohol_bonus, 1.0, 20.0)

# --------------------------------------------------------------------
# BATHHOUSE LAUNDERING & HEALING SERVICE
# --------------------------------------------------------------------
func visit_bathhouse(heal_wounds: bool = true) -> void:
	dirt_amount = 0.0
	blood_amount = 0.0
	infection_level = 0.0

	if heal_wounds:
		for limb in wounds.keys():
			wounds[limb]["injured"] = false
			wounds[limb]["bleeding"] = false
			wound_healed.emit(limb)

	hygiene_changed.emit(dirt_amount, blood_amount, get_effective_charisma())

# --------------------------------------------------------------------
# INFLICT & BANDAGE WOUNDS
# --------------------------------------------------------------------
func inflict_damage_to_limb(limb: String, is_slashing: bool) -> void:
	if not wounds.has(limb):
		limb = "torso"

	wounds[limb]["injured"] = true
	if is_slashing:
		wounds[limb]["bleeding"] = true
		blood_amount = minf(1.0, blood_amount + 0.25)

	wound_inflicted.emit(limb, wounds[limb]["bleeding"])
	hygiene_changed.emit(dirt_amount, blood_amount, get_effective_charisma())

func apply_bandage(limb: String) -> bool:
	if wounds.has(limb) and wounds[limb]["bleeding"]:
		wounds[limb]["bleeding"] = false
		wounds[limb]["bandage_count"] += 1
		wound_healed.emit(limb)
		return true
	return false

# --------------------------------------------------------------------
# CONSUMPTION: SAVIOR SCHNAPPS, FOOD & MONASTIC MEDICINE
# --------------------------------------------------------------------
func drink_alcohol(alcohol_volume: float = 0.08) -> void:
	blood_alcohol_content = minf(0.45, blood_alcohol_content + alcohol_volume)
	nourishment = minf(120.0, nourishment + 10.0)

func eat_food(nutrition: float) -> void:
	nourishment = minf(120.0, nourishment + nutrition)
	if nourishment > 105.0:
		# Overeating "Pig-out" debuff
		pass

func drink_marigold_decoction() -> void:
	infection_level = maxf(0.0, infection_level - 50.0)
	for limb in wounds.keys():
		wounds[limb]["bleeding"] = false
