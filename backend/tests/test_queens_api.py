"""Testes da API das N-Rainhas (pytest).

Como em test_api.py, conferimos só a "cola": rotas, formato do JSON e códigos
de status. As regras do jogo são testadas em prolog/test_queens.pl.

Rodar: `uv run pytest` (na pasta backend) ou `make test-backend` (na raiz).
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

# O mesmo puzzle de example_queens/2 em queens.pl (0 vazio, 1 rainha, 2 pedra).
# A meta é 7 rainhas num 6x6: a pedra em (1, 3) corta a linha e a coluna.
EXAMPLE = [
    [0, 0, 0, 0, 0, 0],
    [0, 0, 0, 2, 0, 0],
    [0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0],
    [0, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0],
]
GOAL = 7

# A única solução do exemplo: duas rainhas na linha 1 e duas na coluna 3.
EXAMPLE_SOLUTION = [
    [0, 0, 0, 1, 0, 0],
    [1, 0, 0, 2, 0, 1],
    [0, 0, 1, 0, 0, 0],
    [0, 0, 0, 0, 1, 0],
    [0, 1, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 0],
]


def post(route: str, board, goal: int = GOAL):
    return client.post(f"/api/queens/{route}", json={"board": board, "goal": goal})


def test_solve():
    response = post("solve", EXAMPLE)
    assert response.status_code == 200
    assert response.json()["board"] == EXAMPLE_SOLUTION


def test_solve_without_solution():
    board = [row[:] for row in EXAMPLE]
    board[3][0] = 1  # ataca a rainha fixa de (4, 1) na diagonal
    response = post("solve", board)
    assert response.status_code == 422
    assert "nenhuma solução" in response.json()["detail"]


def test_solve_rejects_non_square_board():
    # Quem rejeita aqui é o Pydantic, antes de o Prolog ser chamado.
    board = [[0, 0, 0, 0] for _ in range(5)]
    response = post("solve", board)
    assert response.status_code == 422


def test_solve_rejects_unknown_square_code():
    board = [row[:] for row in EXAMPLE]
    board[2][2] = 3
    response = post("solve", board)
    assert response.status_code == 422


def test_solve_requires_goal():
    response = client.post("/api/queens/solve", json={"board": EXAMPLE})
    assert response.status_code == 422


def test_solve_rejects_zero_goal():
    response = post("solve", EXAMPLE, goal=0)
    assert response.status_code == 422


def test_generate():
    response = client.post("/api/queens/generate", json={"size": 6, "difficulty": "easy"})
    assert response.status_code == 200
    body = response.json()
    board = body["board"]
    assert len(board) == 6 and all(len(row) == 6 for row in board)
    assert 1 in sum(board, [])  # no nível fácil há rainha fixa
    assert body["goal"] > 6  # a meta passa de N: as pedras são necessárias


def test_generate_rejects_bad_size():
    response = client.post("/api/queens/generate", json={"size": 5})
    assert response.status_code == 422


def test_generated_puzzle_can_be_solved():
    puzzle = client.post("/api/queens/generate", json={"size": 6}).json()
    response = post("solve", puzzle["board"], puzzle["goal"])
    assert response.status_code == 200
    solved = response.json()["board"]
    assert sum(row.count(1) for row in solved) == puzzle["goal"]


def test_hint():
    response = post("hint", EXAMPLE)
    assert response.status_code == 200
    hint = response.json()
    assert EXAMPLE[hint["row"]][hint["col"]] == 0  # a dica é para uma casa vazia
    assert EXAMPLE_SOLUTION[hint["row"]][hint["col"]] == 1


def test_hint_on_complete_board():
    response = post("hint", EXAMPLE_SOLUTION)
    assert response.status_code == 422
    assert response.json()["detail"] == "Todas as rainhas já estão no tabuleiro."


def test_hint_with_conflicting_queens():
    board = [row[:] for row in EXAMPLE]
    board[3][0] = 1
    response = post("hint", board)
    assert response.status_code == 422
    assert "nenhuma solução" in response.json()["detail"]


def test_count_solutions_example():
    response = post("count", EXAMPLE)
    assert response.status_code == 200
    assert response.json()["count"] == 1


def test_count_solutions_empty_board():
    # Sem pedras e com meta N é o clássico: o 4x4 vazio tem 2 soluções.
    empty_4x4 = [[0] * 4 for _ in range(4)]
    response = post("count", empty_4x4, goal=4)
    assert response.status_code == 200
    assert response.json()["count"] == 2


def test_count_solutions_unsolvable():
    board = [row[:] for row in EXAMPLE]
    board[3][0] = 1  # conflito
    response = post("count", board)
    assert response.status_code == 200
    assert response.json()["count"] == 0
