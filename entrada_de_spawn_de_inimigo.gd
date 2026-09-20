class_name EntradaDeSpawnDeInimigo
extends Resource
## Entrada individual da composição de um spawner: cena, peso relativo e estado.

@export_category("ENTRADA DE SPAWN")

## Nome de exibição desta entrada no Inspector; não afeta a mecânica.
@export var nome := "":
	set(value):
		nome = value
		resource_name = value
## Ativado: esta entrada participa do sorteio ponderado do spawner. Pode ser alterado pelo Inspector Remote.
@export var ativado := true
## Cena do inimigo que esta entrada pode gerar.
@export var cena_do_inimigo: PackedScene
## Peso relativo no sorteio entre as entradas ativadas. A chance é o peso dividido pela soma dos pesos das entradas ativadas; não é percentual. Zero ignora a entrada.
@export_range(0.0, 100.0, 0.1) var peso := 1.0
