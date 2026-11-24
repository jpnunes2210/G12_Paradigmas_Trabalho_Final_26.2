/*  queens.pl: Rainhas atrás das pedras, em Prolog (CLP(FD)).

    O JOGO
    ------
    Ponto de partida: o clássico das N rainhas, em que se colocam N rainhas
    num tabuleiro N x N sem que duas se ataquem (nenhum par na mesma linha,
    coluna ou diagonal).

    A NOSSA REGRA: "PEDRAS BLOQUEIAM O ATAQUE"
    ------------------------------------------
    O puzzle vem com dois tipos de casa preenchida:

        * rainhas fixas (pistas): já estão no lugar certo e não saem dele;
        * pedras: nenhuma rainha pode ficar nelas, e elas CORTAM A LINHA DE
          VISÃO. Uma rainha ataca ao longo da linha, da coluna e das
          diagonais só até a primeira pedra.

    Com isso duas rainhas podem dividir a mesma linha (ou coluna, ou
    diagonal) desde que haja uma pedra entre elas, e o tabuleiro passa a
    comportar MAIS de N rainhas. Por isso cada puzzle diz a sua META: quantas
    rainhas é preciso colocar. O gerador sempre escolhe uma meta maior que N,
    então não dá para resolver ignorando as pedras.

    REPRESENTAÇÃO
    -------------
    Um tabuleiro é uma lista com N linhas de N inteiros cada:

        0 = casa vazia      1 = rainha      2 = pedra

    É a forma que o Python (via janus) envia e recebe, sempre acompanhada da
    meta (um inteiro). Internamente cada casa vira um termo:

        rock        para pedra;
        uma variável de domínio 0..1 para as outras casas (1 = tem rainha).
        As rainhas fixas já entram valendo 1.

    O modelo clássico do CLP(FD) (uma variável por linha guardando a coluna
    da rainha) não serve mais: com pedras, uma linha pode ter duas rainhas.

    COMO TESTAR NO TERMINAL
    -----------------------
        $ swipl backend/prolog/queens.pl
        ?- example_queens(P, G), solve_queens(P, G, S), print_queens(S).
        ?- generate_queens(8, medium, P, G), print_queens(P).
        ?- length(Row, 8), maplist(=(0), Row), length(B, 8), maplist(=(Row), B),
           count_queens(B, 8, 100, N).          % N = 92, como no clássico
*/

