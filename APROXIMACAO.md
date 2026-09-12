# Aproximação até inimigos

Clique numa cápsula vermelha: ela é selecionada, e o Player segue o caminho do NavigationAgent3D até ficar próximo. A seleção permanece quando ele para. Não há ataque, dano ou mudança de vida.

## Distância de parada

Em `player.gd`, `attack_range` tem valor padrão **1,5 unidade**. Para ajustar no editor, selecione **Player → Attack Range**, no Inspetor.

A distância é medida entre as origens dos personagens (os pés), em 3D. O mínimo oferecido no Inspetor é 0,8, acima da soma dos raios das cápsulas atuais (0,75).

O NavigationAgent3D calcula a rota até o inimigo. Antes de aplicar o próximo movimento horizontal, o Player verifica se está dentro do alcance, no mesmo nível (diferença de altura até 0,35) e sem cenário sólido entre os personagens. Quando essas condições são atendidas, deixa de avançar. Gravidade e colisões continuam funcionando normalmente. Isso evita parar na base da plataforma ou do outro lado de uma parede.

O Player agora também colide com a camada dos inimigos, impedindo que atravesse suas cápsulas. Os inimigos permanecem parados; eles não foram incluídos no Bake nem ganharam IA ou navegação dinâmica.

## Cancelamento

Clicar no chão, rampa ou plataforma cancela a aproximação, limpa a seleção, mostra o indicador de clique e define o novo destino normal. Clicar em outro inimigo troca tanto a seleção quanto o alvo da aproximação.

## Testes

1. Pressione F5 e clique no inimigo do chão. O Player deve se aproximar e parar sem encostar ou atravessar a cápsula.
2. Clique no inimigo da plataforma. O Player deve buscar a rampa, subir e parar perto dele.
3. Clique novamente no inimigo do chão. O Player deve descer pela rampa e se aproximar.
4. Durante uma aproximação, clique numa parte livre do chão: a seleção some, o indicador aparece e o Player muda de destino.
5. Altere Attack Range para 2,5 no Inspetor e execute novamente: ele deve parar mais longe.

Apenas os scripts `main.gd` e `player.gd` foram ajustados. A camada de colisão dos inimigos é habilitada pelo Player ao iniciar. Não precisa alterar a cena nem refazer o Bake. Os dummies deste estágio não se movem; não foi implementada perseguição de alvos móveis.
