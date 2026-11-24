# Rainhas atrás das pedras (Prolog + Elm)

## 1. Identificação

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---------------|-----------|-----------------|----------------|
| André Ricardo Meyer de Melo | 231011097 | 14h | @Andremeyerr |
| Giovanni Dornelas Ferreira | 232002664 | 14h | @GGDornelas |
| Ingrid Alves Rocha | 202045348 | 14h | @alvesingrid |
| João Guilherme Capozzi Gonçalves | 232027476 | 16h | @jonas3688 |
| João Paulo Barbosa Pereira Nunes | 232003652 | 16h | @jpnunes2210 |
| José Joaquim da Silva Neto | 232027510 | 16h | @JoaquimNetoo |
| Letícia de Cássia Hladczuk Rodrigues | 221039209 | 14h | @HladczukLe |

- **Nome do projeto:** Rainhas atrás das pedras (Prolog + Elm)
- **Nome do grupo:** Grupo 12 (G12)
- **Repositório:** https://github.com/jpnunes2210/G12_Paradigmas_Trabalho_Final_26.2
- **Commit ou tag entregue:** `v1.0`
- **Ponto de partida:** remix original
- **Slides da apresentação oral:** não há

Partimos das N-rainhas com pedras e
criamos uma regra própria: **as pedras bloqueiam o ataque**. Uma rainha só
enxerga até a primeira pedra da linha, da coluna ou da diagonal, então duas
rainhas podem dividir uma linha se houver pedra entre elas, e o tabuleiro
comporta mais de N rainhas. Cada puzzle traz a sua meta (por exemplo, 10
rainhas no 8 × 8), sempre maior que N, e tem solução única. A regra está
em `backend/prolog/queens.pl` (seção 1, `direction_constraints/4`) e em
`frontend/src/QueensBoard.elm` (`attacks`).

## 2. Resumo

O projeto é um jogo web de N-rainhas com uma regra própria: as pedras do tabuleiro bloqueiam o ataque das rainhas. Por isso cabem mais de N rainhas, e cada puzzle traz a sua meta, com solução única. O SWI-Prolog, com CLP(FD), faz toda a lógica: gera os puzzles, resolve, dá dicas, conta as soluções e grava o passo a passo do backtracking. O Elm desenha a interface e guarda as regras que precisam responder na hora, como os ataques com linha de visão, as casas ameaçadas e a vitória. Ele também cuida do desfazer e refazer, do cronômetro e da animação da busca do Prolog. O Python (FastAPI com janus) só faz a ponte HTTP entre os dois. O Sudoku do template do professor continua no repositório, na página inicial, mas o trabalho do grupo é o N-rainhas.

![Captura de tela do sistema](docs/captura.png)

## 3. Como executar

**Requisitos:**

- SWI-Prolog 9.2 ou superior (com pacote janus-swi)
- Node.js 20.x ou superior (e npm)
- uv 0.4+ / Python 3.12 ou superior

**Instalação e execução:**

1. Instalar as dependências do backend e do frontend:
```sh
make install
```
*(ou `cd backend && uv sync` e `cd frontend && npm install`)*

2. Iniciar o servidor de desenvolvimento (backend e frontend simultaneamente):
```sh
make dev
```
O jogo estará acessível em `http://localhost:5173` (Sudoku em `/` e N-Rainhas em `/queens.html`). A documentação da API FastAPI fica disponível em `http://localhost:8000/docs`.

**Testes:**

Para rodar todos os testes automatizados:
```sh
make test        # Prolog (plunit), API (pytest) e Elm (elm-test)
```
Para rodar individualmente:
- Testes lógicos em Prolog: `make test-prolog`
- Testes da API HTTP em Python: `make test-backend`
- Testes do tabuleiro e da animação em Elm: `make test-elm`

No Ubuntu, o SWI-Prolog do `apt` é antigo e não traz o janus: é preciso instalar pelo PPA oficial (`ppa:swi-prolog/stable`), e o `uv sync` precisa do pacote `python3-dev` para compilar o `janus-swi`.

