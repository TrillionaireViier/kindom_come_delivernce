class_name CombatReticle
extends Control

signal direction_changed(new_dir: int)

enum Direction {
	TOP = 0,
	TOP_RIGHT = 1,
	BOTTOM_RIGHT = 2,
	BOTTOM_LEFT = 3,
	TOP_LEFT = 4,
	THRUST = 5
}

@export var radius: float = 64.0
@export var active_direction: int = Direction.TOP
@export var perfect_block_window_active: bool = false

# Visual styling
var _color_idle := Color(0.85, 0.75, 0.55, 0.4)
var _color_active := Color(0.95, 0.22, 0.18, 0.95)
var _color_glow := Color(1.0, 0.85, 0.25, 1.0)
var _color_parry_green := Color(0.18, 0.95, 0.35, 1.0)

var _pulse_timer: float = 0.0

func _process(delta: float) -> void:
	_pulse_timer += delta * 6.0
	queue_redraw()

func set_active_direction(dir: int) -> void:
	if active_direction != dir:
		active_direction = dir
		direction_changed.emit(active_direction)
		queue_redraw()

func trigger_parry_window(duration: float = 0.4) -> void:
	perfect_block_window_active = true
	var tween := create_tween()
	tween.tween_callback(func(): queue_redraw())
	tween.tween_interval(duration)
	tween.tween_callback(func():
		perfect_block_window_active = false
		queue_redraw()
	)

func _draw() -> void:
	var center := size * 0.5
	
	# Draw center hub / thrust indicator
	var is_thrust := active_direction == Direction.THRUST
	var center_color := _color_active if is_thrust else _color_idle
	draw_circle(center, 9.0, center_color)
	draw_circle(center, 4.0, Color.WHITE if is_thrust else Color(0.4, 0.35, 0.25))
	
	# The 5 angles in radians (0 is top: -PI/2)
	# Angles: Top, Top-Right, Bottom-Right, Bottom-Left, Top-Left
	var angles := [
		-PI * 0.5,             # 0: Top
		-PI * 0.1,             # 1: Top-Right
		PI * 0.3,              # 2: Bottom-Right
		PI * 0.7,              # 3: Bottom-Left
		-PI * 0.9              # 4: Top-Left
	]
	
	for i in range(5):
		var angle: float = angles[i]
		var dir_vec := Vector2(cos(angle), sin(angle))
		var is_active := (active_direction == i)
		
		var line_color := _color_active if is_active else _color_idle
		var line_width := 4.5 if is_active else 2.0
		
		var start_pt := center + dir_vec * 14.0
		var end_pt := center + dir_vec * radius
		
		# Draw petal line
		draw_line(start_pt, end_pt, line_color, line_width, true)
		
		# Draw arrowhead / diamond tip
		var tip_size := 8.0 if is_active else 5.0
		var normal := Vector2(-dir_vec.y, dir_vec.x)
		var p1 := end_pt
		var p2 := end_pt - dir_vec * tip_size + normal * (tip_size * 0.6)
		var p3 := end_pt - dir_vec * (tip_size * 0.4)
		var p4 := end_pt - dir_vec * tip_size - normal * (tip_size * 0.6)
		
		var tip_poly := PackedVector2Array([p1, p2, p3, p4])
		draw_colored_polygon(tip_poly, _color_glow if is_active else line_color)
	
	# Draw Perfect Block (Green Shield) prompt if active
	if perfect_block_window_active:
		var green_scale := 1.0 + sin(_pulse_timer) * 0.15
		var shield_pts := PackedVector2Array([
			center + Vector2(-12, -14) * green_scale,
			center + Vector2(12, -14) * green_scale,
			center + Vector2(10, 4) * green_scale,
			center + Vector2(0, 16) * green_scale,
			center + Vector2(-10, 4) * green_scale
		])
		draw_colored_polygon(shield_pts, _color_parry_green)
		# Inner cross
		draw_line(center + Vector2(0, -10), center + Vector2(0, 10), Color.WHITE, 2.5)
		draw_line(center + Vector2(-6, -3), center + Vector2(6, -3), Color.WHITE, 2.5)
