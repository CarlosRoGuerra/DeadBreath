# Game Design Document — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.1 (F1-D01, 2026-11-20) |
| Responsável | Project Director |
| Estado | **Design.** Nenhuma mecânica de gameplay está implementada ainda; o status real de cada sistema fica no TASK_BOARD e no TEST_RESULTS. |
| Fontes | MASTER_PROMPT §2–5, §9–11, §18; números em DATA_STRUCTURES (pontos de partida para balanceamento) |

## 1. Visão

Um homem comum, sedentário e asmático, fica preso na própria casa numa madrugada de chuva, durante a invasão de três criminosos. Ele não pode lutar. Para sobreviver, precisa se esconder, planejar e escutar. **O próprio corpo é a maior ameaça:** correr salva agora e cobra depois, e o medo faz a respiração denunciá-lo.

## 2. Pilares

| Pilar | O que significa na prática | Teste de design |
|---|---|---|
| **Pessoa comum, não herói** | Sem combate, sem armas, sem confronto vencível (MASTER §3.1) | Alguma ação derrota um inimigo? Então está errada |
| **O corpo trai** | Esforço e medo aumentam respiração, chiado e tosse, que fazem ruído real para a IA | A crise respiratória mudou uma decisão do jogador? |
| **Ouvir para sobreviver** | O áudio é informação: passos, portas, vozes, a própria respiração | Dá para jogar uma situação só pelo som? |
| **Inimigos justos** | A IA só sabe o que viu ou ouviu; nunca recebe a posição do jogador de graça (firewall, ADR-003) | O jogador entende por que foi descoberto? |
| **Escolhas, não roteiro** | Rotas alternativas, distrações e recursos escassos | Há ao menos 2 soluções para o objetivo? |

## 3. Loops

- **Momento a momento (segundos):** observar → escutar → mover-se (devagar, agachado ou rastejando) → esconder-se quando há risco → controlar a respiração.
- **Situação (minutos):** chegar a um objetivo (chave, ferramenta, saída) por uma das rotas, usando distrações e esconderijos, administrando estamina, estresse e respiração.
- **Capítulo (dezenas de minutos):** a casa muda (portas bloqueadas, luz cortada, inimigos novos), surge uma situação nova e o mistério avança por documentos e conversas ouvidas.
- **Falha:** captura → sequência de captura → checkpoint. A dificuldade adaptativa ajusta recursos e janelas de fuga, sem revelar o jogador.

## 4. O protagonista e o corpo

Três sistemas **separados**, acoplados por regras explícitas (DATA_STRUCTURES §1):

| Sistema | Escala | Sobe com | Desce com | Consequência |
|---|---|---|---|---|
| Estamina | 0–100 | Correr, escalar, empurrar móveis | Andar devagar, parar, descansar, local seguro | Sem estamina não há sprint até recuperar 25 |
| Estresse | 0–100 (CALM, TENSE, AFRAID, PANIC) | Inimigo visto ou ouvido, perseguição, susto, captura, ferimento | Tempo sem ameaça, local seguro | Tremor, respiração acelerada, sons involuntários, interações delicadas mais lentas |
| Respiração | Severidade 0–1 (NORMAL → ACCELERATED → LABORED → SYMPTOMATIC → RECOVERING) | Esforço recente e estresse | Repouso; medicação dá alívio temporário | Respiração e chiado audíveis; tosse com **aviso de 1,5 s** antes |

Regras de design que não mudam:
- A tosse nunca é surpresa total: sempre há aviso, para o jogador reagir (sair de perto, abafar se P-01 for aprovada).
- A bombinha alivia a respiração, mas **não devolve estamina** (MASTER §9.2).
- Nada de barras permanentes na tela. O estado do corpo é transmitido por som, câmera e animação. Um indicador visual opcional existe por acessibilidade.

## 5. Movimento e controles

| Ação | Tecla | Efeito |
|---|---|---|
| Andar | W/A/S/D | 1,6 m/s, passos audíveis conforme a superfície |
| Andar devagar | Alt | 0,9 m/s, mais silencioso |
| Correr | Shift | 4,8 m/s; muito ruído e esforço; só em pé |
| Agachar | Ctrl (alterna) | 1,0 m/s; silhueta menor |
| Rastejar | Z (alterna) | 0,5 m/s; passa sob móveis (vão de 0,6 m) |
| Interagir | E (tocar ou segurar) | Segurar abre portas devagar e em silêncio |
| Usar item | Q | Bombinha e outros itens |

