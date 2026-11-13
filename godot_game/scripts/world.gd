class_name GameWorld
extends Node2D

# ====================================================================
# KINGDOM COME: DELIVERANCE - BOHEMIA 1403 WORLD SIMULATOR
# Orchestrates Cuman AI, Master Strike frame traps, Directional Rose,
# Blacksmith Grindstone, Lockpicking, and Historical Bathhouse Hygiene.
# ====================================================================

const SoundManager = preload("res://scripts/sound_manager.gd")
const EnemyScene = preload("res://scenes/enemy.tscn")

@onready var player: CharacterBody2D = $Player
@onready var ui: CanvasLayer = $UI
@onready var reticle: Control = $UI/CombatReticle
@onready var lockpick_overlay: Control = $UI/LockpickOverlay
@onready var grindstone_overlay: Control = $UI/GrindstoneOverlay

var wave_count: int = 1
var kills_count: int = 0

func _ready() -> void:
	SoundManager.init_audio(self)
	
	if player and reticle:
		player.reticle = reticle
		player.stats_changed.connect(_on_player_stats_changed)
		player.blocked_attack.connect(_on_player_blocked)
		if player.has_signal("survival_updated") and ui:
			player.survival_updated.connect(ui.update_survival)
		if player.has_signal("visor_toggled") and ui:
			player.visor_toggled.connect(ui.set_visor)
		if player.has_signal("half_sword_toggled") and ui:
			player.half_sword_toggled.connect(ui.set_half_swording)
		if player.has_signal("master_strike_triggered"):
			player.master_strike_triggered.connect(_on_master_strike_triggered)
	
	if lockpick_overlay:
		lockpick_overlay.visible = false
		lockpick_overlay.unlocked.connect(_on_chest_unlocked)
	
	if grindstone_overlay:
		grindstone_overlay.visible = false
		grindstone_overlay.sharpening_complete.connect(_on_sharpening_done)
		grindstone_overlay.closed.connect(func(): grindstone_overlay.visible = false)
	
	# Spawn first Cuman raider
	_spawn_cuman()
	
	if ui:
		ui.show_notification("⚔️ Quest: Defend Skalitz! [WASD] Move | [Mouse] 5-Point Combat | [RMB] Master Strike | [V] Visor")

func _process(_delta: float) -> void:
	# Center reticle on player in canvas space
	if reticle and player:
		var screen_pos := player.get_global_transform_with_canvas().origin
		reticle.position = screen_pos - reticle.size * 0.5
	
	# Minigame shortcuts
	if Input.is_key_pressed(KEY_L) and not lockpick_overlay.visible and not grindstone_overlay.visible:
		_open_lockpick()
	elif Input.is_key_pressed(KEY_E) and not lockpick_overlay.visible and not grindstone_overlay.visible:
		# Check if near grindstone
		if player and (player.global_position - Vector2(160, 200)).length() < 120.0:
			_open_grindstone()
	elif Input.is_key_pressed(KEY_I):
		if ui:
			ui.toggle_inventory()

func _spawn_cuman() -> void:
	var enemy = EnemyScene.instantiate()
	enemy.enemy_name = "Cuman Raider #" + str(kills_count + 1)
	enemy.position = Vector2(850, 360) + Vector2(randf_range(-50, 50), randf_range(-80, 80))
	enemy.target = player
	enemy.enemy_defeated.connect(_on_enemy_defeated)
	add_child(enemy)

func _on_enemy_defeated(ename: String) -> void:
	kills_count += 1
	if ui:
		ui.groschen += 55
		ui.show_notification("🏆 " + ename + " neutralized! +55 Groschen looted from saddlebag.")
	
	# Spawn next wave enemy
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(player) and player.health > 0:
			_spawn_cuman()
	)

func _on_player_stats_changed(hp: float, stamina: float, hunger: float) -> void:
	if ui:
		ui.update_stats(hp, stamina, hunger)
	
	if hp <= 0.0:
		if ui:
			ui.show_notification("💀 Henry has fallen in battle! Press [R] to reload Savior Schnapps save.")
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()

func _on_player_blocked(perfect: bool) -> void:
	if perfect and ui:
		ui.show_notification("⚡ PERFECT DEFENSE!")

func _on_master_strike_triggered(tech_name: String) -> void:
	if ui:
		ui.show_notification("⚡ MASTER STRIKE: " + tech_name + "! Unblockable counter riposte!")

