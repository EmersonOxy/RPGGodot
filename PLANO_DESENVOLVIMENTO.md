# Plano de desenvolvimento do RPG 3D isométrico

Documento consolidado em 19/09/2026. Deve ser atualizado conforme as tarefas forem implementadas ou as decisões de design mudarem.

Convenção obrigatória para sistemas atuais e futuros: [CONVENCOES.md](CONVENCOES.md). O Inspector deve apresentar parâmetros de design selecionados, em português e agrupados, preservando estados internos e valores existentes. Revisão estrutural: blocos 0 (convenções), 1 (Player) e 2 (inimigos) implementados. Arquétipos migrados preservando valores e atualizados por sinais no Remote; teste breve sem falhas. Próximo bloco: spawner, aguardando aprovação específica.

## Status atualizado — Fases 1 a 3 encerradas

Fases 1, 2 e 3 entregues e confirmadas pelo usuário. As notas antigas de "fase atual" abaixo são históricas.

### Fase 2 — entregas concluídas

- [x] Notificação de coleta com ícone, nome e quantidade, fade e duração configurável.
- [x] Fila/pilha de notificações e deslocamento acompanhando abertura/fechamento do inventário.
- [x] Registro compartilhado de aquisições e destaque dos itens novos; hover/interação remove o destaque.
- [x] Marcação mantida ao acrescentar quantidades à mesma pilha/recurso de item.
- [x] Opção de mostrar/esconder HUD e dicas de controles com menor destaque.
- [x] Tamanho e estilo do cursor aplicados em tempo real.
- [x] Contador independente na hotbar, no canto inferior direito, branco com contorno preto; soma as pilhas do tipo de item e atualiza ao coletar, consumir ou remover. Como no inventário, quantidade 1 não exibe contador.
- [x] Polimentos adicionais: modelos/ícones, animação de surgimento do loot, stacking dos nameplates, hover/clique, escala de texto/fundo/sombra e colisão conforme zoom.

Limite conhecido: o registro de "novo" usa identidade do recurso; unificar essa marcação entre recursos distintos com o mesmo ID não foi implementado. Não confundir com a contagem da hotbar, que já soma por tipo/ID.

### Fase 3 — funcionalidades de gameplay concluídas

As entregas de movimentação, trava, câmera e remapeamento de atalhos estão implementadas e confirmadas; o escopo original da fase está encerrado.

Ajuste após teste: marcador agora é um ponto 2D branco de raio 5 px com contorno escuro, projetado no centro do corpo (posição da CollisionShape3D; fallback de 0,9 unidade acima da origem) após atualização da câmera, independente de fonte/zoom. Alcance dos dummies reduzido de 2,0 para 1,4, ficando dentro do alcance de 1,5 do Player para permitir revidar. A trava continua sem aumentar alcance nem atravessar obstáculos.

