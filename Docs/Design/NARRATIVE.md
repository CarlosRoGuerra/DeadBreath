# NARRATIVE — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.1 (F1-D02, 2026-11-20) — **PROPOSTA** |
| Responsável | Level Designer |
| Estado | Proposta para aprovação do Project Director. Nada aqui está implementado. Nomes de personagens e o objeto são propostas abertas (ver §9). |
| Fontes | MASTER_PROMPT §2, §3, §5 (elementos narrativos, capítulos), §18; GAME_DESIGN_DOCUMENT §1, §7, §10 |

## 1. Premissa

Uma madrugada de chuva. Um homem comum, sedentário e asmático, é o morador atual de uma casa isolada. Três invasores entram para roubar, e logo percebe-se que o roubo é pretexto: procuram um objeto específico que está escondido na casa. Eles conhecem partes da residência que um comprador recente não deveria conhecer.

O protagonista não investiga por heroísmo. Ele quer sair vivo e, de quebra, entender por que está no meio disso.

## 2. Mistério central

**O objeto:** uma caixa metálica pequena, com fechadura de segredo, escondida numa cavidade da parede (cavidade de passagem de fiação, atrás do painel elétrico no porão). Dentro dela há um **livro-caixa**: um caderno de contabilidade paralela com nomes, valores e datas de uma rede de empréstimos ilegais que usava a casa como ponto de pagamento.

**Por que é valioso:** quem tiver o livro pode chantagear ou negociar com a rede. Os invasores trabalham para um intermediário que quer recuperá-lo. O intermediário não aparece em cena; só é mencionado em gravações e conversas (§6).

**Verdade oculta (o que o jogador descobre por partes):**
1. A casa foi dos antigos moradores, que usavam o porão como escritório de contas de um agiota local.
2. O antigo morador escondeu o livro para se proteger, não para proteger a família.
3. A venda da casa ao protagonista foi feita por um corretor ligado à mesma rede. O preço da casa era pago, em parte, fora dos registros. O protagonista é, sem saber, uma peça da operação.

Item 3 é um **twist opcional** (ver §8): reforça a pergunta "de quem é a casa?" sem exigir explicação longa.

## 3. Antigos moradores

**Aurélio Teixeira** (falecido há quatro meses, em hospital, causa natural). Contador aposentado. Fazia a contabilidade de um agiota da região. Guardou o livro como seguro de vida: se alguém da rede tentasse apagá-lo, o livro expunha a rede. Gostava de consertar a casa sozinho; conhecia cada parede e cada painel.

**Marta Teixeira** (vive num lar de idosos na cidade). Professora aposentada. Sabia do esconderijo e do que o marido fazia, mas escolheu calar por medo e por lealdade. Guarda culpa, e é a principal fonte de cartas e de uma gravação (§6).

**Bianca Teixeira** (filha, adulta, mora em outro estado). Não aparece em cena. Aparece em fotos, em um cartão de aniversário e numa mensagem de voz deixada na secretária eletrônica da casa, que nunca foi apagada. Serve para humanizar a família sem exposição.

## 4. Por que os criminosos conhecem a casa

Três caminhos, que se complementam (o jogador encontra pelo menos dois):

- **Um deles trabalhou aqui.** O líder foi eletricista contratado por Aurélio anos atrás, para trocar o quadro e instalar o painel do porão. Foi ele quem viu a cavidade atrás do painel e guardou a planta da casa na memória.
- **O intermediário já entrou.** A rede fez uma vistoria antes da venda, para avaliar a casa como garantia de dívida. Um dos invasores acompanhou essa vistoria e lembra da disposição dos cômodos.
- **Eles têm a planta do corretor.** Uma cópia das plantas de venda circulou entre os envolvidos. Uma folha com carimbo do corretor aparece na cozinha (pista de capítulo 2).

## 5. Os três criminosos (personagens, sem nada sobrenatural)

Os nomes abaixo são propostas. Os arquétipos de IA (THE OBSERVER, THE AGGRESSIVE, THE LEADER, GDD §7) são funções de jogo e **não** são nomes de personagens.

| Arquétipo de IA | Personagem (proposta) | Quem é | O que quer | Como o jogador os conhece |
|---|---|---|---|---|
| THE LEADER | **Vitor Lemos** (proposta) | Eletricista que trabalhou na casa; cumpre ordens do intermediário, mas tem orgulho técnico. Coordena o grupo e divide os setores de busca. | Terminar o serviço e sair sem problemas com a rede. | Fala com os outros, conhece o painel, tem o plano da busca. Revela-se pela própria memória da casa. |
| THE OBSERVER | **Rocha** (proposta) | Ex-segurança de condomínio. Calmo, desconfiado, reconhece rotinas. Não gosta de violência e a usa só quando necessário. | Não ser pego; voltar para casa com o pagamento. | Para, escuta, volta para conferir. Pode demonstrar dúvida sobre o trabalho em conversas ouvidas. |
| THE AGGRESSIVE | **Nando** (proposta) | Jovem endividado, contratado por dinheiro rápido. Impulsivo, fala alto, revira armários. | Resolver a dívida dele e sair da casa. | Persegue por mais tempo, grita e xinga nas conversas. Sua dívida é a ponte para o agiota (capítulo 2). |

