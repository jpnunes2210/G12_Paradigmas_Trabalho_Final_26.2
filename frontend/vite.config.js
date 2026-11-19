// Configuração do Vite: servidor de desenvolvimento com hot reload.
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import elm from "vite-plugin-elm"; // compila arquivos .elm importados no JS
import tailwindcss from "@tailwindcss/vite"; // gera o CSS do Tailwind/daisyUI

export default defineConfig({
  plugins: [elm(), tailwindcss()],
  // O site tem duas páginas (Sudoku e N-Rainhas). Em desenvolvimento o Vite
  // serve as duas sozinho; no `npm run build` precisamos listar cada uma.
  build: {
    rollupOptions: {
      input: {
        sudoku: fileURLToPath(new URL("index.html", import.meta.url)),
        queens: fileURLToPath(new URL("queens.html", import.meta.url)),
      },
    },
  },
  server: {
    // Toda requisição para /api/... é repassada ao backend FastAPI. Assim o
    // frontend e o backend parecem estar no mesmo endereço, e não precisamos
    // configurar CORS.
    proxy: {
      "/api": "http://localhost:8000",
    },
  },
});