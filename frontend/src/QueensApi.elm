module QueensApi exposing
    ( Hint
    , count
    , generate
    , hint
    , solve
    , trace
    )

{-| Comunicação com a parte das Rainhas atrás das pedras do backend.

Mesma ideia do módulo `Api` (do Sudoku): as funções devolvem um `Cmd msg`, uma
DESCRIÇÃO da requisição, e o runtime do Elm a executa. Aproveitamos de lá o
tipo `Difficulty` e o `expectJson`, que já transforma respostas de erro
(`{"detail": "..."}`) em mensagens em português.

Todo pedido leva o tabuleiro E a meta (`goal`): com pedras bloqueando o ataque,
o número de rainhas não é mais o lado do tabuleiro.

-}

import Api exposing (Difficulty, expectJson)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import QueensBoard exposing (Board)
import QueensTrace exposing (Kind(..), Status(..), Step, Trace)


{-| Dica: a linha e a coluna onde vai uma rainha.
-}
type alias Hint =
    { row : Int
    , col : Int
    }


generate : Int -> Difficulty -> (Result String Board -> msg) -> Cmd msg
generate size difficulty toMsg =
    Http.post
        { url = "/api/queens/generate"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "size", Encode.int size )
                    , ( "difficulty", Encode.string (Api.difficultyToString difficulty) )
                    ]
                )
        , expect = expectJson toMsg puzzleDecoder
        }


solve : Board -> (Result String Board -> msg) -> Cmd msg
solve board toMsg =
    Http.post
        { url = "/api/queens/solve"
        , body = Http.jsonBody (encodeBoard board)
        , expect = expectJson toMsg (solutionDecoder (QueensBoard.goal board))
        }


hint : Board -> (Result String Hint -> msg) -> Cmd msg
hint board toMsg =
    Http.post
        { url = "/api/queens/hint"
        , body = Http.jsonBody (encodeBoard board)
        , expect = expectJson toMsg hintDecoder
        }


count : Board -> (Result String Int -> msg) -> Cmd msg
count board toMsg =
    Http.post
        { url = "/api/queens/count"
        , body = Http.jsonBody (encodeBoard board)
        , expect = expectJson toMsg (Decode.field "count" Decode.int)
        }


{-| Pede ao Prolog o passo a passo do backtracking a partir de `board`.
-}
trace : Board -> (Result String Trace -> msg) -> Cmd msg
trace board toMsg =
    Http.post
        { url = "/api/queens/trace"
        , body = Http.jsonBody (encodeBoard board)
        , expect = expectJson toMsg (traceDecoder board)
        }



-- JSON


encodeBoard : Board -> Encode.Value
encodeBoard board =
    Encode.object
        [ ( "board", Encode.list (Encode.list Encode.int) (QueensBoard.toLists board) )
        , ( "goal", Encode.int (QueensBoard.goal board) )
        ]


{-| Lê `{"board": [[...], ...], "goal": 10}`, a resposta do gerador. Se as
linhas não formam um tabuleiro válido (não é quadrado, tem um código
desconhecido, a meta não cabe), o decoder FALHA com a explicação de
`QueensBoard.fromLists`, em vez de produzir um tabuleiro quebrado.
-}
puzzleDecoder : Decoder Board
puzzleDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "goal" Decode.int)
        (Decode.field "board" (Decode.list (Decode.list Decode.int)))
        |> Decode.andThen (\( target, rows ) -> fromResult (QueensBoard.fromLists target rows))


{-| A resposta de "resolver" só traz as linhas; a meta é a do puzzle que
enviamos.
-}
solutionDecoder : Int -> Decoder Board
solutionDecoder target =
    Decode.field "board" (Decode.list (Decode.list Decode.int))
        |> Decode.andThen (\rows -> fromResult (QueensBoard.fromLists target rows))


fromResult : Result String a -> Decoder a
fromResult result =
    case result of
        Ok value ->
            Decode.succeed value

        Err message ->
            Decode.fail message


hintDecoder : Decoder Hint
hintDecoder =
    Decode.map2 Hint
        (Decode.field "row" Decode.int)
        (Decode.field "col" Decode.int)


{-| Lê `{"steps": [["coloca", 0, 1], ...], "status": "solved"}`.
-}
traceDecoder : Board -> Decoder Trace
traceDecoder start =
    Decode.map2 (QueensTrace.trace start)
        (Decode.field "steps" (Decode.list stepDecoder))
        (Decode.field "status" statusDecoder)


{-| Um passo chega como lista de três elementos: [tipo, linha, coluna].
-}
stepDecoder : Decoder Step
stepDecoder =
    Decode.map3 (\kind row col -> Step kind ( row, col ))
        (Decode.index 0 kindDecoder)
        (Decode.index 1 Decode.int)
        (Decode.index 2 Decode.int)


kindDecoder : Decoder Kind
kindDecoder =
    Decode.string
        |> Decode.andThen
            (\name ->
                case name of
                    "coloca" ->
                        Decode.succeed Place

                    "conflito" ->
                        Decode.succeed Conflict

                    "remove" ->
                        Decode.succeed Remove

                    _ ->
                        Decode.fail ("Passo desconhecido: " ++ name)
            )


statusDecoder : Decoder Status
statusDecoder =
    Decode.string
        |> Decode.andThen
            (\name ->
                case name of
                    "solved" ->
                        Decode.succeed Solved

                    "unsolvable" ->
                        Decode.succeed Unsolvable

                    "truncated" ->
                        Decode.succeed Truncated

                    _ ->
                        Decode.fail ("Status desconhecido: " ++ name)
            )
