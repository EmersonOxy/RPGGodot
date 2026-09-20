class_name DifficultyManager
extends Node
## Fonte única dos multiplicadores de dificuldade usados pelo gameplay.

signal difficulty_changed(id: String)

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "gameplay"
const DEFAULT_DIFFICULTY := "normal"
const ORDER: Array[String] = ["easy", "normal", "hard"]
const LABELS := {"easy": "Fácil", "normal": "Normal", "hard": "Difícil"}
const PROFILES := {
	"easy": {
		"enemy_health": 0.75, "enemy_damage": 0.75,
		"enemy_speed": 0.9, "enemy_perception": 0.85,
		"max_enemies": 0.75, "spawn_interval": 1.25,
		"loot_quantity": 1.15,
	},
	"normal": {
		"enemy_health": 1.0, "enemy_damage": 1.0,
		"enemy_speed": 1.0, "enemy_perception": 1.0,
		"max_enemies": 1.0, "spawn_interval": 1.0,
		"loot_quantity": 1.0,
	},
	"hard": {
		"enemy_health": 1.35, "enemy_damage": 1.3,
		"enemy_speed": 1.1, "enemy_perception": 1.2,
		"max_enemies": 1.3, "spawn_interval": 0.75,
		"loot_quantity": 0.9,
	},
}

var current := DEFAULT_DIFFICULTY


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		current = sanitize_id(config.get_value(SECTION, "difficulty", DEFAULT_DIFFICULTY))


func sanitize_id(id: Variant) -> String:
	return id if id is String and id in ORDER else DEFAULT_DIFFICULTY


func get_multiplier(key: String) -> float:
	return float(PROFILES[current].get(key, 1.0))


func get_label(id: String = current) -> String:
	return LABELS.get(sanitize_id(id), LABELS[DEFAULT_DIFFICULTY])


func set_difficulty(id: String, path: String = CONFIG_PATH) -> Error:
	if not id in ORDER:
		return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	if FileAccess.file_exists(path):
		config.load(path)
	config.set_value(SECTION, "difficulty", id)
	var error := config.save(path)
	if error != OK:
		return error
	current = id
	difficulty_changed.emit(current)
	return OK
