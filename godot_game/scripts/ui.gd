class_name GameUI
extends CanvasLayer

# ====================================================================
# KINGDOM COME: DELIVERANCE - HISTORICAL HUD & VISOR SHADER
# Real-time Charisma/Hygiene, Bleeding Wounds, Half-Swording Badge,
# and 15th-Century Klappvisier Helmet Eye-Slit Camera Shader.
# ====================================================================

const SoundManager = preload("res://scripts/sound_manager.gd")

signal open_lockpick_requested
signal open_grindstone_requested
signal return_to_menu_requested

@onready var health_bar: ProgressBar = $ParchmentHUD/VBox/HealthBar
@onready var stamina_bar: ProgressBar = $ParchmentHUD/VBox/StaminaBar
@onready var hunger_label: Label = $ParchmentHUD/VBox/HungerLabel
@onready var quest_banner: Label = $TopBanner/QuestLabel
@onready var prompt_label: Label = $PromptLabel
@onready var inventory_panel: Panel = $InventoryPanel

var groschen: int = 120
var schnapps_count: int = 3
var sword_sharpness_pct: int = 100

var charisma_val: float = 12.0
var dirt_val: float = 0.05
var blood_val: float = 0.0
var active_bleeds: int = 0
var is_half_swording: bool = false
var is_visor_down: bool = false

# Visor Shader Overlay
var visor_rect: ColorRect
var visor_material: ShaderMaterial
var visor_opacity: float = 0.0 # 0.0 (raised) to 1.0 (lowered)
var breathing_time: float = 0.0

var status_label: Label

func _ready() -> void:
	if inventory_panel:
		inventory_panel.visible = false
	
	if prompt_label:
		prompt_label.text = "[LMB] Strike | [RMB] Master Strike | [F] Thrust | [T] Half-Sword | [V] Visor | [C] Bandage | [B] Bathhouse | [E] Grindstone | [L] Lockpick | [H] Schnapps"
	
	# Add extra status label in Parchment HUD for Charisma, Hygiene & Stances
	var vbox: VBoxContainer = $ParchmentHUD/VBox
	if vbox:
		status_label = Label.new()
		status_label.name = "SurvivalStatusLabel"
		status_label.theme_override_font_sizes.font_size = 11
		status_label.theme_override_colors.font_color = Color(0.9, 0.85, 0.65)
		vbox.add_child(status_label)
		_update_status_display()
	
	# Initialize full-screen Klappvisier Bascinet Visor Overlay Shader
	_setup_visor_overlay()

func _setup_visor_overlay() -> void:
	visor_rect = ColorRect.new()
	visor_rect.name = "KlappvisierOverlay"
	visor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var shader := load("res://shaders/visor_helmet_overlay.gdshader") as Shader
	if shader:
		visor_material = ShaderMaterial.new()
		visor_material.shader = shader
		visor_material.set_shader_parameter("visor_lowered", 0.0)
		visor_material.set_shader_parameter("eye_slit_height", 0.16)
		visor_material.set_shader_parameter("breathing_pulse", 0.0)
		visor_rect.material = visor_material
	
	# Insert visor overlay behind HUD so buttons/bars remain readable
	add_child(visor_rect)
	move_child(visor_rect, 0)

func _process(delta: float) -> void:
	# Animate Visor Transition & Breathing Condensation
	var target_opacity := 1.0 if is_visor_down else 0.0
	visor_opacity = move_toward(visor_opacity, target_opacity, delta * 3.5)
	
	if visor_opacity > 0.01:
		breathing_time += delta * 1.4
		if breathing_time > TAU * 10.0:
			breathing_time = fmod(breathing_time, TAU)
		
		if visor_material:
			visor_material.set_shader_parameter("visor_lowered", visor_opacity)
			visor_material.set_shader_parameter("breathing_pulse", (sin(breathing_time) + 1.0) * 0.5)
	elif visor_material:
		visor_material.set_shader_parameter("visor_lowered", 0.0)

func update_stats(hp: float, stamina: float, hunger: float) -> void:
	if health_bar:
		health_bar.value = hp
	if stamina_bar:
		stamina_bar.value = stamina
	if hunger_label:
		if hunger > 70.0:
			hunger_label.text = "⚠️ Henry: \"I feel quite hungry!\" (Press H)"
			hunger_label.modulate = Color(1.0, 0.4, 0.2)
		else:
			hunger_label.text = "Nourishment: Satisfied"
			hunger_label.modulate = Color(0.85, 0.8, 0.7)

func update_survival(charisma: float, dirt: float, blood: float, bleeds: int) -> void:
	charisma_val = charisma
	dirt_val = dirt
	blood_val = blood
	active_bleeds = bleeds
	_update_status_display()

func set_half_swording(active: bool) -> void:
	is_half_swording = active
	_update_status_display()

func set_visor(is_down: bool) -> void:
	is_visor_down = is_down
	_update_status_display()

func _update_status_display() -> void:
	if not status_label:
		return
	
	var stance_str := "⚔️ Stance: " + ("HALF-SWORD" if is_half_swording else "Standard")
	var visor_str := " | Visor: " + ("DOWN [V]" if is_visor_down else "UP [V]")
	var charisma_str := "\n👑 Charisma: " + str(snapped(charisma_val, 0.1)) + " (Dirt: " + str(int(dirt_val * 100)) + "%, Blood: " + str(int(blood_val * 100)) + "%)"
	
	var bleed_str := ""
	if active_bleeds > 0:
		bleed_str = "\n🩸 BLEEDING (" + str(active_bleeds) + " WOUNDS) - Press [C] Bandage!"
		status_label.modulate = Color(1.0, 0.35, 0.3)
	else:
		status_label.modulate = Color(0.9, 0.88, 0.75)
	
	status_label.text = stance_str + visor_str + charisma_str + bleed_str

func show_notification(text: String, duration: float = 3.2) -> void:
	if quest_banner:
		quest_banner.text = text
		var tween := create_tween()
		quest_banner.modulate = Color(1.0, 0.9, 0.3)
		tween.tween_interval(duration)
		tween.tween_property(quest_banner, "modulate", Color(0.9, 0.85, 0.75), 0.5)

func toggle_inventory() -> void:
	if inventory_panel:
		inventory_panel.visible = not inventory_panel.visible
		if inventory_panel.visible:
			SoundManager.play("drink", 1.4)
			_update_inventory_ui()

func _update_inventory_ui() -> void:
	var label: Label = inventory_panel.get_node_or_null("VBox/ItemsLabel")
	if label:
		label.text = "• Groschen: " + str(groschen) + "\n" \
			+ "• Savior Schnapps (Save & Heal): " + str(schnapps_count) + " (Key [H])\n" \
			+ "• Skalitz Arming Sword (Sharpness: " + str(sword_sharpness_pct) + "%)\n" \
			+ "• Milanese Brigandine & Iron Klappvisier Bascinet\n" \
			+ "• Linen Bandages: 4 (Key [C])\n" \
			+ "• Master Strike: Liechtenauer 5-Point Counters [Learned]\n" \
			+ "• Half-Swording: Close Quarters Gripping [Unlocked]"