**Testado em:** Linux (Ubuntu 24.04 / Mint), Ubuntu 24.04 no WSL 2, Windows, Google Chrome e Mozilla Firefox.

## 4. Arquitetura

O sistema adota uma arquitetura em três camadas desacopladas. O Elm gerencia todo o estado da interface e do usuário no navegador de forma funcional e pura, comunicando-se via HTTP/JSON com o backend FastAPI. O Python valida formatos e schemas com Pydantic e aciona diretamente o runtime do SWI-Prolog embutido via Janus, onde reside toda a computação lógica e de restrições.

```
[Elm Frontend] <---HTTP/JSON---> [Python FastAPI] <---janus-swi---> [SWI-Prolog CLP(FD)]
```

| Parte | Responsabilidade | Arquivos principais |
|-------|------------------|---------------------|
| Prolog | Modelo CLP(FD) da regra das pedras, resolução, contagem de soluções, geração com solução única, dica e o passo a passo do backtracking para a animação | `backend/prolog/queens.pl` |
| Elm | Representação imutável do tabuleiro, regras instantâneas (ataque com linha de visão, conflitos, vitória), interface de mesa de jogo, histórico com undo/redo, cronômetro e animação do backtracking | `frontend/src/Queens.elm`, `frontend/src/QueensBoard.elm`, `frontend/src/QueensTrace.elm`, `frontend/src/QueensApi.elm` |
| Python | Camada fina de integração e deserialização HTTP/JSON, despachando consultas ao Prolog via biblioteca Janus | `backend/app/main.py`, `backend/app/prolog.py` |

## 5. Parte em Prolog

### 5.1 Predicados principais

| Predicado | Local | O que faz |
|-----------|-------|-----------|
| `puzzle_model(+Puzzle, +Goal, -Cells, -Vars)` | `backend/prolog/queens.pl:89` | Monta o modelo CLP(FD): cada casa livre vira uma variável 0..1, a pedra vira o átomo `rock`, e as restrições das quatro direções são impostas |
| `direction_constraints(+N, +Cells, +Goal, +Direction)` | `backend/prolog/queens.pl:118` | A regra do jogo: corta cada linha, coluna ou diagonal em trechos entre pedras, exige no máximo uma rainha por trecho e soma a meta |
| `segments(+Line, -Segments)` | `backend/prolog/queens.pl:162` | Corta uma linha nas pedras e devolve os trechos não vazios |
| `solve_queens(+Puzzle, +Goal, -Solution)` | `backend/prolog/queens.pl:187` | Resolve o puzzle com `labeling([ff], ...)` e devolve a primeira solução |
| `count_queens(+Puzzle, +Goal, +Limit, -Count)` | `backend/prolog/queens.pl:206` | Conta as soluções até o teto `Limit`, com `findall/3` e `limit/2` |
| `generate_queens(+Size, +Difficulty, -Puzzle, -Goal)` | `backend/prolog/queens.pl:285` | Gera um puzzle com meta maior que N e solução única, acrescentando pedras até eliminar as soluções concorrentes |
| `hint_queens(+Board, +Goal, -Result)` | `backend/prolog/queens.pl:412` | Indica uma casa onde falta rainha, ou avisa que o tabuleiro está completo ou sem solução |
| `trace_queens(+Puzzle, +Goal, +MaxSteps, -Steps, -Status)` | `backend/prolog/queens.pl:470` | Busca sem CLP(FD), trecho por trecho, e grava cada passo (coloca, conflito, remove) para a animação no Elm |

### 5.2 Conceitos do paradigma lógico utilizados

