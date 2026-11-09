class_name PlayerHenry
extends CharacterBody2D

const SoundManager = preload("res://scripts/sound_manager.gd")
const CombatReticle = preload("res://scripts/combat_reticle.gd")

signal stats_changed(hp: float, stamina: float, hunger: float)
signal attack_started(direction: int, is_thrust: bool)
signal blocked_attack(perfect: bool)

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var speed: float = 180.0
@export var sprint_speed: float = 280.0

var health: float = 100.0
var stamina: float = 100.0
var hunger: float = 25.0 # "I feel quite hungry"
var sword_sharpness: float = 1.0 # From grindstone 1.0 to 1.5

var combat_direction: int = 0 # 0=Top, 1=TR, 2=BR, 3=BL, 4=TL, 5=Thrust
var is_blocking: bool = false
var is_attacking: bool = false
var attack_timer: float = 0.0
var block_cooldown: float = 0.0
var perfect_parry_window: float = 0.0

var attack_angle_current: float = 0.0
var weapon_offset: Vector2 = Vector2(24, 0)
var look_dir: Vector2 = Vector2.RIGHT

var reticle: CombatReticle

func _ready() -> void:
	health = max_health
	stamina = max_stamina

func _process(delta: float) -> void:
	# Stamina regeneration
	if not is_blocking and not is_attacking:
		stamina = minf(max_stamina, stamina + delta * 24.0)
	
	# Hunger increases slowly
	hunger = minf(100.0, hunger + delta * 0.2)
	
	# Perfect parry window decay
	if perfect_parry_window > 0.0:
		perfect_parry_window -= delta
	
	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
	
	# Direction tracking from mouse position relative to screen center
	var mouse_pos := get_global_mouse_position()
	var to_mouse := mouse_pos - global_position
	look_dir = to_mouse.normalized()
	
	if to_mouse.length() > 20.0:
		var raw_angle := to_mouse.angle() # -PI to PI
		# Classify into 5 directional petals
		# Top: -PI/2
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
	
	_handle_input(delta)
	stats_changed.emit(health, stamina, hunger)
	queue_redraw()

func _handle_input(_delta: float) -> void:
	# Attack: Left Click
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_attacking and stamina >= 15.0:
		perform_slash(combat_direction)
	
	# Thrust: Middle Mouse or 'F'
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_key_pressed(KEY_F)) and not is_attacking and stamina >= 12.0:
		perform_thrust()
	
	# Block: Right Click or Space
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_SPACE)) and not is_attacking:
		if not is_blocking:
			perfect_parry_window = 0.35 # Opening window for Perfect Block
			SoundManager.play("sword_clash", 1.2)
		is_blocking = true
		stamina = maxf(0.0, stamina - _delta * 10.0)
	else:
		is_blocking = false
	
	# Drink Savior Schnapps / Eat: 'H'
	if Input.is_key_pressed(KEY_H) and hunger > 20.0:
		drink_schnapps()

func perform_slash(dir: int) -> void:
	is_attacking = true
	attack_timer = 0.35
	stamina -= 16.0
	attack_started.emit(dir, false)
	SoundManager.play("sword_swing", randf_range(0.9, 1.15))
	
	# Check hits against enemies in front
	_check_hit(dir, false)

func perform_thrust() -> void:
	is_attacking = true
	attack_timer = 0.28
	stamina -= 14.0
	attack_started.emit(CombatReticle.Direction.THRUST, true)
	SoundManager.play("sword_swing", 1.3)
	
	_check_hit(CombatReticle.Direction.THRUST, true)

func _check_hit(dir: int, is_thrust: bool) -> void:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + look_dir * 85.0)
	query.exclude = [self]
	var res := space.intersect_ray(query)
	
	if res and res.collider is Node and res.collider.has_method("receive_attack"):
		var base_damage := (28.0 if not is_thrust else 22.0) * sword_sharpness
		res.collider.call("receive_attack", dir, is_thrust, base_damage, self)

