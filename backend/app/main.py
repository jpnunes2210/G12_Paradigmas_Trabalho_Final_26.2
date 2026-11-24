"""API HTTP do Sudoku.

Esta camada é só "cola": recebe JSON, valida o formato com Pydantic, chama o
Prolog (via app/prolog.py) e devolve JSON. Nenhuma regra do jogo mora aqui.

Rodar em modo de desenvolvimento (recarrega ao salvar):
    uv run fastapi dev app/main.py

Documentação interativa gerada automaticamente: http://localhost:8000/docs
"""

from typing import Annotated, Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, field_validator

from app import prolog

app = FastAPI(title="Sudoku e N-Rainhas (Prolog + Elm)")

# Uma linha tem exatamente 9 inteiros de 0 a 9; um tabuleiro tem 9 linhas.
# O Pydantic rejeita automaticamente (erro 422) qualquer coisa fora disso.
Cell = Annotated[int, Field(ge=0, le=9)]
Row = Annotated[list[Cell], Field(min_length=9, max_length=9)]
Grid = Annotated[list[Row], Field(min_length=9, max_length=9)]


class GenerateRequest(BaseModel):
    difficulty: Literal["easy", "medium", "hard"] = "medium"


class BoardRequest(BaseModel):
    board: Grid


class BoardResponse(BaseModel):
    board: Grid


class HintResponse(BaseModel):
    row: int
    col: int
    value: int


# Mensagens que o Elm mostra na tela quando a resposta é 422.
NO_SOLUTION = "Este tabuleiro não tem solução. Confira os números preenchidos."
BOARD_COMPLETE = "O tabuleiro já está completo."


@app.post("/api/generate")
def generate(request: GenerateRequest) -> BoardResponse:
    return BoardResponse(board=prolog.generate(request.difficulty))


@app.post("/api/solve")
def solve(request: BoardRequest) -> BoardResponse:
    try:
        return BoardResponse(board=prolog.solve(request.board))
    except prolog.NoSolution:
        # `from None` diz que a HTTPException SUBSTITUI a exceção original,
        # em vez de ser "causada" por ela; o traceback fica mais limpo.
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None


@app.post("/api/hint")
def hint(request: BoardRequest) -> HintResponse:
    try:
        row, col, value = prolog.hint(request.board)
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None
    except prolog.BoardComplete:
        raise HTTPException(status_code=422, detail=BOARD_COMPLETE) from None
    return HintResponse(row=row, col=col, value=value)


# ---------------------------------------------------------------------------
# Rainhas atrás das pedras
#
# O tabuleiro tem de 4x4 a 12x12 e cada casa é 0 (vazia), 1 (rainha) ou
# 2 (pedra). Junto vai a meta (`goal`): quantas rainhas o puzzle pede. Aqui só
# validamos o FORMATO (quadrado, tamanho, códigos, meta positiva); quem decide
# se o tabuleiro tem solução é o Prolog. O gerador começa em 6x6, porque em
# tabuleiros menores não cabe a rainha extra que a regra das pedras exige.
# ---------------------------------------------------------------------------

MIN_SIZE, MAX_SIZE = 4, 12
MIN_GENERATED_SIZE = 6

QueensCell = Annotated[int, Field(ge=0, le=2)]
QueensRow = Annotated[list[QueensCell], Field(min_length=MIN_SIZE, max_length=MAX_SIZE)]
QueensGrid = Annotated[list[QueensRow], Field(min_length=MIN_SIZE, max_length=MAX_SIZE)]
Goal = Annotated[int, Field(ge=1, le=MAX_SIZE * MAX_SIZE)]


class QueensGenerateRequest(BaseModel):
    size: Annotated[int, Field(ge=MIN_GENERATED_SIZE, le=MAX_SIZE)] = 8
    difficulty: Literal["easy", "medium", "hard"] = "medium"


class QueensBoardRequest(BaseModel):
    board: QueensGrid
    goal: Goal

    @field_validator("board")
    @classmethod
    def board_must_be_square(cls, board: QueensGrid) -> QueensGrid:
        if any(len(row) != len(board) for row in board):
            raise ValueError("o tabuleiro precisa ser quadrado")
        return board


class QueensPuzzleResponse(BaseModel):
    board: QueensGrid
    goal: Goal


class QueensBoardResponse(BaseModel):
    board: QueensGrid


class QueensHintResponse(BaseModel):
    row: int
    col: int


class QueensCountResponse(BaseModel):
    count: int


QUEENS_NO_SOLUTION = (
    "Estas rainhas não levam a nenhuma solução. Tire alguma e tente de novo."
)
QUEENS_COMPLETE = "Todas as rainhas já estão no tabuleiro."


@app.post("/api/queens/generate")
def queens_generate(request: QueensGenerateRequest) -> QueensPuzzleResponse:
    board, goal = prolog.queens_generate(request.size, request.difficulty)
    return QueensPuzzleResponse(board=board, goal=goal)


@app.post("/api/queens/solve")
def queens_solve(request: QueensBoardRequest) -> QueensBoardResponse:
    try:
        return QueensBoardResponse(board=prolog.queens_solve(request.board, request.goal))
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=QUEENS_NO_SOLUTION) from None


@app.post("/api/queens/hint")
def queens_hint(request: QueensBoardRequest) -> QueensHintResponse:
    try:
        row, col = prolog.queens_hint(request.board, request.goal)
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=QUEENS_NO_SOLUTION) from None
    except prolog.BoardComplete:
        raise HTTPException(status_code=422, detail=QUEENS_COMPLETE) from None
    return QueensHintResponse(row=row, col=col)


@app.post("/api/queens/count")
def queens_count(request: QueensBoardRequest) -> QueensCountResponse:
    count = prolog.queens_count(request.board, request.goal)
    return QueensCountResponse(count=count)


@app.post("/api/queens/trace")
def queens_trace(request: QueensBoardRequest) -> QueensTraceResponse:
    """Passo a passo do backtracking do Prolog, para animar no Elm."""
    steps, status = prolog.queens_trace(request.board)
    return QueensTraceResponse(steps=steps, status=status)
