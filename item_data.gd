extends Resource

enum ItemType { WEAPON, ARMOR, CONSUMABLE, MATERIAL, MISC }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

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
