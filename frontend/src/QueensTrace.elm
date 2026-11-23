module QueensTrace exposing
    ( Kind(..)
    , Status(..)
    , Step
    , Trace
    , boardAt
    , currentStep
    , length
    , removesUntil
    , status
    , trace
    )

{-| O "filme" do backtracking do Prolog, do lado do Elm.

O backend devolve a lista de passos que a busca deu (veja `trace_queens/4`
em queens.pl). Este módulo é PURO, como o `QueensBoard`: só sabe montar o
tabuleiro de um passo qualquer do filme. Quem decide QUAL passo mostrar (e
quando avançar) é o `Queens.elm`.

A ideia é a mesma do desfazer/refazer: em vez de guardar um tabuleiro por
passo, guardamos o tabuleiro inicial e a lista de passos. O tabuleiro do
passo `i` é o inicial com os `i` primeiros passos aplicados, um `foldl`.

-}

import Array exposing (Array)
import QueensBoard exposing (Board, Origin(..), Position)



-- TIPOS


{-| O que aconteceu num passo da busca.
-}
type Kind
    = Place -- a rainha foi posta na casa
    | Conflict -- a casa é atacada, então o Prolog nem tenta
    | Remove -- o Prolog VOLTOU: a rainha saiu da casa


type alias Step =
    { kind : Kind
    , position : Position
    }


{-| Como a busca terminou.
-}
type Status
    = Solved
    | Unsolvable
    | Truncated -- parou no limite de passos do backend


{-| O filme: o tabuleiro de onde a busca partiu, os passos e o final.

O tipo é opaco (só `trace` cria um), e os passos ficam num `Array` para
pegar o passo `i` sem percorrer a lista.

-}
type Trace
    = Trace
        { start : Board
        , steps : Array Step
        , status : Status
        }


trace : Board -> List Step -> Status -> Trace
trace start steps finalStatus =
    Trace { start = start, steps = Array.fromList steps, status = finalStatus }



-- CONSULTAS


{-| Quantos passos o filme tem.
-}
length : Trace -> Int
length (Trace t) =
    Array.length t.steps


{-| Como a busca terminou.
-}
status : Trace -> Status
status (Trace t) =
    t.status


{-| O tabuleiro depois dos `index` primeiros passos. `boardAt 0` é o
tabuleiro inicial; `boardAt (length t)` é o final. Índices fora do filme são
trazidos para dentro dele.

As rainhas que a busca põe aparecem como `Revealed` (foi o Prolog que pôs).

-}
boardAt : Int -> Trace -> Board
boardAt index (Trace t) =
    t.steps
        |> Array.slice 0 (clamp 0 (Array.length t.steps) index)
        |> Array.foldl apply t.start


apply : Step -> Board -> Board
apply step board =
    case step.kind of
        Place ->
            QueensBoard.placeQueen Revealed step.position board

        Remove ->
            -- toggleQueen tira rainhas reveladas e não mexe em pistas.
            QueensBoard.toggleQueen step.position board

        Conflict ->
            board


{-| O passo que acabou de ser aplicado para chegar ao tabuleiro `index`
(é o que a tela destaca). `Nothing` no começo do filme.
-}
currentStep : Int -> Trace -> Maybe Step
currentStep index (Trace t) =
    Array.get (index - 1) t.steps


{-| Quantas vezes o Prolog voltou atrás nos `index` primeiros passos.
-}
removesUntil : Int -> Trace -> Int
removesUntil index (Trace t) =
    t.steps
        |> Array.slice 0 (max 0 index)
        |> Array.filter (\step -> step.kind == Remove)
        |> Array.length
