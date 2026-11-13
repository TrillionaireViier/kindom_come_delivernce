class_name GrindstoneMinigame
extends Control

# ====================================================================
# KINGDOM COME: DELIVERANCE - REALISTIC BLACKSMITH GRINDSTONE SHARPENING
# Friction physics simulation: RPM momentum, foot treadle pump,
# blade contact tangents, spark ejection kinematics, and thermal shader.
# ====================================================================

const SoundManager = preload("res://scripts/sound_manager.gd")

signal sharpening_complete(sharpness_level: float)
signal closed

var wheel_speed: float = 0.0 # Revs/sec (0 to 20)
var wheel_rotation: float = 0.0 # Radians
var blade_position: float = 0.5 # 0.0 to 1.0 along the cutting edge
var blade_angle: float = 26.0 # Degrees (Optimal: 20° - 32°)
var blade_contact: bool = false
var contact_intensity: float = 0.0 # 0.0 to 1.0 (heat & pressure)
var sharpness: float = 40.0 # 0 to 100
var blade_durability: float = 100.0 # 0 to 100

var sparks: Array[Vector2] = []
var spark_vels: Array[Vector2] = []
var spark_lifetimes: Array[float] = []

var audio_cooldown: float = 0.0
var wheel_rect: ColorRect
var wheel_material: ShaderMaterial

const WHEEL_RADIUS: float = 125.0

func _ready() -> void:
	# Create internal ColorRect dedicated to rendering the Sandstone Grindstone shader
	wheel_rect = ColorRect.new()
	wheel_rect.name = "SandstoneWheelViewport"
	wheel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader := load("res://shaders/grindstone_wheel.gdshader") as Shader
	if shader:
		wheel_material = ShaderMaterial.new()
		wheel_material.shader = shader
		wheel_rect.material = wheel_material
	add_child(wheel_rect)

func _process(delta: float) -> void:
	var wheel_center := size * 0.5 + Vector2(0, 40)
	
	# Update wheel rect placement to match canvas center
	if wheel_rect:
		wheel_rect.position = wheel_center - Vector2(WHEEL_RADIUS, WHEEL_RADIUS)
		wheel_rect.size = Vector2(WHEEL_RADIUS * 2.0, WHEEL_RADIUS * 2.0)
	
	# 1. Foot Treadle Pump Acceleration (Space bar or Left Click)
	# Mimics physical foot pedal pumping in 15th-century Bohemian forges
	if Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		wheel_speed = minf(18.0, wheel_speed + delta * 22.0)
	else:
		# Natural bearing & water trough rotational friction decay
		wheel_speed = maxf(0.0, wheel_speed - delta * 4.0)
	
	wheel_rotation += wheel_speed * delta * TAU
	if wheel_rotation > TAU * 100.0:
		wheel_rotation = fmod(wheel_rotation, TAU)
	
	# 2. Blade Contact & Kinematic Tracking
	# Mouse Y controls contact pressure against stone rim, Mouse X slides blade laterally
	var mouse := get_local_mouse_position()
	var to_mouse := mouse - wheel_center
	var dist_to_rim := to_mouse.length()
	
	# Contact happens at top/upper arc of the grindstone rim
	blade_contact = (dist_to_rim >= WHEEL_RADIUS - 15.0 and dist_to_rim <= WHEEL_RADIUS + 15.0 and mouse.y < wheel_center.y)
	blade_position = clampf((mouse.x - (wheel_center.x - 100.0)) / 200.0, 0.0, 1.0)
	
	# 3. Blade Bevel Angle Control ('A' decreases bevel, 'D' increases bevel)
	if Input.is_key_pressed(KEY_A):
		blade_angle = maxf(8.0, blade_angle - delta * 32.0)
	if Input.is_key_pressed(KEY_D):
		blade_angle = minf(65.0, blade_angle + delta * 32.0)
	
	# 4. Thermal Friction & Sharpening Physics
	var is_optimal_angle := (blade_angle >= 20.0 and blade_angle <= 32.0)
	
	if blade_contact and wheel_speed > 3.0:
		contact_intensity = minf(1.0, contact_intensity + delta * 3.5)
		
		if is_optimal_angle:
			# High-friction abrasive honing on grit
			sharpness = minf(100.0, sharpness + delta * 16.5)
			# Tangential sparks fly off wheel rotation
			_emit_tangential_sparks(mouse, wheel_center, 6, wheel_speed)
			
			if audio_cooldown <= 0.0:
				SoundManager.play("grindstone", 1.25)
				audio_cooldown = 0.12
		else:
			# Wrong bevel angle ruins the cutting edge and creates smoke
			sharpness = maxf(5.0, sharpness - delta * 8.0)
			blade_durability = maxf(0.0, blade_durability - delta * 6.0)
			_emit_smoke_particles(mouse, 3)
	else:
		contact_intensity = maxf(0.0, contact_intensity - delta * 2.0)
	
	if audio_cooldown > 0.0:
		audio_cooldown -= delta
	
	# 5. Push Real-Time Parameters to Grindstone Shader
	if wheel_material and wheel_rect:
		var contact_uv := (mouse - wheel_rect.position) / wheel_rect.size
		wheel_material.set_shader_parameter("wheel_rotation", wheel_rotation)
		wheel_material.set_shader_parameter("wheel_speed", wheel_speed)
		wheel_material.set_shader_parameter("contact_point_uv", contact_uv)
		wheel_material.set_shader_parameter("contact_intensity", contact_intensity)
		wheel_material.set_shader_parameter("water_wetness", 0.85)
	
	# 6. Particle Physics Update
	_update_sparks(delta)
	
	# 7. Exit Minigame
	if Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_E):
		sharpening_complete.emit(sharpness / 100.0)
		closed.emit()
	
	queue_redraw()

