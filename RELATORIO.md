<!--
  TEMPLATE DO RELATÓRIO DE ENTREGA: Paradigmas de Programação

  Como usar:
  - Copie este arquivo para a raiz do repositório do grupo, com o nome
    RELATORIO.md, e preencha todas as seções.
  - Os textos entre <!- - e - -> (como este) são instruções. Eles não
    aparecem quando o arquivo é visualizado, mas APAGUE-OS antes de entregar.
  - Troque tudo o que estiver entre [colchetes].
  - Seja direto. Frases curtas e listas valem mais que parágrafos longos.
    Um relatório típico cabe em 4 a 8 páginas.
  - O relatório e o código são avaliados juntos. Sempre que possível,
    aponte para o código (arquivo e linha) em vez de descrevê-lo. Os
    critérios de avaliação estão em AVALIACAO.md.
  - ANTES DE ENTREGAR, rode o validador na raiz do repositório:

        uv run scripts/validar_entrega.py

    Ele confere a FORMA do relatório (comentários apagados, colchetes
    preenchidos, tabelas bem formadas, seções presentes, arquivos
    existentes), não o conteúdo. Corrija todos os ERROS apontados.
-->

# [Nome do projeto]

## 1. Identificação

<!--
  Os grupos têm de 3 a 7 pessoas (5, em média). A tabela abaixo tem 5
  linhas: adicione ou remova linhas conforme o tamanho do seu grupo, aqui e
  na seção 10. Os grupos podem misturar alunos das turmas das 14h e das 16h:
  indique a turma de CADA integrante.
-->

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---------------|-----------|-----------------|----------------|
| [Nome]        | [000000]  | [14h]           | [@usuario]     |
| [Nome]        | [000000]  | [16h]           | [@usuario]     |
| [Nome]        | [000000]  | [14h]           | [@usuario]     |
| [Nome]        | [000000]  | [16h]           | [@usuario]     |
| [Nome]        | [000000]  | [14h]           | [@usuario]     |

- **Nome do projeto:** [o mesmo do título acima]
- **Nome do grupo:** [um nome criativo, que não se repita na turma]
  <!--
    O nome do grupo identifica vocês nas planilhas de notas e na chamada
    para a apresentação. Não dá para validar se é único, então caprichem:
    "Grupo 3" vai colidir com o "Grupo 3" da outra turma.
  -->
