/*  test_queens.pl: Testes plunit do jogo N-Rainhas com pedras.

    Para rodar:
        $ swipl -g run_tests -t halt backend/prolog/test_queens.pl

    Vários testes usam números conhecidos do problema clássico: o tabuleiro
    vazio tem 2 soluções com N=4, 4 com N=6 e 92 com N=8. No 8x8, uma rainha
    no canto (0,0) aparece em 4 dessas 92 soluções.
*/

:- use_module(queens).
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(clpfd), [transpose/2]).

%   empty_board(+N, -Board): tabuleiro N x N só com zeros.
empty_board(N, Board) :-
    length(Row, N),
    maplist(=(0), Row),
    length(Board, N),
    maplist(=(Row), Board).

%   set_square(+Board0, +Row, +Col, +Code, -Board): troca uma casa.
%   nth0/4 remove um elemento e devolve o resto; chamado de novo, insere.
set_square(Board0, Row, Col, Code, Board) :-
    nth0(Row, Board0, Line0, OtherLines),
    nth0(Col, Line0, _Old, Rest),
    nth0(Col, Line, Code, Rest),
    nth0(Row, Board, Line, OtherLines).

%   queens_in(+Board, -N): quantas rainhas há no tabuleiro.
queens_in(Board, N) :-
    append(Board, Flat),
    include(==(1), Flat, Queens),
    length(Queens, N).

:- begin_tests(classic).

test(four_queens_has_two_solutions, true(N == 2)) :-
    empty_board(4, B),
    count_queens(B, 100, N).

test(six_queens_has_four_solutions, true(N == 4)) :-
    empty_board(6, B),
    count_queens(B, 100, N).

test(eight_queens_has_92_solutions, true(N == 92)) :-
    empty_board(8, B),
    count_queens(B, 100, N).

test(limit_stops_counting, true(N == 5)) :-
    empty_board(8, B),
    count_queens(B, 5, N).

test(solution_has_one_queen_per_row_and_column) :-
    empty_board(8, B),
    solve_queens(B, S),
    maplist(queens_in_row, S),
    transpose(S, Columns),
    maplist(queens_in_row, Columns).

queens_in_row(Row) :-
    include(==(1), Row, [1]).

:- end_tests(classic).

:- begin_tests(variant).

test(fixed_queen_in_corner, true(N == 4)) :-
    empty_board(8, B0),
    set_square(B0, 0, 0, 1, B),
    count_queens(B, 100, N).

test(rock_removes_solutions, true(N == 88)) :-
    % Pedra em (0,0): some as 4 soluções com rainha no canto (92 - 4).
    empty_board(8, B0),
    set_square(B0, 0, 0, 2, B),
    count_queens(B, 100, N).

test(fixed_queen_decides_solution, true(S == Expected)) :-
    % No 4x4, rainha em (0,1) leva à única solução [1,3,0,2].
    empty_board(4, B0),
    set_square(B0, 0, 1, 1, B),
    solve_queens(B, S),
    Expected = [[0,1,0,0],
                [0,0,0,1],
                [1,0,0,0],
                [0,0,1,0]].

test(rock_is_kept_in_solution, true(S == Expected)) :-
    % Pedra em (0,1) proíbe a primeira solução; sobra [2,0,3,1].
    empty_board(4, B0),
    set_square(B0, 0, 1, 2, B),
    solve_queens(B, S),
    Expected = [[0,2,1,0],
                [1,0,0,0],
                [0,0,0,1],
                [0,1,0,0]].

test(rocks_can_make_puzzle_impossible, fail) :-
    % As duas únicas colunas possíveis da linha 0 (1 e 2) estão bloqueadas.
    empty_board(4, B0),
    set_square(B0, 0, 1, 2, B1),
    set_square(B1, 0, 2, 2, B),
    solve_queens(B, _).

test(two_fixed_queens_in_one_row, fail) :-
    empty_board(4, B0),
    set_square(B0, 0, 0, 1, B1),
    set_square(B1, 0, 3, 1, B),
    solve_queens(B, _).

test(fixed_queens_attacking_each_other, fail) :-
    % (0,0) e (1,1) estão na mesma diagonal.
    empty_board(4, B0),
    set_square(B0, 0, 0, 1, B1),
    set_square(B1, 1, 1, 1, B),
    solve_queens(B, _).

test(non_square_board_is_rejected, fail) :-
    solve_queens([[0,0,0,0], [0,0,0,0]], _).

test(example_puzzle_is_solvable_and_unique, true(N == 1)) :-
    example_queens(P),
    count_queens(P, 2, N).

:- end_tests(variant).

:- begin_tests(generate).

test(unique_solution_small, true(N == 1)) :-
    generate_queens(4, easy, P),
    count_queens(P, 2, N).

