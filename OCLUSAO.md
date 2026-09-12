# Transparência dinâmica

O efeito é ativado somente quando os raios entre a câmera e o corpo do Player encontram um objeto preparado para oclusão. Os raios respeitam a projeção ortográfica.

- Blocos, colunas, paredes e plataformas usam recorte local apenas enquanto encobrem o personagem.
- Telhados do grupo `full_occluder` esmaecem por inteiro enquanto estão na frente dele.
- O chão normal não recebe o efeito. O corpo físico que sustenta os pés também é excluído, protegendo rampas e plataformas enquanto o Player está sobre elas.
- Uma plataforma mais alta pode ficar parcialmente transparente quando encobre o Player no nível inferior. Ao subir nela, deixa de receber o efeito.
- Cada malha possui seu próprio estado: objetos que compartilham cor/material não ficam transparentes juntos.
- Ao sair da oclusão, o efeito desaparece suavemente e o material volta à renderização opaca, sem permanecer na fila de transparência.

Em `OcclusionFade`, **Fade Duration** controla a transição (0,25 s), e **Occluded Alpha** controla a opacidade de telhados. Para impedir completamente o efeito num objeto, adicione o grupo **no_occlusion** ao seu StaticBody3D.

Os candidatos ao recorte local são as malhas já configuradas com `mask_props.tres` ou `mask_platform.tres`. O script cria versões independentes durante a execução. Nenhuma colisão, camada física, navegação, movimentação ou combate é alterada.

Teste passar atrás de um bloco/parede, sair de trás dele, andar sob o telhado e subir à plataforma. Os outros objetos devem permanecer opacos, e todos devem voltar ao estado original ao se afastar. Não precisa refazer o Bake. Pare a execução e recarregue os scripts/materiais externos se o Godot solicitar.
