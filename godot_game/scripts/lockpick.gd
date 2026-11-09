class_name LockpickingMinigame
extends Control

const SoundManager = preload("res://scripts/sound_manager.gd")

signal unlocked(chest_loot: Dictionary)
signal closed

@export var lock_difficulty: float = 1.0 # 1.0 = Normal, 2.0 = Hard

var lock_center: Vector2
var lock_radius: float = 160.0

# Secret sweet spot
var sweet_spot_angle: float = 0.0 # Radians
var sweet_spot_radius: float = 90.0

# State
var lock_rotation: float = 0.0 # 0 to TAU
var cursor_pos: Vector2 = Vector2.ZERO
var cursor_relative_to_center: Vector2 = Vector2.ZERO

var is_sweet_spot: bool = false
var sweet_spot_proximity: float = 0.0 # 0.0 to 1.0

var pick_health: float = 100.0
var lockpicks_remaining: int = 5
var is_solved: bool = false
var shake_offset: Vector2 = Vector2.ZERO

var click_audio_cooldown: float = 0.0

func _ready() -> void:
	_reset_lock()

func _reset_lock() -> void:
	lock_rotation = 0.0
	is_solved = false
	pick_health = 100.0
	# Randomize sweet spot on circular ring
	sweet_spot_angle = randf_range(0.0, TAU)
	sweet_spot_radius = randf_range(45.0, 130.0)

func _process(delta: float) -> void:
	lock_center = size * 0.5
	var raw_mouse := get_local_mouse_position()
	cursor_pos = raw_mouse
	cursor_relative_to_center = cursor_pos - lock_center
	
	if click_audio_cooldown > 0.0:
		click_audio_cooldown -= delta
	
	if is_solved:
		queue_redraw()
		return
	
	# Compute current sweet spot in world coords (rotates with cylinder!)
	var cur_sweet_angle := sweet_spot_angle + lock_rotation
	var sweet_target := Vector2(cos(cur_sweet_angle), sin(cur_sweet_angle)) * sweet_spot_radius
	
	var dist_to_sweet := (cursor_relative_to_center - sweet_target).length()
	var tolerance := 24.0 / lock_difficulty
	
	sweet_spot_proximity = clampf(1.0 - (dist_to_sweet / (tolerance * 3.5)), 0.0, 1.0)
	is_sweet_spot = dist_to_sweet <= tolerance
	
	# Turning the lock with 'D' or Right key
	var wants_to_turn := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	if wants_to_turn:
		if is_sweet_spot:
			# Turn lock smoothly
			lock_rotation += delta * 1.6
			if click_audio_cooldown <= 0.0:
				SoundManager.play("lockpick_click", randf_range(0.9, 1.2))
				click_audio_cooldown = 0.12
			
			if lock_rotation >= PI * 1.2:
				_on_unlock_success()
		else:
			# Tension and pick damage!
			pick_health -= delta * 90.0
			shake_offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
			if click_audio_cooldown <= 0.0:
				SoundManager.play("lockpick_click", 0.6)
				click_audio_cooldown = 0.08
			
			if pick_health <= 0.0:
				_break_pick()
	else:
		# Spring back if released before unlock
		lock_rotation = maxf(0.0, lock_rotation - delta * 3.0)
		shake_offset = Vector2.ZERO
	
	queue_redraw()

func _break_pick() -> void:
	SoundManager.play("lockpick_break", 1.0)
	lockpicks_remaining = max(0, lockpicks_remaining - 1)
	lock_rotation = 0.0
	pick_health = 100.0
	shake_offset = Vector2.ZERO

func _on_unlock_success() -> void:
	is_solved = true
	SoundManager.play("victory", 1.1)
	var loot := {
		"groschen": 150,
		"schnapps": 2,
		"item": "Padded Milanese Gambeson"
	}
	unlocked.emit(loot)

func _draw() -> void:
	var center := lock_center + shake_offset
	
	# Outer lockplate (Iron ring with bolts)
	draw_circle(center, lock_radius + 20.0, Color(0.18, 0.16, 0.14))
	draw_arc(center, lock_radius + 20.0, 0, TAU, 32, Color(0.45, 0.38, 0.28), 5.0)
	
	# Rivets / bolts around rim
	for i in range(8):
		var ang := float(i) * TAU / 8.0
		var r_pos := center + Vector2(cos(ang), sin(ang)) * (lock_radius + 10.0)
		draw_circle(r_pos, 4.0, Color(0.35, 0.3, 0.22))
		draw_circle(r_pos, 2.0, Color(0.65, 0.55, 0.4))
	
	# Inner Rotating Cylinder
	draw_circle(center, lock_radius, Color(0.26, 0.24, 0.22))
	draw_arc(center, lock_radius, 0, TAU, 48, Color(0.55, 0.45, 0.32), 3.0)
	
	# Keyhole slot (rotates with lock_rotation)
	var kh_angle := lock_rotation
	var kh_dir := Vector2(cos(kh_angle), sin(kh_angle))
	var kh_norm := Vector2(-kh_dir.y, kh_dir.x)
	
	# Keyhole shape
	draw_circle(center + kh_dir * 10.0, 10.0, Color.BLACK)
	draw_line(center - kh_dir * 30.0, center + kh_dir * 30.0, Color.BLACK, 6.0)
	
	# Visual pick tool coming from edge to cursor
	draw_line(center + Vector2(0, lock_radius + 30), cursor_pos, Color(0.6, 0.65, 0.7), 3.0)
	
	# KCD Glowing Cursor orb: Grey if cold, Gold if hot sweet spot!
	var cursor_rad := 10.0 + sweet_spot_proximity * 8.0
	var cursor_color: Color
	if is_sweet_spot:
		cursor_color = Color(1.0, 0.85, 0.2, 0.95) # Glowing bright gold!
	else:
		cursor_color = Color(0.6, 0.6, 0.65, 0.5).lerp(Color(0.95, 0.75, 0.2, 0.8), sweet_spot_proximity)
	
	draw_circle(cursor_pos, cursor_rad, cursor_color)
	draw_circle(cursor_pos, 3.5, Color.WHITE)
	if is_sweet_spot:
		# Pulsing glow rings
		draw_arc(cursor_pos, cursor_rad + 4.0, 0, TAU, 24, Color(1.0, 0.9, 0.3, 0.6), 2.0)
	
	# UI text instructions
	var font := ThemeDB.fallback_font
	var status_text := "Hold [D] to Rotate while tracking the Golden Sweet Spot!"
	if is_solved:
		status_text = "CHEST UNLOCKED! (150 Groschen, 2 Savior Schnapps)"
	elif lockpicks_remaining <= 0:
		status_text = "All lockpicks broken! Ask Miller Peshek for more."
	
	draw_string(font, Vector2(center.x - 220, center.y + lock_radius + 48), status_text, HORIZONTAL_ALIGNMENT_CENTER, 440, 16, Color(0.95, 0.85, 0.6))
	draw_string(font, Vector2(center.x - 100, center.y - lock_radius - 28), "Lockpicks: " + str(lockpicks_remaining) + "  |  Tension: " + str(int(100 - pick_health)) + "%", HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color.WHITE)