- [x] Ação `toggle_target_lock`, tecla T: travar/destravar sem iniciar perseguição automática.
- [x] Prioriza inimigo selecionado válido; senão escolhe o mais próximo do cursor entre candidatos visíveis, sem parede entre ele e o Player e a até 12 unidades.
- [x] Ponto branco no centro do corpo; ataques manuais miram no alvo travado e priorizam esse alvo no impacto, mantendo alcance, direção comprometida do golpe e teste de obstáculos.
- [x] Libera ao morrer/remover alvo, morrer Player ou ultrapassar 18 unidades. Pausa/UI/arraste bloqueiam o comando.
- [x] Troca lateral: Q para esquerda e E para direita na tela. Escolhe o candidato válido mais próximo do alvo atual naquele lado; mantém a trava se não houver candidato. Reutiliza alcance de aquisição, visibilidade e obstáculos. Sem trava, não inicia uma automaticamente. Não altera câmera nem perseguição.
- [x] Modos Mouse/WASD/Híbrido em Configurações → Interface → Movimentação, aplicados imediatamente e salvos na seção `controls` (`movement_input_mode`). Híbrido é o padrão. Trocar cancela deslocamento/aproximação anteriores, preservando trava e ataques. No modo WASD, cliques selecionam inimigos e coletam loot próximo, sem caminhar automaticamente; no modo Mouse, WASD não movimenta. Dicas acompanham o modo sem apagar atalhos do InputMap.
- [x] Câmera Livre/Acompanhar alvo em Configurações → Interface, salva como `controls/lock_camera_follow`; acompanhamento ativo por padrão. Na trava, zoom temporário de 13,5% (multiplicador 0,865; respeita mínimo 6) e foco suavizado 40% em direção ao alvo, limitado a 4 unidades ou 20% do span de zoom. Rotação isométrica preservada, offsets somados à composição e ao impacto. Ao destravar, perder alvo ou escolher Livre, retorna suavemente; scroll durante a trava atualiza o zoom-base a restaurar. Troca Q/E também suaviza o foco.
- [x] Segurar Alt (`hold_target_facing`) mantém o personagem voltado suavemente ao alvo travado, parado ou andando. Sem alvo travado, mira na direção do cursor (ponto no chão sob o mouse) para mirar ataques. Soltar retorna à orientação pelo movimento. Ataque/reação a dano mantêm prioridade. Pausa, perda de foco, UI de inventário e arraste interrompem a intenção. Não muda velocidade, dano, câmera ou trajetos; animações laterais/de ré específicas ainda não fazem parte desta entrega.
- [x] A câmera acompanha levemente a posição do cursor: deslocamento passivo suave de até 6% do enquadramento por eixo, nulo com o cursor no centro e conversão por zoom/aspect atual. Pausa, morte, inventário aberto e arraste de interface retornam ao enquadramento do Player; perda de foco zera o deslocamento. Rotação, zoom e movimento do personagem não mudam. Substitui o antigo arraste pelo botão do meio.
- [x] Composição vertical: `vertical_bias` (padrão 0,18) desloca o enquadramento para baixo em fração da altura da tela, deixando o Player abaixo da linha central horizontal em qualquer zoom.
- [x] Remapeamento completo de atalhos em Configurações → Controles: trocar tecla ou botão do mouse por ação, detecção de conflitos com indicação da ação em uso, restaurar ação ou tudo, salvar em `user://keybinds.cfg` e dicas atualizadas na hora. Inventário passou a usar a ação `toggle_inventory`. Botão esquerdo e scroll são reservados. 21 ações remapeáveis (WASD, corrida, arma, ataque, trava/alvo, inventário, HUD, pausa e atalhos da hotbar).

Checagem breve de código e smoke test de hotbar/trava; validação de gameplay e aparência fica com o usuário. Navegação e cenário não foram alterados nesta entrega.

## Forma de trabalho combinada

Implementar em entregas pequenas. Por solicitação do usuário, realizar apenas verificações MUITO breves de código/carregamento, ou testes adicionais quando explicitamente solicitados. Os testes de gameplay, apresentação e balanceamento serão realizados pelo usuário, que retornará os resultados. Evitar baterias extensas para economizar créditos.

## Entrega da Fase 1 — 19/09/2026

Primeira entrega aprovada pelo usuário no teste jogável. Ajuste seguinte: reduzir um pouco mais a velocidade dos ataques.

### Ajuste de socos e impacto aprovado

- Espada mantém reprodução em 1,50. Socos passam a 1,25 e intervalo mínimo de 0,65 s, respeitando o término de cada animação. Dano desarmado permanece 5: opção de defesa rápida, sem golpes sobrepostos.
- Acertos do Player que efetivamente retiram vida produzem faíscas branco-quentes no contato e um impulso de câmera com retorno suave em 0,12 s. Socos usam menos faíscas e 45% da intensidade de câmera.
- Golpes no vazio, fora de alcance, bloqueados pelo cenário ou ignorados pela recuperação do inimigo não ativam os efeitos. Efeitos também aparecem no golpe fatal.
- Câmera mantém ângulo, zoom e posição de acompanhamento; o impulso usa offsets visuais independentes e não acumula deslocamento. Faíscas são removidas após 0,16 s e respeitam a pausa da cena.
- Validação de aparência e sensação fica com o usuário, conforme combinado.

