module Queens exposing (main)

{-| Interface gráfica das N-Rainhas com pedras.

É uma segunda aplicação Elm, independente da do Sudoku (veja `queens.html` e
`queens.js`), mas segue a mesma Arquitetura Elm: `Model`, `Msg`, `update`,
`view`. Ela reaproveita o que já existia: o tipo `Difficulty`, o tratamento de
erros HTTP (`Api`) e as classes do CSS (cabeçalho, painel, botões).

O que é novo fica em dois módulos:

  - `QueensBoard`: o tabuleiro e as regras (puro, sem HTTP nem HTML);
  - `QueensApi`: as requisições ao backend.

Como jogar: ponha N rainhas sem que duas se ataquem. As pedras (casas
escuras com um triângulo) não aceitam rainha, e as rainhas fixas (pistas)
não saem do lugar.

-}

import Api exposing (Difficulty(..), difficultyLabel)
import Browser
import Html exposing (Html, a, aside, button, div, footer, h1, header, input, label, main_, nav, span, text)
import Html.Attributes exposing (attribute, checked, class, classList, disabled, href, type_, value)
import Html.Events exposing (onCheck, onClick)
import QueensApi
import QueensBoard exposing (Board, Origin(..), Position, Square(..))
import Set exposing (Set)
import Time



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- MODEL


{-| Dados que o JavaScript entrega na inicialização (veja `queens.js`).
-}
type alias Flags =
    { darkTheme : Bool
    }


type alias Model =
    { board : Board
    , size : Int
    , difficulty : Difficulty
    , showThreats : Bool
    , darkTheme : Bool
    , loading : Bool
    , error : Maybe String
    , history : List Board
    , future : List Board
    , elapsedSeconds : Int
    , hintsUsed : Int
    }


{-| Tamanhos oferecidos na tela. O Prolog aceita de 4 a 12, mas nos níveis
difíceis os tabuleiros grandes precisam de dezenas de pedras e demoram mais
para ser gerados.
-}
sizes : List Int
sizes =
    [ 6, 8, 10 ]


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { board = QueensBoard.empty 8
            , size = 8
            , difficulty = Medium
            , showThreats = False
            , darkTheme = flags.darkTheme
            , loading = True
            , error = Nothing
            , history = []
            , future = []
            , elapsedSeconds = 0
            , hintsUsed = 0
            }
    in
    ( model, generate model )


{-| Pede um puzzle novo com o tamanho e a dificuldade do modelo.
-}
generate : Model -> Cmd Msg
generate model =
    QueensApi.generate model.size model.difficulty GotPuzzle


subscriptions : Model -> Sub Msg
subscriptions model =
    if not model.loading && not (QueensBoard.isSolved model.board) then
        Time.every 1000 Tick

    else
        Sub.none



-- UPDATE