- **Repositório:** [https://github.com/...]
- **Commit ou tag entregue:** [`a1b2c3d` ou `v1.0`]
  <!--
    O avaliador vai olhar exatamente esta versão. Para criar uma tag:
      git tag v1.0 && git push origin v1.0
  -->
- **Ponto de partida:** [template do Sudoku com ajustes | variante do Sudoku | outro jogo conhecido | remix original | jogo inventado]
  <!--
    Escolha UMA faixa. Ela define o ajuste de escopo da nota do grupo
    (AVALIACAO.md, seção 1.5). O professor confirma a faixa na apresentação.
  -->
- **Slides da apresentação oral:** [`docs/apresentacao.pdf` | link externo | não há]
  <!--
    No final do semestre, cada grupo faz uma apresentação oral de 15
    minutos. Slides são opcionais; se o grupo usar, coloque o arquivo no
    repositório (de preferência em PDF) e indique o caminho aqui.
  -->

## 2. Resumo

<!--
  De 3 a 5 linhas: o que o sistema faz, para quem, e qual problema o
  Prolog resolve nele. Quem ler só esta seção deve entender o projeto.
-->

[Resumo do projeto.]

![Captura de tela do sistema](docs/captura.png)
<!-- Uma ou duas capturas de tela da interface. Crie a pasta docs/ se precisar. -->

## 3. Como executar

<!--
  Teste estas instruções numa máquina "limpa" (ou peça a um colega de
  outro grupo). Se o avaliador não conseguir rodar o sistema, o resto do
  trabalho não pode ser verificado.
-->

**Requisitos** (com as versões que o grupo usou):

- SWI-Prolog [9.x]
- Node.js [2x.x]
- [uv / Python 3.x, se usar]

**Instalação e execução:**

```sh
[comandos exatos, na ordem]
```

**Testes:**

```sh
make test        # Prolog (plunit), API (pytest) e Elm (elm-test)
make test-elm    # só o tabuleiro em Elm
```

**Testado em:** [Linux / Windows / macOS, navegador]

## 4. Arquitetura

<!--
  Um diagrama simples (pode ser em texto) mostrando as partes do sistema e
  como elas se comunicam. Diga em uma frase a responsabilidade de cada parte.
-->

```
[Elm] --HTTP/JSON--> [Python] --janus--> [Prolog]
```

| Parte  | Responsabilidade | Arquivos principais |
|--------|------------------|---------------------|
| Prolog | [...]            | [`backend/prolog/...`] |
| Elm    | [...]            | [`frontend/src/...`]   |
| Python | [só integração]  | [`backend/app/...`]    |

## 5. Parte em Prolog

### 5.1 Predicados principais

<!--
  Os predicados mais importantes, com o local no código. Use a notação
  nome/aridade e indique entradas (+) e saídas (-), como na documentação
  do SWI-Prolog.
-->

| Predicado | Local | O que faz |
|-----------|-------|-----------|
| [`resolver(+Entrada, -Saida)`] | [`arquivo.pl:42`] | [...] |
| [...] | [...] | [...] |

### 5.2 Conceitos do paradigma lógico utilizados

<!--
  Marque o que o projeto usa DE FATO e indique onde. Não é preciso usar
  tudo; é preciso explicar bem o que foi usado.
-->

- [ ] Fatos e regras como base de conhecimento: [onde]
- [ ] Unificação e casamento de padrões: [onde]
- [ ] Recursão (inclusive sobre listas): [onde]
- [ ] Backtracking e múltiplas soluções: [onde]
- [ ] `findall/3`, `bagof/3`, `setof/3` ou similares: [onde]
- [ ] Corte (`!`) ou negação (`\+`), e por que foram necessários: [onde]
- [ ] Programação por restrições (CLP(FD) ou outra): [onde]
- [ ] Predicados de ordem superior (`maplist`, `foldl`, `include`...): [onde]
- [ ] Outro: [...]

### 5.3 Trecho em destaque

<!--
  Escolha o trecho de Prolog de que o grupo mais se orgulha (ou o mais
  difícil). Cole o código e explique como ele funciona: o que é declarado,
  como o Prolog chega à resposta, e por que essa solução é "lógica" e não
  uma tradução de um algoritmo imperativo.
-->

```prolog
[trecho]
```

[Explicação.]

## 6. Parte em Elm

### 6.1 Modelo e mensagens

<!--
  Os tipos centrais do programa: o Model, o tipo Msg e os custom types do
  domínio. Explique as escolhas: por que um custom type e não um Bool, por
  que Maybe ou Result, etc.
-->

```elm
[type alias Model = ...]
[type Msg = ...]
```

[Explicação das escolhas.]

### 6.2 Conceitos do paradigma funcional utilizados

- [ ] Arquitetura Elm (Model, update, view): [onde]
- [ ] Custom types e `case` exaustivo: [onde]
- [ ] `Maybe` e `Result` no lugar de null e exceções: [onde]
- [ ] Funções de ordem superior e aplicação parcial: [onde]
- [ ] Composição (`|>`, `>>`): [onde]
- [ ] Decoders e encoders JSON: [onde]
- [ ] Comandos e subscriptions (efeitos controlados): [onde]
- [ ] Imutabilidade e atualização de records: [onde]
- [ ] Outro: [...]

### 6.3 Trecho em destaque

```elm
[trecho]
```

[Explicação.]

## 7. Integração

<!--
  Curto: a parte Python não é avaliada. Liste as rotas ou a forma de
  comunicação e o formato dos dados trocados. Se o grupo não usou Python,
  explique como Elm e Prolog se comunicam.
-->

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|----------------|---------|-------|------------------|
| [`POST /api/...`] | [...] | [...] | [`...`] |

## 8. Testes e validação

<!--
  Como o grupo sabe que o sistema funciona? Testes automatizados (plunit,
  pytest, elm-test), roteiros de teste manual, casos de borda verificados.
-->

- O tabuleiro em Elm é testado com elm-test em `frontend/tests/QueensBoardTest.elm` (18 testes). O comando é `make test-elm`. O módulo `frontend/src/QueensBoard.elm` é puro, então os testes não sobem servidor nem abrem o navegador.
- Construção: `empty` só cria casas livres (`QueensBoardTest.elm:33`); `fromLists` distingue livre, pista e pedra (`:51`) e recusa lado menor que 4 (`:63`), linha com tamanho errado (`:67`) e código desconhecido (`:76`).
- Jogadas: `placeQueen` não cobre pedra nem rainha já colocada (`:108`); `toggleQueen` coloca e tira a rainha do jogador (`:130`), tira a revelada e não mexe em pista nem pedra (`:142`); `clearPlaced` volta ao puzzle (`:156`).
- Regras: uma rainha sozinha não entra em conflito nem se ameaça (`:180`); conflito em linha, coluna e diagonal (`:196`); pedra não bloqueia o ataque (`:204`); casas ameaçadas (`:207`); resolvido só com N rainhas e nenhum ataque (`:233`).
- Revelação: `revealSolution` preserva pista e pedra, confirma o acerto e revela o resto (`:267`); `clearPlaced` depois disso volta ao puzzle (`:287`).
- O Prolog das N-rainhas já tinha plunit em `backend/prolog/test_queens.pl` (soluções clássicas, pedras, geração e dica). A API já tinha pytest em `backend/tests/test_queens_api.py`. Os dois entram em `make test`.

### Roteiro manual da tela de N-rainhas

Os testes puros de `QueensBoard` não executam a tela `Queens.elm` nem as
requisições HTTP. Os casos abaixo verificam essa integração no navegador.

**Execução:** concluída em 23/11/2026 por André Ricardo Meyer de Melo, no
Google Chrome em Windows, com tabuleiro 6 × 6 e dificuldade Fácil. Os resultados
da tabela foram observados pelo integrante durante a execução manual.

A preparação em Windows PowerShell 5.1 exigiu instalar SWI-Prolog 11.0.0 e
adicionar `C:\Program Files\swipl\bin` ao PATH do terminal. Com isso, `uv sync`
compilou `janus-swi==1.5.3` e o backend iniciou em `http://127.0.0.1:8000`.
Uma verificação HTTP confirmou status 200 tanto para `/queens.html` quanto para
`POST /api/queens/generate` com tamanho 6 e dificuldade `easy`, ambos pelo Vite
em `http://127.0.0.1:5173`. A geração devolveu seis linhas. Essa verificação
confirma a comunicação entre os serviços; os casos de tela foram verificados
separadamente conforme o roteiro abaixo.

**Preparação:** executar `make dev`. No Windows sem `make`, abrir dois terminais
na raiz do repositório e executar os comandos equivalentes:

```powershell
# Terminal 1: backend; requer SWI-Prolog instalado e swipl no PATH.
# Se necessário, para a instalação padrão no Windows, ajustar nesta sessão:
$env:Path = "C:\Program Files\swipl\bin;$env:Path"
cd backend
uv sync
uv run fastapi dev app/main.py
```

```powershell
# Terminal 2: frontend; dependências já instaladas com npm ci --include=dev.
cd frontend
npm run dev
```

Abrir `http://localhost:5173`, acessar N-Rainhas pelo menu ou abrir diretamente
`http://localhost:5173/queens.html`. Selecionar 6 × 6 e Fácil para os primeiros
casos e aguardar o fim do carregamento. As coordenadas nos testes Elm começam
em zero; os rótulos das casas na tela começam em um.

| Caso | Passos | Resultado esperado | Resultado observado |
|------|--------|--------------------|---------------------|
| Colocar e retirar | Clicar em uma casa vazia e clicar novamente na mesma casa. | Primeiro clique coloca uma rainha do jogador e aumenta o contador em um; segundo clique deixa a casa vazia e restaura o contador. | O primeiro clique colocou a rainha e o segundo a retirou. |
| Pedra e pista | Anotar a posição de uma pedra e de uma rainha fixa; clicar em cada uma. | As duas casas e o contador permanecem iguais. | Clicar em pedra e pista não alterou essas casas. |
| Desfazer e refazer | Colocar uma rainha em casa vazia, clicar em Desfazer e depois em Refazer. | Desfazer restaura a casa vazia; Refazer recoloca a rainha na mesma casa e restaura o contador. | Desfazer retirou a rainha colocada; Refazer a recolocou. |
| Dica | Clicar em Limpar para retirar jogadas, depois em Dica. | Surge uma rainha revelada em casa antes vazia; o contador de rainhas e o de dicas aumentam em um, sem modificar pedras e pistas. | Apareceu uma rainha e os contadores de rainhas e dicas aumentaram em um. A tela de conclusão mostrou 1 dica utilizada. |
| Resolver | Clicar em Resolver em um jogo incompleto. | A solução completa aparece, preservando pedras e pistas; rainhas reveladas recebem a aparência correspondente e aparece a mensagem de conclusão. | A tela mostrou “Resolvido com o Prolog!”, “A solução completa foi calculada pelo Prolog.” e os indicadores 6 / 6 rainhas, 01:45 e 1 dica. Pedras e pistas permaneceram nas mesmas casas. |
| Contar soluções | Clicar em Contar soluções no puzzle original; depois colocar duas rainhas na mesma linha e repetir. Usar Limpar entre os cenários. | O puzzle gerado informa solução única; um tabuleiro com rainhas em conflito informa que não há solução. A contagem não altera as casas. | Apareceu “Solução única! (igual ao puzzle gerado)” após Limpar e “Nenhuma solução possível com as rainhas atuais.” após colocar rainhas na mesma linha. |
| Vitória e cronômetro | No mesmo jogo, usar Resolver para anotar a solução, clicar em Limpar e completar manualmente as casas anotadas. Observar o cronômetro antes da última rainha e por pelo menos três segundos depois. | Com N rainhas sem ataques, aparece a vitória e o contador mostra N / N; o cronômetro deixa de avançar. | Apareceu “Parabéns! Todas as rainhas em paz! 🎉”, com 6 / 6 rainhas e 1 dica utilizada, após completar manualmente o tabuleiro. O cronômetro permaneceu em 04:33 por pelo menos três segundos. |
| Tamanho inválido | Alterar somente a próxima requisição de geração para enviar size = 3, conforme o procedimento abaixo; clicar em Fácil no painel Novo jogo. | A API rejeita a entrada; a tela mostra erro, encerra o carregamento e preserva o tabuleiro anterior. | Apareceu “Erro no servidor (código 422).” e o tabuleiro permaneceu igual após a requisição com tamanho 3. |
| Dificuldade inválida | Alterar somente a próxima requisição de geração para enviar difficulty = "invalid", conforme o procedimento abaixo; clicar em Fácil no painel Novo jogo. | A API rejeita a entrada; a tela mostra erro, encerra o carregamento e preserva o tabuleiro anterior. | Apareceu “Erro no servidor (código 422).” e o tabuleiro permaneceu igual após a requisição com dificuldade inválida. |
| Falha de rede | Com um tabuleiro carregado e incompleto, selecionar Offline na aba Network das ferramentas do navegador e clicar em Contar soluções. Depois voltar para No throttling e repetir a contagem. | Sem conexão, a tela mostra erro e mantém as casas; após restabelecer a conexão, a contagem funciona novamente. | Em Offline, apareceu “Não foi possível falar com o servidor. O backend está rodando?” e as casas permaneceram iguais. Após reconectar, a contagem funcionou e mostrou “Nenhuma solução possível com as rainhas atuais.” para o tabuleiro preenchido com rainhas em conflito. |

**Como reproduzir entradas inválidas pela tela:** os botões só oferecem
tamanhos 6, 8 e 10 e dificuldades Fácil, Médio e Difícil. Por isso, os dois
casos inválidos exigem alterar a requisição emitida pela própria aplicação.
Uma chamada isolada à API não verifica a exibição do erro em `Queens.elm`.
Novo jogo é o título do painel; clicar em um tamanho ou dificuldade gera
outro puzzle, inclusive ao clicar novamente na opção já selecionada.

Na página local de N-Rainhas, abrir o Console das ferramentas do navegador e
definir a função abaixo. Ela altera o corpo de uma única requisição de geração
e restaura o envio original antes de encaminhá-la ao backend real:

```javascript
function invalidarProximaGeracao(alteracoes) {
  const enviarOriginal = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function (corpo) {
    let dados;
    try {
      dados = JSON.parse(corpo);
    } catch {
      return enviarOriginal.call(this, corpo);
    }
    if (dados && typeof dados === "object" && "size" in dados && "difficulty" in dados) {
      XMLHttpRequest.prototype.send = enviarOriginal;
      return enviarOriginal.call(this, JSON.stringify({ ...dados, ...alteracoes }));
    }
    return enviarOriginal.call(this, corpo);
  };
}
```

1. Executar `invalidarProximaGeracao({ size: 3 })` e clicar em Fácil.
2. Anotar a mensagem e conferir se as casas anteriores foram preservadas.
3. Executar `invalidarProximaGeracao({ difficulty: "invalid" })` e repetir.
4. Clicar novamente em Fácil, sem alterar a requisição, e verificar a recuperação.

Para as rejeições de validação com HTTP 422, o tratamento atual usa a mensagem
genérica `Erro no servidor (código 422).` quando o campo `detail` da resposta
é uma lista. Esse texto foi confirmado nos dois casos inválidos. Depois deles,
clicar novamente em Fácil, sem alterar a requisição, gerou um novo jogo
normalmente. Recarregar a página remove qualquer alteração temporária feita
pelo Console.

## 9. Limitações e problemas conhecidos

<!--
  Seja honesto. Um problema conhecido e bem descrito vale mais que um
  problema escondido que o avaliador descobre sozinho.
-->

- [Limitação ou bug conhecido, e em que situação acontece.]
- [O que o grupo faria com mais tempo.]

## 10. Contribuição de cada integrante

<!--
  O que cada pessoa fez. Deve ser coerente com o histórico de commits do
  repositório. Todos os integrantes precisam concordar com esta tabela.
-->

| Integrante | Principais contribuições |
|------------|--------------------------|
| [Nome]     | [...] |
| [Nome]     | [...] |
| [Nome]     | [...] |
| [Nome]     | [...] |
| [Nome]     | [...] |

<!--
  Além desta tabela, que é do grupo, cada integrante entrega uma avaliação
  360 graus individual no SEU repositório do GitHub Classroom, em
  avaliacao-360/<matricula>.md. Veja o modelo em avaliacao-360/TEMPLATE.md.
-->

## 11. Fontes, código de terceiros e uso de IA

<!--
  Declare tudo o que não foi escrito pelo grupo. Declarar não tira pontos;
  deixar de declarar pode anular o trabalho.
-->

**Código reaproveitado.** [Ex.: "Partimos do template do Sudoku. Mantivemos
a integração Python e a estrutura do frontend; o arquivo `x.pl` e os
módulos `Y.elm` e `Z.elm` foram escritos pelo grupo."]

**Referências.** [Livros, documentação, tutoriais, repositórios consultados.]

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** auxiliar
  <!--
    nenhum: não usou. pontual: autocompletar, dúvidas, explicar erros.
    auxiliar: trechos gerados pela IA e revisados pelo grupo. intensivo: a
    IA escreveu a maior parte do código. Veja o efeito em AVALIACAO.md,
    seção 1.5. Não declarar anula o trabalho; declarar não tira pontos.
  -->

| Ferramenta | Para que foi usada | Como o grupo verificou o resultado |
|------------|--------------------|------------------------------------|
| Cursor | Entender como funciona o elm-test e ajudar na realização dos testes de `frontend/tests/QueensBoardTest.elm` | O grupo leu o arquivo e rodou `make test-elm`: 18 testes passaram |

## 12. Apresentação oral

<!--
  A apresentação tem 15 minutos e acontece no final do semestre. Uma
  divisão que costuma funcionar: 2 min de contexto, 5 min de demonstração
  do sistema funcionando, 6 min mostrando o código Prolog e Elm mais
  interessante, 2 min de limitações e aprendizados. Todos os integrantes
  devem falar.

  Preencha esta seção antes da apresentação.
-->

- **Slides:** [mesmo caminho indicado na seção 1, ou "não há"]
- **Roteiro:**

| Parte | Duração | Quem apresenta |
|-------|:-------:|----------------|
| [Contexto e objetivo] | [2 min] | [Nome] |
| [Demonstração] | [5 min] | [Nome] |
| [Código Prolog] | [3 min] | [Nome] |
| [Código Elm] | [3 min] | [Nome] |
| [Limitações e aprendizados] | [2 min] | [Nome] |

## 13. Reflexão sobre os paradigmas

<!--
  De 1 a 3 parágrafos. Perguntas que podem ajudar:
  - O que ficou mais simples em Prolog do que seria numa linguagem
    imperativa? E o que ficou mais difícil?
  - O que o compilador do Elm impediu que desse errado?
  - Como a forma de pensar mudou entre as duas linguagens?
-->

[Reflexão.]

---

<!--
  CHECKLIST ANTES DE ENTREGAR (apague esta seção depois de conferir)

  - [ ] `uv run scripts/validar_entrega.py` termina sem erros.
  - [ ] Todos os integrantes, com matrícula e turma, estão na seção 1.
  - [ ] O commit ou tag da seção 1 existe no repositório e é a versão final.
  - [ ] As instruções da seção 3 funcionam numa máquina sem nada instalado
        além dos requisitos listados.
  - [ ] Os locais indicados (arquivo:linha) conferem com o commit entregue.
  - [ ] As seções 10 e 11 foram revisadas por todo o grupo.
  - [ ] Se há slides, o arquivo está no repositório e o caminho da seção 1
        está certo.
  - [ ] Cada integrante entregou a própria avaliação 360 graus no seu
        repositório individual, em avaliacao-360/<matricula>.md.
  - [ ] Nenhum texto entre [colchetes] ou comentário de instrução sobrou.
-->