func _open_lockpick() -> void:
	if lockpick_overlay:
		lockpick_overlay.visible = true
		lockpick_overlay._reset_lock()

func _on_chest_unlocked(loot: Dictionary) -> void:
	if ui:
		ui.groschen += loot.get("groschen", 0)
		ui.schnapps_count += loot.get("schnapps", 0)
		ui.show_notification("🔓 Chest Unlocked! Found " + str(loot["groschen"]) + " Groschen & Savior Schnapps!")
	
	get_tree().create_timer(1.8).timeout.connect(func():
		if lockpick_overlay:
			lockpick_overlay.visible = false
	)

func _open_grindstone() -> void:
	if grindstone_overlay:
		grindstone_overlay.visible = true

func _on_sharpening_done(sharp_level: float) -> void:
	if player:
		player.sword_sharpness = 1.0 + sharp_level * 0.5
	if ui:
		ui.sword_sharpness_pct = int(sharp_level * 100.0)
		ui.show_notification("⚔️ Blade Honed to " + str(ui.sword_sharpness_pct) + "%! Increased cutting & thrust damage.")

func _draw() -> void:
	# Bohemian Castle Courtyard: Cobblestone, Fortress Walls, Blacksmith Forge, Bathhouse Trough
	var ground_color := Color(0.18, 0.16, 0.13)
	draw_rect(Rect2(0, 0, 1280, 720), ground_color)
	
	# Cobblestone grid markings
	var stone_tint := Color(0.24, 0.22, 0.18, 0.35)
	for x in range(0, 1280, 60):
		draw_line(Vector2(x, 0), Vector2(x, 720), stone_tint, 1.0)
	for y in range(0, 720, 60):
		draw_line(Vector2(0, y), Vector2(1280, y), stone_tint, 1.0)
	
	# Castle stone walls on top
	draw_rect(Rect2(0, 0, 1280, 80), Color(0.3, 0.28, 0.25))
	draw_line(Vector2(0, 80), Vector2(1280, 80), Color(0.45, 0.4, 0.35), 4.0)
	
	# Crenellations
	for b in range(0, 1280, 80):
		draw_rect(Rect2(b, 50, 40, 30), Color(0.22, 0.2, 0.18))
	
	# Blacksmith Forge stall on left
	draw_rect(Rect2(40, 140, 160, 120), Color(0.28, 0.18, 0.12)) # Wood stall
	draw_rect(Rect2(50, 150, 50, 50), Color(0.1, 0.1, 0.1)) # Anvil
	draw_circle(Vector2(160, 200), 22.0, Color(0.48, 0.45, 0.4)) # Grindstone
	
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(45, 130), "[E] Blacksmith Grindstone", HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color(0.9, 0.8, 0.5))
	
	# Bathhouse Water Trough (Key [B] to wash dirt & blood)
	draw_rect(Rect2(230, 155, 90, 50), Color(0.32, 0.22, 0.14)) # Wooden Tub
	draw_rect(Rect2(236, 160, 78, 40), Color(0.16, 0.32, 0.48, 0.85)) # Water
	draw_string(font, Vector2(220, 140), "[B] Bathhouse Trough (Wash)", HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color(0.65, 0.85, 0.95))
	
	# Miller's Locked Chest on right
	draw_rect(Rect2(1080, 150, 70, 45), Color(0.35, 0.22, 0.12)) # Chest
	draw_circle(Vector2(1115, 172), 6.0, Color(0.85, 0.7, 0.2)) # Brass lock
	draw_string(font, Vector2(1040, 135), "[L] Locked Chest", HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(0.9, 0.8, 0.5))
	
	# Skalitz Banner with Bohemia Two-Tailed Lion Crest
	var banner_pos := Vector2(640, 40)
	draw_rect(Rect2(banner_pos.x - 30, banner_pos.y, 60, 80), Color(0.75, 0.18, 0.14)) # Red banner
	draw_line(Vector2(banner_pos.x - 30, banner_pos.y + 80), Vector2(banner_pos.x, banner_pos.y + 65), Color(0.18, 0.16, 0.13), 2.0)
	draw_line(Vector2(banner_pos.x, banner_pos.y + 65), Vector2(banner_pos.x + 30, banner_pos.y + 80), Color(0.18, 0.16, 0.13), 2.0)
	draw_circle(banner_pos + Vector2(0, 35), 14.0, Color(0.9, 0.8, 0.3)) # Gold seal
