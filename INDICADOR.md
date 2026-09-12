# Indicador de clique no terreno

Pressione **F5** e clique em partes livres do chão, da rampa e da plataforma. Um pequeno anel azul-claro aparece na superfície, cresce suavemente e desaparece em 0,65 segundo. Cliques rápidos reutilizam o mesmo anel na posição mais recente.

## Arquivos e integração

- `click_indicator.tscn`: cena reutilizável com Node3D e MeshInstance3D usando TorusMesh nativo, sem imagem externa.
- `click_indicator.gd`: posicionamento, alinhamento e animação com Tween.
- `main.tscn`: instancia um único ClickIndicator diretamente sob Main, fora do NavigationRegion3D.
- `main.gd`: após o clique caminhável já validado, chama `show_at(hit.position, hit.normal)`. O tratamento de seleção e movimento existente continua igual.

Não há corpos físicos, áreas ou formas de colisão no indicador. Ele não entra no raycast, não bloqueia o Player e não participa do Bake. Não precisa refazer o Bake.

## Altura e alinhamento

O indicador usa a posição exata encontrada pelo raycast no terreno. A normal desse contato orienta o anel, fazendo-o inclinar junto à rampa. Um deslocamento de 0,03 unidade na direção da normal evita z-fighting, inclusive na plataforma. Ele marca o clique real, não o destino aproximado pelo NavigationAgent3D.

## Animação

O anel começa visível com 70% do tamanho configurado. Durante os primeiros 30% do tempo, cresce para 100%. Depois dos primeiros 20% do tempo, a opacidade diminui gradualmente até zero. Ao terminar, o node fica oculto. Um novo clique encerra o Tween anterior e reinicia posição, escala e opacidade imediatamente.

Clicar em inimigos continua selecionando-os e não cria um indicador de terreno. Um indicador que já estava aparecendo termina sua animação normalmente. Clicar no terreno limpa a seleção, envia o destino e mostra o anel.

## Ajustes no Inspetor

Selecione **Main/ClickIndicator**:

| Propriedade | Padrão | Efeito |
|---|---|---|
| Size | 0,9 | Diâmetro final aproximado, em unidades do mundo |
| Duration | 0,65 | Duração total em segundos |
| Surface Offset | 0,03 | Pequena distância acima da superfície |
| Color | Azul-claro, alfa 0,85 | Cor e opacidade inicial |

Para mudar a espessura do anel, abra `click_indicator.tscn`, selecione **Ring**, expanda **Mesh** e ajuste **Inner Radius**, mantendo-o menor que **Outer Radius**. Quanto mais próximos os raios, mais fino o anel.

Nenhuma configuração manual obrigatória. Recarregue arquivos externos se o editor solicitar.
