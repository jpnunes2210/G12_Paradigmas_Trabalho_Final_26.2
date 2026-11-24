module QueensTraceTest exposing (suite)

{-| Testes do QueensTrace: montar o tabuleiro de qualquer passo do filme do
backtracking. Os passos usados aqui são os que o Prolog devolve para o 4x4
vazio (veja test\_queens.pl).
-}

import Expect
import Fuzz
import QueensBoard exposing (Origin(..), Square(..))
import QueensTrace exposing (Kind(..), Status(..), Step)
import Test exposing (Test, describe, fuzz, test)


place : Int -> Int -> Step
place row col =
    Step Place ( row, col )


conflict : Int -> Int -> Step
conflict row col =
    Step Conflict ( row, col )


remove : Int -> Int -> Step
remove row col =
    Step Remove ( row, col )


{-| O começo da busca no 4x4 vazio: põe (0,0) e (1,2), a linha 2 não tem
saída, então o Prolog volta e tira (1,2).
-}
steps4 : List Step
steps4 =
    [ place 0 0
    , conflict 1 0
    , conflict 1 1
    , place 1 2
    , conflict 2 0
    , conflict 2 1
    , conflict 2 2
    , conflict 2 3
    , remove 1 2
    , place 1 3
    ]


film : QueensTrace.Trace
film =
    QueensTrace.trace (QueensBoard.empty 4) steps4 Truncated


queensAt : Int -> List ( Int, Int )
queensAt index =
    QueensTrace.boardAt index film
        |> QueensBoard.squares
        |> List.filter (Tuple.second >> QueensBoard.isQueen)
        |> List.map Tuple.first


suite : Test
suite =
    describe "QueensTrace"
        [ test "o passo 0 é o tabuleiro inicial" <|
            \_ ->
                QueensTrace.boardAt 0 film
                    |> Expect.equal (QueensBoard.empty 4)
        , test "coloca põe uma rainha revelada" <|
            \_ ->
                QueensTrace.boardAt 1 film
                    |> QueensBoard.squareAt ( 0, 0 )
                    |> Expect.equal (Just (Queen Revealed))
        , test "conflito não muda o tabuleiro" <|
            \_ ->
                QueensTrace.boardAt 3 film
                    |> Expect.equal (QueensTrace.boardAt 1 film)
        , test "antes de voltar, há duas rainhas" <|
            \_ ->
                queensAt 8
                    |> Expect.equal [ ( 0, 0 ), ( 1, 2 ) ]
        , test "remove tira a rainha: o Prolog voltou atrás" <|
            \_ ->
                queensAt 9
                    |> Expect.equal [ ( 0, 0 ) ]
        , test "depois de voltar, tenta a próxima coluna" <|
            \_ ->
                queensAt 10
                    |> Expect.equal [ ( 0, 0 ), ( 1, 3 ) ]
        , test "remove não tira pista do puzzle" <|
            \_ ->
                let
                    start =
                        QueensBoard.placeQueen Given ( 0, 1 ) (QueensBoard.empty 4)
                in
                QueensTrace.trace start [ remove 0 1 ] Unsolvable
                    |> QueensTrace.boardAt 1
                    |> Expect.equal start
        , test "currentStep é o último passo aplicado" <|
            \_ ->
                QueensTrace.currentStep 9 film
                    |> Expect.equal (Just (remove 1 2))
        , test "currentStep no começo é Nothing" <|
            \_ ->
                QueensTrace.currentStep 0 film
                    |> Expect.equal Nothing
        , test "conta as voltas atrás até o passo" <|
            \_ ->
                ( QueensTrace.removesUntil 8 film, QueensTrace.removesUntil 10 film )
                    |> Expect.equal ( 0, 1 )
        , fuzz (Fuzz.intRange -20 40) "índices fora do filme ficam dentro dele" <|
            \index ->
                QueensTrace.boardAt index film
                    |> Expect.equal (QueensTrace.boardAt (clamp 0 (List.length steps4) index) film)
        , test "length e status" <|
            \_ ->
                ( QueensTrace.length film, QueensTrace.status film )
                    |> Expect.equal ( 10, Truncated )
        ]
