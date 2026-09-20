# Convenções do Inspector

## Registro — Spawn independente, revisão do bloco 3 (20/09/2026)

- Cada `SpawnRegion3D` agora é um spawner autocontido: ciclo próprio, intervalo e atraso próprios, distâncias e posicionamento próprios, composição própria e contador próprio de inimigos vivos. Um spawner não afeta nem lê configuração de outro. `EnemySpawnManager` foi removido junto com o grupo `enemy_spawn_regions`; não existe mais limite global nem seleção ponderada entre regiões.
- Inspector do spawner: GERAL (ativada, pai_dos_inimigos), REGIÃO (tamanho_da_regiao), POPULAÇÃO (maximo_de_inimigos), TEMPO (intervalo_de_spawn, atraso_inicial), POSICIONAMENTO (distância mínima/máxima, tentativas, tolerância, raio livre), COMPOSIÇÃO (inimigos) e EDITOR (mostrar_regiao, cor_da_regiao). Os valores expostos são as bases; a dificuldade multiplica intervalo e máximo a partir da base de cada spawner, sem copiar valores entre eles. Setters de base reaplicam a dificuldade; edição pelo Remote afeta somente aquele spawner.
- `EntradaDeSpawnDeInimigo` (Resource) compõe a lista didática: nome (também alimenta resource_name), ativado, cena_do_inimigo e peso relativo. A chance de uma entrada é o peso dividido pela soma dos pesos das entradas ativadas; peso zero ou entrada desativada é ignorada. Entradas ativado/peso podem ser ajustadas pelo Remote.
- Contagem de população por registro e sinais: dicionário por instance_id alimentado por `tree_exited` e `died`; sem varredura de árvore por frame. Cobre queue_free, morte, remoção externa e troca de cena. Inimigos colocados manualmente não consomem limite de spawner.
- Correção de inimigos inertes: `_ready()` do inimigo capturava `home_position` antes de o spawner atribuir `global_position`, deixando a origem na posição do nó `Enemies`; o leash calculado contra essa origem mantinha o inimigo em IDLE mesmo com o jogador ao lado. Novo `EnemyBase.setup_spawn(posição)` define posição e origem logo após `add_child`, de forma determinística, antes do primeiro frame de física. Inimigos manuais continuam capturando a origem no `_ready`.
- Diagnóstico por spawner no Inspector Remote: propriedades somente leitura via `_get_property_list` na categoria DEBUG — Inimigos Vivos ("n / máximo efetivo"), Próximo Spawn (s), Estado e Última Falha. Não são armazenadas nem editáveis; não exigem plugin.
- Migração da composição: WestGround preservou duas entradas (padrão, ágil) e NorthGround três (padrão, pesado, ágil), cada uma com peso 1.0 e ativada; limites atuais (10/10) e tamanhos preservados. `pai_dos_inimigos` padrão é `../../Enemies`.
- Testes: `spawn_region_test.gd` (limites independentes, inimigos manuais, liberação de vaga, desativação isolada, composição ponderada/vazia, posição/home corretos e entrada em CHASE) e `difficulty_test.gd` (bases independentes sob hard/easy) — ambos com 0 falhas. `spawn_manager_test.gd` foi substituído.

Volumes/spawners independentes devem possuir configuração e estado próprios; sistemas globais não devem introduzir limites compartilhados sem necessidade explícita de design.

## Registro — Inimigos, bloco 2 (20/09/2026)

- `EnemyArchetype` é a fonte dos parâmetros do tipo, organizado em IDENTIDADE, COMBATE, PERCEPÇÃO E MOVIMENTO e APARÊNCIA. Propriedades em português, ranges com unidades e tooltips. Setters emitem `changed` para atualizar os consumidores sem polling.
- `EnemyBase` expõe PERFIL, MOVIMENTO, LOOT e ÁUDIO: perfil, gravidade (20), tabela de loot, som de dano e volume (-8 dB). Vida, dano, alcance, tempos, percepção, velocidade e nome efetivos são internos, derivados do perfil e da dificuldade.
- Os três `.tres` tiveram somente os nomes de propriedades migrados. Padrão: vida 100/dano 10/velocidade 2.5; pesado: 240/24/1.5; ágil: 55/7/4.3. Demais valores, cores e escalas preservados. As duas cenas especializadas migraram a referência `archetype` para `perfil`.
- Edição do perfil em runtime preserva a quantidade de vida atual, limitada ao novo máximo. Troca de dificuldade mantém a política anterior de proporção de vida. Cor, escala visual e nome são atualizados; escala continua sem alterar colisão/navegação. Tempos já em andamento não são reiniciados.
- Resources compartilhados afetam intencionalmente todos os consumidores. Para uma instância, usar Tornar único no recurso antes de editar. Trocar o perfil desconecta os sinais do recurso anterior.
- Barra de vida: atraso 0.25 s e duração 0.4 s traduzidos e documentados, utilizados no próximo dano.
- Teste breve `enemy_archetype_test.gd`: zero falhas, incluindo atualização por sinal, preservação/limitação de vida e isolamento de recurso particular. Ambiente restrito reportou avisos de log e certificados.
- XP continua na regra existente do Player (25 por morte); não foi criado um campo de inimigo sem consumidor. Apresentação detalhada do loot e efeitos segue reservada aos respectivos blocos.

