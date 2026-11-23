module QueensBoardEdgeTest exposing (suite)

{-| Casos de borda que complementam os testes de QueensBoardTest.
-}

import Expect
import QueensBoard exposing (Board, Origin(..), Square(..))
import Set
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "QueensBoard: casos de borda"
        [ test "toLists apaga a origem e fromLists reconstrói toda rainha como Given" <|
            \_ ->
                withBoard puzzle <|
                    \board ->
                        board
                            |> QueensBoard.placeQueen Placed ( 0, 2 )
                            |> QueensBoard.placeQueen Revealed ( 1, 0 )
                            |> Expect.all
                                [ \b ->
                                    QueensBoard.toLists b
                                        |> Expect.equal
                                            [ [ 1, 2, 1, 0 ]
                                            , [ 1, 0, 0, 0 ]
                                            , [ 0, 0, 0, 0 ]
                                            , [ 0, 0, 0, 0 ]
                                            ]
                                , \b ->
                                    withBoard (QueensBoard.toLists b) <|
                                        \restored ->
                                            Expect.all
                                                [ \r -> QueensBoard.squareAt ( 0, 0 ) r |> Expect.equal (Just (Queen Given))
                                                , \r -> QueensBoard.squareAt ( 0, 1 ) r |> Expect.equal (Just Rock)
                                                , \r -> QueensBoard.squareAt ( 0, 2 ) r |> Expect.equal (Just (Queen Given))
                                                , \r -> QueensBoard.squareAt ( 1, 0 ) r |> Expect.equal (Just (Queen Given))
                                                ]
                                                restored
                                ]
        , test "queenCount soma pista, rainha do jogador e rainha revelada" <|
            \_ ->
                withBoard puzzle <|
                    \board ->
                        board
                            |> QueensBoard.placeQueen Placed ( 0, 2 )
                            |> QueensBoard.placeQueen Revealed ( 1, 0 )
                            |> QueensBoard.queenCount
                            |> Expect.equal 3
        , test "pedra em casa livre não impede vitória com quatro rainhas sem ataques" <|
            \_ ->
                withBoard
                    [ [ 2, 1, 0, 0 ]
                    , [ 0, 0, 0, 1 ]
                    , [ 1, 0, 0, 0 ]
                    , [ 0, 0, 1, 0 ]
                    ]
                <|
                    \board ->
                        QueensBoard.isSolved board
                            |> Expect.equal True
        , test "toggleQueen fora do tabuleiro preserva toLists" <|
            \_ ->
                withBoard puzzle <|
                    \board ->
                        board
                            |> QueensBoard.toggleQueen ( 9, 9 )
                            |> QueensBoard.toLists
                            |> Expect.equal (QueensBoard.toLists board)
        , test "revealSolution mantém Revealed quando a solução confirma a rainha" <|
            \_ ->
                withBoard
                    [ [ 0, 1, 0, 0 ]
                    , [ 0, 0, 0, 1 ]
                    , [ 1, 0, 0, 0 ]
                    , [ 0, 0, 1, 0 ]
                    ]
                <|
                    \solution ->
                        QueensBoard.empty 4
                            |> QueensBoard.placeQueen Revealed ( 0, 1 )
                            |> QueensBoard.revealSolution solution
                            |> QueensBoard.squareAt ( 0, 1 )
                            |> Expect.equal (Just (Queen Revealed))
        , test "rainhas na outra diagonal entram ambas em conflicts" <|
            \_ ->
                QueensBoard.empty 4
                    |> QueensBoard.placeQueen Placed ( 0, 3 )
                    |> QueensBoard.placeQueen Placed ( 1, 2 )
                    |> QueensBoard.conflicts
                    |> Expect.equal (Set.fromList [ ( 0, 3 ), ( 1, 2 ) ])
        ]


puzzle : List (List Int)
puzzle =
    [ [ 1, 2, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    , [ 0, 0, 0, 0 ]
    ]


withBoard : List (List Int) -> (Board -> Expect.Expectation) -> Expect.Expectation
withBoard rows check =
    case QueensBoard.fromLists rows of
        Ok board ->
            check board

        Err reason ->
            Expect.fail reason
