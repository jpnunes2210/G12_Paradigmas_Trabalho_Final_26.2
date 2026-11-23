"""Testes da API das N-Rainhas (pytest).

Como em test_api.py, conferimos só a "cola": rotas, formato do JSON e códigos
de status. As regras do jogo são testadas em prolog/test_queens.pl.

Rodar: `uv run pytest` (na pasta backend) ou `make test-backend` (na raiz).
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

# O mesmo puzzle de example_queens/1 em queens.pl (0 vazio, 1 rainha, 2 pedra).
EXAMPLE = [
    [0, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0],
    [2, 0, 0, 0, 0, 2],
]

# A única solução do exemplo: colunas [1, 3, 5, 0, 2, 4], uma por linha.
EXAMPLE_SOLUTION = [
    [0, 1, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 0],
    [0, 0, 0, 0, 0, 1],
    [1, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 0, 0],
    [2, 0, 0, 0, 1, 2],
]


def test_solve():
    response = client.post("/api/queens/solve", json={"board": EXAMPLE})
    assert response.status_code == 200
    assert response.json()["board"] == EXAMPLE_SOLUTION


def test_solve_without_solution():
    board = [row[:] for row in EXAMPLE]
    board[1][0] = 1  # ataca a rainha fixa de (0, 1) na diagonal
    response = client.post("/api/queens/solve", json={"board": board})
    assert response.status_code == 422
    assert "nenhuma solução" in response.json()["detail"]


def test_solve_rejects_non_square_board():
    # Quem rejeita aqui é o Pydantic, antes de o Prolog ser chamado.
    board = [[0, 0, 0, 0] for _ in range(5)]
    response = client.post("/api/queens/solve", json={"board": board})
    assert response.status_code == 422


def test_solve_rejects_unknown_square_code():
    board = [row[:] for row in EXAMPLE]
    board[2][2] = 3
    response = client.post("/api/queens/solve", json={"board": board})
    assert response.status_code == 422


def test_generate():
    response = client.post("/api/queens/generate", json={"size": 6, "difficulty": "easy"})
    assert response.status_code == 200
    board = response.json()["board"]
    assert len(board) == 6 and all(len(row) == 6 for row in board)
    assert 1 in sum(board, [])  # no nível fácil há rainha fixa


def test_generate_rejects_bad_size():
    response = client.post("/api/queens/generate", json={"size": 3})
    assert response.status_code == 422


def test_generated_puzzle_can_be_solved():
    board = client.post("/api/queens/generate", json={"size": 6}).json()["board"]
    response = client.post("/api/queens/solve", json={"board": board})
    assert response.status_code == 200
    solved = response.json()["board"]
    assert sum(row.count(1) for row in solved) == 6  # uma rainha por linha


def test_hint():
    response = client.post("/api/queens/hint", json={"board": EXAMPLE})
    assert response.status_code == 200
    hint = response.json()
    assert 1 not in EXAMPLE[hint["row"]]  # a dica é para uma linha sem rainha
    assert EXAMPLE_SOLUTION[hint["row"]][hint["col"]] == 1


def test_hint_on_complete_board():
    response = client.post("/api/queens/hint", json={"board": EXAMPLE_SOLUTION})
    assert response.status_code == 422
    assert response.json()["detail"] == "Todas as rainhas já estão no tabuleiro."


def test_hint_with_conflicting_queens():
    board = [row[:] for row in EXAMPLE]
    board[1][0] = 1
    response = client.post("/api/queens/hint", json={"board": board})
    assert response.status_code == 422
    assert "nenhuma solução" in response.json()["detail"]


def test_count_solutions_example():
    response = client.post("/api/queens/count", json={"board": EXAMPLE})
    assert response.status_code == 200
    assert response.json()["count"] == 1


def test_count_solutions_empty_board():
    # Tabuleiro 4x4 vazio tem exatamente 2 soluções
    empty_4x4 = [[0] * 4 for _ in range(4)]
    response = client.post("/api/queens/count", json={"board": empty_4x4})
    assert response.status_code == 200
    assert response.json()["count"] == 2


def test_count_solutions_unsolvable():
    board = [row[:] for row in EXAMPLE]
    board[1][0] = 1  # conflito
    response = client.post("/api/queens/count", json={"board": board})
    assert response.status_code == 200
    assert response.json()["count"] == 0



def test_trace_example():
    response = client.post("/api/queens/trace", json={"board": EXAMPLE})
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "solved"
    assert body["steps"][0] == ["conflito", 1, 0]
    assert {kind for kind, _, _ in body["steps"]} <= {"coloca", "conflito", "remove"}


def test_trace_backtracks_on_empty_4x4():
    empty_4x4 = [[0] * 4 for _ in range(4)]
    response = client.post("/api/queens/trace", json={"board": empty_4x4})
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "solved"
    assert ["remove", 1, 2] in body["steps"]


def test_trace_unsolvable():
    board = [row[:] for row in EXAMPLE]
    board[1][0] = 1  # conflito com a pista (0,1)
    response = client.post("/api/queens/trace", json={"board": board})
    assert response.status_code == 200
    assert response.json() == {"steps": [], "status": "unsolvable"}
