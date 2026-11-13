class_name EnemyCuman
extends CharacterBody2D

const SoundManager = preload("res://scripts/sound_manager.gd")
const PlayerHenry = preload("res://scripts/player.gd")

signal enemy_defeated(enemy_name: String)

@export var enemy_name: String = "Cuman Raider"
@export var max_health: float = 90.0
@export var max_stamina: float = 80.0
@export var attack_cooldown_min: float = 1.4
@export var attack_cooldown_max: float = 2.6

var health: float = 90.0
var stamina: float = 80.0
var guard_direction: int = 0 # 0=Top, 1=TR, 2=BR, 3=BL, 4=TL, 5=Thrust

var target: PlayerHenry
var is_winding_up: bool = false
var windup_timer: float = 0.0
var attack_timer: float = 0.0
var ai_state_timer: float = 1.0

var is_dead: bool = false
var is_staggered: bool = false
var stagger_timer: float = 0.0
var is_surrendering: bool = false
var taunt_text: String = ""
var taunt_timer: float = 0.0

var look_dir: Vector2 = Vector2.LEFT

func _ready() -> void:
	health = max_health
	stamina = max_stamina
	add_to_group("enemies")

func _process(delta: float) -> void:
	if is_dead:
		return
	
	if is_staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			is_staggered = false
	
	stamina = minf(max_stamina, stamina + delta * 18.0)
	
	if taunt_timer > 0.0 and not is_surrendering:
		taunt_timer -= delta
	
	if windup_timer > 0.0 and not is_staggered:
		windup_timer -= delta
		if windup_timer <= 0.0:
			_execute_attack()
	
	if attack_timer > 0.0:
		attack_timer -= delta
	
	# If surrendering, check for player interaction [E] to accept yield
	if is_surrendering:
		if target and is_instance_valid(target):
			var dist := (target.global_position - global_position).length()
			if dist < 80.0 and Input.is_key_pressed(KEY_E):
				_accept_surrender()
		queue_redraw()
		return
	
	if target and is_instance_valid(target) and not is_staggered:
		var to_target := target.global_position - global_position
		look_dir = to_target.normalized()
		
		# AI combat loop
		ai_state_timer -= delta
		if ai_state_timer <= 0.0:
			_ai_decide()
	
	queue_redraw()

func _ai_decide() -> void:
	ai_state_timer = randf_range(attack_cooldown_min, attack_cooldown_max)
	
	if not target or is_dead or is_staggered or is_surrendering:
		return
	
	var dist := (target.global_position - global_position).length()
	
	# Occasionally switch guard stance
	if randf() < 0.6:
		guard_direction = randi() % 5
	
	# Attack if in range
	if dist < 95.0 and stamina >= 20.0 and not is_winding_up:
		_start_attack_windup()
	elif randf() < 0.3:
		_show_taunt()

func _start_attack_windup() -> void:
	if is_surrendering or is_dead or is_staggered:
		return
	is_winding_up = true
	windup_timer = 0.45
	var chosen_dir := randi() % 6
	guard_direction = chosen_dir
	
	if target and is_instance_valid(target):
		if target.has_method("notify_incoming_attack"):
			target.notify_incoming_attack(guard_direction, guard_direction == 5, 0.45, self)
		if target.reticle:
			target.reticle.trigger_parry_window(0.4)

func _execute_attack() -> void:
	is_winding_up = false
	attack_timer = 0.3
	stamina -= 18.0
	SoundManager.play("sword_swing", randf_range(0.85, 1.05))
	
	if target and is_instance_valid(target):
		var dist := (target.global_position - global_position).length()
		if dist < 100.0:
			var is_thrust := (guard_direction == 5)
			var dmg := 24.0 if not is_thrust else 20.0
			target.receive_attack(guard_direction, is_thrust, dmg, self)

func receive_attack(dir: int, is_thrust: bool, damage: float, attacker: Node) -> void:
	if is_dead:
		return
	
	# Check if Cuman blocks in matching guard direction
	var blocked := (dir == guard_direction and stamina > 15.0 and not is_winding_up)
	if blocked:
		stamina = maxf(0.0, stamina - damage * 0.7)
		SoundManager.play("sword_clash", randf_range(1.0, 1.3))
		_show_floating_text("BLOCKED!", Color.LIGHT_GRAY)
		return
	
	# Direct hit!
	health = maxf(0.0, health - damage)
	stamina = maxf(0.0, stamina - 10.0)
	SoundManager.play("armor_hit", 1.0)
	_show_floating_text("-" + str(int(damage)), Color.RED)
	
	if attacker is Node2D:
		velocity = (global_position - attacker.global_position).normalized() * 100.0
	
	if health <= 0.0:
		_die()