Regras de caracterização: nenhum deles é monstro, nenhum tem poder além do humano. Eles erram, discutem e têm motivos. O jogador deve sentir que são pessoas comuns em uma situação ruim, não vilões de cartão.

## 6. Pistas e revelações por capítulo

Formas de entrega (MASTER §5.1): **documentos** (cartas, notas, faturas, papéis escritos à mão), **fotos**, **gravações** (secretária eletrônica, celular, câmera de segurança com áudio), **conversas ouvidas** (os criminosos falando entre si, sem o jogador ver a cena), **objetos pessoais** e **pistas ambientais** (marcas, fiação, cofre vazio).

Regra de dosagem: nenhum item passa de **120 palavras** de texto ou **45 s** de áudio. Cada cômodo tem no máximo um item narrativo obrigatório; o resto é opcional. Nenhuma pista depende de outra para ser entendida isoladamente.

IDs `CLUE-Cn-xx` servem para rastrear no TASK_BOARD e no QA.

### Capítulo 1 — THE INTRUSION
Objetivo: entender que é um assalto que não é um assalto. Primeiro contato com THE OBSERVER.

| ID | Tipo | Conteúdo | Revela |
|---|---|---|---|
| CLUE-C1-01 | Conversa ouvida (sala) | Dois invasores: "não é isso aqui, a coisa tá no painel, lembra da planta". | A busca tem alvo; eles sabem de uma estrutura da casa. |
| CLUE-C1-02 | Foto (porta da geladeira) | Família Teixeira num churrasco; Aurélio com um caderno no bolso. | Os antigos moradores existem; o caderno aparece (semente). |
| CLUE-C1-03 | Gravação (secretária eletrônica, aparelho na sala) | Mensagem de Bianca: "Pai, o senhor não atende mais, me liga". Data de meses atrás. | Há família fora da casa; Aurélio está morto ou ausente. |
| CLUE-C1-04 | Conversa ouvida (corredor) | Rocha: "essa casa tem rota de fuga, não fica parado na porta". | O corredor é a rota de risco; o Observer conhece a planta. |

**Revelação do capítulo:** a casa não é um alvo aleatório. Os invasores procuram algo que pertenceu aos antigos moradores.

### Capítulo 2 — NO WAY OUT
Objetivo: saídas bloqueadas; achar chave e ferramenta. Segundo inimigo entra em cena (THE AGGRESSIVE), com a dívida.

| ID | Tipo | Conteúdo | Revela |
|---|---|---|---|
| CLUE-C2-01 | Documento (gaveta da cozinha) | Notificação de cobrança de uma financeira, endereçada a Aurélio Teixeira, com valor em atraso. | Aurélio devia dinheiro; havia dívida ligada à casa. |
| CLUE-C2-02 | Gravação (celular de Nando, caído) | Voz de homem, calma: "o dinheiro é da casa, ou o livro volta, ou a casa volta". | Existe um livro; há um credor; a casa é garantia. |
| CLUE-C2-03 | Conversa ouvida (hall, perto do mezanino) | Nando e Vitor discutem: "você disse que sabia onde tava a caixa". "Eu sei onde ficava, o cara mudou tudo". | O líder esteve na casa antes e viu uma reforma. |
| CLUE-C2-04 | Documento (cozinha, junto à mesa) | Planta de venda com carimbo de corretor, com uma cota a lápis: "reforço p/ cavidade". | A venda também circulou entre o credor e o corretor (semente do twist). |

**Revelação do capítulo:** o objeto é um livro, e quem pediu a busca é um credor. A casa servia de garantia.

### Capítulo 3 — THE BASEMENT
Objetivo: descer ao porão, abrir a cavidade ou encontrar o local. Luz cortada; escuridão e eco forte. O líder começa a coordenar buscas.

| ID | Tipo | Conteúdo | Revela |
|---|---|---|---|
| CLUE-C3-01 | Documento (bancada do porão) | Caderno de contas com colunas de nomes e iniciais, sem legenda. Última página: "AT. — pago dia 5". | O livro é de contabilidade paralela. |
| CLUE-C3-02 | Foto (parede do porão) | Aurélio no porão com dois homens de terno, mãos apertadas, sem sorriso. | Aurélio tinha negócios com os credores. |
| CLUE-C3-03 | Conversa ouvida (porão, buscas) | Vitor: "o Aurélio era contador, não era dono de nada, ele guardava o livro pro próprio pescoço". | O livro protegia Aurélio, não era só do agiota. |
| CLUE-C3-04 | Pista ambiental (painel elétrico) | Painel aberto, fiação nova em uma cavidade com parafusos recentes. | Alguém já mexeu no esconderijo; a caixa não está mais lá (ou está?). |

**Revelação do capítulo:** a caixa existe, Aurélio era o contador da rede, e o esconderijo já foi mexido.

