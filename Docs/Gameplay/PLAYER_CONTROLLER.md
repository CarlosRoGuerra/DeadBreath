# Player Controller — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 1.0 (F1-012, 2026-11-20) |
| Estado | **Validado**: revisão técnica F1-010 e validação independente F1-011, ambas APROVADAS COM RESSALVAS; pipeline do Gate F1 verde |
| Código | `game/components/player/` (PlayerRoot, PlayerMotor, PlayerMotorConfig, MotorInput, `player.tscn`), `game/components/interaction/`, `game/content/data/player_motor_config.tres` |
| Contratos | COMPONENT_CONTRACTS §1, §2 (com o complemento v1.0), §3 e §3.1; DATA_STRUCTURES §1.1 e §10 |

## 1. Estrutura

```
Player (PlayerRoot, CharacterBody3D, grupo "player", camada 3, colide com 1 e 2)
├── CollisionShape3D   CylinderShape3D, raio 0,25 m, altura da postura; pés na origem do corpo
├── Head (Node3D)      altura dos olhos = topo do colisor − 0,10 m
│   └── Camera3D       FOV de Settings.fov
├── PlayerMotor        movimento, posturas, step-up, look, head bob, passos, aterrissagem
└── InteractionComponent   raio da câmera, foco, tocar/segurar
```

O **PlayerRoot** é o único script que conhece os componentes (PLR-INV-1; ARC-06 verifica). Ordem do tick, na prioridade de física −90: `motor.step` → limites da fisiologia (neutros na F1) → `interaction.step`.

## 2. Movimento

| Marcha / postura | Velocidade (m/s) | Esforço (`get_exertion`) | Passada (m) |
|---|---|---|---|
| Parado | 0 | 0 | — |
| Andar devagar (Alt) | 0,9 | 0,1 | 0,5 |
| Andar | 1,6 | 0,2 | 0,7 |
| Correr (Shift) | 4,8 | 1,0 | 1,1 |
| Agachado andando | 1,0 | 0,15 | 0,5 |
| Rastejando | 0,5 | 0,25 | 0,4 |

- Aceleração 10 m/s², desaceleração 14 m/s², gravidade 9,8 m/s².
- **Sprint** só em pé, andando para a frente (`move.y > 0,5`) e se a fisiologia permitir (`sprint_allowed`). `apply_limits` só reduz (MOT-INV-3).
- **Posturas:** Ctrl alterna em pé ↔ agachado; Z alterna para rastejar e, de rastejar, volta a agachado. Subir de postura exige espaço livre acima (MOT-INV-1); sem espaço, o comando é ignorado. Agachado não entra sob um vão de 0,6 m; rastejando (0,55 m) passa.
- Alturas do colisor: 1,75 m (em pé), 1,10 m (agachado), 0,55 m (rastejando). A altura dos olhos muda em 0,25 s.

## 3. Degraus, rampas e quedas

- `move_and_slide` sozinho não sobe degraus (spike V6). O motor faz o **step-up** até 0,30 m (folga de 2 mm: 0,30 sobe, 0,31 bloqueia). A sondagem olha só o movimento do tick mais 3 cm, porque o colisor é cilíndrico, com base plana. A altura de pouso é limitada a `step_height`, e o corpo avança 3 cm ao subir, para já estar sobre o degrau novo.
- **Assentamento** (BUG-002): se o tick termina no ar e existe piso voltado para cima até 0,30 m abaixo, o corpo é levado até ele. Isso evita a queda pela quina ao descer escadas.
- Critério verificado por propriedade (`tests/property/player/test_escada_propriedade.gd`): **0 ticks sem chão e nenhum `landed`** subindo e descendo, em todo o ciclo do degrau a cada 5 mm, nas escadas 0,18/0,28, 0,18/0,30 e na da sandbox.
- Rampas até 45° (`floor_max_angle`); parado numa rampa de 30°, o corpo não escorrega.
- **Cantos (BUG-004, contorno):** se o corpo pede movimento no chão e o tick anda menos de 25% do pedido, a velocidade guardada vira o deslocamento real; travado, o motor levanta 1 cm, refaz o movimento horizontal e reassenta. A causa exata (contato dentro da margem de segurança do piso) não foi identificada; dívida técnica antes da F2.
- `landed(fall_speed)` dispara na transição ar → chão de uma queda real, com a velocidade vertical do impacto em m/s. `fall_injury_height` (2,5 m) será usado pela fisiologia (F2).

