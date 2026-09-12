# Referência Full HD (16:9)

## Project Settings > Display > Window
- Viewport Width: 1920.
- Viewport Height: 1080.
- Window Width Override: 1280.
- Window Height Override: 720 (somente tamanho inicial da janela).
- Stretch Mode: canvas_items.
- Stretch Aspect: keep.
- Stretch Scale: padrão 1.0; Scale Mode: padrão fractional.

O editor usa 1920 x 1080 para desenhar as cenas 2D. O Godot escala essa
composição para a janela disponível. Em 1280 x 720 a escala é 2/3.
Em outras proporções, aparecem faixas para preservar 16:9, sem esticar a UI.
A execução inicia em janela; fullscreen utiliza a mesma composição.

## Inventário
InventoryMenu é Full Rect, com mouse_filter Ignore. Panel é Right Wide,
com offsets Left=-450 e Right=0, ocupando toda a altura. Foram removidos
os overrides de anchors/offsets na instância em main.tscn que conflitavam
com a cena original. O bloqueio de clique verifica apenas Panel.
Os mesmos 20 slots continuam salvos e editáveis, com os mesmos índices.
As medidas 2D foram convertidas uma única vez pelo fator 1,5 da antiga
altura de referência para Full HD. Não há recálculo de posições por resolução.
Cores, conteúdo, lógica dos slots e fade foram preservados.

## HUD e câmera
HP, XP, nível e action bar continuam ancorados ao centro inferior.
As dimensões e fontes foram convertidas para a referência Full HD.
Tooltip, pausa e mensagens também receberam conversão das medidas explícitas.
Camera3D: Orthogonal, Size=19, Keep Aspect=Keep Height (explícito).
Posição, ângulo e script da câmera não foram alterados.
O mundo 3D, navegação, Player e inimigos não foram redimensionados.

## Valores antigos
Não havia 1152 fixo nos scripts; a largura antiga vinha do padrão do Godot.
720 era a altura-base explícita no project.godot. Agora só permanece ali
como altura inicial da janela de teste, não como referência de design.
O HUD já utilizava anchors, mas seus offsets/fontes eram dimensionados
para a referência antiga. Essas medidas foram convertidas para Full HD.

## Validação
Godot 4.7.2: 1920 x 1080 fullscreen, 1280 x 720 em janela e 1000 x 800.
Confirmados o canvas lógico Full HD, painel à direita sem corte, 20 slots,
HUD centralizado, matriz ortográfica idêntica, cliques dentro/fora do painel,
fade e pausa. Capturas renderizadas conferidas; teste final sem falhas e
sem erros de script. O modo embutido não foi operado manualmente; utiliza
as mesmas configurações nativas de stretch/aspect.

Arquivos alterados: project.godot, main.tscn, main.gd, inventory_menu.tscn,
inventory_slot.tscn, player_hud.gd, tooltip.tscn e pause_menu.tscn.
Recarregue os arquivos do disco se o editor avisar sobre alterações externas.

Referência: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