- [x] Fatos e regras como base de conhecimento: `backend/prolog/queens.pl:101` (`square_cell/2`, a tradução entre o código da casa e o termo do modelo) e `backend/prolog/queens.pl:145` (`line_key/3`, o que define uma linha, coluna ou diagonal).
- [x] Unificação e casamento de padrões: `backend/prolog/queens.pl:167` (`segments/3` desconstrói a linha em `[Cell | Cells]`) e `backend/prolog/queens.pl:175` (`close_segment/3` distingue trecho vazio de trecho com casas pela forma da lista).
- [x] Recursão (inclusive sobre listas): `backend/prolog/queens.pl:165` (`segments/3` percorre a linha) e `backend/prolog/queens.pl:562` (`rock_between/4` anda casa a casa procurando pedra entre duas rainhas).
- [x] Backtracking e múltiplas soluções: `backend/prolog/queens.pl:525` (`search_segments/6`, cada casa de um trecho é um ponto de escolha) e `backend/prolog/queens.pl:572` (`place_step/2` usa `( true ; ... )` para anotar o "remove" quando o Prolog volta).
- [x] `findall/3`, `bagof/3`, `setof/3` ou similares: `backend/prolog/queens.pl:139` (`bagof/3` agrupa as casas de cada linha pela chave) e `backend/prolog/queens.pl:207` (`findall/3` com `limit/2` para contar soluções).
- [x] Corte (`!`) ou negação (`\+`), e por que foram necessários: `backend/prolog/queens.pl:190` (corte para ficar só com a primeira solução) e `backend/prolog/queens.pl:560` (negação por falha: a rainha ataca se NÃO há pedra entre as duas).
- [x] Programação por restrições (CLP(FD) ou outra): `backend/prolog/queens.pl:95` (`ins 0..1`), `backend/prolog/queens.pl:124` e `backend/prolog/queens.pl:128` (`sum/3` com `#=`), `backend/prolog/queens.pl:234` (`sum/3` com `#<` para achar solução diferente) e `labeling([ff], ...)`.
- [x] Predicados de ordem superior (`maplist`, `foldl`, `include` e outros): `backend/prolog/queens.pl:92` (`maplist/3` aninhado), `backend/prolog/queens.pl:94` (`exclude/3`), `backend/prolog/queens.pl:96` (`maplist/2` com aplicação parcial) e `backend/prolog/queens.pl:347` (`map_list_to_pairs/3`).

### 5.3 Trecho em destaque

O trecho abaixo (`backend/prolog/queens.pl:118-128`) é a regra própria do jogo inteira:

```prolog
direction_constraints(N, Cells, Goal, Direction) :-
    findall(Line, line_positions(N, Direction, Line), Lines),
    maplist(positions_cells(Cells), Lines, CellLines),
    maplist(segments, CellLines, Nested),
    append(Nested, Segments),
    maplist(segment_count, Segments, Counts),
    sum(Counts, #=, Goal).

segment_count(Segment, Count) :-
    Count in 0..1,
    sum(Segment, #=, Count).
```

No clássico, a regra é "uma rainha por linha". Com pedras isso deixa de valer, porque duas rainhas podem dividir a linha se houver pedra entre elas. A saída foi mudar a unidade: em vez de linhas, trechos entre pedras. `segments/2` corta cada linha, coluna e diagonal nas pedras, e `segment_count/2` declara que cada trecho tem 0 ou 1 rainha. Não há nenhum laço verificando ataques: a regra é só essa declaração, e o CLP(FD) cuida da busca.

A última linha, `sum(Counts, #=, Goal)`, é uma restrição redundante. Cada rainha está em exatamente um trecho de cada direção, então bastaria impor a meta uma vez. Repetir nas quatro direções não muda as soluções, mas fortalece a propagação: contar as 92 soluções do 8 × 8 vazio caiu de 6 s para menos de meio segundo.

## 6. Parte em Elm

### 6.1 Modelo e mensagens

Os tipos centrais do jogo (`frontend/src/Queens.elm:59-91` e `frontend/src/QueensBoard.elm:54-91`) expressam o domínio de forma precisa:

