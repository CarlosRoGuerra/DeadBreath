# Stamina System — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.9 (F2-012, 2026-11-20; vira 1.0 após a validação F2-011) |
| Estado | Implementado e revisado (F2-010) |
| Código | `game/sim/physiology/stamina_model.gd`, `stamina_config.gd`, `physiology_coupling.gd`, `coupling_config.gd`; limites aplicados em `game/components/player/player_motor.gd` via `PlayerRoot` |
| Config | `game/content/data/physiology/stamina_config.tres`, `coupling_config.tres` |
| Fonte | DATA_STRUCTURES §1.2 e §1.6 |

## 1. O que é

Fôlego físico de curto prazo, de 0 a 100. É **separado** da respiração: esgotar a estamina não piora a asma diretamente, e a bombinha não devolve estamina (PHY-05).

## 2. Dreno e recuperação

| Situação | Taxa |
|---|---|
| Sprint | −12/s (tanque cheio dura **8,33 s**) |
| Escalar / empurrar móveis | −15/s / −10/s (reservados: as mecânicas entram na F5/F6) |
| Recuperação | só depois de 1,2 s sem dreno: andando 4/s, devagar 7/s, parado 10/s, em repouso 14/s (× 1,3 em zona segura, F5) |

A recuperação efetiva é multiplicada por `stamina_regen_multiplier = (1 − 0,6·severidade)·(1 − 0,3·estresse/100)`: crise e medo atrasam o fôlego.

## 3. Exaustão e sprint

- Ao chegar a 0, o sprint é bloqueado até a estamina voltar a **25** (histerese).
- Na crise, o sprint máximo cai: `max_sprint_multiplier = lerp(1,0, 0,75, (sev − 0,6)/0,4)` acima de 0,6.
- Os limites valem a partir do **tick seguinte** e só reduzem (MOT-INV-3).

## 4. Pendências

- Drenos de escalar e empurrar móveis ligados às mecânicas (F5/F6).
- Zona segura (F5).
