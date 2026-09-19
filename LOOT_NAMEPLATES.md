# Nameplates de loot — auditoria e conclusão

## Atualização: enquadramento e escala de zoom

Esta seção registra a alteração posterior ao stacking aprovado; as seções abaixo são o histórico daquela implementação.

- Causa da deriva: o offset físico fixo tem componentes não nulas nos eixos direito/cima da câmera. Ao variar somente o tamanho ortográfico, essas componentes ocupavam frações diferentes da tela. Não havia deslocamento físico dependente de zoom.
- Zoom real: `Camera3D.size`, mínimo 6, padrão de fábrica 19 (índice 5), máximo 27. Um padrão escolhido nas configurações não redefine a referência visual de fábrica.
- Correção em `camera_follow.gd`: `h_offset = dot(offset, camera_right) * (size / reference - 1)` e equivalente para `v_offset`/camera_up, somando o impulso de impacto existente. Correção aplicada na inicialização, zoom imediato e após a interpolação suave. Posição física, suavização vertical e rotação continuam iguais. Em 19, a correção é zero.
- `reference_camera_size = ZOOM_LEVELS[DEFAULT_ZOOM_INDEX] = 19`. Nameplates usam `camera.size / reference_camera_size`, strength 1, sem clamps adicionais: 0,315789× em 6; 1× em 19; 1,421053× em 27. Compensação completa mantém dimensões projetadas aproximadamente constantes.
- Hierarquia: `WorldLoot → StackingRoot → NameplateScaleRoot → Label3D → LabelBacking`. StackingRoot desloca a pilha; NameplateScaleRoot escala por zoom; Label3D mantém o tween de nascimento. A altura-base original passa ao novo root, evitando escalá-la junto com o tamanho do nome. Texto, contorno e fundo herdam a mesma escala.
- `ClickArea/LabelCollision` permanece separada. Largura/altura vêm do fundo multiplicado pela escala global resultante (zoom × nascimento × pais); posição e orientação continuam sincronizadas. Espessura permanece 0,04.
- Manager recebe as dimensões atuais pelas APIs existentes, sem nenhuma alteração de algoritmo, ordem, gap ou padding. A posição-base agora inclui o novo root. Processamento: câmera (0), loot (1), manager (100).
- Modelos e sua compensação parcial, spawn físico, pickup, UI e estilos não foram alterados.
- Arquivos desta atualização: `camera_follow.gd`, `world_loot.gd`, `loot_label_test.gd`, `LOOT_NAMEPLATES.md`. Sem commit/push.

Validação: **1.567 verificações, zero falhas**, em execução headless com FPS fixo 60. Inclui câmera real extraída da cena principal; padrão/min/max e 800 passos de zoom suave em ambos os modos de aspect; transform físico preservado; impacto; dimensões em cada zoom; stacking contínuo; seleção e raycasts nos quatro cantos em todos os extremos; hover via API; nascimento em zoom não padrão com escala e colisão combinadas. `git diff --check` passou. Não houve teste visual nem eventos reais de mouse: picking e destaque foram exercitados programaticamente. O fluxo existente de clique prioritário em `main.gd` foi preservado.

Como antes, transições entre clusters diferentes ou labels ainda nascendo podem apresentar sobreposição transitória durante a acomodação; o algoritmo aprovado não foi alterado.

## Estado encontrado antes das alterações

Foram lidos `git status`, `git diff`, o diff staged (vazio) e os arquivos completos do manager, loot, cena principal e câmera. Havia alterações não commitadas em `main.tscn` e `world_loot.gd`; `loot_label_manager.gd` e `package-lock.json` estavam não rastreados.

O sistema antigo `_update_label_offset()` **já tinha sido removido**, junto com sua chamada. Não havia `_process()` duplicado. O manager já estava instanciado em `main.tscn`. A separação em `ZoomScaleRoot` e `StackingRoot` estava iniciada corretamente. Essas alterações foram preservadas.

Problemas restantes:

- `viewport_height / (2 * camera.size)` subestimava pixels por unidade por um fator de dois em KEEP_HEIGHT e ignorava KEEP_WIDTH.
- Agrupamento transitivo existia, mas as pilhas finais não eram verificadas contra outros clusters.
- Comparador com tolerância entre pares não garantia ordenação transitiva.
- Posição-base ignorava a hierarquia, o deslocamento do fundo e transformações dos pais.
- Dimensões ignoravam escala animada; largura só era atualizada ao criar o fundo pela primeira vez.
- Label era considerado pronto antes de terminar a animação de crescimento/subida.
- Hitbox atualizava somente posição no stacking, mantinha orientação antiga e não acompanhava escala/visibilidade do surgimento.
- Cache podia manter câmera antiga ao trocar a câmera ativa e offsets de labels já invisíveis.
- Registro dependia de `current_scene` já estar atribuído; desregistro buscava novamente a cena em vez de usar a referência do manager.
- Hitboxes dos modelos podem interceptar raios de nameplates visíveis na frente deles, pois os nomes usam `no_depth_test`.

## Arquivos

- `loot_label_manager.gd`: concluído o manager central existente, ainda não rastreado no Git.
- `world_loot.gd`: corrigidas geometria/base, integração, registro, hover e sincronização da hitbox.
- `main.gd`: prioridade de clique no retângulo visível antes do raycast; a coleta continua usando o fluxo existente.
- `loot_label_test.gd`: teste headless focado no layout e integração.
- `LOOT_NAMEPLATES.md`: este relatório.

A alteração anterior de `main.tscn` foi mantida sem novas edições. `world_loot.tscn`, câmera, inventário, hotbar, ItemData, modelos, sons, notificações e ícones não foram alterados nesta tarefa. A compensação anterior de zoom do modelo foi preservada. `package-lock.json` não foi alterado. Nenhum commit ou push.

## Funções removidas e alteradas

- Não foi necessário remover `_update_label_offset()`: ela já estava ausente. Foi removido o campo obsoleto `_base_label_y`.
- A implementação antiga do manager foi substituída; `_rect_for()` deixou de existir. `resolve_layout()`, `_comes_before()`, `get_loot_at_screen_position()` e `_update_hover()` compõem a resolução e interação centralizadas; `_find_root()` continua realizando union-find.
- `register_loot()`, `unregister_loot()` e `_process()` mantêm registros por ID, descartando referências inválidas antes de convertê-las em tipos Node.
- No loot: revisados `is_label_ready()`, `is_label_visible()`, `get_label_base_position()`, `get_label_width()`, `get_label_height()` e `apply_stack_offset()`.
- Adicionados `get_label_screen_rect()`, `_sync_label_collision()`, `_register_label_manager()`, `set_label_hover()` e `_refresh_mouse_hover()`.
- Atualizados criação do fundo, eventos de hover, `_process()`, `_exit_tree()` e `_set_label_spawn()` para usar essa integração.

## Algoritmo e estabilidade

1. O manager mantém registros centrais e uma lista reutilizada de labels visíveis/prontos. A única varredura do grupo `loot` ocorre na inicialização do manager, para atender instâncias já presentes na cena.
2. Cada retângulo usa os quatro cantos projetados do fundo individual e sua escala real. Não há detecção por distância XZ.
3. Interseções dos retângulos-base com padding de 3 pixels formam clusters transitivos por union-find.
4. A ordem equivale à posição projetada para a câmera ortográfica, mas é calculada sem a translação da câmera. Usa quantização muito pequena, coordenadas espaciais e ID como desempate estrito.
5. O membro inferior fica na base; os demais sobem, mantendo gap de 4 pixels. Cada posição candidata é testada contra TODOS os retângulos já colocados, inclusive de outros clusters. Obstáculos são mantidos por borda inferior decrescente, permitindo resolver com deslocamentos somente para cima em um passe por item.
6. Resolução O(N²), central, sem scans cruzados por WorldLoot. Registros são reutilizados; formas físicas só são redimensionadas se o tamanho mudou.
7. O offset é suavizado em pixels com `1 - exp(-28 * delta)` e aplicado somente em StackingRoot. Atinge aproximadamente 95% do deslocamento em 0,107 s. Abaixo de 0,05 pixel, fixa exatamente o destino, eliminando movimento residual.