```elm
type Origin
    = Given
    | Placed
    | Revealed

type Square
    = Free
    | Rock
    | Queen Origin

type Board
    = Board { side : Int, goal : Int, squares : Dict Position Square }

type alias Model =
    { board : Board
    , size : Int
    , difficulty : Difficulty
    , showThreats : Bool
    , darkTheme : Bool
    , loading : Bool
    , error : Maybe String
    , history : List Board
    , future : List Board
    , elapsedSeconds : Int
    , hintsUsed : Int
    , solutionCount : Maybe Int
    , animation : Maybe Animation
    }
```

A escolha de modelar `Square` como uma união disjunta (`Free | Rock | Queen Origin`) impede por construção estados impossíveis, como ter uma pedra e uma rainha na mesma casa. O tipo `Origin` acoplado ao construtor `Queen` assegura que nenhuma rainha exista sem sabermos se foi uma pista dada (`Given`), se foi posta pelo jogador (`Placed`) ou revelada pelo Prolog (`Revealed`), permitindo estilização semântica e regras de limpeza distintas. O histórico (`history` e `future` como `List Board`) demonstra a força das estruturas de dados persistentes do paradigma funcional: cada movimento preserva o tabuleiro anterior sem cópias manuais profundas. O `Board` é opaco: o módulo não exporta o construtor, e a única entrada é `fromLists`, que valida o lado, os códigos das casas e a meta. A animação é um `Maybe Animation`: enquanto ela existe, a tela mostra o passo a passo do Prolog e não aceita cliques, sem precisar de um booleano solto.

### 6.2 Conceitos do paradigma funcional utilizados

- [x] Arquitetura Elm (Model, update, view): `frontend/src/Queens.elm:38` (`Browser.element` com `init`, `update`, `view` e `subscriptions`).
- [x] Custom types e `case` exaustivo: `frontend/src/QueensBoard.elm:63` (`Square` e `Origin`), `frontend/src/QueensTrace.elm:37` (`Kind` e `Status`) e `frontend/src/Queens.elm:212` (`update` tratando todas as `Msg`).
- [x] `Maybe` e `Result` no lugar de null e exceções: `frontend/src/Queens.elm:66` (`error : Maybe String`), `frontend/src/Queens.elm:72` (`animation : Maybe Animation`) e `frontend/src/QueensBoard.elm:139` (`fromLists` devolve `Result String Board`).
- [x] Funções de ordem superior e aplicação parcial: `frontend/src/QueensBoard.elm:337` (`List.filter` com `attacks board queen` parcialmente aplicada) e `frontend/src/Queens.elm:979` (`List.map (viewSquare conflicts threats step)`).
- [x] Composição (`|>`, `>>`): `frontend/src/QueensBoard.elm:318` (linha de visão: as casas entre as rainhas passam por `|> List.all` procurando pedra) e `frontend/src/QueensTrace.elm:103` (`Array.slice |> Array.foldl` monta o tabuleiro de um passo).
- [x] Decoders e encoders JSON: `frontend/src/QueensApi.elm:95` (`encodeBoard`, com a meta), `frontend/src/QueensApi.elm:108` (`puzzleDecoder` com `Decode.andThen`) e `frontend/src/QueensApi.elm:144` (`traceDecoder`).
- [x] Comandos e subscriptions (efeitos controlados): `frontend/src/Queens.elm:160` (`Time.every` para o cronômetro e, com o intervalo da velocidade escolhida, para a animação).
- [x] Imutabilidade e atualização de records: `frontend/src/Queens.elm:258` (`{ model | board = ..., history = model.board :: model.history }`) e `frontend/src/QueensTrace.elm:101` (o tabuleiro de cada passo é recalculado a partir do inicial, sem guardar uma cópia por passo).

### 6.3 Trecho em destaque

O trecho abaixo (`frontend/src/Queens.elm:265-293`) implementa as operações de desfazer e refazer (undo/redo) apoiando-se diretamente na imutabilidade funcional do Elm:

```elm
Undo ->
    case model.history of
        prev :: rest ->
            ( { model
                | board = prev
                , history = rest
                , future = model.board :: model.future
                , solutionCount = Nothing
              }
            , Cmd.none
            )

        [] ->
            ( model, Cmd.none )

Redo ->
    case model.future of
        next :: rest ->
            ( { model
                | board = next
                , history = model.board :: model.history
                , future = rest
                , solutionCount = Nothing
              }
            , Cmd.none
            )

        [] ->
            ( model, Cmd.none )
```

Em linguagens com estado mutável, implementar undo/redo exige clones caros de matrizes ou padrões complexos de Command com inversão de operações. No Elm, o tabuleiro `Board` é uma estrutura de dados persistente. O `Undo` simplesmente faz pattern matching na cabeça da lista `history`, atribui o tabuleiro anterior como atual e empilha o estado desfeito na lista `future`. Não há alocações destrutivas, e o compilador garante que nenhum estado intermediário corrompa o modelo.

## 7. Integração

A integração entre o frontend Elm e o motor lógico Prolog é intermediada por uma API REST em Python (FastAPI), que valida o payload com Pydantic e se comunica com o Prolog via Janus:

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|----------------|---------|-------|------------------|
| `POST /api/queens/generate` | `{"size": int, "difficulty": string}` | `{"board": [[int]], "goal": int}` | `queens:generate_queens/4` |
| `POST /api/queens/solve` | `{"board": [[int]], "goal": int}` | `{"board": [[int]]}` | `queens:solve_queens/3` |
| `POST /api/queens/hint` | `{"board": [[int]], "goal": int}` | `{"row": int, "col": int}` | `queens:hint_queens/3` |
| `POST /api/queens/count` | `{"board": [[int]], "goal": int}` | `{"count": int}` | `queens:count_queens/4` |
| `POST /api/queens/trace` | `{"board": [[int]], "goal": int}` | `{"steps": [[string, int, int]], "status": string}` | `queens:trace_queens/5` |

No tabuleiro, `0` é casa vazia, `1` é rainha e `2` é pedra. O Pydantic recusa com 422 tabuleiros que não são quadrados, lados fora de 4 a 12, códigos desconhecidos e meta ausente; o gerador só aceita tamanhos de 6 a 12. As rotas do Sudoku do template (`/api/generate`, `/api/solve` e `/api/hint`) continuam lá, sem mudanças.

## 8. Testes e validação

O sistema conta com três níveis de validação automatizada, todos rodados por `make test`:

| Suíte | Arquivo | Testes |
|-------|---------|:------:|
| Prolog (plunit) | `backend/prolog/test_queens.pl` | 43 |
| API (pytest) | `backend/tests/test_queens_api.py` | 19 |
| Elm (elm-test) | `frontend/tests/QueensBoardTest.elm` | 21 |
| Elm (elm-test) | `frontend/tests/QueensBoardEdgeTest.elm` | 6 |
| Elm (elm-test) | `frontend/tests/QueensTraceTest.elm` | 12 |

O Sudoku do template mantém os seus testes (`backend/prolog/test_sudoku.pl`, 11 plunit, e `backend/tests/test_api.py`, 7 pytest), que também passam.

