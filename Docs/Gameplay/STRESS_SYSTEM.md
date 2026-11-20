# Stress System — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.9 (F2-012, 2026-11-20; vira 1.0 após a validação F2-011) |
| Estado | Implementado e revisado (F2-010) |
| Código | `game/sim/physiology/stress_model.gd`, `stress_config.gd`; `threat_sample.gd`; `game/components/player/physiology_component.gd`, `threat_source.gd`, `stub_threat_source.gd` |
| Config | `game/content/data/physiology/stress_config.tres` |
| Fonte | DATA_STRUCTURES §1.3 e §1.5; COMPONENT_CONTRACTS §4 e §5 |

## 1. O que é

O medo do protagonista, de 0 a 100, em faixas CALM < 25 ≤ TENSE < 50 ≤ AFRAID < 75 ≤ PANIC. O estresse não mata. Ele piora a respiração, faz as mãos tremerem e pode arrancar um gasp involuntário.

## 2. Entradas

- **Ameaça percebida** (`ThreatSample`): inimigo visto (`15 × seen_proximity`/s), ouvido (`5 × heard_factor`/s) e perseguição (`20`/s), **somados**. Na F2, a ameaça vem do `StubThreatSource` (testes e painel F4); na F4, do `PlayerThreatMonitor`, que só usa o que o jogador percebe.
- **Picos:** susto (`clamp((dB − 55)/2 + 10, 10, 25)`, ruído externo ≥ 55 dB), ferimento (+20, queda acima de 2,5 m) e captura (+40, F5).
- **Decaimento:** depois de 4 s sem ameaça nem pico, cai 3/s (8/s em zona segura, F5). De 100 a 0 em 37,3 s.

## 3. Consequências

| Efeito | Regra |
|---|---|
| Respiração | `stress_term` na severidade-alvo (RESPIRATORY_SYSTEM §2) |
| Tremor | `tremor_amplitude = smoothstep(50, 100, stress)` → câmera (CameraEffects; reduzível por `tremor_reduction`) |
| Mãos | `steadiness = clamp(1 − 0,7·smoothstep(40, 100, stress) − 0,3·chiado, 0, 1)`: alonga o "segurar" em interações delicadas (`× 1 + 1,5·(1 − steadiness)`) |
| Gasp de susto | pico ≥ 15 com estresse ≥ 50 **antes** do pico → BREATHING 42 dB pelo BreathEmitter |
| Sprint | `stamina_regen_multiplier` cai com o estresse (STAMINA_SYSTEM §3) |

## 4. Pendências

- **Ponte de susto** (revisão F2-010, R2-01): ligar ruídos externos a `add_startle` depende dos ruídos do mundo (F3-002). Hoje, só o painel F4 e os testes geram sustos.
- O `PlayerThreatMonitor` real e o teste PHY-12 ficam para a F4.