test(unique_solution_medium_8, true(N == 1)) :-
    generate_queens(8, medium, P),
    count_queens(P, 2, N).

test(unique_solution_hard_8, true(N == 1)) :-
    generate_queens(8, hard, P),
    count_queens(P, 2, N).

test(board_has_requested_size) :-
    generate_queens(6, easy, P),
    length(P, 6),
    maplist(length_(6), P).

length_(N, List) :- length(List, N).

test(fixed_queens_follow_difficulty_easy, true(N == 2)) :-
    generate_queens(8, easy, P),
    queens_in(P, N).

test(fixed_queens_follow_difficulty_medium, true(N == 1)) :-
    generate_queens(8, medium, P),
    queens_in(P, N).

test(fixed_queens_follow_difficulty_hard, true(N == 0)) :-
    generate_queens(8, hard, P),
    queens_in(P, N).

test(generated_puzzle_is_solvable) :-
    generate_queens(8, hard, P),
    solve_queens(P, S),
    queens_in(S, 8).

test(bad_difficulty, error(_)) :-
    generate_queens(8, impossible, _).

test(size_too_small, error(_)) :-
    generate_queens(3, easy, _).

test(size_too_large, error(_)) :-
    generate_queens(13, easy, _).

:- end_tests(generate).

:- begin_tests(hint).

test(hint_matches_solution, true(Col == Expected)) :-
    example_queens(P),
    hint_queens(P, [Row, Col]),
    solve_queens(P, S),
    nth0(Row, S, SRow),
    nth0(Expected, SRow, 1).

test(hint_is_for_a_row_without_queen) :-
    example_queens(P),
    hint_queens(P, [Row, _]),
    nth0(Row, P, PRow),
    \+ memberchk(1, PRow).

test(complete_board, true(Result == complete)) :-
    example_queens(P),
    solve_queens(P, S),
    hint_queens(S, Result).

test(unsolvable_board, true(Result == unsolvable)) :-
    % Rainha do jogador em (1,0): ataca a pista (0,1) na diagonal.
    example_queens(P),
    set_square(P, 1, 0, 1, B),
    hint_queens(B, Result).

:- end_tests(hint).


:- begin_tests(trace).

%   replay(+Steps, -Queens): aplica os passos e devolve as rainhas que
%   ficaram no tabuleiro (L-C), como a animação faz no Elm.
replay(Steps, Queens) :-
    foldl(apply_step, Steps, [], Queens).

apply_step([coloca, R, C], Qs, [R-C | Qs]).
apply_step([remove, R, C], Qs0, Qs) :- selectchk(R-C, Qs0, Qs).
apply_step([conflito, _, _], Qs, Qs).

test(first_steps_4x4, true(Prefix == [[coloca,0,0], [conflito,1,0], [conflito,1,1], [coloca,1,2]])) :-
    empty_board(4, B),
    trace_queens(B, 1000, Steps, _),
    length(Prefix, 4),
    append(Prefix, _, Steps).

test(backtracks_on_4x4, true(Status == solved)) :-
    % O 4x4 é pequeno, mas já obriga o Prolog a voltar (remove).
    empty_board(4, B),
    trace_queens(B, 1000, Steps, Status),
    memberchk([remove, _, _], Steps).

test(last_state_is_a_solution) :-
    example_queens(P),
    trace_queens(P, 10000, Steps, solved),
    replay(Steps, Placed),
    findall(R-C, ( nth0(R, P, Row), nth0(C, Row, 1) ), Given),
    append(Placed, Given, Queens),
    msort(Queens, Sorted),
    pairs_values(Sorted, Cols),
    solve_queens(P, S),
    findall(C, ( member(Row, S), nth0(C, Row, 1) ), Cols).

test(never_places_on_a_rock) :-
    example_queens(P),
    trace_queens(P, 10000, Steps, _),
    forall(member([coloca, R, C], Steps),
           ( nth0(R, P, Row), nth0(C, Row, Code), Code =\= 2 )).

test(unsolvable_3x3, true(Status == unsolvable)) :-
    empty_board(3, B),
    trace_queens(B, 1000, Steps, Status),
    replay(Steps, []).                  % voltou de tudo: tabuleiro vazio

test(conflicting_clues, true(Steps-Status == []-unsolvable)) :-
    empty_board(4, B0),
    set_square(B0, 0, 0, 1, B1),
    set_square(B1, 2, 2, 1, B),
    trace_queens(B, 1000, Steps, Status).

test(stops_at_limit, true(Len-Status == 10-truncated)) :-
    empty_board(8, B),
    trace_queens(B, 10, Steps, Status),
    length(Steps, Len).

:- end_tests(trace).