- O tabuleiro em Elm é testado com elm-test em `frontend/tests/QueensBoardTest.elm` e `frontend/tests/QueensBoardEdgeTest.elm`. O comando é `make test-elm`. O módulo `frontend/src/QueensBoard.elm` é puro, então os testes não sobem servidor nem abrem o navegador.
- Construção: `empty` só cria casas livres (`QueensBoardTest.elm:34`); `fromLists` distingue livre, pista e pedra (`:53`) e recusa lado menor que 4 (`:65`), linha com tamanho errado (`:69`), código desconhecido (`:78`) e meta que não cabe no tabuleiro (`:87`).
- Jogadas: `placeQueen` não cobre pedra nem rainha já colocada (`:125`); `toggleQueen` coloca e tira a rainha do jogador (`:147`), tira a revelada e não mexe em pista nem pedra (`:159`); `clearPlaced` volta ao puzzle (`:173`).
- Regras: uma rainha sozinha não entra em conflito nem se ameaça (`:197`); conflito em linha, coluna e diagonal (`:213`); pedra entre duas rainhas bloqueia o ataque, e pedra fora da linha não (`:221`); o ataque para na primeira pedra (`:229`); casas ameaçadas (`:247`); a meta pode passar de N (`:273`); resolvido só com a meta de rainhas e nenhum ataque (`:290`).
- Revelação: `revealSolution` preserva pista e pedra, confirma o acerto e revela o resto (`:324`); `clearPlaced` depois disso volta ao puzzle (`:344`).
- Animação: `frontend/tests/QueensTraceTest.elm` confere que o passo 0 é o tabuleiro inicial, que "coloca" põe uma rainha revelada, que "conflito" não muda o tabuleiro, que "remove" tira a rainha mas nunca uma pista, e a contagem de voltas atrás.
- Os testes plunit em `backend/prolog/test_queens.pl` cobrem o caso clássico (sem pedras e meta N, 2, 4 e 92 soluções), a regra das pedras (bloqueio em linha, coluna e diagonais, espaço para rainha extra, exemplo com solução única), o gerador (solução única, meta maior que N, pistas por dificuldade), a dica e o passo a passo do backtracking (primeiros passos do 4 × 4, volta atrás, estado final igual à solução, nunca põe rainha em pedra, pedra entre duas pistas, meta impossível e limite de passos).
- Os testes pytest em `backend/tests/test_queens_api.py` conferem as rotas, os códigos 422 e a meta (`goal`) ausente ou inválida, inclusive na rota da animação.

### Casos de borda de QueensBoard

O arquivo `frontend/tests/QueensBoardEdgeTest.elm` complementa os testes de
`QueensBoardTest.elm` com um teste para cada caso abaixo:

| Caso | Verificação |
|------|-------------|
| Conversão e origem | Em um tabuleiro com pista em (0,0), pedra em (0,1), rainha Placed em (0,2) e Revealed em (1,0), `toLists` codifica ambas as rainhas adicionadas como 1. Ao reconstruir com `fromLists`, elas passam a Queen Given; a pista e a pedra são preservadas. Esse é o formato enviado à API. |
| Vitória com pedra | A solução 4 × 4 nas colunas 1, 3, 0, 2, com pedra na casa livre (0,0), mantém `isSolved` verdadeiro. |
| Contagem por origem | `queenCount` retorna 3 para um tabuleiro com uma pista, uma rainha do jogador e uma revelada. |
| Revelação confirmada | Uma Queen Revealed em uma posição confirmada pela solução permanece Queen Revealed após `revealSolution`. |
| Clique fora do tabuleiro | `toggleQueen (9,9)` em um tabuleiro 4 × 4 preserva o resultado de `toLists`. |
| Diagonal oposta | As rainhas em (0,3) e (1,2) aparecem ambas no conjunto `conflicts`. |

No Windows sem `make`, executar na raiz o equivalente ao alvo `test-elm`,
usando as dependências locais já instaladas:

```powershell
cd frontend
npm test
cd ..
```

A suíte deve executar os 39 testes sem falhas. O elm-test descobre os
arquivos automaticamente em `frontend/tests/`.

### Roteiro manual da tela de N-rainhas

Os testes puros de `QueensBoard` não executam a tela `Queens.elm` nem as
requisições HTTP. Os casos abaixo verificam essa integração no navegador.

**Atenção:** este roteiro foi executado antes da regra das pedras que
bloqueiam o ataque. Com a regra nova, o contador mostra rainhas / meta (por
exemplo, 7 no 6 × 6) em vez de N / N, e duas rainhas na mesma linha só entram
em conflito se não houver pedra entre elas. O roteiro precisa ser repetido
com a versão atual.

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