### Capítulo 4 — LAST BREATH
Objetivo: remédios escassos; buscas coordenadas. O jogador encontra a voz de Aurélio e a culpa de Marta.

| ID | Tipo | Conteúdo | Revela |
|---|---|---|---|
| CLUE-C4-01 | Gravação (secretária eletrônica, segunda mensagem) | Aurélio, gravado meses antes: "Se alguém da casa de vocês procurar, não tranquem a cozinha, eu deixei a coisa onde ninguém acha." | Ele deixou o livro de propósito; a cozinha é a pista final. |
| CLUE-C4-02 | Documento (carta de Marta, envelope no quarto) | "Eu sabia onde ele escondeu e nunca falei. Não quero que mais ninguém pague por isso." | Marta sabia; o silêncio dela também pesou. |
| CLUE-C4-03 | Conversa ouvida (sala, buscas coordenadas) | Rocha: "a casa é grande, mas a caixa é pequena, a gente acha se para de gritar". | A busca fica organizada; o Observer quer sair logo. |

**Revelação do capítulo:** a família sabia. A casa foi usada de propósito, e o esconderijo é deliberado.

### Capítulo 5 — OUTSIDE
Objetivo: fuga na chuva. Piso de ruído alto; trovões como janelas de movimento. A escolha final (§7).

| ID | Tipo | Conteúdo | Revela |
|---|---|---|---|
| CLUE-C5-01 | Documento (saída, junto à porta externa) | Recibo de transferência em nome de um dos criminosos, pago pela rede. | Eles também são peças descartáveis. |
| CLUE-C5-02 | Gravação (celular de Vitor, descarregando) | Vitor: "se o livro for pra polícia, eu não vou sozinho pra cadeia". | O conflito interno do grupo muda a fuga. |

**Revelação do capítulo:** o livro é a única coisa que pode mudar o destino de todos, e o protagonista decide o que fazer com ele.

## 7. Final e escolhas (proposta)

O jogador acaba com o livro em mãos, ou com o conhecimento de onde ele está. O destino depende de uma escolha feita no capítulo 5 (ou antes, se o jogador entregar o livro a um dos criminosos):

| Escolha | Consequência narrativa | Consequência mecânica (a validar com o Director) |
|---|---|---|
| Entregar o livro ao intermediário | Sai vivo; o protagonista vira cúmplice. | Final "silêncio". Sem captura final. |
| Levar o livro à polícia | Sai vivo; a rede é exposta, e a casa vira cena de investigação. | Final "exposição". Exige a sirene da viatura no ato final. |
| Destruir o livro | Sai vivo; a verdade fica só com ele. | Final "queima". Sem ganho externo. |

Três finais, todos sem combate: nenhum deles envolve o protagonista vencendo um criminoso.

## 8. Twist opcional: a casa foi paga com dívida

Se aprovado, o item 3 de §2 é revelado no capítulo 4 por CLUE-C2-04 (planta com cota a lápis) e por uma carta do corretor, achada no capítulo 5. O protagonista compra a casa com um financiamento intermediado pela mesma rede. Não é preciso explicar os detalhes: basta o jogador entender que a compra não foi limpa.

Recomendação: manter como opcional. Ele reforça o pilar "escolhas, não roteiro" sem exigir um final alternativo a mais.

## 9. Questões abertas (decisões para o Director)

| # | Questão | Proposta |
|---|---|---|
| N-01 | O protagonista tem nome? | Não nomear na v0.1; o jogador ouve o nome só em uma carta do banco no capítulo 2 (a decidir). |
| N-02 | Nomes dos criminosos | Vitor, Rocha e Nando (§5), a validar. |
| N-03 | Twist de §8 entra no escopo? | Opcional; decidir na F5 com o roteiro do vertical slice. |
| N-04 | Número de finais | Três (§7). Mais de três aumenta o custo de texto e de QA sem ganho de pilar. |
| N-05 | Idioma das gravações | Português do Brasil, com legendas (ACC-04). |

## 10. Regras de escrita (para os documentos do jogo)

- Texto curto: até 120 palavras por documento; áudios até 45 s.
- Sem explicação em voz de narrador. Toda informação chega por algo que um personagem faria ou diria.
- Nenhum criminoso fala sobre o objeto de forma que explique a história inteira; cada um sabe só um pedaço.
- Nada sobrenatural: a casa é assombrada só pelo medo e pela história das pessoas.
- Nomes de personagens, cidades e empresas são fictícios. Não usar marcas, logotipos ou textos de terceiros (ART_DIRECTION §8).
- Não copiar estrutura ou personagens de jogos de referência (MASTER §4). A forma das pistas deve nascer da casa, não de um jogo conhecido.

## 11. Registro

- F1-D02 (2026-11-20): NARRATIVE v0.1 proposto. Sem implementação. Próximo passo: aprovação do Director e definição de N-01 a N-05; depois, revisão com o Software Architect quanto ao formato de pistas (documento, gravação, conversa) no sistema de objetivos.
