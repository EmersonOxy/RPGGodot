# Arraste, descarte e loot

- I abre/fecha com slide e fade. Slide Duration na raiz InventoryMenu controla a duração (0,25 s).
- Arraste um item até outro slot: move, troca ou junta pilhas iguais até max_stack.
- Solte fora do painel para descartar a pilha inteira. O item aparece perto do Player, não na posição distante do cursor.
- Soltar sobre uma região inválida da UI cancela. Pausa e morte impedem movimentação/descarte.
- O descarte procura uma superfície próxima na mesma altura, rejeitando paredes e pontos ocupados.
- Sem lugar seguro, a pilha permanece no inventário e aparece uma mensagem.
- Recolher uma pilha exige espaço para a quantidade completa; não há perda nem inclusão parcial seguida de duplicação.
- Os 20 slots continuam gravados na cena e editáveis individualmente.

Os nomes do loot agora têm fundo escuro, letras maiores e cores mais suaves.
O texto não gira nem muda de tamanho no hover. Só a malha do item gira.
Quantity controla a quantidade no mundo. Label Distance (12) limita a exibição
à proximidade do Player. Label3D define Font Size, Pixel Size e Outline Size.
A etiqueta acompanha o item e desaparece junto com ele.

Novo: inventory_dropper.gd.
Alterados: inventory.gd, inventory_slot.gd, inventory_menu.gd/.tscn,
world_loot.gd/.tscn. O mundo, a câmera Full HD e o combate não foram alterados.

Verificado no Godot 4.7.2: arraste GUI real entre slots e até o mundo; troca;
fusão parcial respeitando limite; conservação da quantidade; descarte na
plataforma; superfícies de chão/rampa; coleta única; falha atômica quando
cheio; abertura/fechamento e reversão rápida do slide. Sem erros de script.

## Erro p_gutter
Não há TextEdit/gutter nos scripts do jogo. A mensagem se refere ao editor
de texto do próprio Godot; não foi reproduzida nos testes desta alteração.
Há relatos anteriores relacionados à recarga de scripts externos:
https://github.com/godotengine/godot/issues/81135
Salve as alterações do editor e reabra o Godot. Se persistir, experimente
desativar Editor Settings > Text Editor > Appearance > Highlight Type Safe Lines.
Não foi alterada globalmente essa preferência, nem apagado o cache do editor.