- O gerador de Rainhas atrás das pedras só aceita tabuleiros de 6 × 6 a 12 × 12. Em 4 × 4 nenhuma combinação de até três pedras comporta cinco rainhas, e o 5 × 5 precisa de três pedras, então não dá para garantir meta maior que N. Os tabuleiros de 4 × 4 e 5 × 5 ainda podem ser resolvidos e contados pela API.
- O 10 × 10 no nível Difícil costuma levar de 1 a 5 segundos para ser gerado, mas às vezes passa de 10 segundos. Sem rainhas fixas, cada pedra nova exige uma prova de que não sobrou outra solução, e uma pedra que corta linhas pode criar soluções novas. Os tamanhos 6 × 6 e 8 × 8 ficam abaixo de 2 segundos em todos os níveis.
- A animação do backtracking usa uma busca sem CLP(FD), para que se vejam as voltas atrás, e para em 5000 passos. Nos níveis Fácil e Médio ela costuma chegar à solução; no Difícil, sem rainhas fixas, quase sempre para antes, e a tela avisa que a busca foi interrompida.
- O roteiro manual da seção 8 foi executado antes da regra das pedras e precisa ser repetido com a versão atual.
- O que faríamos com mais tempo: uma poda melhor na animação (contando também os trechos de coluna e diagonal), para que ela chegue ao fim nos tabuleiros difíceis; um editor para o jogador montar o próprio puzzle com pedras, com o Prolog conferindo se a solução é única; e níveis de dificuldade medidos pelo esforço de busca, e não só pelo número de pistas.

## 10. Contribuição de cada integrante

| Integrante | Principais contribuições |
|------------|--------------------------|
| João Guilherme Capozzi Gonçalves | Implementação do histórico com desfazer/refazer (undo/redo), cronômetro via subscriptions, contador de dicas, integração e endpoint de contagem de soluções no frontend e backend |
| Letícia de Cássia Hladczuk Rodrigues | Redesenho completo da interface como mesa de jogo clássica (veios de madeira em CSS, efeito marfim e latão das rainhas) e revisão da responsividade visual; revisão e correção deste relatório e do `README.md` |
| João Paulo Barbosa Pereira Nunes | Estruturação da arquitetura geral do projeto, pipeline de CI/CD, integração do backend FastAPI e refinamento da comunicação HTTP |
| José Joaquim da Silva Neto | Modelagem inicial do módulo Prolog de N-Rainhas com pedras, implementação das restrições CLP(FD) e suite de testes plunit |
| Giovanni Dornelas Ferreira | Testes de integração da API, revisão dos decoders JSON em Elm, documentação e suporte à validação dos casos de borda |
| André Ricardo Meyer de Melo | Implementação dos seis casos de borda em `frontend/tests/QueensBoardEdgeTest.elm`; elaboração, execução no Chrome e registro do roteiro manual da tela de N-rainhas na seção 8, incluindo jogadas, histórico, Dica, Resolver, contagem de soluções, vitória, cronômetro, entradas inválidas e falha de rede. |
| Ingrid Alves Rocha | Regra própria das pedras que bloqueiam o ataque (remix original): modelo CLP(FD) por trechos e novo gerador em `queens.pl`, meta (`goal`) na API e linha de visão no Elm, com os testes correspondentes |

## 11. Fontes, código de terceiros e uso de IA

**Código reaproveitado:** Partimos do template do Sudoku disponibilizado pelo professor Fábio M. Mendes. Mantivemos a estrutura de integração entre Python e SWI-Prolog via Janus e estendemos a aplicação desenvolvendo a variante completa de N-Rainhas com pedras (`queens.pl`, `QueensBoard.elm`, `QueensTrace.elm`, `QueensApi.elm`, `Queens.elm` e rotas na API). O Sudoku original continua no repositório sem mudanças de lógica.

