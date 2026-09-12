# Revisão do protótipo — 12/09/2026

Revisados todos os scripts, cenas e recursos próprios encontrados no projeto, incluindo as alterações recentes de WASD, perseguição, vida do Player, escadas, câmera, oclusão e pausa. Essas funcionalidades foram preservadas.

## Correções aplicadas

1. **Alvo móvel:** o Player atualizava o caminho apenas no clique, mesmo quando o inimigo mudava de posição. Agora atualiza o destino quando o alvo se desloca mais de 0,25 unidade; se a referência deixar de existir, cancela a aproximação.
2. **Soltar WASD:** o agente podia retomar o ponto registrado antes do movimento manual. Agora o destino é encerrado na posição atual ao soltar as teclas.
3. **Estado de movimento:** `is_moving` e `move_direction` podiam continuar indicando caminhada após a parada. Agora são atualizados após a resolução física e limpos na morte.
4. **Morte do Player:** a seleção e o indicador de clique permaneciam ativos. Agora são limpos, assim como cliques pendentes. Cliques pendentes também são descartados ao pausar.
5. **Escada:** a transformação do corpo `StepSlope` estava alterando a cunha de colisão em relação aos degraus. As alturas medidas perto das extremidades eram aproximadamente 0,015 e 2,987. Após a correção, são 0,167 e 1,833, correspondentes à rampa de colisão de 0 a 2 unidades que suporta os degraus visuais.
6. **Navegação:** o Bake foi refeito após corrigir a escada, com Max Climb de 0,2. Os trajetos que travavam na escada/rampa passaram. A escada usa sua cunha de colisão contínua; foi retirado o código que alterava diretamente Y do Player e dos inimigos para tentar subir degraus.
7. **IA:** evita reenviar o mesmo destino de retorno a cada passo de física; na perseguição, atualiza o destino quando o Player se desloca mais de 0,25 unidade. O intervalo de ataque tem limite mínimo no Inspetor.
8. **Oclusão:** os raios para esmaecer telhados e o eixo do shader foram adequados à projeção ortográfica. A busca em cache também verifica se as malhas ainda existem.

## Validação

- Importação e carregamento dos scripts no Godot 4.7.2.
- Bateria de regressão: **17 verificações passaram**, cobrindo alvo móvel, parada, morte, pausa e oito percursos do mapa.
- Bateria de sistemas: **25 verificações passaram**, cobrindo dano e intervalos dos dois lados, cancelamento, morte, perseguição, retorno, WASD, indicador nas três superfícies, transparência, pausa e reinício com R.
- Conferência com renderização Forward+ / D3D12: interface de morte, HP, menu de pausa e telhado transparente; 23 verificações da bateria de sistemas também passaram nessa execução.
- Percursos: rampa principal (subida e descida), base da escada, plataforma oeste pela escada (subida e descida), rampa leste, pátio coberto e área ampliada do chão.
- Teste adicional: inimigo da plataforma desce pela rampa para alcançar o Player; reinício com R restaura a vida.

Os testes de casos específicos reposicionam personagens apenas em instâncias temporárias de execução. Não alteram posições salvas no mapa.

## Observações e limites

Durante alguns testes acelerados, o Jolt emitiu um aviso de limite de tarefas internas. As verificações terminaram sem falhas; o aviso não apareceu na execução renderizada conferida. Não foi alterada a configuração do motor para esconder esse aviso.

Os testes cobrem os fluxos citados, mas não garantem ausência de bugs em todas as combinações de entradas, posições ou futuras alterações. O submenu Configurações continua sendo apenas um placeholder e Menu Principal continua desabilitado, como estavam antes da revisão.

A colisão das escadas é uma rampa contínua sob os degraus visuais, não uma colisão individual por degrau. Isso mantém a subida física suave.

## Como abrir

Pare a execução com F8. Se o editor avisar sobre arquivos alterados externamente, recarregue-os, incluindo `main.tscn`. Depois pressione F5. O novo Bake já está salvo; não é necessário fazê-lo manualmente.

Arquivos alterados: `main.gd`, `player.gd`, `enemy_dummy.gd`, `main.tscn`, `world_navigation.tres`, `occlusion_fade.gd` e `occluder_mask.gdshader`. O chão de 100 × 100, as posições dos inimigos, a câmera e os menus foram preservados. Um backup dos arquivos anteriores foi guardado na pasta de trabalho da revisão.

Os documentos anteriores descrevem etapas históricas e podem mencionar limitações já superadas; este relatório registra o estado revisto.
