module QueensBoardTest exposing (suite)

{-| Testes do tabuleiro de N-Rainhas.

`QueensBoard` é puro: estas asserções não sobem servidor nem abrem o
navegador. Elas travam as regras que o jogador vê na hora (ataque, pedra,
pista, revelação) e o formato que vai e volta da API.

-}

import Expect
import QueensBoard exposing (Board, Origin(..), Square(..))
import Set
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "QueensBoard"
        [ describe "construção" construction
        , describe "jogadas" moves
        , describe "regras" rules
        , describe "solução revelada" revealed
        ]



-- CONSTRUÇÃO


construction : List Test
construction =
    [ test "empty cria só casas livres" <|
        \_ ->
            QueensBoard.empty 4
                |> Expect.all
                    [ \board -> QueensBoard.size board |> Expect.equal 4
                    , \board -> QueensBoard.squares board |> List.length |> Expect.equal 16
                    , \board -> QueensBoard.queenCount board |> Expect.equal 0
                    , \board -> QueensBoard.isSolved board |> Expect.equal False
                    , \board ->
                        QueensBoard.squares board
                            |> List.map Tuple.first
                            |> Expect.equal
                                (List.concatMap
                                    (\row -> List.map (\col -> ( row, col )) (List.range 0 3))
                                    (List.range 0 3)
                                )
                    , \board -> QueensBoard.toLists board |> Expect.equal (blank 4)
                    ]
    , test "fromLists distingue livre, pista e pedra" <|
        \_ ->
            withBoard puzzle <|
                \board ->
                    Expect.all
                        [ expectSquare ( 0, 0 ) (Queen Given)
                        , expectSquare ( 0, 1 ) Rock
                        , expectSquare ( 0, 2 ) Free
                        , \b -> QueensBoard.hasRevealed b |> Expect.equal False
                        , \b -> QueensBoard.toLists b |> Expect.equal puzzle
                        ]
                        board
    , test "fromLists recusa lado menor que 4" <|
        \_ ->
            QueensBoard.fromLists (blank 3)
                |> Expect.equal (Err "Tabuleiro com formato inválido.")
    , test "fromLists recusa linha com tamanho errado" <|
        \_ ->
            QueensBoard.fromLists
                [ [ 0, 0, 0, 0 ]
                , [ 0, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                ]
                |> Expect.equal (Err "Tabuleiro com formato inválido.")
    , test "fromLists recusa código desconhecido" <|
        \_ ->
            QueensBoard.fromLists
                [ [ 0, 0, 0, 9 ]
                , [ 0, 0, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                ]
                |> Expect.equal (Err "Código de casa desconhecido: 9")
    , test "casa fora do tabuleiro não existe" <|
        \_ ->
            QueensBoard.squareAt ( 4, 0 ) (QueensBoard.empty 4)
                |> Expect.equal Nothing
    , test "isQueen reconhece qualquer origem" <|
        \_ ->
            Expect.all
                [ \() -> QueensBoard.isQueen (Queen Given) |> Expect.equal True
                , \() -> QueensBoard.isQueen (Queen Placed) |> Expect.equal True
                , \() -> QueensBoard.isQueen (Queen Revealed) |> Expect.equal True
                , \() -> QueensBoard.isQueen Free |> Expect.equal False
                , \() -> QueensBoard.isQueen Rock |> Expect.equal False
                ]
                ()
    ]



-- JOGADAS


moves : List Test
moves =
    [ test "placeQueen só ocupa casa livre e conta toda rainha como 1" <|
        \_ ->
            withBoard puzzle <|
                \board ->
                    board
                        |> QueensBoard.placeQueen Placed ( 0, 2 )
                        |> QueensBoard.placeQueen Revealed ( 0, 0 )
                        |> QueensBoard.placeQueen Placed ( 0, 1 )
                        |> QueensBoard.placeQueen Placed ( 9, 9 )
                        |> Expect.all
                            [ expectSquare ( 0, 2 ) (Queen Placed)
                            , expectSquare ( 0, 0 ) (Queen Given)
                            , expectSquare ( 0, 1 ) Rock
                            , \b ->
                                QueensBoard.toLists b
                                    |> Expect.equal
                                        [ [ 1, 2, 1, 0 ]
                                        , [ 0, 0, 0, 0 ]
                                        , [ 0, 0, 0, 0 ]
                                        , [ 0, 0, 0, 0 ]
                                        ]
                            ]
    , test "toggle coloca e tira rainha do jogador" <|
        \_ ->
            withBoard puzzle <|
                \board ->
                    board
                        |> QueensBoard.toggleQueen ( 0, 2 )
                        |> Expect.all
                            [ expectSquare ( 0, 2 ) (Queen Placed)
                            , \b ->
                                QueensBoard.toggleQueen ( 0, 2 ) b
                                    |> expectSquare ( 0, 2 ) Free
                            ]
    , test "toggle tira rainha revelada e não mexe em pista nem pedra" <|
        \_ ->
            withBoard puzzle <|
                \board ->
                    board
                        |> QueensBoard.placeQueen Revealed ( 1, 0 )
                        |> QueensBoard.toggleQueen ( 1, 0 )
                        |> QueensBoard.toggleQueen ( 0, 0 )
                        |> QueensBoard.toggleQueen ( 0, 1 )
                        |> Expect.all
                            [ expectSquare ( 1, 0 ) Free
                            , expectSquare ( 0, 0 ) (Queen Given)
                            , expectSquare ( 0, 1 ) Rock
                            ]
    , test "clearPlaced deixa só o puzzle original" <|
        \_ ->
            withBoard puzzle <|
                \board ->
                    board
                        |> QueensBoard.placeQueen Placed ( 0, 2 )
                        |> QueensBoard.placeQueen Revealed ( 1, 0 )
                        |> QueensBoard.clearPlaced
                        |> Expect.all
                            [ expectSquare ( 0, 0 ) (Queen Given)
                            , expectSquare ( 0, 1 ) Rock
                            , expectSquare ( 0, 2 ) Free
                            , expectSquare ( 1, 0 ) Free
                            , \b -> QueensBoard.toLists b |> Expect.equal puzzle
                            ]
    ]



-- REGRAS


rules : List Test
rules =
    [ test "uma rainha sozinha não está em conflito nem se ameaça" <|
        \_ ->
            withBoard
                [ [ 1, 0, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                ]
            <|
                \board ->
                    Expect.all
                        [ \b -> QueensBoard.conflicts b |> Expect.equal Set.empty
                        , \b -> Set.member ( 0, 0 ) (QueensBoard.threatened b) |> Expect.equal False
                        , \b -> QueensBoard.isSolved b |> Expect.equal False
                        ]
                        board
    , test "rainhas na mesma linha, coluna ou diagonal entram em conflito" <|
        \_ ->
            Expect.all
                [ \() -> expectConflicts rowPair [ ( 0, 0 ), ( 0, 3 ) ]
                , \() -> expectConflicts sameColumn [ ( 0, 1 ), ( 3, 1 ) ]
                , \() -> expectConflicts sameDiagonal [ ( 0, 0 ), ( 2, 2 ) ]
                ]
                ()
    , test "pedra não bloqueia o ataque" <|
        \_ ->
            expectConflicts rockBetween [ ( 0, 0 ), ( 0, 3 ) ]
    , test "casas ameaçadas são a linha, a coluna e as diagonais da rainha" <|
        \_ ->
            withBoard
                [ [ 0, 0, 0, 0 ]
                , [ 0, 1, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                , [ 0, 0, 0, 0 ]
                ]
            <|
                \board ->
                    QueensBoard.threatened board
                        |> Expect.equal
                            (Set.fromList
                                [ ( 0, 0 )
                                , ( 0, 1 )
                                , ( 0, 2 )
                                , ( 1, 0 )
                                , ( 1, 2 )
                                , ( 1, 3 )
                                , ( 2, 0 )
                                , ( 2, 1 )
                                , ( 2, 2 )
                                , ( 3, 1 )
                                , ( 3, 3 )
                                ]
                            )
    , test "está resolvido só com N rainhas e nenhum ataque" <|
        \_ ->
            Expect.all
                [ \() ->
                    withBoard solution4 <|
                        \board ->
                            Expect.all
                                [ \b -> QueensBoard.queenCount b |> Expect.equal 4
                                , \b -> QueensBoard.conflicts b |> Expect.equal Set.empty
                                , \b -> QueensBoard.isSolved b |> Expect.equal True
                                ]
                                board
                , \() ->
                    withBoard threeQueens <|
                        \board -> QueensBoard.isSolved board |> Expect.equal False
                , \() ->
                    withBoard sameRow <|
                        \board ->
                            Expect.all
                                [ \b -> QueensBoard.queenCount b |> Expect.equal 4
                                , \b -> QueensBoard.isSolved b |> Expect.equal False
                                ]
                                board
                ]
                ()
    ]



-- SOLUÇÃO REVELADA


revealed : List Test
revealed =
    [ test "revealSolution preserva pista e pedra, confirma o acerto e revela o resto" <|
        \_ ->
            withBoard puzzle <|
                \board ->
                    withBoard overlay <|
                        \solution ->
                            board
                                |> QueensBoard.placeQueen Placed ( 1, 0 )
                                |> QueensBoard.placeQueen Placed ( 2, 2 )
                                |> QueensBoard.placeQueen Revealed ( 2, 0 )
                                |> QueensBoard.revealSolution solution
                                |> Expect.all
                                    [ expectSquare ( 0, 0 ) (Queen Given)
                                    , expectSquare ( 0, 1 ) Rock
                                    , expectSquare ( 1, 0 ) (Queen Placed)
                                    , expectSquare ( 2, 2 ) Free
                                    , expectSquare ( 2, 0 ) Free
                                    , expectSquare ( 3, 2 ) (Queen Revealed)
                                    , \b -> QueensBoard.hasRevealed b |> Expect.equal True
                                    ]
    , test "clearPlaced depois da revelação volta ao puzzle" <|
        \_ ->
            withBoard puzzle <|
                \board ->
                    withBoard overlay <|
                        \solution ->
                            board
                                |> QueensBoard.placeQueen Placed ( 1, 0 )
                                |> QueensBoard.revealSolution solution
                                |> QueensBoard.clearPlaced
                                |> Expect.all
                                    [ \b -> QueensBoard.toLists b |> Expect.equal puzzle
                                    , \b -> QueensBoard.hasRevealed b |> Expect.equal False
                                    ]
    ]



-- TABULEIROS DE EXEMPLO
--
-- 0 = livre, 1 = rainha, 2 = pedra. O lado mínimo aceito por `fromLists` é 4.


puzzle : List (List Int)
puzzle =
    [ [ 1, 2, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    ]


{-| Solução clássica de 4 rainhas: colunas 1, 3, 0, 2.
-}
solution4 : List (List Int)
solution4 =
    [ [ 0, 1, 0, 0 ]
    , [ 0, 0, 0, 1 ]
    , [ 1, 0, 0, 0 ]
    , [ 0, 0, 1, 0 ]
    ]


{-| As três primeiras rainhas da solução: sem ataque, mas ainda não são N.
-}
threeQueens : List (List Int)
threeQueens =
    [ [ 0, 1, 0, 0 ]
    , [ 0, 0, 0, 1 ]
    , [ 1, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    ]


sameRow : List (List Int)
sameRow =
    [ [ 1, 1, 1, 1 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    ]


rowPair : List (List Int)
rowPair =
    [ [ 1, 0, 0, 1 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    ]


sameColumn : List (List Int)
sameColumn =
    [ [ 0, 1, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 1, 0, 0 ]
    ]


sameDiagonal : List (List Int)
sameDiagonal =
    [ [ 1, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 1, 0 ]
    , [ 0, 0, 0, 0 ]
    ]


rockBetween : List (List Int)
rockBetween =
    [ [ 1, 2, 2, 1 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    ]


{-| O que o Prolog devolveria por cima de `puzzle`: confirma (1, 0),
revela (3, 2) e não confirma a rainha errada em (2, 2).
-}
overlay : List (List Int)
overlay =
    [ [ 1, 0, 0, 0 ]
    , [ 1, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 1, 0 ]
    ]


blank : Int -> List (List Int)
blank side =
    List.repeat side (List.repeat side 0)



-- AJUDANTES


withBoard : List (List Int) -> (Board -> Expect.Expectation) -> Expect.Expectation
withBoard rows check =
    case QueensBoard.fromLists rows of
        Ok board ->
            check board

        Err reason ->
            Expect.fail reason


expectSquare : QueensBoard.Position -> Square -> Board -> Expect.Expectation
expectSquare position expected board =
    QueensBoard.squareAt position board
        |> Expect.equal (Just expected)


expectConflicts : List (List Int) -> List QueensBoard.Position -> Expect.Expectation
expectConflicts rows expected =
    withBoard rows <|
        \board ->
            QueensBoard.conflicts board
                |> Expect.equal (Set.fromList expected)
