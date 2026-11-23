module QueensApi exposing
    ( Hint
    , count
    , generate
    , hint
    , solve
    , trace
    )

{-| Comunicação com a parte das N-Rainhas do backend.

Mesma ideia do módulo `Api` (do Sudoku): as funções devolvem um `Cmd msg`, uma
DESCRIÇÃO da requisição, e o runtime do Elm a executa. Aproveitamos de lá o
tipo `Difficulty` e o `expectJson`, que já transforma respostas de erro
(`{"detail": "..."}`) em mensagens em português.

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
        , expect = expectJson toMsg boardDecoder
        }


solve : Board -> (Result String Board -> msg) -> Cmd msg
solve board toMsg =
    Http.post
        { url = "/api/queens/solve"
        , body = Http.jsonBody (encodeBoard board)
        , expect = expectJson toMsg boardDecoder
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
        [ ( "board", Encode.list (Encode.list Encode.int) (QueensBoard.toLists board) ) ]


{-| Lê `{"board": [[...], ...]}`. Se a lista de linhas não forma um tabuleiro
válido (não é quadrada, tem um código desconhecido), o decoder FALHA com a
explicação de `QueensBoard.fromLists`, em vez de produzir um tabuleiro
quebrado.
-}
boardDecoder : Decoder Board
boardDecoder =
    Decode.field "board" (Decode.list (Decode.list Decode.int))
        |> Decode.andThen
            (\rows ->
                case QueensBoard.fromLists rows of
                    Ok board ->
                        Decode.succeed board

                    Err message ->
                        Decode.fail message
            )


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