**Referências:**
- Documentação oficial do SWI-Prolog e biblioteca `library(clpfd)`.
- Guia oficial da linguagem Elm (https://guide.elm-lang.org).
- Documentação do FastAPI e Pydantic v2.

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** auxiliar

| Ferramenta | Para que foi usada | Como o grupo verificou o resultado |
|------------|--------------------|------------------------------------|
| Claude (Anthropic) / Gemini (Google) | Apoio na estruturação inicial de trechos de CSS avançado, sugestão de padrões para o decoder Elm e conferência das mensagens de erro do validador | Todos os trechos sugeridos foram revisados manualmente, compilados via `elm make`, testados na interface e validados pelas suítes do `pytest` e `plunit` |
| Cursor | Entender como funciona o elm-test e ajudar na realização dos testes de `frontend/tests/QueensBoardTest.elm` | O grupo leu o arquivo e rodou `make test-elm`: 18 testes passaram |
| Claude Code | Implementar a regra das pedras que bloqueiam o ataque: modelo CLP(FD) por trechos e gerador em `backend/prolog/queens.pl`, campo `goal` na API, linha de visão e meta em `frontend/src/QueensBoard.elm`, painel da regra em `Queens.elm` e os testes correspondentes | O grupo rodou `make test` (plunit, pytest e elm-test passando) e testou as rotas por HTTP |
| Claude Code | Consertar o merge entre a animação do backtracking e a regra das pedras (lista de exportação do `queens.pl`, classe `QueensTraceResponse` da API e painel lateral do `Queens.elm`), adaptar `trace_queens/5` à meta e às pedras, reescrever o `README.md` com foco no N-rainhas e revisar este relatório | As suítes foram rodadas depois das correções (43 plunit, 26 pytest e 39 elm-test passando, além do `npm run build`), e o jogo subiu com `make dev` no WSL. As referências de linha deste relatório foram conferidas contra o código atual |

## 12. Apresentação oral

- **Slides:** não há
- **Roteiro:**

| Parte | Duração | Quem apresenta |
|-------|:-------:|----------------|
| Contexto do projeto e visão geral da arquitetura | 2 min | João Paulo Barbosa Pereira Nunes |
| Demonstração prática do jogo das N-Rainhas e Sudoku | 5 min | André Ricardo Meyer de Melo |
| Modelagem lógica em Prolog, CLP(FD) e busca com unicidade | 3 min | José Joaquim da Silva Neto |
| Frontend em Elm, modelagem por tipos e imutabilidade (Undo/Redo) | 3 min | João Guilherme Capozzi Gonçalves |
| Limitações técnicas, aprendizados e testes | 2 min | Giovanni Dornelas Ferreira |

## 13. Reflexão sobre os paradigmas

A experiência de integrar o paradigma lógico (Prolog) e o paradigma funcional (Elm) em uma mesma aplicação evidenciou como cada paradigma resolve com naturalidade problemas que seriam excessivamente verbosos no paradigma imperativo clássico. No Prolog, a modelagem das regras do jogo foi inteiramente declarativa: definimos as restrições que um tabuleiro válido deve satisfazer (ausência de ataques nas linhas, colunas e diagonais, além da proibição de posicionamento sobre pedras) e deixamos que o mecanismo de propagação do CLP(FD) e o motor de backtracking explorassem o espaço de busca. Resolver o puzzle, fornecer uma dica ótima ou verificar a existência de soluções concorrentes tornou-se uma consequência direta do mesmo modelo lógico.

Por outro lado, o paradigma funcional em Elm complementou essa flexibilidade com rigor e segurança. A modelagem através de custom types e a impossibilidade de estados inconsistentes no `Model` eliminaram por completo exceções em tempo de execução (`null pointer exceptions`). A imutabilidade de dados facilitou a criação de funcionalidades avançadas como desfazer/refazer, que em linguagens imperativas demandariam cópias defensivas e mutações frágeis. A mudança mental mais marcante entre os dois polos foi transitar de um ambiente onde se declara "quais relações lógicas definem a resposta correta" (Prolog) para um fluxo estrito onde se define "como o estado do mundo se transforma a cada mensagem do usuário" (Elm).
