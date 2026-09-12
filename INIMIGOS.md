# Primeiro teste de inimigos: seleção

Pressione **F5**. Já existem dois inimigos vermelhos: `Enemies/GroundDummy` no chão (Y = 0) e `Enemies/PlatformDummy` na plataforma (Y = 2).

## Arquivos e nodes

- `enemy_dummy.tscn`: cena reutilizável com CharacterBody3D, MeshInstance3D vermelho, CollisionShape3D e SelectionIndicator (um TorusMesh amarelo).
- `enemy_dummy.gd`: guarda Max Health / Health, inicialmente 100, e mostra ou oculta o anel. Não tem movimento, ataque, perseguição, dano ou morte.
- `main.gd`: continua tratando cliques e agora mantém a referência de um único inimigo selecionado.
- `main.tscn`: ganhou o node organizador Enemies e as duas instâncias. Player, câmera, iluminação e cenário permanecem com a mesma configuração.

## Seleção

O raio do clique consulta terreno (camada 1), obstáculos (camada 2) e inimigos (camada 4), ignorando o Player (camada 3). O grupo `enemies` identifica inimigos; `walkable` identifica terreno caminhável.

Ao clicar numa cápsula vermelha, o anel anterior é ocultado e o novo é mostrado. Clicar novamente no mesmo inimigo mantém sua seleção. Clicar numa superfície caminhável limpa a seleção e envia o destino ao NavigationAgent3D existente. Clicar em obstáculos ou no fundo não altera a seleção nem o destino.

Selecionar um inimigo agora inicia a aproximação automática até o alcance configurado no Player. Clicar no terreno cancela essa aproximação. Consulte [APROXIMACAO.md](APROXIMACAO.md). Ainda não há ataque.

O anel é filho do inimigo, deitado no plano X/Z e elevado 0,04 unidade acima dos pés para não piscar contra o chão. Por isso acompanha a posição e a altura da instância: Y = 0,04 no chão e Y = 2,04 na plataforma. Neste estágio, posicione os dummies nas superfícies horizontais; o anel não se inclina automaticamente em rampas.

A colisão dos dummies permite detectá-los pelo clique e agora bloqueia fisicamente o Player. Eles continuam fora do Bake e permanecem parados.

## Adicionar outro inimigo manualmente

Os dois pedidos já estão na cena. Para adicionar mais um:

1. Pare o jogo e abra `main.tscn`.
2. Selecione `Enemies` e arraste `enemy_dummy.tscn` do painel FileSystem para ele, ou duplique um dummy com **Ctrl+D**.
3. No Inspetor, ajuste **Transform > Position**. A origem representa os pés. Exemplo no chão: `(-6, 0, 4)`; exemplo no topo da plataforma: `(1.5, 2, -6)`.
4. Mantenha Rotation zerada e Scale em `(1, 1, 1)` para este teste.
5. Salve a cena e pressione F5.

Não precisa configurar grupos, materiais, seleção ou colisão novamente; vêm da cena reutilizável. Não precisa refazer o Bake para adicionar esses dummies.

## Testes

1. Clique no inimigo do chão: deve surgir um anel amarelo junto aos pés.
2. Clique no da plataforma: o primeiro anel desaparece e o segundo aparece sobre a plataforma, não no chão inferior.
3. Alterne várias vezes: somente um anel deve ficar visível.
4. Clique no chão: o anel desaparece e o Player caminha.
5. Clique numa parte livre da plataforma e depois no chão inferior: o Player deve continuar usando a rampa.
6. Clique atrás de Block e Column: o Player deve continuar contornando os obstáculos.
7. Para conferir a vida, durante a execução selecione a árvore **Remote**, abra um dummy e observe Health = 100 no Inspetor. Selecioná-lo não altera esse valor.

Se o Godot avisar sobre alterações externas, recarregue os arquivos. Não existe configuração manual obrigatória.