func receive_stagger(damage: float) -> void:
	if is_dead:
		return
	health = maxf(0.0, health - damage)
	stamina = maxf(0.0, stamina - 45.0)
	is_winding_up = false
	windup_timer = 0.0
	is_staggered = true
	stagger_timer = 1.35
	_show_floating_text("MEISTERHAU RIPOSTE! -" + str(int(damage)), Color.GOLD)
	if health <= 0.0:
		_die()
	elif health < 24.0 and not is_surrendering and randf() < 0.7:
		_trigger_surrender()

func _trigger_surrender() -> void:
	is_surrendering = true
	is_winding_up = false
	windup_timer = 0.0
	taunt_text = "Kérlek, ne ölj meg! I yield! [E] Accept Mercy (+Groschen)"
	taunt_timer = 999.0
	SoundManager.play("armor_hit", 0.7)

func _accept_surrender() -> void:
	is_dead = true
	SoundManager.play("victory", 1.2)
	enemy_defeated.emit(enemy_name)
	taunt_text = "Köszönöm! (Groschen surrendered)"
	taunt_timer = 2.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.8)
	tween.tween_callback(queue_free)

func _die() -> void:
	is_dead = true
	SoundManager.play("victory", 1.0)
	enemy_defeated.emit(enemy_name)
	taunt_text = "Argh! King Sigismund..."
	taunt_timer = 2.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 2.5)
	tween.tween_callback(queue_free)

func _show_taunt() -> void:
	var taunts := [
		"Kurva anyád!",
		"You fight like a peasant, Henry!",
		"Your Skalitz steel is soft!",
		"I will feast on your rations!",
		"Stand and die, boy!"
	]
	taunt_text = taunts[randi() % taunts.size()]
	taunt_timer = 2.0

func _show_floating_text(txt: String, col: Color) -> void:
	taunt_text = txt
	taunt_timer = 1.0

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	
	if is_surrendering or is_staggered:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * _delta)
		move_and_slide()
		return
	
	if target and is_instance_valid(target):
		var to_target := target.global_position - global_position
		var dist := to_target.length()
		
		# Move towards Henry if far, circle him if close
		if dist > 85.0:
			velocity = velocity.move_toward(to_target.normalized() * 120.0, 500.0 * _delta)
		elif dist < 65.0:
			velocity = velocity.move_toward(-to_target.normalized() * 80.0, 500.0 * _delta)
		else:
			# Strafe sideways
			var strafe := Vector2(-to_target.y, to_target.x).normalized()
			velocity = velocity.move_toward(strafe * 70.0, 400.0 * _delta)
	
	move_and_slide()

func _draw() -> void:
	# Draw Cuman Raider: Pointed Eastern Helmet, Fur Trim, Scale Armor, Saber
	var cuman_armor := Color(0.25, 0.28, 0.32)
	var cuman_gold := Color(0.85, 0.65, 0.25)
	var cuman_fur := Color(0.45, 0.32, 0.22)
	
	# Shadow
	draw_ellipse(Vector2(0, 8), 18.0, 9.0, Color(0, 0, 0, 0.35))
	
	# Body & Lamellar Scale Armor
	draw_circle(Vector2.ZERO, 16.0, cuman_armor)
	draw_circle(Vector2.ZERO, 12.0, cuman_fur)
	
	# Pointed Cuman Helmet with Brass Faceplate Mask
	draw_circle(Vector2(0, -4), 9.0, cuman_gold)
	draw_circle(Vector2(0, -8), 4.0, Color(0.9, 0.8, 0.4)) # Spire tip
	
	# Eastern Saber weapon or Hands Raised in Surrender
	if is_surrendering:
		# Hands raised in surrender
		draw_circle(Vector2(-10, -18), 3.5, cuman_gold)
		draw_circle(Vector2(10, -18), 3.5, cuman_gold)
		# Saber dropped on ground
		draw_line(Vector2(-14, 12), Vector2(16, 16), Color(0.8, 0.8, 0.85), 2.5)
	else:
		var saber_base := look_dir * 18.0
		var saber_tip := saber_base + look_dir * (36.0 if not is_winding_up else 20.0)
		draw_line(saber_base, saber_tip, Color(0.95, 0.95, 1.0), 3.0)
	
	# Health Bar above head
	var bar_width := 44.0
	var bar_height := 5.0
	var bar_y := -32.0
	
	# Background
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, bar_height), Color(0.1, 0.1, 0.1, 0.8))
	# Red health
	var hp_pct := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * hp_pct, bar_height), Color(0.9, 0.2, 0.2, 1.0))
	# Gold stamina
	var stam_pct := clampf(stamina / max_stamina, 0.0, 1.0)
	draw_rect(Rect2(-bar_width * 0.5, bar_y + 6.0, bar_width * stam_pct, 2.5), Color(0.95, 0.8, 0.2, 1.0))
	
	# Taunt / Floating Text
	if taunt_timer > 0.0 and taunt_text != "":
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-60, -42), taunt_text, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1.0, 0.95, 0.7))
