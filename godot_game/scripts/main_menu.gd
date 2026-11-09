class_name MainMenu
extends Control

const SoundManager = preload("res://scripts/sound_manager.gd")

var embers: Array[Vector2] = []
var ember_speeds: Array[float] = []

func _ready() -> void:
	SoundManager.init_audio(self)
	
	# Spawn ember particles
	for i in range(40):
		embers.append(Vector2(randf_range(0, 1280), randf_range(0, 720)))
		ember_speeds.append(randf_range(25.0, 75.0))

func _process(delta: float) -> void:
	for i in range(embers.size()):
		embers[i].y -= ember_speeds[i] * delta
		embers[i].x += sin(embers[i].y * 0.02) * delta * 15.0
		if embers[i].y < -10.0:
			embers[i].y = 730.0
			embers[i].x = randf_range(0, 1280)
	queue_redraw()

func _on_start_combat_pressed() -> void:
	SoundManager.play("sword_clash", 1.0)
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_lockpick_training_pressed() -> void:
	SoundManager.play("lockpick_click", 1.0)
	var world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	world.call_deferred("_open_lockpick")
	queue_free()

func _on_grindstone_pressed() -> void:
	SoundManager.play("grindstone", 1.0)
	var world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	world.call_deferred("_open_grindstone")
	queue_free()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _draw() -> void:
	# Dark medieval parchment background
	var bg_color := Color(0.08, 0.07, 0.06)
	draw_rect(Rect2(0, 0, 1280, 720), bg_color)
	
	# Gold filigree border
	draw_rect(Rect2(24, 24, 1232, 672), Color(0.65, 0.52, 0.25, 0.4), false, 2.0)
	draw_rect(Rect2(32, 32, 1216, 656), Color(0.45, 0.35, 0.18, 0.25), false, 1.0)
	
	# Draw floating embers
	for ember in embers:
		var col := Color(1.0, randf_range(0.4, 0.7), 0.1, randf_range(0.4, 0.85))
		draw_circle(ember, randf_range(1.5, 3.0), col)
