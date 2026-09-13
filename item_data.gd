extends Resource
class_name ItemData

enum ItemType { WEAPON, ARMOR, CONSUMABLE, MATERIAL, MISC }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum EquipmentSlot { NONE, HEAD, WEAPON, OFFHAND, CHEST, HANDS, LEGS, BOOTS, RING, AMULET }

@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var attack_damage_bonus: int = 0
@export var armor_bonus: int = 0
@export var max_health_bonus: int = 0
@export var strength_bonus: int = 0
@export var dexterity_bonus: int = 0
@export var intelligence_bonus: int = 0
@export var heal_amount: int = 0

const BONUS_LABELS := {
	"attack_damage": "Dano", "armor": "Armadura", "max_health": "Vida máxima",
	"strength": "Força", "dexterity": "Destreza", "intelligence": "Inteligência"
}

func get_bonus_text() -> String:
	var lines: PackedStringArray = []
	for stat in BONUS_LABELS:
		var value: int = get(stat + "_bonus")
		if value != 0:
			lines.append("%s %+d" % [BONUS_LABELS[stat], value])
	if heal_amount > 0 and item_type == ItemType.CONSUMABLE:
		lines.append("Restaura %d de vida" % heal_amount)
	return "\n".join(lines)

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var item_type: ItemType = ItemType.MISC
@export var rarity: Rarity = Rarity.COMMON
@export var stackable: bool = false
@export var max_stack: int = 1
@export var icon_color: Color = Color.WHITE

const RARITY_NAMES := ["Comum", "Incomum", "Raro", "Épico", "Lendário"]
const TYPE_NAMES := ["Arma", "Armadura", "Consumível", "Material", "Diversos"]


func get_rarity_name() -> String:
	return RARITY_NAMES[rarity]


func get_type_name() -> String:
	return TYPE_NAMES[item_type]
