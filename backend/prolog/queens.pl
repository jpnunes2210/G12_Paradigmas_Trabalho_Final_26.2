/*  queens.pl: N-Rainhas com pedras, em Prolog (CLP(FD)).

    O JOGO
    ------
    Clássico: colocar N rainhas num tabuleiro N x N sem que duas se ataquem
    (nenhum par na mesma linha, coluna ou diagonal).

    A VARIANTE: "RAINHAS COM PEDRAS"
    --------------------------------
    O puzzle já vem com dois tipos de casa preenchida:

        * rainhas fixas (pistas): já estão no lugar certo e não saem dele;
        * pedras: casas bloqueadas, onde NENHUMA rainha pode ser colocada.

    Com isso o puzzle tem solução única, como no Sudoku. O jogador completa o
    resto. As pedras não bloqueiam o ataque entre rainhas: elas só proíbem
    a casa. (Uma extensão natural: pedras que também bloqueiam a linha de
    visão, o que muda as restrições de diagonal.)

    REPRESENTAÇÃO
    -------------
    Um tabuleiro é uma lista com N linhas de N inteiros cada:

        0 = casa vazia      1 = rainha      2 = pedra

    É a forma que o Python (via janus) envia e recebe. Internamente, porém,
    modelamos o problema do jeito clássico do CLP(FD): uma lista Qs de N
    variáveis, onde Qs[i] é a COLUNA da rainha da linha i. Isso já garante,
    por construção, uma rainha por linha.

    COMO TESTAR NO TERMINAL
    -----------------------
        $ swipl backend/prolog/queens.pl
        ?- example_queens(P), solve_queens(P, S), print_queens(S).
        ?- generate_queens(8, medium, P), print_queens(P).
        ?- length(Row, 8), maplist(=(0), Row), length(B, 8), maplist(=(Row), B),
           count_queens(B, 100, N).             % N = 92
*/

