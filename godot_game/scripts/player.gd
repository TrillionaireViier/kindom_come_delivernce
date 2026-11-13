class_name PlayerHenry
extends CharacterBody2D

# ====================================================================
# KINGDOM COME: DELIVERANCE - HENRY OF SKALITZ
# Directional Swordplay (5-Point Rose + Thrust), Liechtenauer Master Strikes,
# Multi-Layer Armor Mitigation, Half-Swording Stance, and Visor Mode.
# ====================================================================

const SoundManager = preload("res://scripts/sound_manager.gd")
const CombatReticle = preload("res://scripts/combat_reticle.gd")
const MasterStrikeSystem = preload("res://scripts/master_strike_system.gd")
const SurvivalSystem = preload("res://scripts/survival_system.gd")

signal stats_changed(hp: float, stamina: float, hunger: float)
signal attack_started(direction: int, is_thrust: bool)
signal blocked_attack(perfect: bool)
signal master_strike_triggered(counter_name: String)
signal visor_toggled(is_down: bool)
signal half_sword_toggled(is_active: bool)
signal survival_updated(charisma: float, dirt: float, blood: float, bleeds: int)

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var speed: float = 180.0
@export var sprint_speed: float = 280.0
@export var warfare_skill: float = 12.0 # Increases Master Strike timing window

var health: float = 100.0
var stamina: float = 100.0
var sword_sharpness: float = 1.0 # 1.0 to 1.5 multiplier from grindstone

var combat_direction: int = 0 # 0=Top, 1=TR, 2=BR, 3=BL, 4=TL, 5=Thrust
var is_blocking: bool = false
var is_attacking: bool = false
var attack_timer: float = 0.0
var block_cooldown: float = 0.0

# KCD Stances & Equipment Modes
var is_half_swording: bool = false # Gripping blade midway for lethal plate piercing
var is_visor_down: bool = false    # Lowers Klappvisier bascinet visor (+armor, restricted view)
var has_plate_armor: bool = true
var has_mail_hauberk: bool = true
var has_gambeson: bool = true

# Incoming Attack Tracking for Master Strike Timing
var incoming_attack_active: bool = false
var incoming_attack_dir: int = 0
var incoming_attack_is_thrust: bool = false
var incoming_windup_elapsed: float = 0.0
var incoming_attacker: Node = null

# Survival Engine
var survival: SurvivalSystem
var reticle: CombatReticle
var look_dir: Vector2 = Vector2.RIGHT

var feedback_text: String = ""
var feedback_timer: float = 0.0
var feedback_color: Color = Color.GOLD

func _ready() -> void:
	health = max_health
	stamina = max_stamina
	
	# Instantiate Historical Survival Engine
	survival = SurvivalSystem.new()
	survival.name = "HenrySurvivalSystem"
	add_child(survival)
	survival.hygiene_changed.connect(_on_hygiene_changed)

func _process(delta: float) -> void:
	# 1. Stamina Regeneration (impaired by heavy fatigue/wounds)
	if not is_blocking and not is_attacking:
		var stam_regen := 24.0
		if survival.energy < 30.0:
			stam_regen *= 0.65 # Sleep deprivation debuff
		stamina = minf(max_stamina, stamina + delta * stam_regen)
	
	# 2. Bleeding Health Drain from Localized Wounds
	var bleeds := _get_active_bleeds_count()
	if bleeds > 0:
		health = maxf(0.0, health - delta * float(bleeds) * 1.8)
		if randf() < delta * 1.5:
			SoundManager.play("armor_hit", 1.4)
	
	# 3. Track Incoming Attack Window for Master Strike
	if incoming_attack_active:
		incoming_windup_elapsed += delta
		if incoming_windup_elapsed > 0.5:
			incoming_attack_active = false
	
	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
	
	if feedback_timer > 0.0:
		feedback_timer -= delta
	
	# 4. Direction Tracking from Mouse Position (5-Point Liechtenauer Rose)
	var mouse_pos := get_global_mouse_position()
	var to_mouse := mouse_pos - global_position
	look_dir = to_mouse.normalized()
	
	if to_mouse.length() > 20.0:
		var raw_angle := to_mouse.angle() # -PI to PI
		var deg := rad_to_deg(raw_angle)
		if deg < -126.0 or deg > 126.0:
			combat_direction = 3 if deg > 0 else 4 # BL or TL
		elif deg >= -126.0 and deg < -54.0:
			combat_direction = 0 # Top
		elif deg >= -54.0 and deg < 18.0:
			combat_direction = 1 # Top-Right
		elif deg >= 18.0 and deg <= 90.0:
			combat_direction = 2 # Bottom-Right
		else:
			combat_direction = 3 # Bottom-Left
	
	if reticle:
		reticle.set_active_direction(combat_direction)
	
	_handle_combat_input(delta)
	
	stats_changed.emit(health, stamina, survival.nourishment)
	survival_updated.emit(survival.get_effective_charisma(), survival.dirt_amount, survival.blood_amount, bleeds)
	queue_redraw()

