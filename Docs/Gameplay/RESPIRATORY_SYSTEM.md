# Respiratory System — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.9 (F2-012, 2026-11-20; vira 1.0 após a validação F2-011) |
| Estado | Implementado e revisado (F2-010 APROVADO COM RESSALVAS) |
| Código | `game/sim/physiology/respiratory_model.gd`, `respiratory_config.gd`, `medication_profile.gd`; `game/components/player/physiology_component.gd`; sons em `breath_emitter.gd` (produtor único) e `presentation/audio/breathing_audio.gd` |
| Config | `game/content/data/physiology/respiratory_config.tres`, `medication_inhaler.tres` |
| Fonte das fórmulas | DATA_STRUCTURES §1.4 e §1.7; contrato COMPONENT_CONTRACTS §4 |

## 1. O que o jogador sente

A asma é a principal ameaça interna. Esforço recente e estresse sobem a **severidade** (0..1). Com ela sobem a frequência respiratória, o chiado e o risco de tosse. A respiração é sempre audível para o jogador, "dentro da cabeça". A partir da F3, ela também vira ruído para os inimigos.

## 2. Modelo

```
exertion_ema = EMA do esforço (τ = 8 s)
stress_term  = max(0, stress/100 − 0,3) / 0,7
target       = clamp(0,7·exertion_ema + 0,4·stress_term, 0, 1) · (1 − alívio_da_medicação)
severity     → anda até target a 0,08/s subindo; desce a 0,03/s (0,06/s em repouso)
breathing_rate     = lerp(14, 40, max(exertion_ema, severity))      rpm
wheezing_intensity = smoothstep(0,35, 0,9, severity)
cough_probability  = 0,25 · ((severity − 0,55)/0,45)²  acima de 0,55   (por segundo)
```

A estamina **não** entra na severidade (PHY-05). Repouso = parado e agachado ou rastejando (escondido também, F5).

## 3. Estados

NORMAL → ACCELERATED → LABORED → SYMPTOMATIC, e na volta RECOVERING. Limiares e histerese em DATA §1.4. Toda transição exige 1,0 s no estado atual (PHY-INV-4). `recovery_progress` vai de 0 a 1 em RECOVERING.

## 4. Tosse

- A cada tick com risco, sem tosse pendente nem cooldown: `rng.randf() < cough_probability·dt` agenda a tosse para daqui a **1,5 s** e emite `cough_warning` (pigarro, COUGHING 32 dB).
- Se a severidade cair abaixo de 0,55 durante o aviso (por exemplo, com a bombinha), a tosse é cancelada: `coughed(true)`, sem som.
- A tosse acontece com `coughed(false)` (COUGHING 65 dB) e inicia um cooldown de 4 s.
- **Garantia:** toda tosse involuntária tem aviso ≥ 1,5 s antes (PHY-INV-5; 1 043 tosses verificadas na revisão, 0 violações).

## 5. Medicação (bombinha)

- Tecla **Q**: redução **absoluta** de 0,35 na severidade, aplicada em 3 s, mais alívio de 0,7 que decai em 90 s. Cooldown de 10 s. Puff audível (MEDICATION 38 dB).
- Doses: 3 por bombinha; o jogador começa com uma; o pickup soma. Sem dose ou em cooldown: nada acontece, com feedback (`item_use_failed`).
- **Não devolve estamina** (PHY-INV-2).
- Comprimido e água: o modelo tem `apply_consumable`; a ligação ao jogo vem na F5, com a tela de inventário.

## 6. Som (produtor único, NOI-INV-1)

O `BreathEmitter` emite um evento por ciclo respiratório: categoria BREATHING, ou WHEEZING quando há chiado. A família do som (calm, fast, labored) depende do período do ciclo. O `BreathingAudio` toca inspiração e expiração no ritmo do ciclo, sem cortar a expiração, e põe o chiado como camada a partir da expiração. Volume: `clamp(perceived_db − 45, −45, 0)` dB (DATA §2.4). Os sons são procedurais (D-07); veja `tools/audio/README.md`.

## 7. Números verificados

| Situação | Resultado |
|---|---|
| Sprint de tanque cheio (PHY-01) | LABORED em 5,55 s; esgota em 8,33 s com severidade 0,453 |
| Repouso a partir de 0,6 (PHY-03) | < 0,2 em 6,67 s (EMA inicial até 0,65) ou 8,80 s (EMA 0,857) |
| Bombinha em SYMPTOMATIC (PHY-04) | −0,440 em 3 s |
| Invariância a dt (PHY-11) | diferença ≤ 0,0086 entre dt 1/60 e 0,1 |

## 8. Pendências

- Propostas P-01 (abafar a tosse) e P-02 (prender a respiração): a avaliar com o jogo rodando.
- Precisão do save (ARCH-001): decisão antes da F5.
- Timbre dos sons: depende da audição do usuário.