O cálculo usa sempre posições-base, nunca os retângulos já deslocados como novas âncoras. Assim o layout não se retroalimenta. Labels isolados têm destino zero. Posições finais são livres de interseção; durante a transição curta entre layouts ou enquanto um label está nascendo, pode haver sobreposição transitória, sem prometer separação instantânea e teleporte ao mesmo tempo.

## Geometria, spawn e zoom

`get_label_base_position()` reconstrói o transform do centro do fundo pela hierarquia real, zerando somente a translação de StackingRoot. Não subtrai posições globais quase iguais e não depende de um Y fixo.

O tween de nascimento continua controlando somente `Label3D.position/scale/outline`. StackingRoot controla somente o deslocamento de layout. O label entra na pilha após concluir o crescimento; a hitbox acompanha sua animação mesmo antes disso.

Camera3D ortográfica usa `size` como extensão TOTAL: em KEEP_HEIGHT, `ppu = viewport_height / size`; em KEEP_WIDTH, `ppu = viewport_width / size`. Um offset de tela positivo para baixo corresponde a `-camera_up * offset / ppu`. O código utiliza a diferença entre duas chamadas de `project_position()` na mesma profundidade, evitando fórmulas duplicadas e respeitando aspect, offsets e projeção. A validação compara a escala projetada real nos dois modos de aspect.

O layout recalcula com o zoom atual, sem redimensionar os nameplates para corrigir conflitos. O manager processa depois da câmera. A fórmula existente de compensação visual dos modelos permanece intacta.

## Hitbox, hover e clique

LabelCollision recebe a posição global do fundo, dimensões escaladas e basis ortonormal da câmera atual. A sincronização ocorre após aplicar stacking, no update normal e no callback do tween de nascimento. Hitboxes de nomes invisíveis são desativadas. Espessura reduzida para 0,04 unidade evita volumes profundos desnecessários.

Clique e hover consultam primeiro o retângulo VISÍVEL do nome. Isso corresponde ao `no_depth_test` já utilizado pelo visual e impede um modelo de outro item de roubar o clique. A hitbox física continua alinhada e testada nos cantos e centro. O destaque reutiliza o estilo e os cursores existentes. Cliques fora dos nomes continuam no raycast original; pickup não foi reimplementado.

## Validação

Comando: `Godot --headless --path . --fixed-fps 60 --script res://loot_label_test.gd`.

Resultado: **239 verificações, 0 falhas**, sem erros de script nessa execução (aproximadamente 3 segundos).

A cena principal também foi iniciada com `--headless --path . --quit-after 3`, saída 0. Essa execução registrou os erros já conhecidos de imagem nula em `item_preview_generator.gd:73–74`, devido ao preview renderizado em headless. Esse sistema ficou intacto, conforme o escopo solicitado.

Cobertura: singleton, seis labels reais de diferentes larguras, transitividade A-B-C, colisão de pilha com outro cluster, 20 conjuntos determinísticos de 30 retângulos, estabilidade exata após acomodação, zoom 6/19/27, KEEP_HEIGHT/KEEP_WIDTH, preservação do corpo/modelo, remoção intermediária, pais rotacionados/escalados, conversão pixels/mundo, picking de nomes, raycasts nos cantos/centros da hitbox, surgimento e carregamento da cena principal.

`git diff --check` passou. A busca final não encontrou `_update_label_offset` nos scripts; cada arquivo mantém somente um `_process()`.

## Conferência visual manual restante

- Aparência compacta da pilha e gap com a fonte/contorno atuais.
- Sensação da transição ao coletar itens do meio ou alterar zoom continuamente.
- Hover e clique GUI reais em cada nome, inclusive com modelos atrás e inventário aberto.
- Crescimento, sombra/fundo e entrada de loot recém-dropado na pilha.
- Pilhas muito grandes perto das bordas da tela; não foi adicionado reposicionamento horizontal nem confinamento à janela.