func _emit_tangential_sparks(contact: Vector2, center: Vector2, count: int, speed: float) -> void:
	var radial_vec := (contact - center).normalized()
	# Tangent vector of clockwise rotation: (-y, x)
	var tangent := Vector2(-radial_vec.y, radial_vec.x)
	var base_lin_speed := speed * 28.0 + 120.0
	
	for i in range(count):
		sparks.append(contact)
		# Spread angle cone: +/- 18 degrees around tangent
		var spread_angle := randf_range(-0.32, 0.32)
		var dir := tangent.rotated(spread_angle)
		var spd := randf_range(base_lin_speed * 0.7, base_lin_speed * 1.35)
		spark_vels.append(dir * spd)
		spark_lifetimes.append(randf_range(0.18, 0.42))

func _emit_smoke_particles(origin: Vector2, count: int) -> void:
	for i in range(count):
		sparks.append(origin)
		var angle := randf_range(-PI * 0.75, -PI * 0.25)
		spark_vels.append(Vector2(cos(angle), sin(angle)) * randf_range(30.0, 60.0))
		spark_lifetimes.append(randf_range(0.35, 0.75))

func _update_sparks(delta: float) -> void:
	var idx := 0
	while idx < sparks.size():
		spark_lifetimes[idx] -= delta
		if spark_lifetimes[idx] <= 0.0:
			sparks.remove_at(idx)
			spark_vels.remove_at(idx)
			spark_lifetimes.remove_at(idx)
		else:
			# Atmospheric gravity and aerodynamic drag
			spark_vels[idx].y += 480.0 * delta
			spark_vels[idx] *= (1.0 - 0.4 * delta)
			sparks[idx] += spark_vels[idx] * delta
			idx += 1

