class_name EnemyArchetype
extends Resource
## Configuração compartilhada do tipo. Editar afeta todos os consumidores; torne o recurso único para personalizar uma instância.

@export_category("ARQUÉTIPO DE INIMIGO")

@export_group("IDENTIDADE")
## Nome mostrado na barra de vida.
@export var nome: String = "Dummy":
	set(value):
		nome = value
		emit_changed()

@export_group("COMBATE")
## Vida base antes da dificuldade. Alterar pelo Remote não cura o inimigo.
@export_range(1, 10000, 1, "or_greater") var vida_maxima: int = 100:
	set(value):
		vida_maxima = maxi(1, value)
		emit_changed()
## Dano base por golpe, antes da dificuldade.
@export_range(1, 10000, 1, "or_greater") var dano: int = 10:
	set(value):
		dano = maxi(1, value)
		emit_changed()
## Alcance em metros; altura e obstáculos continuam sendo verificados.
@export_range(0.01, 30.0, 0.01, "or_greater", "suffix:m") var alcance_de_ataque: float = 1.4:
	set(value):
		alcance_de_ataque = maxf(0.01, value)
		emit_changed()
## Intervalo em segundos após a recuperação; vale para o próximo ataque.
@export_range(0.01, 30.0, 0.01, "or_greater", "suffix:s") var intervalo_de_ataque: float = 1.5:
	set(value):
		intervalo_de_ataque = maxf(0.01, value)
		emit_changed()
## Preparação em segundos antes do impacto; vale para o próximo ataque.
@export_range(0.01, 30.0, 0.01, "or_greater", "suffix:s") var antecipacao_do_ataque: float = 0.4:
	set(value):
		antecipacao_do_ataque = maxf(0.01, value)
		emit_changed()
## Recuperação em segundos após o impacto.
@export_range(0.01, 30.0, 0.01, "or_greater", "suffix:s") var recuperacao_do_ataque: float = 0.55:
	set(value):
		recuperacao_do_ataque = maxf(0.01, value)
		emit_changed()

@export_group("PERCEPÇÃO E MOVIMENTO")
## Distância de detecção em metros, multiplicada pela dificuldade.
@export_range(0.01, 30.0, 0.01, "or_greater", "suffix:m") var distancia_de_deteccao: float = 8.0:
	set(value):
		distancia_de_deteccao = maxf(0.01, value)
		emit_changed()
## Distância máxima do jogador até o ponto de origem, em metros.
@export_range(0.01, 30.0, 0.01, "or_greater", "suffix:m") var limite_de_perseguicao: float = 15.0:
	set(value):
		limite_de_perseguicao = maxf(0.01, value)
		emit_changed()
## Velocidade base em metros por segundo, multiplicada pela dificuldade.
@export_range(0.01, 30.0, 0.01, "or_greater", "suffix:m/s") var velocidade_de_movimento: float = 2.5:
	set(value):
		velocidade_de_movimento = maxf(0.01, value)
		emit_changed()

@export_group("APARÊNCIA")
## Cor base do corpo; flashes de dano e antecipação continuam temporários.
@export var cor_do_corpo: Color = Color(0.8, 0.12, 0.16, 1.0):
	set(value):
		cor_do_corpo = value
		emit_changed()
## Escala apenas da malha. Não altera a colisão nem a navegação.
@export_range(0.1, 3.0, 0.05, "or_greater") var escala_visual: float = 1.0:
	set(value):
		escala_visual = maxf(0.01, value)
		emit_changed()
