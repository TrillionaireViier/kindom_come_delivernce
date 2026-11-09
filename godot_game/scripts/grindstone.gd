class_name GrindstoneMinigame
extends Control

const SoundManager = preload("res://scripts/sound_manager.gd")

signal sharpening_complete(sharpness_level: float)
signal closed

var wheel_speed: float = 0.0 # Revs/sec
var wheel_rotation: float = 0.0
var blade_position: float = 0.5 # 0.0 to 1.0 along blade
var blade_angle: float = 25.0 # Degrees
var blade_contact: bool = false
var sharpness: float = 40.0 # 0 to 100

var sparks: Array[Vector2] = []
var spark_vels: Array[Vector2] = []
var spark_lifetimes: Array[float] = []

var audio_cooldown: float = 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# Space bar pumps the foot treadle to accelerate the stone wheel
	if Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		wheel_speed = minf(16.0, wheel_speed + delta * 20.0)
	else:
		wheel_speed = maxf(0.0, wheel_speed - delta * 3.5)
	
	wheel_rotation += wheel_speed * delta * TAU
	
	# Mouse Y controls blade contact, Mouse X controls blade slide
	var mouse := get_local_mouse_position()
	var wheel_center := size * 0.5 + Vector2(0, 40)
	
	# Check contact with top of wheel
	var dist_to_rim := (mouse - wheel_center).length()
	blade_contact = (dist_to_rim >= 110.0 and dist_to_rim <= 135.0 and mouse.y < wheel_center.y)
	
	# Angle control with 'A' and 'D'
	if Input.is_key_pressed(KEY_A):
		blade_angle = maxf(10.0, blade_angle - delta * 30.0)
	if Input.is_key_pressed(KEY_D):
		blade_angle = minf(60.0, blade_angle + delta * 30.0)
	
	if audio_cooldown > 0.0:
		audio_cooldown -= delta
	
	# Sharpening evaluation
	if blade_contact and wheel_speed > 4.0:
		var is_optimal_angle := (blade_angle >= 20.0 and blade_angle <= 32.0)
		if is_optimal_angle:
			sharpness = minf(100.0, sharpness + delta * 15.0)
			# Spawn orange sparks
			_emit_sparks(mouse, 5)
			if audio_cooldown <= 0.0:
				SoundManager.play("grindstone", 1.2)
				audio_cooldown = 0.15
		else:
			# Dulling from wrong angle
			sharpness = maxf(10.0, sharpness - delta * 5.0)
			_emit_smoke(mouse, 2)
	
	# Update spark particles
	_update_sparks(delta)
	
	if Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_E):
		sharpening_complete.emit(sharpness / 100.0)
		closed.emit()
	
	queue_redraw()

func _emit_sparks(origin: Vector2, count: int) -> void:
	for i in range(count):
		sparks.append(origin)
		var angle := randf_range(-PI * 0.8, -PI * 0.2)
		var spd := randf_range(140.0, 320.0)
		spark_vels.append(Vector2(cos(angle), sin(angle)) * spd)
		spark_lifetimes.append(randf_range(0.15, 0.4))

func _emit_smoke(origin: Vector2, count: int) -> void:
	for i in range(count):
		sparks.append(origin)
		var angle := randf_range(-PI * 0.7, -PI * 0.3)
		spark_vels.append(Vector2(cos(angle), sin(angle)) * 40.0)
		spark_lifetimes.append(randf_range(0.3, 0.6))

func _update_sparks(delta: float) -> void:
	var idx := 0
	while idx < sparks.size():
		spark_lifetimes[idx] -= delta
		if spark_lifetimes[idx] <= 0.0:
			sparks.remove_at(idx)
			spark_vels.remove_at(idx)
			spark_lifetimes.remove_at(idx)
		else:
			spark_vels[idx].y += 500.0 * delta # Gravity
			sparks[idx] += spark_vels[idx] * delta
			idx += 1