type Msg
    = NewGame
    | SizeChosen Int
    | DifficultyChosen Difficulty
    | GotPuzzle (Result String Board)
    | SquareClicked Position
    | Undo
    | Redo
    | Tick Time.Posix
    | ThreatsToggled Bool
    | ThemeToggled Bool
    | HintRequested
    | GotHint (Result String QueensApi.Hint)
    | SolveRequested
    | GotSolution (Result String Board)
    | ResetRequested
    | ErrorDismissed


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewGame ->
            startGame model

        SizeChosen size ->
            startGame { model | size = size }

        DifficultyChosen difficulty ->
            startGame { model | difficulty = difficulty }

        GotPuzzle (Ok board) ->
            ( { model
                | board = board
                , loading = False
                , history = []
                , future = []
                , elapsedSeconds = 0
                , hintsUsed = 0
              }
            , Cmd.none
            )

        GotPuzzle (Err error) ->
            ( failed error model, Cmd.none )

        SquareClicked position ->
            -- Enquanto o Prolog trabalha, o tabuleiro na tela está para ser
            -- trocado: ignoramos os cliques.
            if model.loading then
                ( model, Cmd.none )

            else
                let
                    newBoard =
                        QueensBoard.toggleQueen position model.board
                in
                if newBoard == model.board then
                    ( model, Cmd.none )

                else
                    ( { model
                        | board = newBoard
                        , history = model.board :: model.history
                        , future = []
                      }
                    , Cmd.none
                    )

        Undo ->
            case model.history of
                prev :: rest ->
                    ( { model
                        | board = prev
                        , history = rest
                        , future = model.board :: model.future
                      }
                    , Cmd.none
                    )

                [] ->
                    ( model, Cmd.none )

        Redo ->
            case model.future of
                next :: rest ->
                    ( { model
                        | board = next
                        , history = model.board :: model.history
                        , future = rest
                      }
                    , Cmd.none
                    )

                [] ->
                    ( model, Cmd.none )

        Tick _ ->
            if model.loading || QueensBoard.isSolved model.board then
                ( model, Cmd.none )

            else
                ( { model | elapsedSeconds = model.elapsedSeconds + 1 }, Cmd.none )

        ThreatsToggled show ->
            ( { model | showThreats = show }, Cmd.none )

        ThemeToggled dark ->
            ( { model | darkTheme = dark }, Cmd.none )

        HintRequested ->
            ( { model | loading = True, error = Nothing }
            , QueensApi.hint model.board GotHint
            )

        GotHint (Ok { row, col }) ->
            let
                newBoard =
                    QueensBoard.placeQueen Revealed ( row, col ) model.board
            in
            ( { model
                | board = newBoard
                , loading = False
                , history = model.board :: model.history
                , future = []
                , hintsUsed = model.hintsUsed + 1
              }
            , Cmd.none
            )

        GotHint (Err error) ->
            ( failed error model, Cmd.none )

        SolveRequested ->
            -- Mandamos só o puzzle original: um palpite errado do jogador
            -- não deve impedir o Prolog de achar a solução.
            ( { model | loading = True, error = Nothing }
            , QueensApi.solve (QueensBoard.clearPlaced model.board) GotSolution
            )

        GotSolution (Ok solution) ->
            let
                newBoard =
                    QueensBoard.revealSolution solution model.board
            in
            ( { model
                | board = newBoard
                , loading = False
                , history = model.board :: model.history
                , future = []
              }
            , Cmd.none
            )

        GotSolution (Err error) ->
            ( failed error model, Cmd.none )

        ResetRequested ->
            let
                newBoard =
                    QueensBoard.clearPlaced model.board
            in
            if newBoard == model.board then
                ( { model | error = Nothing }, Cmd.none )

            else
                ( { model
                    | board = newBoard
                    , history = model.board :: model.history
                    , future = []
                    , error = Nothing
                  }
                , Cmd.none
                )

        ErrorDismissed ->
            ( { model | error = Nothing }, Cmd.none )


startGame : Model -> ( Model, Cmd Msg )
startGame model =
    ( { model | loading = True, error = Nothing }, generate model )


failed : String -> Model -> Model
failed error model =
    { model | loading = False, error = Just error }



-- VIEW
--
-- As classes são semânticas, como no Sudoku: o Elm diz O QUE o elemento é
-- ("square", "square--rock") e o CSS (style.css) diz como ele aparece.


view : Model -> Html Msg
view model =
    div [ class "app" ]
        [ header [ class "app-header" ]
            [ div [ class "app-container app-header-content" ]
                [ h1 [ class "app-title" ] [ text "N-Rainhas" ]
                , span [ class "app-subtitle" ] [ text "Prolog + Elm" ]
                , viewNav
                , viewThemeToggle model
                ]
            ]
        , main_ [ class "app-main" ]
            [ div [ class "app-container game" ]
                [ viewBoard model
                , aside [ class "side-panel" ]
                    [ span [ class "panel-label" ] [ text "Novo jogo" ]
                    , viewSizePicker model
                    , viewDifficulty model
                    , div [ class "message-area" ] [ viewMessages model ]
                    , viewStats model
                    , viewHistoryControls model
                    , span [ class "panel-label" ] [ text "Ajuda" ]
                    , viewThreatsToggle model
                    , viewActions model
                    ]
                ]
            ]
        , footer [ class "app-footer" ]
            [ text "Clique numa casa para pôr ou tirar uma rainha. As pedras e as rainhas fixas não se movem." ]
        ]


{-| Troca entre os dois jogos. São duas páginas, então são links comuns.
-}
viewNav : Html msg
viewNav =
    nav [ class "nav" ]
        [ a [ class "nav-link", href "/" ] [ text "Sudoku" ]
        , a [ class "nav-link nav-link--active", attribute "aria-current" "page", href "/queens.html" ] [ text "N-Rainhas" ]
        ]