- Ataque armado: reprodução inicialmente reduzida de 2,392 para 1,65 e, após aprovação, para 1,50; desarmado: de 1,0 para 0,85 e depois 0,78. Ajustáveis em `Player/Visual`.
- Movimento horizontal do Player bloqueado durante o ataque, incluindo recuperação da animação; gravidade continua ativa. Destinos por clique são retomados ao terminar. Rotação acompanha o alvo somente antes do impacto.
- Dano continua sincronizado com o evento da animação. Alcance, altura e obstáculos são conferidos novamente no impacto. XP só é concedido quando o alvo realmente morre.
- Inimigos preparam o ataque por 0,4 s, permanecem parados e recuperam por 0,55 s. O impacto verifica se o jogador continua vivo e alcançável.
- Antecipação visual nas cápsulas: cor âmbar e compressão, seguida de extensão e retorno. Flash branco curto ao receber dano. São efeitos provisórios para os dummies; animações esqueléticas próprias e áudio ficam pendentes de recursos adequados.
- Stamina para corrida: máximo 100, consumo 22/s, regeneração 28/s após 1 s, retomada após exaustão em 20%. Parâmetros no Player. Funciona com WASD e clique; não consome parado ou durante ataques.
- Barra verde de stamina acima da barra de ações, com fade ao começar a gastar e após encher.

Verificação breve: editor Godot 4.7.2 carregou sem erros de script; cena principal iniciada por três frames em headless. Essa execução registrou imagem nula no gerador de previews de itens (`item_preview_generator.gd:52–53`), que usa renderização indisponível no modo headless. Aparência, combate e balanceamento ainda precisam do teste manual do usuário. Não foi executada bateria de regressão.

## Visão atual do projeto

### Áudio temporário — espada e passos

Atualização dos arquivos de passos: grama, pedra e tecido usam os pares `*_padrao.mp3` e `*_alternativo.mp3`. Após retorno do usuário, passos usam apenas UM reprodutor: alternativo substitui o padrão naquele passo, sem sobreposição. Há uma tentativa de 35% a cada 4 s de deslocamento contínuo; chance e intervalo são independentes dos da espada e ajustáveis em `Player/Audio`. Redução de 50% da grama mantida em ambas as variantes.

A cadência dos passos agora é calculada pelas durações dos clips Walk/Run e pelas velocidades e misturas usadas pelo AnimationTree, considerando dois passos por ciclo. Cada disparo reinicia um único som, interrompendo a cauda anterior caso necessário. Esse ajuste acompanha caminhada, corrida e estado armado/desarmado sem depender da duração do loop de áudio. É sincronização de cadência, não marcação exata de contato de cada pé; a avaliação auditiva/visual fica com o usuário. Velocidade-base de reprodução (pitch) continua ajustável separadamente.

Para superfícies de tecido, adicionar metadata String `footstep_surface = "cloth"` (ou `"tecido"`) ao corpo físico do piso no editor. Grama aceita `grass`/`grama`; pedra é o padrão para as demais superfícies. Nenhum piso existente foi convertido arbitrariamente em tecido. O arquivo extra `passos_em_tecido.mp3` não é usado; foi preservado.

- `Player/Audio` usa `player_audio.gd`; recursos, volumes e intervalos são editáveis no Inspector, inclusive no Remote durante a execução.
- Espada toca no evento de impacto da animação. Som padrão no uso normal, inclusive no vazio; alternativo no primeiro golpe contra um inimigo alcançável. Depois, chance de 35% por golpe elegível, com intervalo mínimo de 4 s entre alternativos. Trocar de inimigo ou passar 6 s sem golpe contra um alvo inicia um novo encontro.
- Passos usam loops temporários: grama em `Ground`, pedra nas demais superfícies. A metadata `footstep_surface` com `grass` ou `stone` permite definir o material por superfície.
- Reprodução acompanha velocidade real, WASD/clique, corrida, exaustão e obstáculos. Para ao ficar parado, sair do chão, atacar ou morrer. Pausa acompanha a árvore da cena. Acelerar a reprodução também altera o tom, conforme a solução temporária solicitada.
- Velocidade-base dos passos: 1,1; volume dos passos: -14 dB; espada: -8 dB. Avaliação auditiva fica com o usuário.
- Ajuste posterior: som padrão sempre acompanha o golpe; alternativo é uma camada simultânea adicional, mantendo as regras de chance e intervalo. Cada camada tem seu próprio reprodutor.
- Passos na grama reduzidos a 50% da amplitude (-6,02 dB adicionais); pedra mantém o volume-base.
- Menu de configurações: controles de volume geral, efeitos sonoros, espada e passos (0–100%), silenciar tudo e restaurar áudio. Aplicação e salvamento imediatos em `user://settings.cfg`, seção `audio`; cancelar as alterações de vídeo não desfaz áudio já salvo. Buses `Swords` e `Footsteps` alimentam `Effects`, que alimenta `Master`.