func _handle_combat_input(_delta: float) -> void:
	# LMB: Directional Slash (or Half-Sword strike)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_attacking and stamina >= 15.0:
		perform_slash(combat_direction)
	
	# MMB or 'F': Thrust (Abstechen)
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_key_pressed(KEY_F)) and not is_attacking and stamina >= 12.0:
		perform_thrust()
	
	# RMB or SPACE: Raise Guard / Defend (triggers Master Strike check if timed right)
	var wants_block := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_SPACE)
	if wants_block and not is_attacking:
		if not is_blocking:
			_on_guard_raised()
		is_blocking = true
		stamina = maxf(0.0, stamina - _delta * 9.0)
	else:
		is_blocking = false
	
	# Key 'T': Toggle Half-Swording Grip (Halbschwert)
	if Input.is_action_just_pressed("ui_focus_next") or Input.is_key_pressed(KEY_T):
		if not is_attacking and block_cooldown <= 0.0:
			is_half_swording = not is_half_swording
			half_sword_toggled.emit(is_half_swording)
			block_cooldown = 0.3
			SoundManager.play("sword_clash", 1.5)
			_show_feedback("HALF-SWORDING: " + ("ACTIVE (Anti-Plate Piercing)" if is_half_swording else "OFF"), Color.AQUA)
	
	# Key 'V': Toggle Klappvisier Visor
	if Input.is_key_pressed(KEY_V) and block_cooldown <= 0.0:
		is_visor_down = not is_visor_down
		visor_toggled.emit(is_visor_down)
		block_cooldown = 0.35
		SoundManager.play("armor_hit", 0.75)
		_show_feedback("HELMET VISOR: " + ("LOWERED (+Max Armor / Slit View)" if is_visor_down else "RAISED (Full Visibility)"), Color.ORANGE)
	
	# Key 'C': Apply Bandage to Bleeding Limb
	if Input.is_key_pressed(KEY_C) and block_cooldown <= 0.0:
		_apply_bandage_action()
		block_cooldown = 0.4
	
	# Key 'H': Drink Savior Schnapps (Save game, restore HP & Stamina, +BAC)
	if Input.is_key_pressed(KEY_H) and block_cooldown <= 0.0:
		drink_schnapps()
		block_cooldown = 0.5
	
	# Key 'B': Wash in Trough / Bathhouse
	if Input.is_key_pressed(KEY_B) and block_cooldown <= 0.0:
		survival.visit_bathhouse(false)
		block_cooldown = 0.5
		SoundManager.play("drink", 1.1)
		_show_feedback("BATHHOUSE WASH: Dirt & Blood Cleaned! Charisma Restored.", Color.LIGHT_GREEN)
	
	if block_cooldown > 0.0:
		block_cooldown -= _delta

