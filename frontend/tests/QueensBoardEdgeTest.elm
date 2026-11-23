module QueensBoardEdgeTest exposing (suite)

{-| Casos de borda que complementam os testes de QueensBoardTest.
-}

import Expect
import QueensBoard exposing (Board, Origin(..), Square(..))
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