% Os nomes exportados têm sufixo `_queens` de propósito: o backend carrega
% sudoku.pl e queens.pl no mesmo processo (janus.consult), e dois módulos
% não podem exportar solve/2 para o mesmo módulo `user`.
:- module(queens,
          [ solve_queens/3,       % +Puzzle, +Goal, -Solution
            count_queens/4,       % +Puzzle, +Goal, +Limit, -Count
            generate_queens/4,    % +Size, +Difficulty, -Puzzle, -Goal
            hint_queens/3,        % +Board, +Goal, -Result
            trace_queens/5,       % +Puzzle, +Goal, +MaxSteps, -Steps, -Status
            example_queens/2,     % -Puzzle, -Goal
            print_queens/1        % +Board
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(aggregate)).
:- use_module(library(random)).
:- use_module(library(error)).
:- use_module(library(solution_sequences)).   % limit/2


/* =========================================================================
   1. AS REGRAS (restrições)
   =========================================================================

   Chamamos de TRECHO um pedaço de linha (ou coluna, ou diagonal) entre duas
   pedras ou entre uma pedra e a borda. Dentro de um trecho todas as casas
   se enxergam; entre trechos diferentes a pedra corta a visão. A regra
   inteira cabe numa frase: cada trecho tem NO MÁXIMO UMA rainha, e o total
   de rainhas é a meta.
*/

%!  puzzle_model(+Puzzle, +Goal, -Cells, -Vars) is semidet.
%
%   Cells é a matriz de casas (rock ou 0..1) e Vars são as casas que podem
%   receber rainha. Só registra as restrições; quem escolhe valores é o
%   labeling. Falha se o tabuleiro não for quadrado ou se as rainhas fixas
%   já se atacarem.
puzzle_model(Puzzle, Goal, Cells, Vars) :-
    length(Puzzle, N),
    maplist(same_length(Puzzle), Puzzle),     % tabuleiro quadrado
    maplist(maplist(square_cell), Puzzle, Cells),
    append(Cells, Flat),
    exclude(==(rock), Flat, Vars),
    Vars ins 0..1,
    maplist(direction_constraints(N, Cells, Goal),
            [row, column, diagonal, antidiagonal]).

%   square_cell(?Code, ?Cell): a casa do formato da API e o termo do modelo.
%   A casa vazia vira uma variável nova (o `_`), ainda sem domínio.
square_cell(0, _).
square_cell(1, 1).
square_cell(2, rock).

%!  direction_constraints(+N, +Cells, +Goal, +Direction) is semidet.
%
%   Para cada trecho de uma direção, Count (0 ou 1) é quantas rainhas ele
%   tem. Isso já é a regra: no máximo uma rainha por trecho.
%
%   A soma dos Counts é a meta, e isso vale nas QUATRO direções, porque os
%   trechos de uma direção repartem as casas livres: cada rainha está em
%   exatamente um trecho de linha, um de coluna e um de cada diagonal.
%   Bastaria impor a meta uma vez; as outras três somas são restrições
%   REDUNDANTES, que não mudam as soluções mas deixam a propagação muito
%   mais forte. Com elas o CLP(FD) percebe cedo, por exemplo, que uma linha
%   sem rainha deixa as outras sem lugar para completar a meta (contar as 92
%   soluções do 8 x 8 cai de 6 s para menos de meio segundo).
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

%!  line_positions(+N, ?Direction, -Positions) is nondet.
%
%   Positions são as casas de UMA linha da direção dada, em ordem. Uma
%   linha é o conjunto de casas que têm a mesma chave (line_key/3): a mesma
%   linha, a mesma coluna, a mesma diferença R - C (diagonal) ou a mesma
%   soma R + C (antidiagonal). bagof/3 agrupa pelas chaves: cada solução,
%   no backtracking, é o grupo de uma chave.
line_positions(N, Direction, Positions) :-
    Last is N - 1,
    bagof(R-C,
          ( between(0, Last, R),
            between(0, Last, C),
            line_key(Direction, R-C, _Key) ),
          Positions).

line_key(row,          R-_, R).
line_key(column,       _-C, C).
line_key(diagonal,     R-C, K) :- K is R - C.
line_key(antidiagonal, R-C, K) :- K is R + C.

positions_cells(Cells, Positions, Line) :-
    maplist(cell_at(Cells), Positions, Line).

cell_at(Cells, R-C, Cell) :-
    nth0(R, Cells, Row),
    nth0(C, Row, Cell).

%!  segments(+Line, -Segments) is det.
%
%   Corta Line nas pedras: Segments são os trechos não vazios entre elas.
%   Comparamos com ==/2 e não com =/2 de propósito: as casas livres são
%   variáveis, e unificá-las com `rock` transformaria a casa em pedra.
segments(Line, Segments) :-
    segments(Line, [], Segments).

segments([], Current, Segments) :-
    close_segment(Current, [], Segments).
segments([Cell | Cells], Current, Segments) :-
    (   Cell == rock
    ->  close_segment(Current, Rest, Segments),
        segments(Cells, [], Rest)
    ;   segments(Cells, [Cell | Current], Segments)
    ).

%   Um trecho vazio (duas pedras seguidas, ou pedra na borda) não conta.
close_segment([], Segments, Segments).
close_segment([Cell | Cells], Rest, [[Cell | Cells] | Rest]).


/* =========================================================================
   2. RESOLVER E CONTAR
   ========================================================================= */

%!  solve_queens(+Puzzle, +Goal, -Solution) is semidet.
%
%   Solution é Puzzle com Goal rainhas no lugar (as pedras continuam).
%   Falha se não há solução.
solve_queens(Puzzle, Goal, Solution) :-
    puzzle_model(Puzzle, Goal, Cells, Vars),
    labeling([ff], Vars),         % `ff` (first fail): variável de menor domínio
    !,                            % só queremos a primeira solução
    cells_board(Cells, Solution).

%   cells_board(+Cells, -Board): de volta ao formato 0/1/2. Depois do
%   labeling as casas livres já são 0 ou 1; só a pedra muda de nome.
%   (square_cell/2 não serve ao contrário: a casa vazia, `_`, casaria com
%   tudo.)
cells_board(Cells, Board) :-
    maplist(maplist(cell_code), Cells, Board).

cell_code(rock, 2) :- !.
cell_code(Value, Value).

%!  count_queens(+Puzzle, +Goal, +Limit, -Count) is det.
%
%   Quantas soluções Puzzle tem, contando no máximo até Limit.
count_queens(Puzzle, Goal, Limit, Count) :-
    findall(x,
            limit(Limit, ( puzzle_model(Puzzle, Goal, _, Vars),
                           labeling([ff], Vars) )),
            Found),
    length(Found, Count).

%!  queen_positions(+Board, -Positions) is det.
%
%   As casas com rainha, como Linha-Coluna. Serve tanto para o formato 0/1/2
%   quanto para a matriz do modelo depois do labeling.
queen_positions(Board, Positions) :-
    findall(R-C,
            ( nth0(R, Board, Row),
              nth0(C, Row, Square),
              Square == 1 ),
            Positions).

%!  another_solution(+Puzzle, +Goal, +Target, -Other) is semidet.
%
%   Other (lista de casas) é uma solução de Puzzle DIFERENTE de Target (a
%   solução que o gerador tem em mente). Falha se Target é a única.
%
%   Como as duas têm Goal rainhas, "diferente" é o mesmo que "deixa vazia
%   pelo menos uma casa de Target": a soma dessas casas fica abaixo da meta.
another_solution(Puzzle, Goal, Target, Other) :-
    puzzle_model(Puzzle, Goal, Cells, Vars),
    maplist(cell_at(Cells), Target, TargetCells),
    sum(TargetCells, #<, Goal),
    labeling([ff], Vars),
    !,
    queen_positions(Cells, Other).

/* =========================================================================
   3. GERADOR
   =========================================================================

   Queremos um puzzle com SOLUÇÃO ÚNICA e meta maior que N. Em etapas:

   (a) espalhar algumas pedras ao acaso (as "paredes") e pedir ao CLP(FD)
       uma solução aleatória com N + Extra rainhas, que só existe porque as
       paredes cortam linhas. Se aquelas paredes não permitem, sorteamos
       outras;
   (b) manter algumas rainhas dessa solução (Target) como pistas (quantas
       depende da dificuldade; no nível `hard` não há nenhuma);
   (c) enquanto o puzzle tiver outra solução além de Target, pegar uma
       dessas soluções e colocar uma PEDRA numa casa dela que Target não
       usa. A pedra elimina aquela solução e nunca prejudica Target: tirar
       uma casa e cortar linhas só pode separar rainhas, nunca juntá-las.
       Cada volta ocupa uma casa nova, então o laço termina.

   Uma diferença em relação ao clássico: como a pedra corta linhas, ela
   pode CRIAR soluções novas (dois trechos onde antes havia um). Por isso,
   em (c), preferimos as casas que cortam menos linhas (as da borda).

   A versão anterior ainda tentava devolver cada pedra no fim, para tirar
   as desnecessárias. Aqui isso quase nunca removia alguma (a escolha pela
   borda já evita pedras sobrando) e dobrava o tempo, porque cada tentativa
   é uma prova completa de unicidade. Ficou de fora.
*/

%   extra_queens(+N, -Extra): quantas rainhas a meta tem além de N.
%   Cada rainha extra precisa de mais ou menos duas paredes para caber.
extra_queens(N, 1) :- N < 8, !.
extra_queens(_, 2).

%   fixed_queens(+Difficulty, +N, -Count): quantas rainhas ficam como pista.
%   `//` é a divisão inteira; somar K-1 antes de dividir por K arredonda
%   para cima.
fixed_queens(easy,   N, Count) :- Count is (N + 3) // 4.    % ceil(N / 4)
fixed_queens(medium, N, Count) :- Count is (N + 7) // 8.    % ceil(N / 8)
fixed_queens(hard,   _, 0).                                  % só pedras

%!  generate_queens(+Size, +Difficulty, -Puzzle, -Goal) is semidet.
%
%   Size entre 6 e 12 (abaixo de 6 não cabe rainha extra com poucas pedras:
%   no 4 x 4, nenhuma combinação de até três pedras aceita cinco rainhas).
%   Difficulty é easy, medium ou hard. Tabuleiros grandes no nível hard
%   demoram alguns segundos.
generate_queens(Size, Difficulty, Puzzle, Goal) :-
    must_be(between(6, 12), Size),
    must_be(oneof([easy, medium, hard]), Difficulty),
    extra_queens(Size, Extra),
    Goal is Size + Extra,
    WallCount is 2 * Extra,
    between(1, 500, _Attempt),                    % outras paredes, se preciso
    random_target(Size, Goal, WallCount, Walls, Target),
    !,
    fixed_queens(Difficulty, Size, FixedCount),
    random_permutation(Target, Shuffled),
    length(Fixed, FixedCount),
    append(Fixed, _, Shuffled),                   % as FixedCount primeiras
    add_rocks(Size, Goal, Target, Fixed, Walls, Rocks),
    puzzle_board(Size, Rocks, Fixed, Puzzle).

%!  random_target(+N, +Goal, +WallCount, -Walls, -Target) is semidet.
%
%   Sorteia WallCount paredes e uma solução aleatória com Goal rainhas.
%   Falha se essas paredes não deixam caber Goal rainhas.
random_target(N, Goal, WallCount, Walls, Target) :-
    all_positions(N, Positions),
    random_permutation(Positions, Shuffled),
    length(Walls, WallCount),
    append(Walls, _, Shuffled),
    puzzle_board(N, Walls, [], Board),
    puzzle_model(Board, Goal, Cells, Vars),
    random_permutation(Vars, Order),
    random_labeling(Order),
    !,
    queen_positions(Cells, Target).

%   random_labeling(+Vars): como labeling/2, mas tenta os valores de cada
%   variável em ordem embaralhada (mesma ideia do gerador de Sudoku).
random_labeling([]).
random_labeling([Var | Vars]) :-
    (   integer(Var)
    ->  true
    ;   fd_dom(Var, Domain),
        findall(V, (V in Domain, indomain(V)), Values),
        random_permutation(Values, Shuffled),
        member(Var, Shuffled)                % ponto de escolha: volta se falhar
    ),
    random_labeling(Vars).

%!  add_rocks(+N, +Goal, +Target, +Fixed, +Rocks0, -Rocks) is det.
%
%   Acrescenta pedras (lista de Linha-Coluna) até Target ser a única solução.
add_rocks(N, Goal, Target, Fixed, Rocks0, Rocks) :-
    puzzle_board(N, Rocks0, Fixed, Puzzle),
    (   another_solution(Puzzle, Goal, Target, Other)
    ->  subtract(Other, Target, Candidates),       % casas que só Other usa
        gentlest_rock(N, Rocks0, Candidates, Rock),
        add_rocks(N, Goal, Target, Fixed, [Rock | Rocks0], Rocks)
    ;   Rocks = Rocks0
    ).

%!  gentlest_rock(+N, +Rocks, +Candidates, -Rock) is det.
%
%   Entre as casas candidatas, sorteia uma das que cortam menos linhas.
%   map_list_to_pairs/3 monta pares Cortes-Casa e keysort/2 os ordena.
gentlest_rock(N, Rocks, Candidates, Rock) :-
    map_list_to_pairs(cuts(N, Rocks), Candidates, Scored),
    keysort(Scored, [Fewest-_ | _]),
    findall(Position, member(Fewest-Position, Scored), Best),
    random_member(Rock, Best).

%!  cuts(+N, +Rocks, +Position, -Cuts) is det.
%
%   Em quantas linhas uma pedra em Position separaria duas casas livres:
%   a casa precisa ter vizinho livre dos dois lados naquela direção. Uma
%   pedra no canto não corta nada; na borda, corta no máximo uma linha.
cuts(N, Rocks, Position, Cuts) :-
    aggregate_all(count,
                  ( member(DR-DC, [0-1, 1-0, 1-1, 1-(-1)]),
                    free_neighbor(N, Rocks, Position, DR-DC),
                    BackR is -DR,
                    BackC is -DC,
                    free_neighbor(N, Rocks, Position, BackR-BackC) ),
                  Cuts).

free_neighbor(N, Rocks, R-C, DR-DC) :-
    R1 is R + DR,
    C1 is C + DC,
    Last is N - 1,
    between(0, Last, R1),
    between(0, Last, C1),
    \+ memberchk(R1-C1, Rocks).

%!  puzzle_board(+N, +Rocks, +Queens, -Board) is det.
%
%   Monta o tabuleiro 0/1/2 com pedras em Rocks, rainhas em Queens e o
%   resto vazio.
puzzle_board(N, Rocks, Queens, Board) :-
    Last is N - 1,
    numlist(0, Last, Indexes),
    findall(Row,
            ( member(R, Indexes),
              findall(Code,
                      ( member(C, Indexes),
                        board_code(R-C, Rocks, Queens, Code) ),
                      Row) ),
            Board).

board_code(Position, Rocks, Queens, Code) :-
    (   memberchk(Position, Rocks)  -> Code = 2
    ;   memberchk(Position, Queens) -> Code = 1
    ;   Code = 0
    ).

all_positions(N, Positions) :-
    Last is N - 1,
    findall(R-C, ( between(0, Last, R), between(0, Last, C) ), Positions).


/* =========================================================================
   4. DICA
   ========================================================================= */

%!  hint_queens(+Board, +Goal, -Result) is det.
%
%   Board é o tabuleiro atual (pistas, pedras e rainhas do jogador). Result:
%
%       [Row, Col]   uma casa, escolhida ao acaso, onde a solução tem uma
%                    rainha que o tabuleiro ainda não tem;
%       complete     todas as rainhas já estão no lugar;
%       unsolvable   as rainhas postas não levam a nenhuma solução.
hint_queens(Board, Goal, Result) :-
    (   solve_queens(Board, Goal, Solution)
    ->  queen_positions(Solution, Needed),
        queen_positions(Board, Placed),
        subtract(Needed, Placed, Missing),
        (   Missing == []
        ->  Result = complete
        ;   random_member(Row-Col, Missing),
            Result = [Row, Col]
        )
    ;   Result = unsolvable
    ).


/* =========================================================================
   5. BACKTRACKING PASSO A PASSO (para a animação)
   =========================================================================

   O solver de cima usa CLP(FD): a propagação corta quase tudo antes de
   tentar, então quase não se VÊ o backtracking. Para a animação usamos uma
   busca "ingênua" (sem CLP(FD)) e anotamos cada passo:

       [coloca,   L, C]   uma rainha foi posta na casa (L, C);
       [conflito, L, C]   a casa (L, C) é atacada, então nem é tentada;
       [remove,   L, C]   o Prolog VOLTOU: a rainha de (L, C) saiu.

   A busca anda pelos TRECHOS DE LINHA (seção 1), da esquerda para a direita
   e de cima para baixo. Cada trecho recebe no máximo uma rainha: o Prolog
   tenta cada casa dele e, se ainda sobrarem trechos suficientes para chegar
   à meta, também tenta deixá-lo vazio. Os trechos que já têm uma pista
   ficam de fora. Sem pedras e com meta N, cada linha é um trecho e não
   sobra nenhum para deixar vazio: é a busca clássica, linha por linha.

   O ataque respeita a regra do jogo: uma rainha só enxerga até a primeira
   pedra (attacks_queen/3).

   O truque está em place_step/2. A disjunção ( true ; ... ) deixa um ponto
   de escolha: na ida, o `true` segue em frente; quando uma linha de baixo
   falha, o Prolog volta até aqui, entra no segundo ramo, anota o "remove"
   e falha de novo, passando para a próxima coluna. Ou seja, quem decide
   quando voltar é o próprio backtracking do Prolog: só o espiamos.

   Por que a anotação não some ao voltar? Porque o backtracking desfaz as
   ligações de variáveis. Por isso os passos vão para fatos dinâmicos
   (assertz/1) e o contador para flag/3, que NÃO são desfeitos.
*/

:- dynamic trace_step/2.        % trace_step(Indice, [Tipo, Linha, Coluna])

%!  trace_queens(+Puzzle, +Goal, +MaxSteps, -Steps, -Status) is det.
%
%   Steps são os passos da busca, na ordem. Status é:
%     * solved     achou Goal rainhas sem ataques (o último estado é a
%                  solução);
%     * unsolvable a busca esgotou todas as opções;
%     * truncated  parou ao chegar em MaxSteps passos.
%   As rainhas fixas (pistas) já começam no tabuleiro e as pedras nunca
%   recebem rainha, como no jogo.
trace_queens(Puzzle, Goal, MaxSteps, Steps, Status) :-
    findall(R-C, ( nth0(R, Puzzle, Row), nth0(C, Row, 2) ), Rocks),
    queen_positions(Puzzle, Given),
    length(Given, GivenCount),
    Need is Goal - GivenCount,
    free_row_segments(Puzzle, Segments),
    retractall(trace_step(_, _)),
    flag(queens_trace, _, 0),
    (   (   Need < 0
        ;   \+ given_consistent(Given, Rocks)
        )
    ->  Status = unsolvable
    ;   catch(( search_segments(Segments, Need, Given, Rocks, [], MaxSteps)
              ->  Status = solved
              ;   Status = unsolvable
              ),
              trace_limit,
              Status = truncated)
    ),
    findall(Step, trace_step(_, Step), Steps),
    retractall(trace_step(_, _)).

%   As pistas não podem se atacar.
given_consistent(Given, Rocks) :-
    \+ ( select(Q1, Given, Rest),
         member(Q2, Rest),
         attacks_queen(Q1, Q2, Rocks) ).

%!  free_row_segments(+Puzzle, -Segments) is det.
%
%   Os trechos de linha que ainda podem receber rainha, em ordem de leitura.
%   Cada trecho é uma lista de casas L-C, da esquerda para a direita. Os
%   trechos que já têm uma pista ficam de fora: neles não cabe outra rainha.
%   Reaproveita segments/2 da seção 1, que corta uma linha nas pedras.
free_row_segments(Puzzle, Segments) :-
    findall(Segment,
            ( nth0(R, Puzzle, Row),
              findall(Cell, ( nth0(C, Row, Code), trace_cell(R-C, Code, Cell) ),
                      Cells),
              segments(Cells, Chunks),
              member(Chunk, Chunks),
              \+ memberchk(given, Chunk),
              msort(Chunk, Segment) ),          % segments/2 inverte a ordem
            Segments).

trace_cell(_,        2, rock).
trace_cell(_,        1, given).
trace_cell(Position, 0, Position).

%!  search_segments(+Segments, +Need, +Given, +Rocks, +Placed, +Max) is nondet.
%
%   Põe mais Need rainhas nos trechos de Segments. Placed são as rainhas já
%   postas pela busca (L-C). Se sobram menos trechos que rainhas, nem tenta:
%   é a poda que faz a busca terminar em tempo de animação.
search_segments(_, 0, _, _, _, _) :- !.
search_segments(Segments, Need, Given, Rocks, Placed, Max) :-
    length(Segments, Left),
    Left >= Need,
    Segments = [Segment | Rest],
    (   member(Position, Segment),            % ponto de escolha: cada casa
        (   safe(Position, Placed, Given, Rocks)
        ->  true
        ;   Position = R-C,
            record_step([conflito, R, C], Max),
            fail
        ),
        place_step(Position, Max),
        Need1 is Need - 1,
        search_segments(Rest, Need1, Given, Rocks, [Position | Placed], Max)
    ;   Left > Need,                          % sobra trecho: este fica vazio
        search_segments(Rest, Need, Given, Rocks, Placed, Max)
    ).

%   A casa é segura se nenhuma rainha posta nem pista a ataca.
safe(Q, Placed, Given, Rocks) :-
    \+ ( member(Other, Placed), attacks_queen(Q, Other, Rocks) ),
    \+ ( member(Other, Given), attacks_queen(Q, Other, Rocks) ).

%!  attacks_queen(+Q1, +Q2, +Rocks) is semidet.
%
%   Q1 ataca Q2: estão na mesma linha, coluna ou diagonal e não há pedra
%   entre elas. Andamos de Q1 em direção a Q2, uma casa por vez.
attacks_queen(R1-C1, R2-C2, Rocks) :-
    (   R1 =:= R2
    ;   C1 =:= C2
    ;   abs(R1 - R2) =:= abs(C1 - C2)
    ),
    !,
    DR is sign(R2 - R1),
    DC is sign(C2 - C1),
    \+ rock_between(R1-C1, R2-C2, DR-DC, Rocks).

rock_between(R-C, Target, DR-DC, Rocks) :-
    R1 is R + DR,
    C1 is C + DC,
    R1-C1 \== Target,
    (   memberchk(R1-C1, Rocks)
    ->  true
    ;   rock_between(R1-C1, Target, DR-DC, Rocks)
    ).

%   Anota "coloca" na ida e "remove" quando o Prolog voltar por aqui.
place_step(Row-Col, Max) :-
    record_step([coloca, Row, Col], Max),
    (   true
    ;   record_step([remove, Row, Col], Max),
        fail
    ).

record_step(Step, Max) :-
    flag(queens_trace, K, K),
    (   K >= Max
    ->  throw(trace_limit)
    ;   K1 is K + 1,
        flag(queens_trace, _, K1),
        assertz(trace_step(K, Step))
    ).


/* =========================================================================
   6. UTILITÁRIOS PARA USO NO TERMINAL
   ========================================================================= */

%   Um puzzle 6x6 para experimentar: meta de 7 rainhas, uma pedra e uma
%   rainha fixa. Tem solução única, e a pedra em (1,3) trabalha dobrado: a
%   linha 1 e a coluna 3 têm DUAS rainhas cada, uma de cada lado dela.
%
%        . . . Q . .
%        Q . . # . Q
%        . . Q . . .
%        . . . . Q .
%        . Q . . . .      <- a pista
%        . . . Q . .
example_queens([[0,0,0,0,0,0],
                [0,0,0,2,0,0],
                [0,0,0,0,0,0],
                [0,0,0,0,0,0],
                [0,1,0,0,0,0],
                [0,0,0,0,0,0]],
               7).

%   print_queens(+Board): `Q` rainha, `#` pedra, `.` vazio.
print_queens(Board) :-
    forall(member(Row, Board),
           ( maplist(format_square, Row), nl )).

format_square(0) :- !, write(' .').
format_square(1) :- !, write(' Q').
format_square(2) :- write(' #').