func _on_guard_raised() -> void:
	SoundManager.play("sword_clash", 1.15)
	
	# MASTER STRIKE EVALUATION
	# If an incoming enemy attack windup is active, evaluate reaction
	if incoming_attack_active and is_instance_valid(incoming_attacker):
		var defense_result := MasterStrikeSystem.evaluate_defense(
			incoming_attack_dir,
			incoming_attack_is_thrust,
			combat_direction,
			incoming_windup_elapsed,
			warfare_skill
		)
		
		if defense_result.is_master_strike:
			_execute_master_strike(defense_result)
			incoming_attack_active = false
			return
		elif defense_result.success:
			# Perfect Block (Green Shield Window)
			_execute_perfect_block(defense_result)
			incoming_attack_active = false
			return

func _execute_master_strike(res: Dictionary) -> void:
	# 1. KCD Signature Cinematic Slow-Motion Frame Trap
	Engine.time_scale = 0.22
	var slowmo_dur: float = float(res.get("slowmo_duration", 0.34))
	get_tree().create_timer(slowmo_dur, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)
	
	# 2. Authentic Procedural Audio & Visual Polish
	SoundManager.play("perfect_parry", 1.0)
	stamina = minf(max_stamina, stamina + 20.0) # Free stamina reward
	
	# 3. Devastating Unblockable Meisterhau Riposte Damage
	var counter_damage: float = 38.0 * float(res.get("counter_damage_mult", 1.95)) * sword_sharpness
	if is_half_swording:
		counter_damage *= 1.25 # Extra puncture trauma
	
	if incoming_attacker and incoming_attacker.has_method("receive_stagger"):
		incoming_attacker.call("receive_stagger", counter_damage)
	
	# 4. Notify Systems & HUD
	var tech_name: String = str(res.get("counter_name", "Meisterhau Counter"))
	master_strike_triggered.emit(tech_name)
	blocked_attack.emit(true)
	_show_feedback("⚔️ MASTER STRIKE! " + tech_name, Color.GOLD)

func _execute_perfect_block(res: Dictionary) -> void:
	# Subtle time dilation on perfect block
	Engine.time_scale = 0.5
	var slowmo_dur: float = float(res.get("slowmo_duration", 0.18))
	get_tree().create_timer(slowmo_dur, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)
	
	SoundManager.play("sword_clash", 1.3)
	blocked_attack.emit(true)
	if incoming_attacker and incoming_attacker.has_method("receive_stagger"):
		incoming_attacker.call("receive_stagger", 12.0)
	_show_feedback("⚡ PERFECT BLOCK!", Color.GREEN_YELLOW)

func notify_incoming_attack(from_dir: int, is_thrust: bool, _windup_duration: float, attacker: Node) -> void:
	incoming_attack_active = true
	incoming_attack_dir = from_dir
	incoming_attack_is_thrust = is_thrust
	incoming_windup_elapsed = 0.0
	incoming_attacker = attacker

func perform_slash(dir: int) -> void:
	is_attacking = true
	attack_timer = 0.32
	stamina -= (18.0 if not is_half_swording else 12.0)
	attack_started.emit(dir, false)
	SoundManager.play("sword_swing", randf_range(0.9, 1.15))
	
	_check_hit(dir, false)

func perform_thrust() -> void:
	is_attacking = true
	attack_timer = 0.28
	stamina -= (14.0 if not is_half_swording else 10.0)
	attack_started.emit(CombatReticle.Direction.THRUST, true)
	SoundManager.play("sword_swing", 1.3)
	
	_check_hit(CombatReticle.Direction.THRUST, true)

func _check_hit(dir: int, is_thrust: bool) -> void:
	var space := get_world_2d().direct_space_state
	var reach := 90.0 if not is_half_swording else 70.0
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + look_dir * reach)
	query.exclude = [self]
	var res := space.intersect_ray(query)
	
	if res and res.collider is Node and res.collider.has_method("receive_attack"):
		var base_damage := (28.0 if not is_thrust else 24.0) * sword_sharpness
		if is_half_swording and is_thrust:
			base_damage *= 1.35 # Half-sword thrust penetrates armor
		res.collider.call("receive_attack", dir, is_thrust, base_damage, self)