func receive_attack(from_dir: int, is_thrust: bool, damage: float, attacker: Node) -> void:
	if is_blocking and stamina > 10.0:
		if perfect_parry_window > 0.0:
			# MASTER STRIKE / PERFECT PARRY!
			SoundManager.play("perfect_parry", 1.0)
			stamina = minf(max_stamina, stamina + 15.0)
			blocked_attack.emit(true)
			# Counter-attack attacker with master strike riposte
			if attacker and attacker.has_method("receive_stagger"):
				attacker.call("receive_stagger", 30.0)
			return
		else:
			# Normal Block: Stamina absorbs damage
			SoundManager.play("sword_clash", 0.95)
			stamina = maxf(0.0, stamina - damage * 0.8)
			blocked_attack.emit(false)
			return
	
	# Unblocked Hit!
	health = maxf(0.0, health - damage)
	SoundManager.play("armor_hit", randf_range(0.9, 1.1))
	
	# Screen knockback
	velocity = (global_position - attacker.global_position).normalized() * 120.0

func receive_stagger(damage: float) -> void:
	health = maxf(0.0, health - damage)
	stamina = maxf(0.0, stamina - 25.0)
	SoundManager.play("armor_hit", 0.8)

func drink_schnapps() -> void:
	health = minf(max_health, health + 35.0)
	hunger = maxf(0.0, hunger - 30.0)
	stamina = max_stamina
	SoundManager.play("drink", 1.0)

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
	
	var cur_speed := sprint_speed if is_sprinting else speed
	if is_blocking or is_attacking:
		cur_speed *= 0.5
	
	velocity = velocity.move_toward(move_input * cur_speed, 800.0 * _delta)
	move_and_slide()

func _draw() -> void:
	# Draw Henry: Torso (Red & Black Skalitz Gambeson), Arms, Sword & Shield
	var body_color := Color(0.72, 0.18, 0.14) # Skalitz red
	var armor_color := Color(0.35, 0.38, 0.42) # Iron brigandine
	
	# Shadow
	draw_ellipse(Vector2(0, 8), 18.0, 9.0, Color(0, 0, 0, 0.35))
	
	# Torso & Shoulders
	draw_circle(Vector2.ZERO, 16.0, body_color)
	draw_circle(Vector2.ZERO, 11.0, armor_color)
	
	# Head
	draw_circle(Vector2(0, -4), 8.5, Color(0.85, 0.7, 0.55))
	# Hair (Henry's brown peasant bowl/bob haircut)
	draw_arc(Vector2(0, -6), 9.0, -PI, 0.0, 16, Color(0.3, 0.2, 0.12), 4.0)
	
	# Weapon / Sword hand facing look_dir
	var sword_base := look_dir * 18.0
	var sword_tip := sword_base + look_dir * (38.0 if not is_attacking else 52.0)
	
	if is_attacking:
		# Attack slash arc trail
		var side := Vector2(-look_dir.y, look_dir.x)
		var trail_color := Color(1.0, 0.9, 0.5, 0.6)
		draw_line(sword_base - side * 15.0, sword_tip + side * 10.0, trail_color, 4.0)
	
	# Draw Arming Sword
	draw_line(sword_base, sword_tip, Color(0.9, 0.92, 0.95), 3.0)
	# Crossguard
	var guard_norm := Vector2(-look_dir.y, look_dir.x)
	draw_line(sword_base - guard_norm * 8.0, sword_base + guard_norm * 8.0, Color(0.85, 0.75, 0.3), 3.0)
	
	# Skalitz Shield on left arm
	var shield_pos := Vector2(-look_dir.y, look_dir.x) * 16.0
	var shield_pts := PackedVector2Array([
		shield_pos + Vector2(-6, -10),
		shield_pos + Vector2(6, -10),
		shield_pos + Vector2(5, 4),
		shield_pos + Vector2(0, 11),
		shield_pos + Vector2(-5, 4)
	])
	draw_colored_polygon(shield_pts, Color(0.72, 0.18, 0.14)) # Red shield with gold cross
	draw_line(shield_pos + Vector2(0, -8), shield_pos + Vector2(0, 8), Color(0.95, 0.85, 0.3), 1.5)
