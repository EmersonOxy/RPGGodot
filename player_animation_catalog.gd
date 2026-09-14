extends RefCounted
# Explicit links to the user's approved sources; the .tres clips preserve their corrected retarget.
const CLIPS := {
 "Idle": ["player_unarmed_idle", "Sem espada/idle_sem_espada.fbx"],
 "Walk": ["player_unarmed_walk", "Sem espada/andar_sem_espada.fbx"],
 "Run": ["player_unarmed_run", "Sem espada/correr_sem_espada.fbx"],
 "ArmedIdle": ["player_armed_idle", "Com espada/idle_com_espada_duas_maos.fbx"],
 "ArmedWalk": ["player_armed_walk", "Com espada/andar_com_espada_duas_maos.fbx"],
 "ArmedRun": ["player_armed_run", "Com espada/correr_com_espada_duas_maos.fbx"],
 "Attack1": ["player_unarmed_attack_1", "Sem espada/atacar_sem_espada.fbx"],
 "Attack2": ["player_unarmed_attack_2", "Sem espada/atacar_sem_espada_2.fbx"],
 "Attack3": ["player_unarmed_attack_3", "Sem espada/atacar_sem_espada_3.fbx"],
 "ArmedAttack": ["player_armed_attack", "Com espada/atacar_com_espada_duas_maos.fbx"],
 "Hit1": ["player_unarmed_hit_1", "Sem espada/tomar_dano_sem_espada.fbx"],
 "Hit2": ["player_unarmed_hit_2", "Sem espada/tomar_dano_sem_espada_2.fbx"],
 "Hit3": ["player_unarmed_hit_3", "Sem espada/tomar_dano_sem_espada_3.fbx"],
 "Hit4": ["player_unarmed_hit_4", "Sem espada/tomar_dano_sem_espada_4.fbx"],
 "ArmedHit1": ["player_armed_hit_1", "Com espada/tomar_dano_com_espada_duas_maos.fbx"],
 "ArmedHit2": ["player_armed_hit_2", "Com espada/tomar_dano_com_espada_duas_maos_2.fbx"],
 "Death": ["player_unarmed_death", "Sem espada/morrer_sem_espada.fbx"],
 "ArmedDeath1": ["player_armed_death_1", "Com espada/morrer_com_espada_duas_maos.fbx"],
 "ArmedDeath2": ["player_armed_death_2", "Com espada/morrer_com_espada_duas_maos_2.fbx"],
 "Long1": ["player_armed_idle_long_1", "Com espada/Idle_com_espada_duas_maos_demorado.fbx"],
 "Long2": ["player_armed_idle_long_2", "Com espada/Idle_com_espada_duas_maos_demorado_2.fbx"],
 "Draw1": ["player_draw_1", "Transições/sacar_espada_duas_maos.fbx"],
 "Draw2": ["player_draw_2", "Transições/sacar_espada_duas_maos_2.fbx"],
 "Sheathe1": ["player_sheathe_1", "Transições/guardar_espada_duas_maos.fbx"],
 "Sheathe2": ["player_sheathe_2", "Transições/guardar_espada_duas_maos_2.fbx"]
}
static func library() -> AnimationLibrary:
	var result := AnimationLibrary.new()
	for name in CLIPS:
		result.add_animation(name, load("res://assets/player/approved/" + CLIPS[name][0] + ".tres"))
	return result