func receive_attack(from_dir: int, is_thrust: bool, raw_damage: float, attacker: Node) -> void:
	# If blocking, evaluate block defense
	if is_blocking and stamina > 12.0:
		SoundManager.play("sword_clash", 0.95)
		stamina = maxf(0.0, stamina - raw_damage * 0.75)
		blocked_attack.emit(false)
		_show_feedback("BLOCKED", Color.LIGHT_GRAY)
		return
	
	# Multi-Layered Historical Armor Mitigation
	var dmg_type := MasterStrikeSystem.DamageType.PIERCE if is_thrust else MasterStrikeSystem.DamageType.SLASH
	var mitigation := MasterStrikeSystem.calculate_armor_mitigation(
		raw_damage,
		dmg_type,
		has_plate_armor and is_visor_down, # Visor gives full head/torso plate rating
		has_mail_hauberk,
		has_gambeson,
		false
	)
	
	# Apply mitigated damage
	var final_hp_dmg: float = mitigation["final_health_damage"]
	var stam_trauma: float = mitigation["stamina_trauma"]
	var caused_bleeding: bool = mitigation["caused_bleeding"]
	
	health = maxf(0.0, health - final_hp_dmg)
	stamina = maxf(0.0, stamina - stam_trauma)
	SoundManager.play("armor_hit", randf_range(0.9, 1.1))
	
	if caused_bleeding:
		var limbs := ["torso", "arms", "legs", "head"]
		survival.inflict_damage_to_limb(limbs[randi() % limbs.size()], not is_thrust)
		_show_feedback("⚠️ WOUNDED & BLEEDING! [C] Bandage", Color.RED)
	
	# Knockback
	if attacker is Node2D:
		velocity = (global_position - attacker.global_position).normalized() * 125.0

func receive_stagger(damage: float) -> void:
	health = maxf(0.0, health - damage)
	stamina = maxf(0.0, stamina - 30.0)
	SoundManager.play("armor_hit", 0.8)

func _apply_bandage_action() -> void:
	for limb in ["torso", "arms", "legs", "head"]:
		if survival.apply_bandage(limb):
			SoundManager.play("drink", 1.3)
			_show_feedback("Bandaged " + limb.capitalize() + "! Bleeding stopped.", Color.GREEN)
			return
	_show_feedback("No bleeding wounds to bandage.", Color.LIGHT_GRAY)

func drink_schnapps() -> void:
	health = minf(max_health, health + 45.0)
	stamina = max_stamina
	survival.drink_alcohol(0.10) # Savior Schnapps is strong monastic spirits
	SoundManager.play("drink", 1.0)
	_show_feedback("Savior Schnapps consumed! Game Saved & Wounds Tended.", Color.GOLD)

func _get_active_bleeds_count() -> int:
	var count := 0
	for limb in survival.wounds.keys():
		if survival.wounds[limb]["bleeding"]:
			count += 1
	return count

func _on_hygiene_changed(_dirt: float, _blood: float, _charisma: float) -> void:
	pass

func _show_feedback(txt: String, col: Color) -> void:
	feedback_text = txt
	feedback_color = col
	feedback_timer = 2.2

func _physics_process(_delta: float) -> void:
	var move_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_input.x += 1.0
	
	move_input = move_input.normalized()
	
	var is_sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and stamina > 10.0 and move_input != Vector2.ZERO
	if is_sprinting:
		stamina = maxf(0.0, stamina - _delta * 18.0)
		survival.dirt_amount = minf(1.0, survival.dirt_amount + _delta * 0.008) # Running in Bohemian mud kicks up dirt
	
	var cur_speed := sprint_speed if is_sprinting else speed
	if is_blocking or is_attacking or is_half_swording:
		cur_speed *= 0.6
	
	velocity = velocity.move_toward(move_input * cur_speed, 850.0 * _delta)
	move_and_slide()

