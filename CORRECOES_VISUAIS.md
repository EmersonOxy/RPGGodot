CORREÇÕES VISUAIS — INVENTÁRIO E HP DOS INIMIGOS

Arquivos alterados: inventory_menu.gd/.tscn, inventory_slot.gd/.tscn,
enemy_health_bar.gd/.tscn e enemy_dummy.tscn (remove somente HealthLabel antigo).
Inventory.gd, Player HUD, combate, loot, XP e navegação não foram alterados.

INVENTÁRIO
Abra inventory_menu.tscn. Os 20 slots são instâncias salvas de inventory_slot.tscn em:
Panel/Margin/VBox/BagSlots/Slot01 ... Slot20.
BagSlots é Control, não Container. Selecione um Slot e arraste no editor 2D,
ou edite Layout > Transform > Position / Size no Inspector. Os scripts não
alteram essas posições nem criam slots. Selecione a raiz da instância Slot,
não seu VBox interno. O tamanho mínimo da cena de slot é 32 x 40.
O tamanho inicial é 46 x 54, para caber no painel atual sem mudar sua posição.

O menu procura Slot01 pelo nome e associa ao índice 0; Slot20 ao índice 19.
Nomes ausentes, script incorreto ou contagem diferente de 20 produzem warning.
O sinal updated do inventário atualiza os slots, sem duplicar conexões.
I abre/fecha com fade de 0,20/0,18 segundos. Não há animação de posição.

BARRAS
Abra enemy_health_bar.tscn. Dentro de SubViewport/EnemyHealthBar existem
DamageGhostBar e HealthBar, ambas ProgressBar com Fill Mode = Begin to End
(LEFT_TO_RIGHT, valor 0). O HP altera value, não scale.
Antes, scale.x reduzia uma QuadMesh centrada na origem: ambas as extremidades
se aproximavam do centro. Agora o Control tem tamanho fixo e a esquerda fica fixa.
A barra vermelha atualiza imediatamente. A bege espera e depois converge.
A barra permanece visível durante o desenvolvimento e é filha do inimigo;
a morte remove os dois juntos. Sprite3D com Billboard Enabled orienta todo
nome/barra para a câmera. Não há texto 100/100 flutuante.

Tamanho: as duas ProgressBar têm 110 x 10 no Inspector; mantenha as mesmas
posições/tamanhos nas duas. Sprite3D > Pixel Size = 0.0264 dá aproximadamente
110 x 10 pixels com a câmera atual em uma janela de 720 pixels de altura.
Altere Pixel Size para escalar todo o conjunto, ou os retângulos de ambas
as barras para mudar somente a barra. Ao ampliar além de 128 x 40, aumente
SubViewport > Size e o Control interno para evitar corte. Nome: font size 14.
Na raiz EnemyHealthBar, Damage Delay = 0.25 e Damage Duration = 0.4 segundos.
Danos consecutivos cancelam o tween antigo e levam o ghost ao HP mais recente.

VALIDAÇÃO
Godot 4.7.2: importação, execução headless e execução gráfica sem erros de script.
Confirmados: 20 instâncias; índices por nome; mudança manual de posição/tamanho;
coleta atualizando slot; pilhas 10 + 3; espadas em slots separados; I/fade;
clique na UI; barras 100 -> 80 -> 40; atraso e convergência; billboard;
remoção sem barra órfã; pausa/retomada. Screenshot renderizado conferido.
Nenhuma configuração manual obrigatória. Se o editor avisar sobre arquivos
alterados externamente, recarregue as versões do disco.
