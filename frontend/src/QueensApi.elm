module QueensApi exposing
    ( Hint
    , count
    , generate
    , hint
    , solve
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
