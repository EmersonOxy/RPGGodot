# Ataque básico automático

Pressione F5 e clique em um inimigo. O Player se aproxima usando a navegação existente e, dentro de Attack Range, aplica **20 de dano a cada 1 segundo**. O primeiro ataque acontece assim que ele chega ao alcance e o intervalo está disponível.

O texto acima do inimigo mostra `100/100`, `80/100`, `60/100`, `40/100` e `20/100`. No quinto ataque, a vida chega a zero e o inimigo é removido. Sua seleção é limpa, e o Player para de atacar e de se aproximar. Reiniciar com F5 restaura os inimigos.

## Responsabilidades

- `player.gd`: aproximação, verificação de alcance e intervalo do ataque. `ATTACK_DAMAGE = 20` e `ATTACK_INTERVAL = 1.0` são as constantes no início do arquivo.
- `enemy_dummy.gd`: recebe dano por `take_damage`, atualiza HP, emite o sinal `died` e remove o inimigo quando HP chega a zero.
- `enemy_dummy.tscn`: ganhou `HealthLabel`, um Label3D acima da cabeça que fica voltado para a câmera.
- `main.gd`: observa a morte do inimigo selecionado, remove a seleção e cancela a aproximação.

O ataque exige o alvo selecionado, alcance, altura compatível e ausência de parede entre os personagens. O intervalo é compartilhado pelo Player: clicar repetidamente ou trocar de inimigo não produz ataques extras. Clicar no terreno continua cancelando o alvo, removendo a seleção e mostrando o indicador de movimento.

## Testar

1. Clique no inimigo do chão e acompanhe a redução de 20 em 20 até ele desaparecer.
2. Clique no da plataforma: o Player deve subir pela rampa antes de atacar.
3. Durante os ataques, clique no chão: a vida deve parar de diminuir.
4. Clique repetidamente no inimigo: o intervalo continua sendo de 1 segundo.

Não precisa refazer o Bake ou configurar nada manualmente. Recarregue os arquivos externos se o editor solicitar. Não foram adicionados animações, crítico, defesa, loot, XP, skills ou ataque inimigo.