Superfícies (madeira, tapete, azulejo, concreto) mudam o ruído dos passos. Não se levanta sem espaço acima (MOT-INV-1).

## 6. Furtividade e ruído

- Todo som de gameplay é um **evento de ruído** com categoria, intensidade (dB a 1 m), posição e duração. O mesmo evento alimenta o áudio que o jogador ouve e a audição da IA (ADR-004).
- O som se propaga pela casa por salas e portas: porta fechada abafa, parede abafa mais, andar de cima abafa mais ainda.
- A chuva cria um piso de ruído por sala. **Trovões** abrem janelas curtas para se mover. Isso é central no capítulo 5.
- Distrações: objetos arremessáveis criam ruído longe do jogador (F3).

## 7. Inimigos

Três criminosos humanos, sem nada sobrenatural, com a mesma máquina de estados (patrulha → suspeita → investigação → busca → perseguição → perda de contato → retorno) e perfis numéricos diferentes (DATA_STRUCTURES §3.1):

| Inimigo | Personalidade | Como o jogador percebe |
|---|---|---|
| THE OBSERVER | Cauteloso, investiga com calma, enxerga longe | Para, escuta, volta para conferir |
| THE AGGRESSIVE | Rápido, persistente, ouve menos | Persegue por mais tempo, revira esconderijos |
| THE LEADER | Coordena o grupo e divide a busca em setores | Fala com os outros; as buscas ficam organizadas |

A IA nunca recebe a posição real do jogador; só o que viu, ouviu (com posição estimada) e lembra.

## 8. Esconderijos

Guarda-roupas, debaixo de camas, atrás de móveis, banheiros, depósitos, sótão e porão. Cada esconderijo tem entrada e saída (com ruído), proteção visual e chance de inspeção pela IA. Escondido, o jogador continua respirando, e o medo pode denunciá-lo.

## 9. Itens

Bombinha (3 doses por unidade), outros medicamentos, água, chaves, ferramentas, documentos e objetos de distração. Capacidade limitada, sem crafting complexo (MASTER §18).

## 10. Campanha

| Capítulo | Situação nova (proposta; ROADMAP F6) |
|---|---|
| 1 — THE INTRUSION | Aprender a se esconder e a escutar; primeiro contato com o Observer |
| 2 — NO WAY OUT | Saídas bloqueadas; procurar chaves e ferramentas; segundo inimigo |
| 3 — THE BASEMENT | Luz cortada: escuridão e eco forte; o Leader começa a coordenar |
| 4 — LAST BREATH | Remédios escassos; buscas coordenadas pelos três |
| 5 — OUTSIDE | Exterior na chuva: piso de ruído alto, trovões como janelas; fuga final |

A história (o objeto que os invasores procuram e a ligação com os antigos moradores) é contada por documentos, fotos, gravações e conversas ouvidas, sem longas exposições. Detalhes em NARRATIVE.md (F1-D02).

## 11. Captura e checkpoint

Captura: controles desabilitados → animação curta → transição → último checkpoint, com inventário, objetivos e mundo restaurados sem duplicar itens (MASTER §9.10; DATA_STRUCTURES §6).

## 12. Dificuldade adaptativa

Mede capturas, tempo, recursos e fugas. Ajusta recursos opcionais, janelas de fuga, intensidade de busca e frequência de patrulha. **Nunca revela o jogador** (MASTER §9.9).

## 13. Interface e acessibilidade

Interface mínima. Opções (DATA_STRUCTURES §10): redução de movimento de câmera e de tremor, intensidade dos efeitos, indicador respiratório, legendas com tamanho ajustável e remapeamento de controles.

## 14. Fora de escopo

Mundo aberto, combate, inimigos sobrenaturais, crafting complexo, multiplayer, simulação médica detalhada e cinemáticas antes de a gameplay ser validada (MASTER §18).

## 15. Questões abertas

| Item | Onde decidir |
|---|---|
| Abafar a tosse (P-01) e prender a respiração (P-02) | F2 |
| Categoria de ruído VOICE (P-03) | F3 |
| Pipeline de personagens 3D (D-05), assets CC0 (D-06), gravação de respiração real (D-07) | Usuário (TASK_BOARD §1) |
| Ferimentos com efeito físico (P-06), localização (P-04), Steam (P-05) | F6–F8 |
