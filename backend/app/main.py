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
# N-Rainhas com pedras
#
# O tabuleiro tem de 4x4 a 12x12 e cada casa é 0 (vazia), 1 (rainha) ou
# 2 (pedra). Aqui só validamos o FORMATO (quadrado, tamanho, códigos); quem
# decide se o tabuleiro tem solução é o Prolog.
# ---------------------------------------------------------------------------

MIN_SIZE, MAX_SIZE = 4, 12

QueensCell = Annotated[int, Field(ge=0, le=2)]
QueensRow = Annotated[list[QueensCell], Field(min_length=MIN_SIZE, max_length=MAX_SIZE)]
QueensGrid = Annotated[list[QueensRow], Field(min_length=MIN_SIZE, max_length=MAX_SIZE)]


class QueensGenerateRequest(BaseModel):
    size: Annotated[int, Field(ge=MIN_SIZE, le=MAX_SIZE)] = 8
    difficulty: Literal["easy", "medium", "hard"] = "medium"


class QueensBoardRequest(BaseModel):
    board: QueensGrid

    @field_validator("board")
    @classmethod
    def board_must_be_square(cls, board: QueensGrid) -> QueensGrid:
        if any(len(row) != len(board) for row in board):
            raise ValueError("o tabuleiro precisa ser quadrado")
        return board


class QueensBoardResponse(BaseModel):
    board: QueensGrid


class QueensHintResponse(BaseModel):
    row: int
    col: int


QUEENS_NO_SOLUTION = (
    "Estas rainhas não levam a nenhuma solução. Tire alguma e tente de novo."
)
QUEENS_COMPLETE = "Todas as rainhas já estão no tabuleiro."


@app.post("/api/queens/generate")
def queens_generate(request: QueensGenerateRequest) -> QueensBoardResponse:
    board = prolog.queens_generate(request.size, request.difficulty)
    return QueensBoardResponse(board=board)


@app.post("/api/queens/solve")
def queens_solve(request: QueensBoardRequest) -> QueensBoardResponse:
    try:
        return QueensBoardResponse(board=prolog.queens_solve(request.board))
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=QUEENS_NO_SOLUTION) from None


@app.post("/api/queens/hint")
def queens_hint(request: QueensBoardRequest) -> QueensHintResponse:
    try:
        row, col = prolog.queens_hint(request.board)
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=QUEENS_NO_SOLUTION) from None
    except prolog.BoardComplete:
        raise HTTPException(status_code=422, detail=QUEENS_COMPLETE) from None
    return QueensHintResponse(row=row, col=col)