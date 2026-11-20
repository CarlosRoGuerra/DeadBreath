# Resultados de Testes — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 |
| Regra | Só entram resultados com saída real registrada (arquivo em `Docs/QA/EVIDENCE/` ou bloco copiado da execução) |

---

## DISC-003 — Spike de verificação da engine (Gate F0)

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Executor | Project Director (sessão principal) |
| Engine | `4.7.2.stable.official.ed1daf0bf`, binário oficial do GitHub; SHA-512 do zip igual ao de `SHA512-SUMS.txt` do release |
| Máquina | i7-14700KF, RX 9070 XT, 32 GB, Windows 11 Pro 26300 |
| Projeto | `spikes/disc003/` (descartável; não é o jogo) |
| Reexecução | `bash spikes/disc003/run_spike.sh D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe` (executado 1 vez com sucesso; gera os logs abaixo) |
| Verificação independente | Pendente: o QA reexecuta na F1-011 |

| # | Critério (ENGINE_DECISION §7) | Resultado | Evidência |
|---|---|---|---|
| V1 | Versão começa com `4.7.2.stable` | **PASSOU**: `4.7.2.stable.official.ed1daf0bf` | `EVIDENCE/DISC-003/V1_V2_V4.log` |
| V2 | Script headless retorna 0/1 | **PASSOU**: `pass` → 0; `fail` → 1 | `V1_V2_V4.log` |
| V3 | Forward+ com névoa volumétrica e luz pontual renderiza com janela | **PASSOU**: Vulkan 1.4.359, Forward+, RX 9070 XT, 1920×1080; luminância média 0,207; 98,8% das amostras acima de 0,05; imagem inspecionada | `V3_default.log`, `V3_screenshot.png` |
| V4 | `--check-only` após `--import` falha com erro proposital | **PASSOU**: `parse_error.gd` → 1; `untyped.gd` → 1 (warning tratado como erro); `unsafe.gd` → 1; `ok.gd` → 0 | `V1_V2_V4.log` |
| V5 | p95 ≤ 6,9 ms (vsync off, 1080p, 600 frames após 120) | **PASSOU**. Execução 1: Vulkan 1,921 ms, D3D12 0,902 ms. Execução 2 (logs gravados): Vulkan 1,206 ms, D3D12 0,962 ms | `V5_vulkan.log`, `V5_d3d12.log`, `V5_frametimes_*.csv` |
| V6 | CharacterBody3D em escada, rampa e vão de 0,6 m com Jolt e GodotPhysics3D | **PASSOU**: 16/16 pistas nos dois motores; resultados idênticos em execução repetida | `V6_JoltPhysics.*`, `V6_GodotPhysics3D.*` |

### V6 — comparação dos motores (execução final)

Controlador mínimo do spike (`spikes/disc003/mover.gd`), 60 Hz, `floor_snap_length` 0,3 m, `floor_max_angle` 45°, step-up de até 0,30 m. "Sem chão" = ticks em movimento com `is_on_floor() == false`.

| Pista | Jolt | GodotPhysics3D |
|---|---|---|
| Cápsula · rampa 30° (sobe até 1,5 m) | passou, tick 258 | passou, tick 258 |
| Cápsula · parado na rampa por 2 s | deslocamento 0,0000 m | 0,0000 m |
| Cápsula · sobe escada (8 × 0,18 m) | passou; 8 step-ups; sem chão 40/220 | passou; 8 step-ups; sem chão 40/220 |
| Cápsula · escada sem step-up | bloqueia em x = 1,760 (informativo) | idem |
| Cápsula · desce escada | passou; sem chão **59/215** | passou; sem chão **60/215** |
| Cápsula 0,55 m · vão de 0,6 m rastejando | passou; teto bloqueado 168/168 sob a laje, 0/230 fora | idem |
| Cápsula 1,75 m · vão de 0,6 m em pé | bloqueia em x = 2,747 | idem |
| Cápsula · obstáculo 0,35 m (acima do step) | bloqueia | bloqueia |
| Cápsula · obstáculo 0,29 m (abaixo do step) | sobe (1 step-up) | sobe (1 step-up) |
| Cilindro · rampa 30° | passou; **1 step-up espúrio** na base | passou; 0 step-up |
| Cilindro · sobe escada | passou; sem chão 2/218 | passou; sem chão **0/216** |
| Cilindro · desce escada | passou; sem chão **60/215** | passou; sem chão **0/216** |
| Cilindro · obstáculos e vão | iguais à cápsula | iguais à cápsula |
| Tempo de parede (721 ticks, 16 corpos), 2 execuções; o log gravado é o da 2ª | 381,6 e 370,5 ms | 387,2 e 405,9 ms |

**Execução 1 (descartada para a escolha):** o step-up do controlador do spike não disparava (sondagem de 1 tick = 2,7 cm; a base arredondada da cápsula batia na quina). Essa execução mostrou que `DEFAULT` = GodotPhysics3D no 4.7.2 (números idênticos). Logs preservados em `V6_run1_*`.

**Decisão:** GodotPhysics3D (ENGINE_DECISION §6). Achados para o PlayerMotor em ENGINE_DECISION §7.1.