% Os nomes exportados têm sufixo `_queens` de propósito: o backend carrega
% sudoku.pl e queens.pl no mesmo processo (janus.consult), e dois módulos
% não podem exportar solve/2 para o mesmo módulo `user`.
:- module(queens,
          [ solve_queens/2,       % +Puzzle, -Solution
            count_queens/3,       % +Puzzle, +Limit, -Count
            generate_queens/3,    % +Size, +Difficulty, -Puzzle
            hint_queens/2,        % +Board, -Result
            example_queens/1,     % -Puzzle
            print_queens/1        % +Board
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(random)).
:- use_module(library(solution_sequences)).   % limit/2


/* =========================================================================
   1. AS REGRAS (restrições)
   ========================================================================= */

%!  queens_constraints(+N, -Qs) is det.
%
%   Qs é uma lista de N variáveis; Qs[i] é a coluna (0..N-1) da rainha da
%   linha i. Impõe as regras clássicas, mas NÃO escolhe valores: só registra
%   as restrições e deixa a propagação do CLP(FD) trabalhar.
queens_constraints(N, Qs) :-
    length(Qs, N),
    Max is N - 1,
    Qs ins 0..Max,
    all_distinct(Qs),             % duas rainhas nunca na mesma coluna
    no_diagonal_attacks(Qs).

%!  no_diagonal_attacks(+Qs) is det.
%
%   Nenhum par de rainhas na mesma diagonal. Compara a primeira rainha com
%   todas as seguintes e recorre na cauda, assim cada par é visto uma vez.
no_diagonal_attacks([]).
no_diagonal_attacks([Q | Qs]) :-
    no_attack(Q, Qs, 1),
    no_diagonal_attacks(Qs).

%   no_attack(+Q, +Qs, +Distance): Q não ataca nenhuma rainha de Qs, onde a
%   primeira de Qs está Distance linhas abaixo de Q. Duas rainhas estão na
%   mesma diagonal quando a diferença das colunas é igual (em módulo) à
%   diferença das linhas; por isso proibimos Q = Q1 + D e Q = Q1 - D.
no_attack(_, [], _).
no_attack(Q, [Q1 | Qs], Distance) :-
    Q #\= Q1 + Distance,
    Q #\= Q1 - Distance,
    Next is Distance + 1,
    no_attack(Q, Qs, Next).

%!  puzzle_model(+Puzzle, -Qs) is semidet.
%
%   Liga o tabuleiro (formato 0/1/2) ao modelo: além das regras clássicas,
%   cada linha impõe as suas rainhas fixas e as suas pedras. Falha se o
%   tabuleiro já for contraditório (por exemplo, duas rainhas fixas na mesma
%   linha).
puzzle_model(Puzzle, Qs) :-
    length(Puzzle, N),
    maplist(same_length(Puzzle), Puzzle),     % tabuleiro quadrado
    queens_constraints(N, Qs),
    maplist(row_constraints, Puzzle, Qs).

%   row_constraints(+Row, ?Q): o que a linha Row diz sobre a coluna Q.
row_constraints(Row, Q) :-
    findall(RockCol, nth0(RockCol, Row, 2), RockCols),
    maplist(not_in_column(Q), RockCols),      % pedra: a rainha não pode ficar aí
    findall(QueenCol, nth0(QueenCol, Row, 1), QueenCols),
    (   QueenCols == []     -> true           % linha livre
    ;   QueenCols = [Fixed] -> Q #= Fixed     % rainha já posta: coluna decidida
    ;   fail                                  % duas rainhas na mesma linha
    ).

not_in_column(Q, Col) :- Q #\= Col.


/* =========================================================================
   2. RESOLVER E CONTAR
   ========================================================================= */

%!  solve_queens(+Puzzle, -Solution) is semidet.
%
%   Solution é Puzzle com todas as rainhas no lugar (as pedras continuam).
%   Falha se não há solução.
solve_queens(Puzzle, Solution) :-
    puzzle_model(Puzzle, Qs),
    labeling([ff], Qs),           % `ff` (first fail): variável de menor domínio
    !,                            % só queremos a primeira solução
    solution_board(Puzzle, Qs, Solution).

%!  solution_board(+Puzzle, +Qs, -Board) is det.
%
%   Desenha as colunas Qs (já inteiros) no formato 0/1/2, preservando as
%   pedras do puzzle.
solution_board(Puzzle, Qs, Board) :-
    maplist(solution_row, Puzzle, Qs, Board).

solution_row(PuzzleRow, QueenCol, Row) :-
    length(PuzzleRow, N),
    Last is N - 1,
    numlist(0, Last, Cols),
    maplist(solution_cell(QueenCol), Cols, PuzzleRow, Row).

%   Se -> Então ; Senão encadeado: rainha, ou pedra herdada, ou vazio.
solution_cell(QueenCol, Col, Old, New) :-
    (   QueenCol =:= Col -> New = 1
    ;   Old =:= 2        -> New = 2
    ;   New = 0
    ).

%!  count_queens(+Puzzle, +Limit, -Count) is det.
%
%   Quantas soluções Puzzle tem, contando no máximo até Limit.
count_queens(Puzzle, Limit, Count) :-
    findall(x,
            limit(Limit, ( puzzle_model(Puzzle, Qs),
                           labeling([ff], Qs) )),
            Found),
    length(Found, Count).

%!  another_solution(+Puzzle, +Target, -Other) is semidet.
%
%   Other (lista de colunas) é uma solução de Puzzle DIFERENTE de Target (a
%   solução que o gerador tem em mente). Falha se Target é a única.
%
%   A restrição "diferente" é declarada por reificação: para cada linha,
%   B_i #<==> (Q_i #\= T_i) vale 1 quando a rainha da linha i está em outra
%   coluna que em Target. Exigir soma >= 1 diz "difere em pelo menos uma
%   linha".
another_solution(Puzzle, Target, Qs) :-
    puzzle_model(Puzzle, Qs),
    maplist(differs, Qs, Target, Diffs),
    sum(Diffs, #>=, 1),
    labeling([ff], Qs),
    !.

differs(Q, T, B) :- B #<==> (Q #\= T).

%   unique_solution(+Puzzle, +Target): Target é a única solução de Puzzle.
unique_solution(Puzzle, Target) :-
    \+ another_solution(Puzzle, Target, _).


/* =========================================================================
   3. GERADOR
   =========================================================================

   Queremos um puzzle com SOLUÇÃO ÚNICA. Em três etapas:

   (a) sortear uma solução completa (Target) do tabuleiro vazio;
   (b) manter algumas rainhas dela como pistas (quantas depende da
       dificuldade: menos pistas, mais pedras e mais difícil; no nível
       `hard` não há rainha nenhuma, só pedras);
   (c) enquanto o puzzle tiver outra solução além de Target, pegar uma
       dessas soluções e colocar uma PEDRA numa casa dela que Target não
       usa. Essa pedra elimina aquela solução e nunca prejudica Target.
       Como cada pedra elimina pelo menos uma solução, o laço termina.

   Por fim, tentamos devolver cada pedra à origem: se o puzzle continua com
   solução única sem ela, ela era desnecessária (ficou redundante por causa
   das pedras que vieram depois) e some.
*/

%   fixed_queens(+Difficulty, +N, -Count): quantas rainhas ficam como pista.
%   Quanto menos pistas, mais pedras o gerador precisa para garantir solução
%   única, e mais difícil fica. `//` é a divisão inteira; somar K-1 antes de
%   dividir por K arredonda para cima.
fixed_queens(easy,   N, Count) :- Count is (N + 3) // 4.    % ceil(N / 4)
fixed_queens(medium, N, Count) :- Count is (N + 7) // 8.    % ceil(N / 8)
fixed_queens(hard,   _, 0).                                  % só pedras

%!  generate_queens(+Size, +Difficulty, -Puzzle) is det.
%
%   Size entre 4 e 12; Difficulty é easy, medium ou hard. Tabuleiros grandes
%   no nível hard (10 ou mais) precisam de dezenas de pedras e demoram mais.
generate_queens(Size, Difficulty, Puzzle) :-
    must_be(between(4, 12), Size),
    must_be(oneof([easy, medium, hard]), Difficulty),
    fixed_queens(Difficulty, Size, FixedCount),
    random_solution(Size, Target),
    Last is Size - 1,
    numlist(0, Last, Rows),
    random_permutation(Rows, Shuffled),
    length(FixedRows, FixedCount),
    append(FixedRows, _, Shuffled),                   % as FixedCount primeiras
    add_rocks(Size, Target, FixedRows, [], Rocks0),
    prune_rocks(Size, Target, FixedRows, Rocks0, Rocks),
    puzzle_board(Size, Target, FixedRows, Rocks, Puzzle),
    !.

%!  random_solution(+N, -Cols) is det.
%
%   Uma solução aleatória do tabuleiro vazio, como lista de colunas.
random_solution(N, Qs) :-
    queens_constraints(N, Qs),
    random_labeling(Qs),
    !.

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

%!  add_rocks(+N, +Target, +FixedRows, +Rocks0, -Rocks) is det.
%
%   Acrescenta pedras (lista de Linha-Coluna) até Target ser a única solução.
add_rocks(N, Target, FixedRows, Rocks0, Rocks) :-
    puzzle_board(N, Target, FixedRows, Rocks0, Puzzle),
    (   another_solution(Puzzle, Target, Other)
    ->  random_rock(Other, Target, Rock),
        add_rocks(N, Target, FixedRows, [Rock | Rocks0], Rocks)
    ;   Rocks = Rocks0
    ).

%   random_rock(+Other, +Target, -Row-Col): uma casa onde Other tem rainha e
%   Target não. Existe sempre, pois Other difere de Target.
random_rock(Other, Target, Rock) :-
    findall(Row-Col,
            ( nth0(Row, Other, Col),
              nth0(Row, Target, TargetCol),
              Col =\= TargetCol ),
            Candidates),
    random_member(Rock, Candidates).

%!  prune_rocks(+N, +Target, +FixedRows, +Rocks0, -Rocks) is det.
prune_rocks(N, Target, FixedRows, Rocks0, Rocks) :-
    prune_rocks_(Rocks0, [], N, Target, FixedRows, Rocks).

prune_rocks_([], Kept, _, _, _, Kept).
prune_rocks_([Rock | Rest], Kept, N, Target, FixedRows, Rocks) :-
    append(Kept, Rest, Without),                       % tudo, menos Rock
    puzzle_board(N, Target, FixedRows, Without, Puzzle),
    (   unique_solution(Puzzle, Target)
    ->  Next = Kept                                    % desnecessária: descarta
    ;   Next = [Rock | Kept]
    ),
    prune_rocks_(Rest, Next, N, Target, FixedRows, Rocks).

%!  puzzle_board(+N, +Target, +FixedRows, +Rocks, -Board) is det.
%
%   Monta o tabuleiro 0/1/2: pedras onde Rocks manda; rainhas de Target só
%   nas linhas de FixedRows; o resto vazio.
puzzle_board(N, Target, FixedRows, Rocks, Board) :-
    Last is N - 1,
    numlist(0, Last, Indexes),
    findall(Row,
            ( member(R, Indexes),
              findall(Code,
                      ( member(C, Indexes),
                        board_cell(R-C, Target, FixedRows, Rocks, Code) ),
                      Row) ),
            Board).

board_cell(R-C, Target, FixedRows, Rocks, Code) :-
    (   memberchk(R-C, Rocks)
    ->  Code = 2
    ;   memberchk(R, FixedRows), nth0(R, Target, C)
    ->  Code = 1
    ;   Code = 0
    ).


/* =========================================================================
   4. DICA
   ========================================================================= */

%!  hint_queens(+Board, -Result) is det.
%
%   Board é o tabuleiro atual (pistas, pedras e rainhas do jogador). Result:
%
%       [Row, Col]   uma linha ainda sem rainha, escolhida ao acaso, e a
%                    coluna onde a rainha dela fica na solução;
%       complete     todas as rainhas já estão no lugar;
%       unsolvable   as rainhas postas não levam a nenhuma solução.
hint_queens(Board, Result) :-
    (   solve_queens(Board, Solution)
    ->  rows_without_queen(Board, Rows),
        (   Rows == []
        ->  Result = complete
        ;   random_member(Row, Rows),
            nth0(Row, Solution, SolutionRow),
            once(nth0(Col, SolutionRow, 1)),
            Result = [Row, Col]
        )
    ;   Result = unsolvable
    ).

rows_without_queen(Board, Rows) :-
    findall(R, ( nth0(R, Board, Row), \+ memberchk(1, Row) ), Rows).


/* =========================================================================
   5. UTILITÁRIOS PARA USO NO TERMINAL
   ========================================================================= */

%   Um puzzle 6x6 para experimentar (rainha fixa na linha 0 e duas pedras).
example_queens([[0,1,0,0,0,0],
                [0,0,0,0,0,0],
                [0,0,0,0,0,0],
                [0,0,0,0,0,0],
                [0,0,0,0,0,0],
                [2,0,0,0,0,2]]).

%   print_queens(+Board): `Q` rainha, `#` pedra, `.` vazio.
print_queens(Board) :-
    forall(member(Row, Board),
           ( maplist(format_square, Row), nl )).

format_square(0) :- !, write(' .').
format_square(1) :- !, write(' Q').
format_square(2) :- write(' #').