func _draw() -> void:
	var wheel_center := size * 0.5 + Vector2(0, 40)
	var wheel_rad := 120.0
	
	# Wooden Trough & Frame
	draw_rect(Rect2(wheel_center.x - 140, wheel_center.y - 30, 280, 160), Color(0.25, 0.16, 0.1))
	draw_rect(Rect2(wheel_center.x - 130, wheel_center.y + 40, 260, 80), Color(0.15, 0.25, 0.35, 0.8)) # Water
	
	# Rotating Sandstone Grindstone Wheel
	draw_circle(wheel_center, wheel_rad, Color(0.55, 0.52, 0.48))
	draw_arc(wheel_center, wheel_rad, 0, TAU, 48, Color(0.38, 0.35, 0.32), 6.0)
	
	# Stone grooves to visualize rotation
	for i in range(12):
		var ang := wheel_rotation + float(i) * TAU / 12.0
		var p1 := wheel_center + Vector2(cos(ang), sin(ang)) * 25.0
		var p2 := wheel_center + Vector2(cos(ang), sin(ang)) * (wheel_rad - 10.0)
		draw_line(p1, p2, Color(0.42, 0.4, 0.36), 3.0)
	
	# Iron Center Axle
	draw_circle(wheel_center, 22.0, Color(0.2, 0.2, 0.2))
	draw_circle(wheel_center, 8.0, Color(0.7, 0.7, 0.7))
	
	# Draw Broadsword held in Henry's hands
	var mouse := get_local_mouse_position()
	var sword_color := Color(0.9, 0.92, 0.95)
	var blade_len := 220.0
	var rad_ang := deg_to_rad(blade_angle)
	var sword_dir := Vector2(cos(rad_ang), sin(rad_ang))
	
	var hilt_pos := mouse - sword_dir * 140.0
	var tip_pos := mouse + sword_dir * 80.0
	
	# Steel Blade
	draw_line(hilt_pos, tip_pos, sword_color, 8.0)
	# Fuller groove
	draw_line(hilt_pos + sword_dir * 20.0, tip_pos - sword_dir * 20.0, Color(0.5, 0.55, 0.6), 2.5)
	# Crossguard
	var guard_norm := Vector2(-sword_dir.y, sword_dir.x)
	draw_line(hilt_pos - guard_norm * 25.0, hilt_pos + guard_norm * 25.0, Color(0.85, 0.75, 0.25), 6.0)
	
	# Draw Sparks
	for i in range(sparks.size()):
		var is_smoke := spark_vels[i].length() < 70.0
		var sp_color := Color(0.7, 0.7, 0.7, 0.5) if is_smoke else Color(1.0, 0.8, 0.2, 0.9)
		draw_circle(sparks[i], 2.5 if not is_smoke else 4.0, sp_color)
	
	# Sharpness & Instructions HUD
	var font := ThemeDB.fallback_font
	var bar_w := 260.0
	var bar_x := size.x * 0.5 - bar_w * 0.5
	var bar_y := 40.0
	
	draw_rect(Rect2(bar_x, bar_y, bar_w, 18), Color(0.1, 0.1, 0.1, 0.8))
	var pct := clampf(sharpness / 100.0, 0.0, 1.0)
	draw_rect(Rect2(bar_x, bar_y, bar_w * pct, 18), Color(0.3, 0.8, 0.4).lerp(Color(1.0, 0.85, 0.2), pct))
	
	draw_string(font, Vector2(bar_x, bar_y - 8), "BLADE SHARPNESS: " + str(int(sharpness)) + "% (+Damage Bonus)", HORIZONTAL_ALIGNMENT_CENTER, int(bar_w), 14, Color.WHITE)
	draw_string(font, Vector2(bar_x, bar_y + 36), "Optimal Angle: 20°-32° | Current: " + str(int(blade_angle)) + "°", HORIZONTAL_ALIGNMENT_CENTER, int(bar_w), 13, Color(0.9, 0.85, 0.6))
	draw_string(font, Vector2(bar_x - 100, size.y - 40), "Pump [SPACE] for Wheel Speed | [A/D] Change Blade Angle | [E / ESC] Finish", HORIZONTAL_ALIGNMENT_CENTER, int(bar_w + 200), 14, Color.LIGHT_GRAY)