O projeto é um protótipo funcional de RPG 3D isométrico feito em Godot 4.7. A cena principal é `main.tscn`.

Sistemas atualmente presentes:

- Movimentação por clique e por WASD.
- Corrida com Shift.
- Navegação 3D com obstáculos, rampas, escadas e diferentes elevações.
- Câmera ortográfica isométrica com níveis de zoom.
- Seleção, aproximação e perseguição de inimigos.
- Combate automático e ataque manual com o botão direito.
- Inimigos com estados `IDLE`, `CHASE`, `ATTACK` e `RETURN`.
- Vida, dano flutuante, morte, XP e progressão de nível.
- Loot físico no cenário e coleta por aproximação.
- Inventário espacial de 10 colunas por 6 linhas.
- Pilhas, troca, movimentação e descarte de itens.
- Equipamentos e bônus de atributos.
- Barra de ações para consumíveis.
- Modelo animado com estados armado e desarmado.
- Oclusão dinâmica para paredes, plataformas e telhados.
- HUD, menu de pausa e configurações de vídeo e interface.

## Arquitetura principal

### `main.gd`

- Interpreta os cliques no mundo.
- Prioriza loot, inimigos e superfícies caminháveis.
- Mantém o inimigo selecionado.
- Envia destinos e alvos ao Player.
- Exibe notificações gerais e a interface de morte.

### `player.gd`

- Movimentação manual e por navegação.
- Aproximação de inimigos e loot.
- Ataques automáticos e manuais.
- Vida, atributos, XP e nível.
- Coleta e uso de consumíveis.
- Cria `Equipment` e `ActionBar` durante a execução.

### `player_visual.gd`

- Rotação visual do personagem.
- Árvore e reprodução de animações.
- Estados da espada: sem arma, embainhada, sacando, em mãos e guardando.
- Eventos de impacto, dano e morte.

### `enemy_dummy.gd`

- Máquina de estados da IA.
- Perseguição, ataque e retorno ao ponto inicial.
- Vida, seleção e barra de vida 3D.
- Geração de loot ao morrer.

### Sistemas de itens

- `item_data.gd`: definição de itens, raridades, tipos, tamanho, equipamento e bônus.
- `inventory.gd`: ocupação da grade, pilhas e movimentação de itens.
- `equipment.gd`: equipamentos e cálculo dos bônus.
- `action_bar.gd`: atalhos para consumíveis.
- `world_loot.gd`: apresentação, seleção e coleta de loot no mundo.

Itens existentes: espada gasta, espada de ferro, poção de vida, fragmento antigo, peitoral de couro, botas de couro, anel simples e amuleto antigo.

## Pontos de atenção técnicos

- Parte da documentação antiga descreve etapas já superadas. Este documento e `REVISAO.md` devem ser considerados as referências mais atuais.
- `player.gd` concentra movimento, combate, coleta, progressão e atributos. No futuro, deve ser separado em componentes menores.
- `main.tscn` concentra quase todo o mapa e deve ser dividido quando o conteúdo crescer.
- Equipamento e barra de ações são criados por script, enquanto o inventário faz parte da cena. Convém padronizar a composição futuramente.
- Ainda não existe persistência do personagem, inventário, progresso ou estado do mundo.
- O projeto ainda usa o nome interno `New Game Project`.
- Existem ferramentas e experimentos históricos em `scratch/`; devem ser separados ou arquivados quando não forem mais necessários.
- Layers e masks de física aparecem como valores numéricos em diferentes scripts. Convém centralizá-los ou nomeá-los nas configurações do projeto.
- Acessos diretos a membros internos, como `_items` e `_is_open`, devem futuramente ser substituídos por APIs públicas.

## Direção geral

Antes de adicionar muitos sistemas isolados, o objetivo é formar uma pequena experiência completa de 5 a 10 minutos:

`Explorar -> enfrentar inimigos -> receber loot -> equipar ou usar itens -> ganhar XP -> enfrentar um inimigo mais forte -> concluir um objetivo`

Uma primeira vertical slice pode conter:

- Três inimigos comuns.
- Um inimigo elite.
- Um objetivo simples, como eliminar inimigos ou recuperar um artefato.
- Recompensa e condição de vitória.
- Salvamento do progresso essencial.

## Roadmap aprovado

### Fase 1 — Combate sólido

Fase entregue; histórico dos objetivos originais:

1. Diminuir a velocidade da animação de ataque, que atualmente está rápida demais.
2. Parar brevemente Player e inimigos durante a preparação e o impacto dos ataques.
3. Organizar cada ataque nas fases de preparação, impacto e recuperação.
4. Melhorar a antecipação e a recuperação visual dos ataques inimigos.
5. Melhorar o feedback de impacto com reação, flash, recuo, pausa visual e sons quando houver recursos adequados.
6. Implementar stamina, inicialmente aplicada à corrida.

Regras desejadas para a trava durante ataques:

- O personagem não deve deslizar enquanto executa a parte comprometida do golpe.
- O inimigo deve interromper a perseguição durante seu ataque.
- A rotação pode continuar por um curto período para alinhar o golpe.
- O dano deve continuar acontecendo no evento de impacto da animação.
- O movimento retorna durante a recuperação ou ao final da animação, conforme o ataque.

O código já possui conceitos aproveitáveis: `attack_cooldown`, `hit_attack_lock_timer`, `enemy_attack_recovery` e eventos de impacto em `player_visual.gd`.

Primeira versão da stamina:

- Drena somente durante a corrida.
- Regenera após um pequeno atraso.
- Impede a corrida quando chega a zero.
- A barra aparece durante o uso e pode desaparecer quando estiver cheia.
- Valores devem ser configuráveis no Player.
- Ataques, esquiva e salto não consumirão stamina nesta primeira versão.

### Fase 2 — Loot e interface

- [x] 1. Mostrar no canto inferior direito o último item coletado, com ícone, nome e quantidade.
- [x] 2. Aplicar fade e tempo de exibição configurável.
- [x] 3. Empilhar ou enfileirar coletas realizadas em sequência.
- [x] 4. Mover a notificação em direção ao centro quando o inventário abrir, evitando sobreposição.
- [x] 5. Retornar a notificação ao canto quando o inventário fechar.
- [x] 6. Mostrar uma borda fina em destaque ao redor dos itens novos.
- [x] 7. Definir quando um item deixa de ser novo: hover, seleção ou interação.
- [x] 8. Preservar corretamente o estado de item novo ao juntar pilhas.
- [x] 9. Adicionar opção para esconder ou exibir a HUD.
- [x] 10. Dar menos destaque visual às informações de teclas no canto inferior esquerdo.
- [x] 11. Adicionar configuração de tamanho do cursor aplicada em tempo real.

O registro de aquisições deve ser compartilhado entre a notificação de coleta e a marcação de itens novos.

### Fase 3 — Controles, trava de alvo e câmera

- [x] 1. Permitir os modos de movimento `mouse`, `WASD` e `híbrido`.
- [x] 2. Manter somente os atalhos relevantes ativos para o modo escolhido.
- [x] 3. Criar trava e destrava de alvo.
- [x] 4. Mostrar um ponto branco ou marcador equivalente sobre o inimigo travado.
- [x] 5. Destravar automaticamente quando o alvo morrer, for removido ou sair do limite permitido.
- [x] 6. Permitir trocar de alvo para os lados.
- [x] 7. Separar adequadamente a rotação do personagem e o controle da câmera.
- [x] 8. Adicionar a configuração `câmera acompanha alvo` ou `câmera livre` durante o lock-on.
- [x] 9. Permitir mover a câmera com o mouse até uma distância máxima definida somente no código.
- [x] 10. Fazer a câmera respeitar inventário, outras interfaces, zoom e lock-on.
- [x] 11. Implementar remapeamento completo de teclas em uma etapa própria.
- [x] 12. Detectar conflitos, restaurar padrões, salvar escolhas e atualizar dicas de teclas em tempo real.

O lock-on deve ser implementado incrementalmente. A primeira entrega conterá apenas travar, destravar, marcador visual e perda segura do alvo. Câmera e troca de alvos entram depois que essa base estiver estável.

### Fase 4 — Estrutura do jogo, inimigos e dificuldade

