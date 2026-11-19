// Tema claro/escuro, compartilhado pelas páginas que usam este módulo.
//
// A escolha fica no localStorage sob a MESMA chave que o main.js do Sudoku
// usa, então trocar o tema numa página vale também para a outra.

const THEME_KEY = "sudoku-theme";

// Tema inicial: a última escolha do jogador ou, na primeira visita, a
// preferência do sistema operacional. Devolve `true` para o tema escuro.
export function initialDarkTheme() {
  const savedTheme = localStorage.getItem(THEME_KEY);
  const systemIsDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  return savedTheme ? savedTheme === "dark" : systemIsDark;
}

// Guarda a escolha quando o botão sol/lua muda. Ouvimos o `document` inteiro
// ("delegação de eventos") porque o checkbox é criado pelo Elm e pode ser
// recriado a qualquer momento.
export function rememberThemeChanges() {
  document.addEventListener("change", (event) => {
    if (event.target.matches(".theme-controller")) {
      localStorage.setItem(THEME_KEY, event.target.checked ? "dark" : "light");
    }
  });
}