{-| Botão sol/lua, igual ao do Sudoku (componente `theme-controller` do
daisyUI; veja `Main.viewThemeToggle` para os detalhes).
-}
viewThemeToggle : Model -> Html Msg
viewThemeToggle model =
    label [ class "theme-toggle", attribute "aria-label" "Alternar tema claro/escuro" ]
        [ input
            [ type_ "checkbox"
            , class "theme-controller"
            , value "dark"
            , checked model.darkTheme
            , onCheck ThemeToggled
            ]
            []
        , span [ class "swap-off" ] [ text "☀" ]
        , span [ class "swap-on" ] [ text "☾" ]
        ]


{-| Escolha do tamanho. Reaproveita as classes do seletor de dificuldade.
-}
viewSizePicker : Model -> Html Msg
viewSizePicker model =
    let
        option size =
            button
                [ class "difficulty-option"
                , classList [ ( "difficulty-option--active", size == model.size ) ]
                , disabled model.loading
                , onClick (SizeChosen size)
                ]
                [ text (String.fromInt size ++ " × " ++ String.fromInt size) ]
    in
    div [ class "difficulty-picker" ] (List.map option sizes)


viewDifficulty : Model -> Html Msg
viewDifficulty model =
    let
        option difficulty =
            button
                [ class "difficulty-option"
                , classList [ ( "difficulty-option--active", difficulty == model.difficulty ) ]
                , disabled model.loading
                , onClick (DifficultyChosen difficulty)
                ]
                [ text (difficultyLabel difficulty) ]
    in
    div [ class "difficulty-picker" ] (List.map option [ Easy, Medium, Hard ])


viewMessages : Model -> Html Msg
viewMessages model =
    case ( model.error, model.loading ) of
        ( Just error, _ ) ->
            div [ class "message message--error" ]
                [ span [] [ text error ]
                , button [ class "message-close", onClick ErrorDismissed ] [ text "✕" ]
                ]

        ( Nothing, True ) ->
            div [ class "message message--loading" ]
                [ span [ class "spinner" ] []
                , span [] [ text "O Prolog está pensando..." ]
                ]

        ( Nothing, False ) ->
            if QueensBoard.isSolved model.board then
                viewVictoryCard model

            else
                text ""


viewVictoryCard : Model -> Html Msg
viewVictoryCard model =
    let
        hasRevealed =
            QueensBoard.hasRevealed model.board

        headline =
            if hasRevealed then
                "Resolvido com o Prolog!"

            else if model.hintsUsed == 0 then
                "Vitória Impecável! 🏆"

            else
                "Parabéns! Todas as rainhas em paz! 🎉"

        detailText =
            if hasRevealed then
                "A solução completa foi calculada pelo Prolog."

            else if model.hintsUsed == 0 then
                "Você resolveu todo o desafio sem pedir nenhuma dica!"

            else
                "Você completou o tabuleiro utilizando "
                    ++ String.fromInt model.hintsUsed
                    ++ (if model.hintsUsed == 1 then
                            " dica."

                        else
                            " dicas."
                       )
    in
    div [ class "message message--success victory-card" ]
        [ div [ class "victory-headline" ] [ text headline ]
        , div [ class "victory-detail" ] [ text detailText ]
        , div [ class "victory-summary-stats" ]
            [ span [ class "victory-badge" ] [ text ("⏱️ " ++ formatTime model.elapsedSeconds) ]
            , span [ class "victory-badge" ] [ text ("💡 " ++ String.fromInt model.hintsUsed ++ " dicas") ]
            ]
        ]


formatTime : Int -> String
formatTime totalSeconds =
    let
        minutes =
            totalSeconds // 60

        seconds =
            modBy 60 totalSeconds

        pad n =
            if n < 10 then
                "0" ++ String.fromInt n

            else
                String.fromInt n
    in
    pad minutes ++ ":" ++ pad seconds


