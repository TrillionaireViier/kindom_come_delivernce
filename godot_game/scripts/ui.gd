class_name GameUI
extends CanvasLayer

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

func _ready() -> void:
	if inventory_panel:
		inventory_panel.visible = false
	if prompt_label:
		prompt_label.text = "[E] Grindstone  |  [L] Lockpick Chest  |  [H] Drink Savior Schnapps  |  [I] Inventory"

func update_stats(hp: float, stamina: float, hunger: float) -> void:
	if health_bar:
		health_bar.value = hp
	if stamina_bar:
		stamina_bar.value = stamina
	if hunger_label:
		if hunger > 70.0:
			hunger_label.text = "⚠️ Henry: \"I feel quite hungry!\" (Press H to Eat/Drink)"
			hunger_label.modulate = Color(1.0, 0.4, 0.2)
		else:
			hunger_label.text = "Nourishment: Satisfied"
			hunger_label.modulate = Color(0.85, 0.8, 0.7)

func show_notification(text: String, duration: float = 3.0) -> void:
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
			+ "• Padded Gambeson & Iron Mail Coif\n" \
			+ "• Lockpicks: 5"