func _draw() -> void:
	var wheel_center := size * 0.5 + Vector2(0, 40)
	
	# Wooden Grindstone Trough Frame
	draw_rect(Rect2(wheel_center.x - 145, wheel_center.y - 20, 290, 165), Color(0.24, 0.16, 0.10))
	draw_rect(Rect2(wheel_center.x - 135, wheel_center.y + 40, 270, 85), Color(0.14, 0.22, 0.32, 0.85)) # Water Trough
	
	# If shader is unavailable fallback to procedural wheel draw
	if not wheel_material:
		draw_circle(wheel_center, WHEEL_RADIUS, Color(0.55, 0.52, 0.48))
		draw_arc(wheel_center, WHEEL_RADIUS, 0, TAU, 48, Color(0.38, 0.35, 0.32), 6.0)
		for i in range(12):
			var ang := wheel_rotation + float(i) * TAU / 12.0
			var p1 := wheel_center + Vector2(cos(ang), sin(ang)) * 25.0
			var p2 := wheel_center + Vector2(cos(ang), sin(ang)) * (WHEEL_RADIUS - 10.0)
			draw_line(p1, p2, Color(0.42, 0.4, 0.36), 3.0)
	
	# Iron Center Axle & Mounting Bolt
	draw_circle(wheel_center, 22.0, Color(0.18, 0.18, 0.20))
	draw_circle(wheel_center, 8.0, Color(0.65, 0.65, 0.70))
	
	# Broadsword held in Henry's Hands
	var mouse := get_local_mouse_position()
	var sword_color := Color(0.92, 0.94, 0.97)
	var rad_ang := deg_to_rad(blade_angle)
	var sword_dir := Vector2(cos(rad_ang), sin(rad_ang))
	
	var hilt_pos := mouse - sword_dir * 140.0
	var tip_pos := mouse + sword_dir * 85.0
	
	# Steel Blade with Fuller Groove
	draw_line(hilt_pos, tip_pos, sword_color, 8.0)
	draw_line(hilt_pos + sword_dir * 20.0, tip_pos - sword_dir * 20.0, Color(0.48, 0.54, 0.62), 2.5)
	
	# Brass Crossguard & Pommel
	var guard_norm := Vector2(-sword_dir.y, sword_dir.x)
	draw_line(hilt_pos - guard_norm * 26.0, hilt_pos + guard_norm * 26.0, Color(0.86, 0.76, 0.28), 6.5)
	draw_circle(hilt_pos - sword_dir * 28.0, 8.0, Color(0.86, 0.76, 0.28))
	
	# Contact Spark & Smoke Render
	for i in range(sparks.size()):
		var is_smoke := spark_vels[i].length() < 90.0
		if is_smoke:
			draw_circle(sparks[i], 4.5, Color(0.65, 0.65, 0.65, 0.45))
		else:
			var heat_ratio := clampf(spark_lifetimes[i] / 0.35, 0.0, 1.0)
			var spark_col := Color(1.0, 0.45, 0.05).lerp(Color(1.0, 0.95, 0.4), heat_ratio)
			draw_circle(sparks[i], 2.8, spark_col)
			# Spark trail line
			draw_line(sparks[i], sparks[i] - spark_vels[i] * 0.015, spark_col, 1.8)
	
	# HUD: Blade Sharpness, Angle Gauge & Instructions
	var font := ThemeDB.fallback_font
	var bar_w := 280.0
	var bar_x := size.x * 0.5 - bar_w * 0.5
	var bar_y := 40.0
	
	# Sharpness Bar
	draw_rect(Rect2(bar_x, bar_y, bar_w, 20), Color(0.08, 0.08, 0.1, 0.85))
	var pct := clampf(sharpness / 100.0, 0.0, 1.0)
	var bar_col := Color(0.85, 0.25, 0.2).lerp(Color(0.25, 0.85, 0.35), pct)
	draw_rect(Rect2(bar_x, bar_y, bar_w * pct, 20), bar_col)
	draw_rect(Rect2(bar_x, bar_y, bar_w, 20), Color(0.6, 0.55, 0.4), false, 1.5)
	
	draw_string(font, Vector2(bar_x, bar_y - 8), "BLADE SHARPNESS: %d%% (+Damage Bonus)" % int(sharpness), HORIZONTAL_ALIGNMENT_CENTER, int(bar_w), 14, Color.WHITE)
	
	# Angle Indicator
	var is_optimal := (blade_angle >= 20.0 and blade_angle <= 32.0)
	var angle_col := Color(0.3, 0.9, 0.4) if is_optimal else Color(0.9, 0.3, 0.2)
	draw_string(font, Vector2(bar_x, bar_y + 40), "Optimal Angle: 20°-32° | Current: %d° %s" % [int(blade_angle), "(PERFECT)" if is_optimal else "(POOR)"], HORIZONTAL_ALIGNMENT_CENTER, int(bar_w), 13, angle_col)
	
	# RPM Gauge
	var rpm_text := "Wheel RPM: %d / 1080" % int(wheel_speed * 60.0)
	draw_string(font, Vector2(bar_x, bar_y + 60), rpm_text, HORIZONTAL_ALIGNMENT_CENTER, int(bar_w), 12, Color(0.7, 0.75, 0.85))
	
	draw_string(font, Vector2(bar_x - 120, size.y - 40), "Pump [SPACE / LMB] Treadle | [A/D] Bevel Angle | Mouse: Blade Contact | [E / ESC] Finish", HORIZONTAL_ALIGNMENT_CENTER, int(bar_w + 240), 13, Color.LIGHT_GRAY)