## 4. Câmera

- Mouse look em graus por pixel (`Settings.mouse_sensitivity`, padrão 0,12), `invert_y`, pitch limitado a ±85°.
- **Compensação visual do step-up:** a física sobe o degrau de uma vez, e a câmera converge suavemente (decaimento de 12/s). A compensação ignora a variação de altura explicada pela inclinação do piso, então em rampa a câmera acompanha o corpo (erro ≤ 1 cm; BUG-003).
- **Head bob:** amplitude 0,03 m × (1 − `Settings.motion_reduction`), meio ciclo por passada. Com redução total, amplitude 0 (ACC-01, parte da F1).

## 5. Passos e superfícies

- `footstep(surface, gait, stance)` a cada passada, só no chão.
- A superfície vem do metadado `surface` do colisor sob o jogador: `wood`, `carpet`, `tile` ou `concrete` (sandbox). Sem metadado, `default`.
- Na F3, esses sinais viram eventos de ruído (NoiseEmitter). Hoje não há som.

## 6. Interação

- Raio da câmera de 2,0 m; foco só em alvos da camada 5 (`interactable`); paredes (camadas 1 e 2) bloqueiam. Não há interação através de paredes.
- **Tocar** (E) executa ações instantâneas. **Segurar** executa ações com `hold_time`. Soltar antes do tempo, ou perder o foco, dispara `interaction_failed`.
- **Pausa (BUG-005):** pausar no meio de um segurar cancela o segurar (`interaction_failed`); para tentar de novo, aperte depois de continuar.
- Com `requires_steady_hands`, o tempo de segurar é multiplicado por `1 + 1,5 × (1 − firmeza)`. A firmeza vem da fisiologia (1,0 na F1).
- **Porta:** segurar abre devagar (1,6 s, `opened(slow = true)`); tocar abre no tempo normal (0,35 s). Trancada: `locked_feedback`. Porta que começa aberta nasce com o painel aberto.
- **A porta não empurra** (BUG-006/009/010): o painel só avança se mantiver 2 cm de folga de corpos móveis (jogador, inimigos, objetos dinâmicos). Se encostaria, espera e emite `blocked(body)` uma vez; volta a andar quando dois incrementos seguidos estão livres. Paredes não bloqueiam o giro: o arco livre é responsabilidade do level design.
- **Pickup:** exige `persist_id`, emite `EventBus.item_picked` e some.

## 7. Input e opções

Ações e teclas padrão em SYSTEM_ARCHITECTURE §11.1. O remapeamento pelo menu de pausa (Esc → Controles) grava em `Settings.input_bindings`. Teclas inválidas são recusadas, e uma ação nunca fica sem ligação (ACC-05).

## 8. Debug (desligado em produção)

F3 mostra fps, frame time, postura, marcha, esforço, velocidade e foco. Com o overlay aberto, N liga ou desliga o noclip e T teleporta para o chão na mira. Tudo fica desligado com `GameState.is_production_build`.

## 9. Testes

MOT-01 a MOT-04 (incluindo a sandbox), step-up e bloqueio, escada (padrão e propriedade), câmera em rampa, `landed`, `footstep`, look, FOV, head bob, config, interação (20), debug, input (ACC-05). Resultados em `Docs/QA/TEST_RESULTS.md`.

## 10. Limitações e pendências

- `step_probe_distance` foi removido da config (F1-010): o parâmetro tinha deixado de ter efeito depois da 2ª correção do BUG-001.
- Ao entrar numa rampa em sprint, a câmera tem um pico transitório de até 3,8 cm (verificação F1-010, ressalva do R1-03); em regime o erro é zero.
- Sem fisiologia (F2), ruído (F3) nem esconderijos (F5): os ganchos são `apply_limits`, os sinais `footstep`/`landed`/`opened`/`interaction_failed` e `InteractionContext.is_hidden`.
- Sem verificação visual automatizada além das capturas de evidência.
