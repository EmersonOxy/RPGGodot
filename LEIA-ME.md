# Navegação com obstáculos e elevação

O ataque básico automático está disponível: 20 de dano por segundo, HP visível e remoção ao morrer. Consulte [COMBATE.md](COMBATE.md).

Clicar em inimigos agora inicia a aproximação até o alcance configurado. Consulte [APROXIMACAO.md](APROXIMACAO.md).

Cliques no terreno agora exibem um anel temporário alinhado à superfície. Ajustes e funcionamento estão em [INDICADOR.md](INDICADOR.md).

O projeto também inclui dois inimigos dummy selecionáveis, um em cada altura. Consulte [INIMIGOS.md](INIMIGOS.md) para testar a seleção e adicionar novas instâncias.

Abra `main.tscn` no Godot 4.7 e pressione **F5**. Se o editor avisar sobre alterações externas, recarregue os arquivos. O Bake já está salvo: nenhuma configuração manual é necessária para testar.

## Teste rápido

1. Clique no chão do outro lado do bloco ou da coluna: o personagem contorna o obstáculo.
2. Clique na face superior da plataforma verde: ele procura a entrada da rampa marrom e sobe.
3. Clique numa parte visível do chão inferior: ele volta pela rampa, mesmo que uma borda da plataforma esteja mais perto.
4. Clique noutro ponto durante o movimento para trocar o destino.

Cliques no fundo, nas paredes laterais ou nos objetos são ignorados. O clique considera a primeira superfície visível; não atravessa a plataforma para selecionar chão escondido atrás dela.

## Arquivos

- `main.tscn`: cena existente ampliada, preservando personagem, câmera, luz e controles.
- `main.gd`: converte o clique em um raio 3D e aceita as faces superiores de chão, rampa e plataforma.
- `player.gd`: usa NavigationAgent3D para seguir os pontos do caminho. A velocidade horizontal, a gravidade e move_and_slide controlam o CharacterBody3D.
- `world_navigation.tres`: NavigationMesh com o Bake pronto e seus parâmetros editáveis.
- `ramp_mesh.tres`: malha 3D da rampa, um recurso ArrayMesh nativo e estático.
- `project.godot`: ajustada a resolução vertical padrão do mapa de navegação para coincidir com a do Bake.

## Nodes adicionados e reorganizados

- `NavigationRegion3D`: contém Ground, Platform, Ramp e Props. Usa `world_navigation.tres`.
- `Player/NavigationAgent3D`: calcula o caminho até o clique. Ele orienta a movimentação; não move nem teleporta o personagem.
- `Platform`: StaticBody3D com BoxMesh e BoxShape3D, com topo em Y = 2.
- `Ramp`: StaticBody3D com MeshInstance3D e ConvexPolygonShape3D em formato de cunha.
- `ExcludeTop`, dentro de Block e Column: NavigationObstacle3D usados no Bake para excluir os topos dos obstáculos.
- `Platform/ExcludeInterior`: NavigationObstacle3D que exclui o chão dentro do volume sólido, sem remover a superfície superior.

Block e Column continuam sólidos. A coluna foi reposicionada no nível inferior para deixar a plataforma livre. Os obstáculos são estáticos; não foi necessário ativar avoidance para desvio dinâmico.

## Como funciona a elevação

A rampa mede 3,5 unidades de largura, 6 de comprimento e sobe 2 unidades (inclinação de aproximadamente 18,4°). Sua cunha de colisão coincide com a malha visível: começa no chão e termina na altura da plataforma, sem degrau.

O personagem não tem mais o eixo Y bloqueado. O script solicita movimento horizontal; move_and_slide resolve o contato com a rampa, e a gravidade mantém o personagem sobre o terreno. Floor Snap ajuda a manter contato na descida. Não há teleporte, atribuição de altura à posição ou interpolação artificial de Y.

O Bake analisa as colisões estáticas em 3D e gera polígonos em diferentes alturas. Conecta superfícies conforme inclinação, desnível permitido e espaço para o personagem. A rampa é uma conexão contínua; as paredes de 2 unidades excedem o desnível permitido de 0,2 e não viram atalhos. Não há NavigationLink3D ligando bordas.

## Quando refazer o Bake

Depois de mover ou redimensionar chão, rampa, plataforma ou obstáculos:

1. Pare a execução e abra `main.tscn`.
2. Selecione `NavigationRegion3D` na árvore da cena.
3. Clique em **Bake NavigationMesh** (ou **Bake NavMesh**) na barra do editor 3D.
4. Salve a cena e o recurso de navegação com **Salvar tudo**.

Ao redimensionar objetos, mantenha malha, colisão e volumes de exclusão coerentes. Ao alterar a rampa, sua malha e sua colisão precisam continuar com o mesmo formato.

## Valores importantes no Inspetor

| Node/recurso | Propriedade | Atual | Efeito |
|---|---|---|---|
| Player | Speed | 4 | Velocidade horizontal |
| Player | Gravity | 20 | Aceleração vertical para baixo |
| Player | Floor Snap Length | 0,35 | Mantém contato ao descer inclinações |
| Player | Floor Max Angle | 45° | Inclinação reconhecida como chão pela física |
| NavigationMesh | Agent Radius | 0,5 | Folga para o corpo ao redor de paredes; exige novo Bake |
| NavigationMesh | Agent Height | 1,8 | Espaço vertical necessário; exige novo Bake |
| NavigationMesh | Agent Max Slope | 40° | Inclinação máxima navegável; exige novo Bake |
| NavigationMesh | Agent Max Climb | 0,2 | Desnível tolerado na geração; não faz o corpo subir degraus automaticamente |
| NavigationMesh | Cell Size / Cell Height | 0,25 / 0,1 | Resolução do Bake; mantenha alinhada com as configurações do mapa |
| NavigationAgent3D | Path Desired Distance | 0,25 | Tolerância para avançar entre pontos do caminho |
| NavigationAgent3D | Target Desired Distance | 0,2 | Distância de parada no destino |
| Camera3D | Size | 19 | Enquadramento ortográfico |

O Radius do NavigationAgent3D não substitui o Agent Radius do NavigationMesh. Para alterar a folga dos caminhos, ajuste o recurso NavigationMesh e refaça o Bake.

Referências oficiais: [NavigationMesh](https://docs.godotengine.org/en/stable/classes/class_navigationmesh.html) e [NavigationObstacle3D](https://docs.godotengine.org/en/stable/classes/class_navigationobstacle3d.html).

Este protótipo não inclui combate, inimigos, inventário, loot ou geração procedural.
