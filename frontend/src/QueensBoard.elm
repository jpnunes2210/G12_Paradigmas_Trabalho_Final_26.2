module QueensBoard exposing
    ( Board
    , Origin(..)
    , Position
    , Square(..)
    , clearPlaced
    , conflicts
    , empty
    , fromLists
    , hasRevealed
    , isQueen
    , isSolved
    , placeQueen
    , queenCount
    , revealSolution
    , size
    , squareAt
    , squares
    , threatened
    , toLists
    , toggleQueen
    )

{-| Regras e representação do tabuleiro de N-Rainhas com pedras, do lado do Elm.

Como o módulo `Sudoku`, este módulo é PURO: não faz HTTP e não sabe nada de
HTML. As regras que precisam ser instantâneas (quem ataca quem, o tabuleiro
está resolvido?) moram aqui; achar a solução é trabalho do Prolog.

-}

import Dict exposing (Dict)
import Set exposing (Set)



-- TIPOS


{-| De onde veio uma rainha.

Guardar a origem no tipo (e não numa lista à parte) deixa o compilador
garantir que toda rainha tem uma origem, e permite que a `view` mostre cada
uma de um jeito.

-}
type Origin
    = Given -- pista do puzzle: não sai do lugar
    | Placed -- colocada pelo jogador
    | Revealed -- revelada pelo Prolog (dica ou "resolver")


{-| O conteúdo de uma casa. Uma casa é EXATAMENTE uma destas três coisas:
não existe "pedra com rainha" nem "rainha sem origem".
-}
type Square
    = Free
    | Rock -- pedra: nenhuma rainha pode ficar aqui
    | Queen Origin


{-| Posição de uma casa: (linha, coluna), a partir de 0.
-}
type alias Position =
    ( Int, Int )


{-| O tabuleiro: o lado e um `Dict` com TODAS as casas, indexado pela posição.

Tuplas de inteiros são `comparable`, então podem ser chaves de `Dict`. Como a
chave é (linha, coluna), `Dict.toList` já devolve as casas em ordem de leitura.

Para que ninguém de fora monte um tabuleiro incoerente (lado 5 com 3 casas,
por exemplo), o tipo é opaco: o módulo não exporta o construtor. A única
porta de entrada é `fromLists`, que valida.

-}
type Board
    = Board
        { side : Int
        , squares : Dict Position Square
        }


{-| Lado do tabuleiro (o N das N rainhas).
-}
size : Board -> Int
size (Board board) =
    board.side



-- CONSTRUÇÃO E CONVERSÃO
--
-- O formato da API é uma lista de linhas de inteiros:
-- 0 = vazia, 1 = rainha, 2 = pedra.


{-| Tabuleiro sem nada, só casas livres. Serve de tela inicial enquanto o
primeiro puzzle não chega do servidor.
-}
empty : Int -> Board
empty side =
    let
        range =
            List.range 0 (side - 1)

        entries =
            List.concatMap
                (\row -> List.map (\col -> ( ( row, col ), Free )) range)
                range
    in
    Board { side = side, squares = Dict.fromList entries }