viewStats : Model -> Html Msg
viewStats model =
    div [ class "queens-stats" ]
        [ div [ class "queens-stat-item", attribute "title" "Tempo decorrido" ]
            [ span [ class "queens-stat-icon" ] [ text "⏱️" ]
            , span [ class "queens-stat-value" ] [ text (formatTime model.elapsedSeconds) ]
            ]
        , div [ class "queens-stat-item", attribute "title" "Dicas utilizadas" ]
            [ span [ class "queens-stat-icon" ] [ text "💡" ]
            , span [ class "queens-stat-value" ] [ text (String.fromInt model.hintsUsed ++ " dicas") ]
            ]
        , div [ class "queens-stat-item", attribute "title" "Rainhas no tabuleiro" ]
            [ span [ class "queens-stat-icon" ] [ text "♛" ]
            , span [ class "queens-stat-value" ]
                [ text
                    (String.fromInt (QueensBoard.queenCount model.board)
                        ++ " / "
                        ++ String.fromInt (QueensBoard.size model.board)
                    )
                ]
            ]
        ]


viewHistoryControls : Model -> Html Msg
viewHistoryControls model =
    div [ class "history-controls" ]
        [ button
            [ class "action-button action-button--history"
            , disabled (model.loading || List.isEmpty model.history)
            , onClick Undo
            ]
            [ text "↶ Desfazer" ]
        , button
            [ class "action-button action-button--history"
            , disabled (model.loading || List.isEmpty model.future)
            , onClick Redo
            ]
            [ text "↷ Refazer" ]
        ]


viewThreatsToggle : Model -> Html Msg
viewThreatsToggle model =
    label [ class "threat-toggle" ]
        [ input
            [ type_ "checkbox"
            , class "threat-toggle-input"
            , checked model.showThreats
            , onCheck ThreatsToggled
            ]
            []
        , text "Mostrar casas atacadas"
        ]


viewActions : Model -> Html Msg
viewActions model =
    let
        nothingToReveal =
            model.loading || QueensBoard.isSolved model.board
    in
    div [ class "actions" ]
        [ button [ class "action-button action-button--hint", disabled nothingToReveal, onClick HintRequested ] [ text "Dica" ]
        , button [ class "action-button action-button--solve", disabled nothingToReveal, onClick SolveRequested ] [ text "Resolver" ]
        , button [ class "action-button action-button--reset", disabled model.loading, onClick ResetRequested ] [ text "Limpar" ]
        ]


viewBoard : Model -> Html Msg
viewBoard model =
    let
        conflicts =
            QueensBoard.conflicts model.board

        threats =
            if model.showThreats then
                QueensBoard.threatened model.board

            else
                Set.empty
    in
    div
        [ class "queens-board"
        , classList [ ( "queens-board--solved", QueensBoard.isSolved model.board ) ]

        -- O CSS lê o lado do tabuleiro em `var(--n)`. O Elm só informa o
        -- número; quem calcula tamanhos e cores é o CSS.
        , attribute "style" ("--n: " ++ String.fromInt (QueensBoard.size model.board))
        ]
        (List.map (viewSquare conflicts threats) (QueensBoard.squares model.board))


viewSquare : Set Position -> Set Position -> ( Position, Square ) -> Html Msg
viewSquare conflicts threats ( position, square ) =
    let
        ( row, col ) =
            position
    in
    button
        [ class "square"
        , classList
            [ ( "square--dark", modBy 2 (row + col) == 1 )
            , ( "square--rock", square == Rock )
            , ( "square--queen", QueensBoard.isQueen square )
            , ( "square--given", square == Queen Given )
            , ( "square--placed", square == Queen Placed )
            , ( "square--revealed", square == Queen Revealed )
            , ( "square--conflict", Set.member position conflicts )
            , ( "square--threatened", square == Free && Set.member position threats )
            ]
        , attribute "aria-label" (squareLabel position square)
        , onClick (SquareClicked position)
        ]
        [ viewPiece square ]


viewPiece : Square -> Html msg
viewPiece square =
    case square of
        Queen _ ->
            span [ class "square-piece" ] [ text "♛" ]

        Rock ->
            span [ class "square-rock" ] []

        Free ->
            text ""


{-| Texto lido pelos leitores de tela (acessibilidade).
-}
squareLabel : Position -> Square -> String
squareLabel ( row, col ) square =
    let
        description =
            case square of
                Free ->
                    "vazia"

                Rock ->
                    "pedra"

                Queen Given ->
                    "rainha fixa"

                Queen Placed ->
                    "rainha"

                Queen Revealed ->
                    "rainha revelada pelo Prolog"
    in
    "Linha "
        ++ String.fromInt (row + 1)
        ++ ", coluna "
        ++ String.fromInt (col + 1)
        ++ ": "
        ++ description
