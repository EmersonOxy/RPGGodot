with open("inventory_menu.tscn", "r", encoding="utf-8") as f:
    lines = f.readlines()

out = []
in_slots = False
for line in lines:
    if line.startswith("[ext_resource"):
        out.append(line)
        if "3_equipment" in line:
            out.append("[ext_resource type=\"Script\" path=\"res://inventory_grid_ui.gd\" id=\"4_grid\"]\n")
        continue
    
    if line.startswith("[node name=\"Slot") and "BagSlots" in line:
        in_slots = True
        continue
    
    if in_slots:
        if line.startswith("[node ") or line.startswith("[connection ") or line.startswith("[sub_resource "):
            in_slots = False
        else:
            continue
            
    if line.startswith("[node name=\"BagSlots\" type=\"Control\" parent=\"Panel/Margin/VBox\""):
        out.append(line)
        out.append("script = ExtResource(\"4_grid\")\n")
        continue
        
    if not in_slots:
        out.append(line)

with open("inventory_menu.tscn", "w", encoding="utf-8") as f:
    f.writelines(out)