{-| Converte o formato da API em tabuleiro, ou explica por que não deu.

Toda rainha que chega do servidor é `Given`: no puzzle são as pistas, e na
solução só nos interessa saber ONDE há rainha (veja `revealSolution`).

-}
fromLists : List (List Int) -> Result String Board
fromLists rows =
    let
        side =
            List.length rows

        toEntry index code =
            let
                position =
                    ( index // side, modBy side index )
            in
            squareFromCode code
                |> Result.map (\square -> ( position, square ))
    in
    if side < 4 || List.any (\row -> List.length row /= side) rows then
        Err "Tabuleiro com formato inválido."

    else
        List.concat rows
            |> List.indexedMap toEntry
            |> combine
            |> Result.map (\entries -> Board { side = side, squares = Dict.fromList entries })


squareFromCode : Int -> Result String Square
squareFromCode code =
    case code of
        0 ->
            Ok Free

        1 ->
            Ok (Queen Given)

        2 ->
            Ok Rock

        _ ->
            Err ("Código de casa desconhecido: " ++ String.fromInt code)


{-| Vira uma lista de `Result` num `Result` de lista: o primeiro erro vence.
É o que o `Json.Decode.list` faz com decoders, aqui com `Result`.
-}
combine : List (Result e a) -> Result e (List a)
combine =
    List.foldr (Result.map2 (::)) (Ok [])


{-| O caminho inverso, no formato que enviamos ao backend. Toda rainha, de
qualquer origem, vira 1.
-}
toLists : Board -> List (List Int)
toLists board =
    let
        range =
            List.range 0 (size board - 1)

        code position =
            case squareAt position board of
                Just Rock ->
                    2

                Just (Queen _) ->
                    1

                _ ->
                    0
    in
    range
        |> List.map (\row -> List.map (\col -> code ( row, col )) range)



-- CONSULTAS


{-| Todas as casas com a sua posição, linha por linha (a ordem do `Dict`).
-}
squares : Board -> List ( Position, Square )
squares (Board board) =
    Dict.toList board.squares


positions : Board -> List Position
positions (Board board) =
    Dict.keys board.squares


{-| `Nothing` quando a posição está fora do tabuleiro.
-}
squareAt : Position -> Board -> Maybe Square
squareAt position (Board board) =
    Dict.get position board.squares


isQueen : Square -> Bool
isQueen square =
    case square of
        Queen _ ->
            True

        _ ->
            False


queenPositions : Board -> List Position
queenPositions (Board board) =
    board.squares
        |> Dict.filter (\_ square -> isQueen square)
        |> Dict.keys


queenCount : Board -> Int
queenCount board =
    List.length (queenPositions board)


{-| Alguma rainha veio do Prolog (dica ou "resolver")?
-}
hasRevealed : Board -> Bool
hasRevealed (Board board) =
    board.squares
        |> Dict.values
        |> List.any ((==) (Queen Revealed))



-- AS REGRAS


{-| Uma rainha em `a` ataca `b`? Mesma linha, mesma coluna ou mesma diagonal
(a diferença das linhas é igual, em módulo, à das colunas). Uma casa não ataca
a si mesma.

As pedras NÃO bloqueiam o ataque: elas só proíbem a casa.

-}
attacks : Position -> Position -> Bool
attacks ( row1, col1 ) ( row2, col2 ) =
    ( row1, col1 )
        /= ( row2, col2 )
        && (row1 == row2 || col1 == col2 || abs (row1 - row2) == abs (col1 - col2))


{-| As rainhas que são atacadas por outra rainha.
-}
conflicts : Board -> Set Position
conflicts board =
    let
        queens =
            queenPositions board
    in
    queens
        |> List.filter (\queen -> List.any (attacks queen) queens)
        |> Set.fromList


{-| As casas atacadas por alguma rainha (para o jogador ver onde NÃO pode pôr
outra).
-}
threatened : Board -> Set Position
threatened board =
    let
        queens =
            queenPositions board
    in
    positions board
        |> List.filter (\position -> List.any (attacks position) queens)
        |> Set.fromList


{-| N rainhas, e nenhuma ataca outra. As pedras já estão garantidas: o jogo
não deixa pôr rainha em cima de uma pedra.
-}
isSolved : Board -> Bool
isSolved board =
    queenCount board == size board && Set.isEmpty (conflicts board)



-- MUDANÇAS
--
-- Tudo é imutável: cada função devolve um tabuleiro NOVO.


{-| Põe uma rainha na casa, se ela estiver livre. Pedras e rainhas ficam como
estão.
-}
placeQueen : Origin -> Position -> Board -> Board
placeQueen origin position (Board board) =
    let
        place square =
            case square of
                Free ->
                    Queen origin

                _ ->
                    square
    in
    Board { board | squares = Dict.update position (Maybe.map place) board.squares }


{-| O clique do jogador: casa livre recebe uma rainha, rainha do jogador (ou
revelada) sai. Pedras e pistas não mudam.
-}
toggleQueen : Position -> Board -> Board
toggleQueen position (Board board) =
    let
        toggle square =
            case square of
                Free ->
                    Queen Placed

                Queen Placed ->
                    Free

                Queen Revealed ->
                    Free

                Queen Given ->
                    square

                Rock ->
                    square
    in
    Board { board | squares = Dict.update position (Maybe.map toggle) board.squares }


{-| Tira as rainhas do jogador e as reveladas, deixando só o puzzle original.
-}
clearPlaced : Board -> Board
clearPlaced (Board board) =
    let
        clear square =
            case square of
                Queen Placed ->
                    Free

                Queen Revealed ->
                    Free

                _ ->
                    square
    in
    Board { board | squares = Dict.map (\_ square -> clear square) board.squares }


{-| Mostra a solução devolvida pelo Prolog (`solution`) sobre o tabuleiro atual
(`board`).

  - pedras e pistas ficam como estão;
  - rainha do jogador que a solução confirma fica como está;
  - onde a solução tem rainha e a casa está livre, aparece uma rainha revelada;
  - qualquer outra rainha (errada) some.

-}
revealSolution : Board -> Board -> Board
revealSolution solution (Board board) =
    let
        merge position current =
            case ( current, squareAt position solution ) of
                ( Rock, _ ) ->
                    Rock

                ( Queen Given, _ ) ->
                    current

                ( Queen Placed, Just (Queen _) ) ->
                    current

                ( _, Just (Queen _) ) ->
                    Queen Revealed

                _ ->
                    Free
    in
    Board { board | squares = Dict.map merge board.squares }
