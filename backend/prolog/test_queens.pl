/*  test_queens.pl: Testes plunit de "Rainhas atrás das pedras".

    Para rodar:
        $ swipl -g run_tests -t halt backend/prolog/test_queens.pl

    Sem pedras e com meta N, o jogo é o clássico das N rainhas. Por isso
    vários testes usam números conhecidos: o tabuleiro vazio tem 2 soluções
    com N=4, 4 com N=6 e 92 com N=8. No 8x8, uma rainha no canto (0,0)
    aparece em 4 dessas 92 soluções.
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

%   squares_in(+Code, +Board, -N): quantas casas com Code há no tabuleiro.
squares_in(Code, Board, N) :-
    append(Board, Flat),
    include(==(Code), Flat, Found),
    length(Found, N).

%   Solução única de example_queens/2.
example_solution([[0,0,0,1,0,0],
                  [1,0,0,2,0,1],
                  [0,0,1,0,0,0],
                  [0,0,0,0,1,0],
                  [0,1,0,0,0,0],
                  [0,0,0,1,0,0]]).

:- begin_tests(classic).

test(four_queens_has_two_solutions, true(N == 2)) :-
    empty_board(4, B),
    count_queens(B, 4, 100, N).

test(six_queens_has_four_solutions, true(N == 4)) :-
    empty_board(6, B),
    count_queens(B, 6, 100, N).

test(eight_queens_has_92_solutions, true(N == 92)) :-
    empty_board(8, B),
    count_queens(B, 8, 100, N).

test(limit_stops_counting, true(N == 5)) :-
    empty_board(8, B),
    count_queens(B, 8, 5, N).

test(no_room_for_n_plus_one_without_rocks, true(N == 0)) :-
    empty_board(6, B),
    count_queens(B, 7, 100, N).

test(solution_has_one_queen_per_row_and_column) :-
    empty_board(8, B),
    solve_queens(B, 8, S),
    maplist(one_queen, S),
    transpose(S, Columns),
    maplist(one_queen, Columns).

one_queen(Row) :-
    include(==(1), Row, [1]).

:- end_tests(classic).

:- begin_tests(rocks).

test(rock_blocks_the_row, true(N == 1)) :-
    % Rainhas em (0,0) e (0,2) com pedra entre elas. O resto do 4x4 é
    % pedra, para isolar a linha 0.
    B = [[1,2,1,0],
         [2,2,2,2],
         [2,2,2,2],
         [2,2,2,2]],
    count_queens(B, 2, 100, N).

test(queens_without_rock_between_attack, fail) :-
    B = [[1,0,1,0],
         [2,2,2,2],
         [2,2,2,2],
         [2,2,2,2]],
    solve_queens(B, 2, _).

test(rock_blocks_the_column_and_diagonals, true(N == 1)) :-
    % Quatro rainhas que se veriam numa grade sem pedras: as linhas e as
    % colunas são cortadas pelas pedras de borda, e as duas diagonais,
    % (0,0)-(2,2) e (0,2)-(2,0), pela pedra em (1,1).
    B = [[1,2,1,2],
         [2,2,2,2],
         [1,2,1,2],
         [2,2,2,2]],
    fail_unless_blocked(B),
    count_queens(B, 4, 100, N).

%   Sem a pedra central as mesmas quatro rainhas se atacam.
fail_unless_blocked(B) :-
    set_square(B, 1, 1, 0, Open),
    \+ solve_queens(Open, 4, _).

test(rock_in_corner_removes_solutions, true(N == 88)) :-
    % Pedra no canto não corta linha nenhuma: só some as 4 soluções que
    % usavam a casa (92 - 4).
    empty_board(8, B0),
    set_square(B0, 0, 0, 2, B),
    count_queens(B, 8, 100, N).

test(rock_makes_room_for_extra_queen, true(N > 0)) :-
    % No 6x6 vazio não cabem 7 rainhas; com a pedra em (1,3), cabem.
    empty_board(6, B0),
    set_square(B0, 1, 3, 2, B),
    count_queens(B, 7, 100, N).

test(fixed_queen_in_corner, true(N == 4)) :-
    empty_board(8, B0),
    set_square(B0, 0, 0, 1, B),
    count_queens(B, 8, 100, N).

test(fixed_queens_attacking_each_other, fail) :-
    % (0,0) e (1,1) estão na mesma diagonal, sem pedra entre elas.
    empty_board(4, B0),
    set_square(B0, 0, 0, 1, B1),
    set_square(B1, 1, 1, 1, B),
    solve_queens(B, 4, _).

test(rock_is_kept_in_solution, true(Rocks == 1)) :-
    example_queens(P, G),
    solve_queens(P, G, S),
    squares_in(2, S, Rocks).

test(non_square_board_is_rejected, fail) :-
    solve_queens([[0,0,0,0], [0,0,0,0]], 2, _).

test(example_has_unique_solution, true(S == Expected)) :-
    example_queens(P, G),
    count_queens(P, G, 2, 1),
    solve_queens(P, G, S),
    example_solution(Expected).

test(example_needs_its_clue, true(N == 2)) :-
    % Sem a rainha fixa em (4,1) o exemplo tem duas soluções.
    example_queens(P0, G),
    set_square(P0, 4, 1, 0, P),
    count_queens(P, G, 100, N).

:- end_tests(rocks).

:- begin_tests(generate).

test(unique_solution_easy_6, true(N == 1)) :-
    generate_queens(6, easy, P, G),
    count_queens(P, G, 2, N).

test(unique_solution_medium_8, true(N == 1)) :-
    generate_queens(8, medium, P, G),
    count_queens(P, G, 2, N).

test(unique_solution_hard_8, true(N == 1)) :-
    generate_queens(8, hard, P, G),
    count_queens(P, G, 2, N).

test(goal_is_larger_than_n, true(G > 8)) :-
    generate_queens(8, easy, _, G).

test(board_has_requested_size) :-
    generate_queens(6, easy, P, _),
    length(P, 6),
    maplist(length_(6), P).

length_(N, List) :- length(List, N).

test(fixed_queens_follow_difficulty_easy, true(N == 2)) :-
    generate_queens(8, easy, P, _),
    squares_in(1, P, N).

test(fixed_queens_follow_difficulty_medium, true(N == 1)) :-
    generate_queens(8, medium, P, _),
    squares_in(1, P, N).

test(fixed_queens_follow_difficulty_hard, true(N == 0)) :-
    generate_queens(8, hard, P, _),
    squares_in(1, P, N).

test(generated_puzzle_reaches_goal, true(N == G)) :-
    generate_queens(8, hard, P, G),
    solve_queens(P, G, S),
    squares_in(1, S, N).

test(generated_solution_needs_the_rocks, true(Row > 1)) :-
    % Meta maior que N: alguma linha da solução tem duas rainhas.
    generate_queens(6, medium, P, G),
    solve_queens(P, G, S),
    maplist([Line, Count]>>squares_in(1, [Line], Count), S, Counts),
    max_list(Counts, Row).

test(bad_difficulty, error(_)) :-
    generate_queens(8, impossible, _, _).

test(size_too_small, error(_)) :-
    generate_queens(5, easy, _, _).

test(size_too_large, error(_)) :-
    generate_queens(13, easy, _, _).

:- end_tests(generate).

:- begin_tests(hint).

test(hint_matches_solution) :-
    example_queens(P, G),
    hint_queens(P, G, [Row, Col]),
    example_solution(S),
    nth0(Row, S, SRow),
    nth0(Col, SRow, 1).

test(hint_is_for_an_empty_square) :-
    example_queens(P, G),
    hint_queens(P, G, [Row, Col]),
    nth0(Row, P, PRow),
    nth0(Col, PRow, 0).

test(complete_board, true(Result == complete)) :-
    example_solution(S),
    hint_queens(S, 7, Result).

test(unsolvable_board, true(Result == unsolvable)) :-
    % Rainha do jogador em (3,0): ataca a pista (4,1) na diagonal.
    example_queens(P, G),
    set_square(P, 3, 0, 1, B),
    hint_queens(B, G, Result).

:- end_tests(hint).
