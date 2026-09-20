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

@export_group("COMPORTAMENTO FORA DE COMBATE")
## Como o inimigo se comporta sem perceber o jogador. Parado mantém o inimigo imóvel; Vagar alterna pausas e caminhadas curtas ao redor da posição de origem.
@export_enum("Parado", "Vagar") var comportamento_fora_de_combate: int = 1:
	set(value):
		comportamento_fora_de_combate = clampi(value, 0, 1)
		emit_changed()
## Raio, em metros, ao redor da posição de origem onde o inimigo escolhe destinos de vagar. O centro é sempre a origem, nunca a posição atual.
@export_range(0.5, 50.0, 0.5, "or_greater", "suffix:m") var raio_de_movimento_ambiente: float = 6.0:
	set(value):
		raio_de_movimento_ambiente = maxf(0.5, value)
		emit_changed()
## Multiplicador sobre a velocidade de movimento usado fora de combate. Não altera a velocidade de combate.
@export_range(0.05, 1.0, 0.05) var multiplicador_de_velocidade_ambiente: float = 0.7:
	set(value):
		multiplicador_de_velocidade_ambiente = clampf(value, 0.05, 1.0)
		emit_changed()
## Pausa mínima entre caminhadas, em segundos.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var pausa_minima_ambiente: float = 1.5:
	set(value):
		pausa_minima_ambiente = maxf(0.0, value)
		emit_changed()
## Pausa máxima entre caminhadas, em segundos.
@export_range(0.1, 60.0, 0.1, "or_greater", "suffix:s") var pausa_maxima_ambiente: float = 4.0:
	set(value):
		pausa_maxima_ambiente = maxf(pausa_minima_ambiente, value)
		emit_changed()
## Quantidade de candidatos sorteados ao escolher um destino; se nenhum for navegável, o inimigo espera e tenta novamente.
@export_range(1, 50, 1) var tentativas_de_destino: int = 8:
	set(value):
		tentativas_de_destino = maxi(1, value)
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