- [x] 1. Criar uma classe ou componente base de inimigo.
- [x] 2. Criar pelo menos três arquétipos:
   - Corpo a corpo padrão.
   - Pesado, lento e resistente, com ataque antecipado.
   - Ágil, mais rápido e frágil.
- [x] 3. Criar blocos ou volumes invisíveis configuráveis que definam posição e tamanho de regiões de spawn.
- [x] 4. Criar um gerenciador de spawn que respeite limites, distância do Player e espaço navegável.
- [x] 5. Adicionar o sistema de dificuldade.
- [x] 6. Centralizar na dificuldade os multiplicadores e limites de:
   - Vida e dano dos inimigos.
   - Quantidade simultânea de inimigos.
   - Frequência de spawn.
   - Percepção e agressividade.
   - Qualidade ou quantidade de loot, se desejado.
- [x] 7. Adicionar a opção de dificuldade à interface e persistir a escolha.
- [ ] 8. Criar objetivo simples, inimigo elite, recompensa e condição de vitória.
- [ ] 9. Implementar save/load para:
   - Posição, vida, nível e XP.
   - Inventário e quantidades.
   - Equipamentos e barra de ações.
   - Configurações.
   - Objetivos e estados importantes do mundo.

A dificuldade deve ser centralizada. Não espalhar testes como `if difficulty == hard` por diferentes scripts.

### Fase 5 — Polimento e expansão

1. Fazer a HUD desaparecer dinamicamente após longo tempo de inatividade.
2. Aproximar suavemente a câmera do personagem durante essa inatividade.
3. Sincronizar o desaparecimento da HUD e o zoom com o início da animação idle longa.
4. Permitir desativar esse comportamento nas configurações.
5. Adicionar pequeno efeito de vento durante a corrida.
6. Fazer o efeito de corrida surgir e desaparecer com fade.
7. Criar paredes ou volumes invisíveis ajustáveis no editor.
8. Definir obstáculos que podem ser pulados.
9. Implementar animação e física de pulo.
10. Integrar o pulo ao movimento por clique e à navegação, provavelmente usando `NavigationLink3D` onde for apropriado.
11. Decidir separadamente se inimigos também poderão usar os pontos de salto.

## Prioridade por impacto e esforço

| Melhoria | Esforço estimado | Importância |
|---|---:|---:|
| Diminuir velocidade do ataque | Muito baixo | Alta |
| Travar movimento durante ataques | Baixo a médio | Muito alta |
| Reduzir destaque das dicas de teclas | Muito baixo | Baixa |
| Opção de esconder a HUD | Baixo | Média |
| Notificação do último item coletado | Médio | Alta |
| Marcar itens novos | Médio | Média a alta |
| Stamina | Médio | Alta |
| Lock-on | Alto | Muito alta |
| Modos mouse, WASD e híbrido | Alto | Alta |
| Sistema de dificuldade | Médio a alto | Alta |
| Spawns aleatórios por região | Alto | Alta |
| Câmera deslocável pelo mouse | Médio a alto | Média |
| HUD dinâmica com zoom e idle | Médio a alto | Média |
| Pulo integrado à navegação | Alto | Situacional |
| Efeito de vento na corrida | Médio | Baixa |

## Refatorações planejadas

Quando a vertical slice estiver funcional, a divisão desejada do Player é:

```text
Player
|-- PlayerMovement
|-- PlayerCombat
|-- PlayerStats
|-- PlayerProgression
|-- Inventory
|-- Equipment
|-- ActionBar
`-- Visual
```

Outras refatorações:

- Criar uma base comum para inimigos.
- Separar mapa, entidades e interface em cenas menores.
- Padronizar a criação dos componentes do Player.
- Centralizar configurações e constantes compartilhadas.
- Manter os testes atuais e ampliar a cobertura conforme novos sistemas forem criados.

## Casos de teste importantes

- Morte durante coleta, ataque ou animação.
- Pausa durante ataque, drag-and-drop ou transição de interface.
- Remoção do alvo durante o evento de impacto.
- Inimigo sem rota válida.
- Player e inimigo em alturas diferentes.
- Inventário cheio e pilhas parcialmente ocupadas.
- Equipar ou desequipar sem espaço livre.
- Conservação de quantidades durante coleta, descarte e fusão de pilhas.
- Save/load de itens de tamanhos diferentes.
- Troca de modo de movimento durante navegação ou combate.
- Perda ou morte do alvo durante lock-on.
- Interação entre lock-on, câmera livre e interfaces abertas.

## Próxima tarefa

Atual: Fase 3 encerrada com a aprovação do usuário. Fase 4 em andamento, itens 1 a 7 implementados. `enemy_base.gd` extrai a lógica comum; `enemy_archetype.gd` define os perfis padrão, pesado e ágil. `spawn_region_3d.gd` define volumes invisíveis configuráveis por posição, tamanho, limite, peso e cenas permitidas. `enemy_spawn_manager.gd` controla intervalo e população global, respeita limite local, distância do Player, NavigationMap e espaço físico livre. Duas regiões iniciais foram adicionadas ao mapa. `difficulty_manager.gd` centraliza os perfis Fácil, Normal e Difícil, aplicando vida, dano, velocidade, percepção, população e intervalo de spawn; a opção foi adicionada à interface e persiste em `settings.cfg`. Mudanças durante a partida atualizam inimigos existentes preservando a proporção de vida. Carregamento no Godot 4.7.2 aprovado; testes focados retornaram `ARCHETYPES: 0 failures`, `SPAWN_MANAGER: 0 failures` e `DIFFICULTY: 0 failures`. Próxima entrega: objetivo simples, inimigo elite, recompensa e condição de vitória. O restante desta seção registra entregas anteriores.

Ataque manual contínuo: segurar `manual_attack` (botão direito atual) repete golpes respeitando cooldown e fim da animação, mirando a posição atual do mouse a cada novo golpe. Soltar termina apenas o golpe em andamento e limpa ataques pendentes. Clique rápido continua dando um golpe. Iniciar ataque manual cancela aproximação/ataque automático; pausa, perda de foco, morte, arraste e passagem sobre UI interrompem a repetição, exigindo novo pressionamento.

Correção do grunhido: a reprodução agora é interrompida ao terminar ou cancelar a animação de ataque, mesmo se o arquivo for mais longo. Vozes de dano e morte ficam independentes dessa interrupção.

Sons de combate e morte integrados: grunhido no evento do golpe (junto das camadas de espada, também nos socos), voz de dano do inimigo inclusive no golpe fatal e voz de dano do Player escolhida entre padrão/alternativo (35%). Uma única voz do Player impede sobreposição das variantes; morte interrompe os sons anteriores e inicia a voz junto da animação. Vozes usam o volume de Efeitos; streams, volume e chance do Player são ajustáveis em `Player/Audio`.

Morte: comandos bloqueados, inventário fechado e HUD oculto durante a animação. A tela e os atalhos de reinício são liberados apenas após `AnimationTree.animation_finished` do clip de morte. Checagem breve automática confirmou tela oculta inicialmente e exibida após o término (`DEATH_SEQUENCE_OK=true`). Execução headless ainda registra os avisos conhecidos de miniaturas sem imagem e um aviso de objetos remanescentes ao encerrar o teste; avaliação auditiva/visual fica com o usuário. Script temporário de checagem removido após uso.

Ajuste seguinte: deslocamento geral reduzido em 20% (MOVEMENT_SPEED_SCALE de 0,85 para 0,68), incluindo caminhada/corrida, clique/WASD e armado/desarmado. Animações de corrida reduzidas em 15%: sem arma de 2,00 para 1,70, com arma de 1,44 para 1,224. Reprodução normalizada pela escala de movimento original para evitar somar involuntariamente a redução física à redução visual; mantém a caminhada previamente ajustada. Cadência de passos segue as animações.

Ajuste solicitado após avaliação dos passos: animações de caminhada 40% mais lentas em relação aos valores originais, sem arma de 2,50 para 1,50 e com arma de 3,75 para 2,25 (substitui a redução inicial de 20%). Velocidade de deslocamento e animações de corrida preservadas. A cadência do áudio acompanha os novos valores automaticamente.

Aguardar o retorno do usuário sobre a entrega da Fase 1 e ajustar velocidade dos golpes, duração da trava, feedback dos inimigos e stamina conforme a sensação ao jogar. Depois seguir para a Fase 2. Sons e animações próprias de inimigos permanecem como polimento pendente de recursos adequados.
