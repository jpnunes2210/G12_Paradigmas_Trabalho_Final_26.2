// Ponto de entrada JavaScript da página das N-Rainhas (veja queens.html).
//
// Use o MESMO estilo do main.js: se trocar para o style-simples.css lá,
// troque aqui também.
import "./style.css";

import { Elm } from "./Queens.elm";
import { initialDarkTheme, rememberThemeChanges } from "./theme.js";

// `flags` é entregue à função `init` do Elm (veja o tipo Flags em Queens.elm).
Elm.Queens.init({
  node: document.getElementById("app"),
  flags: { darkTheme: initialDarkTheme() },
});

rememberThemeChanges();