Todo parâmetro de design, balanceamento, apresentação ou comportamento que razoavelmente precise ser ajustado durante o desenvolvimento deve ser exposto no Inspector quando tecnicamente apropriado. O Inspector é uma interface de configuração selecionada, não uma listagem de todas as variáveis.

## Regras obrigatórias para sistemas atuais e futuros

1. Configurações de desenvolvimento devem aparecer em português: nomes, categorias, grupos, subgrupos, opções e documentação. Preferir identificadores portugueses sem acentos; não traduzir APIs nativas ou externas.
2. Usar `@export_category`, `@export_group` e, quando a quantidade justificar, `@export_subgroup`. Evitar grupos enormes e hierarquia desnecessária.
3. Usar `@export_range` com faixa coerente, unidade quando aplicável e `or_greater` quando o limite superior for apenas conveniência de edição. Proteger restrições matemáticas reais, como divisores positivos.
4. Documentar os parâmetros com comentários `##` em português, explicando unidades, efeitos, dependências e quando alterações entram em vigor.
5. Não exportar estados internos: vida/XP/stamina atuais, nível atual, alvos, cooldowns correntes, flags, Tweens, caches, materiais duplicados, referências temporárias ou valores derivados.
6. Evitar números mágicos de design. Constantes técnicas e invariantes permanecem internas. Não expor uma variável apenas porque existe.
7. Manter uma fonte de configuração por conceito. Acessos de compatibilidade só podem encaminhar à fonte principal, sem outro armazenamento ou export concorrente.
8. Parâmetros destinados a testes devem responder ao Inspector Remote quando seguro. Preferir leitura direta, setters e sinais; não fazer polling por frame para detectar mudanças.
9. Preservar o estado durante ajustes: aumentar máximos não cura nem repõe recursos; diminuir limita o estado atual quando necessário. Mudanças de duração normalmente valem no próximo evento, sem reiniciar ações em curso.
10. Resources compartilhados devem ter proprietário e escopo explícitos: global, tipo ou instância. Documentar que editar um recurso compartilhado afeta seus consumidores; usar recurso particular somente quando a configuração for por instância.
11. Novas mecânicas devem seguir estas regras desde a criação. Não sacrificar encapsulamento nem fazer refatorações alheias para expor parâmetros.

## Migração de propriedades

Antes de renomear, localizar referências em scripts, cenas, resources e trilhas de animação. Registrar defaults e overrides serializados; migrar nomes preservando valores antes de reabrir/salvar cenas. Comparar os valores efetivos e fazer a checagem breve autorizada. Não substituir propriedades nativas por correspondências textuais indiscriminadas.

## Registro — Player, blocos 0 e 1 (20/09/2026)

- Grupos: MOVIMENTO, STAMINA, COMBATE, ATRIBUTOS BASE e COLETA.
- Não foram encontrados overrides serializados dos exports do Player nas cenas/resources atuais; `main.tscn` não precisou de migração neste bloco. Os `attack_range` dos recursos de inimigos pertencem a outro sistema.
- Clique (`speed = 4.0`) e WASD (`manual_move_speed = 4.0`) usam agora `velocidade_de_movimento = 4.0`. Mesmos multiplicadores: escala 0.68, arma 0.80 e corrida 1.5. Gravidade 20.0.
- Stamina: máximo 100.0, consumo 22.0/s, regeneração 28.0/s, atraso 1.0 s, retomada 0.2 (20%).
- Combate: dano base 20, desarmado 5, alcance 1.5 m, intervalos 1.0/0.65 s, buffer 0.25 s, trava de movimento 0.18 s, trava de ataque 0.12 s.
- Atributos base: vida 100, armadura 0, força/destreza/inteligência 10. Coleta 1.75 m; `COLLECT_RANGE`, sem uso, foi removido.
- Cinco propriedades antigas permanecem apenas como getters internos de compatibilidade: `max_stamina`, `base_attack_damage`, `attack_range`, `MOVEMENT_SPEED_SCALE` e `HIT_ATTACK_LOCK`. Não aparecem no Inspector e não guardam valores próprios.
- Progressão permanece interna neste bloco: o limite inicial de XP é 100, enquanto a fórmula existente é `80 + (nível - 1) * 20`. Expor esses valores sem definir essa diferença criaria controles ambíguos. Nenhuma regra de progressão foi alterada.
- Propriedades de duração são usadas no próximo evento; timers em andamento não são reiniciados. Atributos recalculam bônus e notificam a HUD por setters, sem recriar componentes.