func _draw() -> void:
	# Dynamic Dirt & Blood visual layering on Henry
	var dirt_tint := Color(0.3, 0.22, 0.15).lerp(Color.WHITE, 1.0 - survival.dirt_amount * 0.5)
	var base_body := Color(0.72, 0.18, 0.14) * dirt_tint
	var armor_col := Color(0.38, 0.40, 0.44) * dirt_tint
	
	# Shadow
	draw_ellipse(Vector2(0, 9), 19.0, 9.5, Color(0, 0, 0, 0.35))
	
	# Torso & Gambeson
	draw_circle(Vector2.ZERO, 16.5, base_body)
	# Mail Hauberk & Breastplate
	draw_circle(Vector2.ZERO, 11.5, armor_col)
	
	# Blood spatters on armor
	if survival.blood_amount > 0.05:
		var blood_col := Color(0.65, 0.05, 0.05, clampf(survival.blood_amount, 0.2, 0.9))
		draw_circle(Vector2(4, -3), 4.5, blood_col)
		draw_circle(Vector2(-3, 4), 3.0, blood_col)
	
	# Head & Helmet
	if is_visor_down:
		# Iron Klappvisier Bascinet with nose ridge
		draw_circle(Vector2(0, -4), 9.0, Color(0.28, 0.30, 0.33))
		# Brass rim highlight & Eye slit
		draw_line(Vector2(-6, -5), Vector2(6, -5), Color(0.1, 0.1, 0.1), 2.5)
		draw_line(Vector2(0, -9), Vector2(0, -2), Color(0.85, 0.72, 0.25), 1.8) # Center brass rib
	else:
		# Henry's face & Hair
		draw_circle(Vector2(0, -4), 8.5, Color(0.85, 0.7, 0.55))
		draw_arc(Vector2(0, -6), 9.0, -PI, 0.0, 16, Color(0.3, 0.2, 0.12), 4.0)
	
	# Longsword / Arming Sword Rendering
	var sword_base := look_dir * 18.0
	var sword_tip := sword_base + look_dir * (42.0 if not is_attacking else 58.0)
	var guard_norm := Vector2(-look_dir.y, look_dir.x)
	
	if is_half_swording:
		# Half-Swording: Left hand grips center of blade, weapon held shorter
		sword_tip = sword_base + look_dir * 32.0
		# Left hand on blade
		draw_circle(sword_base + look_dir * 16.0, 3.8, Color(0.5, 0.45, 0.4))
	
	# Blade
	draw_line(sword_base, sword_tip, Color(0.92, 0.94, 0.98), 3.2)
	# Fuller line
	draw_line(sword_base + look_dir * 4.0, sword_tip - look_dir * 8.0, Color(0.5, 0.55, 0.6), 1.6)
	# Crossguard & Brass Pommel
	draw_line(sword_base - guard_norm * 9.0, sword_base + guard_norm * 9.0, Color(0.88, 0.78, 0.3), 3.2)
	draw_circle(sword_base - look_dir * 8.0, 3.5, Color(0.88, 0.78, 0.3))
	
	# Skalitz Red & Gold Shield on Offhand
	var shield_pos := -guard_norm * 16.0
	var shield_pts := PackedVector2Array([
		shield_pos + Vector2(-6, -10),
		shield_pos + Vector2(6, -10),
		shield_pos + Vector2(5, 4),
		shield_pos + Vector2(0, 11),
		shield_pos + Vector2(-5, 4)
	])
	draw_colored_polygon(shield_pts, Color(0.72, 0.18, 0.14) * dirt_tint)
	draw_line(shield_pos + Vector2(0, -8), shield_pos + Vector2(0, 8), Color(0.95, 0.85, 0.3), 1.5)
	
	# Feedback Text HUD above Henry
	if feedback_timer > 0.0 and feedback_text != "":
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-120, -38), feedback_text, HORIZONTAL_ALIGNMENT_CENTER, 240, 13, feedback_color)
